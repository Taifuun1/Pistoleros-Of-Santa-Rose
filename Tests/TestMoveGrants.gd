extends SceneTree

## Headless validation for canonical class/equipment Move grants and the active
## loadout (Docs/System Design/First Steps Implementation Plan.md, commit 11):
## grant origins, the four-Move cap, activation commands, equipment-swap gating,
## generation passthrough and snapshot round trips.
## Run with: godot --headless --script res://Tests/TestMoveGrants.gd

const PartyScript = preload("res://Globals/Party.gd")
const ProjectorScript = preload("res://Globals/CombatLoadoutProjector.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")

const MEMBER_KEY := "Fixture Hand"
const CLASS_NAME := "Fixture Class"
const INNATE_MOVE := "Innate Shot"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_testProjection()
	_testActorDataProjection()
	_testCommands()
	_testEquipmentGating()
	_testGeneration()
	_testSnapshots()

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures)
	quit(failures)


func _testProjection() -> void:
	print("--- Grant projection ---")
	var movesData := _fixtureMoves()
	var member := {
		"innateMoves": [INNATE_MOVE],
		"moves": [INNATE_MOVE, "Alpha", "Beta", "Gamma", "Epsilon"],
		"equipment": { "weapon": { "grantedMoves": ["Beta", "Delta"] } },
	}
	var classData := { "moves": ["Alpha", "Beta", "Gamma"] }
	var projection: Dictionary = ProjectorScript.project(member, classData)
	var names := []
	var origins := []
	for entry in projection.available:
		names.append(str(entry.name))
		origins.append(str(entry.origin))
	_check(names == [INNATE_MOVE, "Alpha", "Beta", "Gamma", "Delta"], "grants merge in direct, class, equipment order with one entry each, got %s" % str(names))
	_check(origins == ["direct", "class", "class", "class", "equipment"], "each grant keeps its first origin, got %s" % str(origins))
	_check(projection.active == [INNATE_MOVE, "Alpha", "Beta", "Gamma"], "the cap keeps the first four selected grants")
	_check(projection.dropped == ["Epsilon"], "the selection beyond the cap is reported as dropped")
	_check(ProjectorScript.hasOffensiveMove(["Alpha", "Beta"], movesData), "an offensive active Move satisfies the fight requirement")
	_check(!ProjectorScript.hasOffensiveMove(["Beta", "Gamma"], movesData), "support-only Moves do not satisfy the fight requirement")
	_check(ProjectorScript.unknownMoveIds(["Alpha", "Missing"], movesData) == ["Missing"], "unknown ids are reported without changing the list")

	var unresolved: Dictionary = ProjectorScript.project({ "moves": ["Loose Move"] }, {})
	_check(unresolved.active == ["Loose Move"] and unresolved.dropped.is_empty(), "without resolvable grants the caller's list passes through")

	var duplicated: Dictionary = ProjectorScript.project({ "moves": ["Alpha", "Alpha"] }, { "moves": ["Alpha"] })
	_check(duplicated.active == ["Alpha"] and duplicated.duplicated == ["Alpha"], "a repeated selection collapses and is reported")


func _testActorDataProjection() -> void:
	print("\n--- Direct actor data ---")
	var actorData := { "moves": ["Scratch", "Scratch"] }
	var classData := { "moves": ["Sharp Shot"] }
	_check(ProjectorScript.resolvedDirectMoves(actorData, classData) == ["Scratch", "Sharp Shot"], "direct actors keep authored order and gain class grants")
	var equipmentGrants := { "moves": [], "equipment": { "weapon": { "grantedMoves": ["Sharp Shot", "Hold Steady"] } } }
	_check(ProjectorScript.resolvedDirectMoves(equipmentGrants, {}) == ["Sharp Shot", "Hold Steady"], "direct actors gain equipment grants in slot order")
	var overCap := { "moves": ["A", "B", "C", "D", "E"] }
	_check(ProjectorScript.resolvedDirectMoves(overCap, {}).size() == 4, "direct actor loadouts are capped at four")


func _testCommands() -> void:
	print("\n--- Party loadout commands ---")
	var party := _makeParty()
	var changes := []
	party.partyChanged.connect(func(memberKey: String) -> void: changes.append(memberKey))

	var snapshot: Dictionary = party.getMoveLoadoutSnapshot(MEMBER_KEY)
	_check(snapshot.success, "the loadout projection reads")
	_check(snapshot.cap == 4 and snapshot.used == 0, "a new member starts with no activated Move")
	_check((snapshot.available as Array).size() == 5, "every class and innate grant is listed, got %d" % (snapshot.available as Array).size())
	_check((snapshot.available as Array)[0].origin == "direct", "the innate grant is listed first")

	_check(party.activateMove(MEMBER_KEY, "Missing Move").reason == "unknown_move", "an authored-unknown Move is refused")
	_check(party.activateMove(MEMBER_KEY, "Zeta").reason == "move_not_available", "a canonical Move the member is not granted is refused")
	_check(party.activateMove("Nobody", "Alpha").reason == "unknown_member", "an unknown member is refused")
	_check(party.activateMove(MEMBER_KEY, "Alpha").success, "an available Move activates")
	_check(party.activateMove(MEMBER_KEY, "Alpha").reason == "already_active", "activating twice is refused")
	_check(party.getFightData(MEMBER_KEY).moves == ["Alpha"], "the fight receives the resolved active list")
	_check(changes == [MEMBER_KEY], "one successful activation emits one member change")
	_check(party.deactivateMove(MEMBER_KEY, "Alpha").reason == "last_offensive_move", "the last offensive Move cannot be deactivated")
	_check(party.deactivateMove(MEMBER_KEY, "Beta").reason == "not_active", "deactivating an inactive Move is refused")
	_check(party.getMoveLoadoutSnapshot(MEMBER_KEY).active == ["Alpha"], "a refused command leaves the loadout untouched")

	for moveName in ["Innate Shot", "Beta", "Gamma"]:
		_check(party.activateMove(MEMBER_KEY, moveName).success, "'%s' activates while space remains" % moveName)
	_check(party.getMoveLoadoutSnapshot(MEMBER_KEY).used == 4, "the cap accepts four activated Moves")
	_check(party.activateMove(MEMBER_KEY, "Delta").reason == "move_cap_reached", "a fifth activation is refused")
	_check(party.deactivateMove(MEMBER_KEY, "Gamma").success, "a non-offensive Move deactivates")
	_check(party.getMoveLoadoutSnapshot(MEMBER_KEY).used == 3, "the deactivation freed a slot")

	party.setInventoryManagementAllowed(false)
	_check(party.activateMove(MEMBER_KEY, "Delta").reason == "management_unavailable", "loadout changes follow the Journal management policy")
	party.setInventoryManagementAllowed(true)
	_check(party.activateMove(MEMBER_KEY, "Delta").success, "the same activation succeeds once management is allowed")

	var empty := PartyScript.new()
	empty.configureInventory(ItemCatalogScript.new())
	empty.configureCharacterData(_fixtureClasses(), {}, _fixtureMoves())
	_check(empty.getMoveLoadoutSnapshot(MEMBER_KEY).reason == "unknown_member", "the snapshot refuses an unknown member")

	var withoutMoves := _makeParty()
	withoutMoves.configureCharacterData(_fixtureClasses(), {}, {})
	_check(withoutMoves.getMoveLoadoutSnapshot(MEMBER_KEY).reason == "data_unavailable", "a missing Move catalog fails closed")
	withoutMoves.free()
	empty.free()
	party.free()


func _testEquipmentGating() -> void:
	print("\n--- Equipment swap gating ---")
	var party := _makeParty()
	var granting := _weapon("fixture_cattleman", ["Scratch"])
	var plain := _weapon("fixture_plain", [])
	party.inventory = [granting, plain]
	party.setInventoryManagementAllowed(true)

	var preview: Dictionary = party.getEquipmentPreview(MEMBER_KEY, "fixture_cattleman")
	_check(preview.success and preview.moveValid, "equipping a granting weapon is previewed as valid")
	_check(party.equipItem(MEMBER_KEY, "fixture_cattleman").success, "the granting weapon equips")
	_check(party.getMoveLoadoutSnapshot(MEMBER_KEY).available.size() == 6, "the equipment grant joins the available list")
	_check(party.activateMove(MEMBER_KEY, "Alpha").success, "an offensive Move stays active through the swap")
	_check(party.activateMove(MEMBER_KEY, "Scratch").success, "the equipment-granted Move activates")
	_check(party.getFightData(MEMBER_KEY).moves.has("Scratch"), "the fight loadout includes the equipment grant")

	var before: Dictionary = party.exportState()
	var refused: Dictionary = party.equipItem(MEMBER_KEY, "fixture_plain")
	_check(refused.reason == "move_grant_lost", "a swap that removes an active grant is refused, got %s" % str(refused))
	_check(party.exportState() == before, "a refused swap mutates nothing")
	var refusedPreview: Dictionary = party.getEquipmentPreview(MEMBER_KEY, "fixture_plain")
	_check(!refusedPreview.moveValid and refusedPreview.reason == "move_grant_lost", "the preview explains the blocked swap")
	_check(party.deactivateMove(MEMBER_KEY, "Scratch").success, "the equipment grant can be deactivated")
	_check(party.equipItem(MEMBER_KEY, "fixture_plain").success, "the swap succeeds once the grant is inactive")
	var grantedNames := []
	for entry in party.getMoveLoadoutSnapshot(MEMBER_KEY).available:
		grantedNames.append(str(entry.name))
	_check(!grantedNames.has("Scratch"), "the equipment grant leaves the available list with its item")
	party.free()



func _testGeneration() -> void:
	print("\n--- Item grant passthrough ---")
	var generator = ItemGenerationScript.new()
	var cattleman: Dictionary = generator.generateWeapon({ "definitionId": "cattleman", "family": "revolver", "rarity": "common" })
	_check(cattleman.definitionId == "cattleman", "a forced weapon definition rolls that base")
	_check(cattleman.get("grantedMoves", []) == ["Sharp Shot"], "the authored weapon grant reaches its rolled instance")
	var plain: Dictionary = generator.generateWeapon({ "definitionId": "colt_paterson", "family": "revolver", "rarity": "common" })
	_check(!plain.has("grantedMoves"), "a weapon without an authored grant stays grant-free")

	generator.equipmentData = _fixtureEquipmentData()
	var equipment: Dictionary = generator.generateEquipment({ "zone": "anywhere" })
	_check(equipment.get("grantedMoves", []) == ["Scratch"], "an authored equipment grant reaches its rolled instance")
	generator.free()


func _testSnapshots() -> void:
	print("\n--- Loadout snapshots ---")
	var party := _makeParty(["Alpha"])
	party.setInventoryManagementAllowed(true)
	_check(party.activateMove(MEMBER_KEY, "Beta").success, "the fixture member activates a second Move")
	var snapshot: Dictionary = party.exportState()
	_check(snapshot.members[MEMBER_KEY].moves == ["Alpha", "Beta"], "the snapshot records the selected loadout")
	_check(int(snapshot.formatVersion) == party.STATE_FORMAT_VERSION, "the snapshot carries the current Party domain version")

	var reloaded := _makeParty(["Alpha"])
	_check(reloaded.importState(snapshot).success, "the snapshot imports")
	_check(reloaded.party[MEMBER_KEY].moves == ["Alpha", "Beta"], "the restored member keeps its selection")
	_check(reloaded.getFightData(MEMBER_KEY).moves == ["Alpha", "Beta"], "the restored selection still resolves for combat")

	var before: Dictionary = reloaded.exportState()
	var unavailable := snapshot.duplicate(true)
	unavailable.members[MEMBER_KEY].moves = ["Zeta"]
	var refused: Dictionary = reloaded.importState(unavailable)
	_check(refused.reason == "invalid_move", "an ungranted selection is refused, got %s" % str(refused))
	_check(reloaded.exportState() == before, "a refused import leaves the member untouched")

	var unknown := snapshot.duplicate(true)
	unknown.members[MEMBER_KEY].moves = ["Missing Move"]
	_check(reloaded.importState(unknown).reason == "invalid_move", "an authored-unknown selection is refused")

	var emptySelection := snapshot.duplicate(true)
	emptySelection.members[MEMBER_KEY].moves = []
	_check(reloaded.importState(emptySelection).reason == "invalid_move", "an empty selection with available grants is refused")

	var duplicatedSelection := snapshot.duplicate(true)
	duplicatedSelection.members[MEMBER_KEY].moves = ["Alpha", "Alpha"]
	_check(reloaded.importState(duplicatedSelection).reason == "invalid_state", "a duplicated selection is refused")

	var legacy := snapshot.duplicate(true)
	legacy.formatVersion = party.LEGACY_STATE_FORMAT_VERSION
	legacy.members[MEMBER_KEY].erase("moves")
	_check(reloaded.importState(legacy).success, "a pre-loadout snapshot imports")
	_check(reloaded.party[MEMBER_KEY].moves == ["Alpha"], "the pre-loadout default is the member's canonical selection")
	reloaded.free()
	party.free()



## Fixture member/class: five grants (one innate, four class) with one offensive
## Move, plus an extra canonical id that is authored but not granted. The
## optional canonical selection seeds the pre-loadout migration default.
func _makeParty(canonicalMoves: Array = []) -> Node:
	var party = PartyScript.new()
	var catalog = ItemCatalogScript.new()
	party.configureInventory(catalog, _fixtureClasses())
	party.configureCharacterData(_fixtureClasses(), {}, _fixtureMoves())
	var member := _member()
	member["moves"] = canonicalMoves.duplicate()
	party.party = { MEMBER_KEY: member }
	party._newGameBaseline = {
		"money": party.money,
		"level": party.level,
		"inventory": party.inventory.duplicate(true),
		"nextInstanceNumber": 1,
		"party": party.party.duplicate(true),
	}
	party.setInventoryManagementAllowed(true)
	return party


func _member() -> Dictionary:
	return {
		"actorName": MEMBER_KEY,
		"hp": 10,
		"walkingSpeed": 75,
		"runningSpeed": 25,
		"stats": {
			"sixShootin": 2, "highTailin": 3, "taffyin": 1,
			"damage": { "lead": { "revolver": 1, "rifle": 1, "shotgun": 1 }, "explosive": { "gunpowder": 1, "liquid": 1, "shrapnel": 1 } },
			"defense": { "style": 1, "sand": 1 },
			"resistances": { "bleed": 0.0, "poison": 0.0 },
		},
		"rodeo": null,
		"baseMaxHp": 10,
		"injuryDamage": 0,
		"injuryRate": 4,
		"characterClass": CLASS_NAME,
		"innateMoves": [INNATE_MOVE],
		"moves": [],
		"beltReservations": [],
		"magazine": [1, 0, 2],
		"equipment": { "weapon": null, "headwear": null, "bandana": null, "duster": null, "belt": null, "trousers": null, "justins": null },
	}


func _fixtureClasses() -> Dictionary:
	return { CLASS_NAME: { "name": CLASS_NAME, "magazine": [1, 0, 2], "moves": ["Alpha", "Beta", "Gamma", "Delta"], "beltSpace": 1, "defense": { "sand": 1 }, "explosiveBase": 0 } }


func _fixtureMoves() -> Dictionary:
	return {
		INNATE_MOVE: { "name": INNATE_MOVE, "category": "duck" },
		"Alpha": { "name": "Alpha", "category": "attack_ability", "baseAmount": 3 },
		"Beta": { "name": "Beta", "category": "duck" },
		"Gamma": { "name": "Gamma", "category": "duck" },
		"Delta": { "name": "Delta", "category": "duck" },
		"Epsilon": { "name": "Epsilon", "category": "duck" },
		"Zeta": { "name": "Zeta", "category": "duck" },
		"Scratch": { "name": "Scratch", "category": "attack_ability", "baseAmount": 2 },
	}


func _weapon(instanceId: String, grantedMoves: Array) -> Dictionary:
	var item := {
		"instanceId": instanceId,
		"definitionId": instanceId,
		"itemType": "weapon",
		"quantity": 1,
		"name": instanceId,
		"baseName": instanceId,
		"family": "revolver",
		"familyNoun": "Revolver",
		"baseDamage": 3,
		"stats": {},
		"sprite": "",
		"zone": "anywhere",
		"rarity": "common",
		"rarityName": "Trail-Worn",
		"prefix": {},
		"suffix": {},
	}
	if !grantedMoves.is_empty():
		item["grantedMoves"] = grantedMoves.duplicate()
	return item


func _fixtureEquipmentData() -> Dictionary:
	return {
		"slots": ["belt"],
		"genericBases": { "belt": { "id": "fixture_belt", "name": "Fixture Belt", "baseStats": {}, "grantedMoves": ["Scratch"] } },
		"spritePools": { "belt": [] },
		"zones": {},
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

