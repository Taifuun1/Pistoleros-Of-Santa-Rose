extends SceneTree

## Headless validation for canonical equipment stats and the equip command
## (Docs/System Design/Journal/Inventory and Equipment.md, patch 3).
## Run with: godot --headless --script res://Tests/TestEquipmentStats.gd

const CharacterStatCalculatorScript = preload("res://Globals/CharacterStatCalculator.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const PartyScript = preload("res://Globals/Party.gd")

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var calculator = CharacterStatCalculatorScript.new()
	testCalculator(calculator)
	testParty()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func testCalculator(calculator) -> void:
	print("--- Calculator: supported modifiers ---")
	var member = _member()
	var classData = { "beltSpace": 1 }
	var current = calculator.calculate(member, classData)
	_check(current.maxHp == 15, "base 12 + 4 MxHP - 1 injury = 15, got %d" % current.maxHp)
	_check(current.hp == 12, "current HP stays 12")
	_check(current.stats.sixShootin == 3, "Six Shootin' starts from base")
	_check(current.stats.highTailin == 7, "weapon High Tailin' adds to base")
	_check(current.stats.taffyin == 2, "Taffyin' starts from base")
	_check(current.stats.defense.style == 5 and current.stats.defense.sand == 3, "gear Style/Sand add to defense")
	_check(current.weapon.weapon == "rifle" and current.weapon.baseDamage == 9, "rifle base 4 + rifle damage 5 = 9")
	_check(current.beltSpace == 2, "class belt 1 + belt item 1 = 2")
	_check(!current.stats.has("damageTakenReduction"), "unsupported affix is not applied as a stat")
	_check(member.stats.highTailin == 6 and member.equipment.weapon.stats.rifleDamage == 5, "source member is not mutated")

	print("\n--- Calculator: HP clamp, knockout and replacement preview ---")
	member.hp = 99
	var clamped = calculator.calculate(member, classData)
	_check(clamped.hp == 15, "HP clamps down to effective MxHP")
	member.hp = 5
	_check(calculator.calculate(member, classData).hp == 5, "higher MxHP never heals current HP")
	member.hp = 12
	member.knockoutDebuffs = [{ "stat": "sixShootin", "amount": -1 }]
	var debuffed = calculator.calculate(member, classData)
	_check(debuffed.stats.sixShootin == 2, "knockout debuff applies after equipment")
	_check(member.stats.sixShootin == 3, "knockout preview does not mutate source")
	member.knockoutDebuffs = []

	var revolver = _weapon("revolver", 6, { "revolverDamage": 3, "rifleDamage": 50, "mxHp": 2 })
	var projected = calculator.calculate(member, classData, "weapon", revolver)
	_check(projected.weapon.weapon == "revolver" and projected.weapon.baseDamage == 9, "only matching family damage applies")
	_check(projected.maxHp == 17, "replacement weapon MxHP is previewed")
	var deltas = calculator.compare(current, projected)
	_check(!_hasDelta(deltas, "weapon.baseDamage", 0), "same base damage is omitted from changed rows")
	var familyRows = deltas.filter(func(row): return row.path == "weapon.weapon")
	_check(familyRows.size() == 1 and familyRows[0].before == "rifle" and familyRows[0].after == "revolver", "weapon family change has its own row")
	_check(deltas.filter(func(row): return row.path == "maxHp")[0].delta == 2, "MxHP delta is projected")

	print("\n--- Calculator: legacy member without equipment ---")
	var legacy = { "hp": 12, "baseMaxHp": 12, "injuryDamage": 4, "injuryRate": 4,
		"stats": { "sixShootin": 3, "highTailin": 6 }, "knockoutDebuffs": [], "weapon": { "type": "lead", "weapon": "rifle", "baseDamage": 4 } }
	var legacyData = calculator.calculate(legacy, {})
	_check(legacyData.maxHp == 11 and legacyData.hp == 11, "legacy injury behavior is preserved")
	_check(legacyData.stats.defense.style == 0 and legacyData.stats.damage.lead.revolver == -1, "missing stat containers get safe defaults")
	_check(legacyData.weapon.weapon == "rifle" and legacyData.weapon.baseDamage == 4, "legacy weapon is preserved")
	_check(legacyData.beltSpace == -1, "unknown class leaves belt space uncapped")


func testParty() -> void:
	var catalog = ItemCatalogScript.new()
	var classes = { "Gunslinger": { "beltSpace": 1 } }
	print("\n--- Party: canonical starter and snapshot ---")
	var starter = PartyScript.new()
	starter.configureInventory(catalog, classes)
	var starterWalker = starter.party["Walker Langley"]
	_check(!starterWalker.has("weapon"), "legacy weapon field is removed")
	_check(starterWalker.equipment.weapon.instanceId == "starter_walker_rifle", "starter weapon is a canonical gear instance")
	_check(starterWalker.equipment.headwear == null and starterWalker.equipment.justins == null, "all empty slots are explicit")
	var starterFight = starter.getFightData("Walker Langley")
	_check(starterFight.weapon.weapon == "rifle" and starterFight.weapon.baseDamage == 4, "starter fight weapon is projected from equipment")
	_check(starterFight.beltSpace == 1, "starter Gunslinger belt space is computed")
	var snapshot = starter.getInventorySnapshot()
	_check(snapshot.members.size() == 1, "snapshot includes party members")
	_check(snapshot.members[0].equipment.weapon.instanceId == "starter_walker_rifle", "snapshot exposes deep equipment copies")
	_check(snapshot.members[0].fightData.weapon.baseDamage == 4, "snapshot includes current fight projection")
	starter.free()

	print("\n--- Party: preview and atomic equip into an empty slot ---")
	var party = PartyScript.new()
	party.configureInventory(catalog, classes)
	party.inventory = []
	party._nextInstanceNumber = 1
	party.setInventoryManagementAllowed(true)
	var inventorySignals = []
	var equipmentSignals = []
	party.inventoryChanged.connect(func(): inventorySignals.append(true))
	party.equipmentChanged.connect(func(_memberKey): equipmentSignals.append(true))

	var highDuster = party.addItem(_duster("Duster High", 10))
	var highId = highDuster.acceptedInstanceIds[0]
	var preview = party.getEquipmentPreview("Walker Langley", highId)
	_check(preview.success and preview.slot == "duster", "duster preview resolves its slot")
	_check(preview.projected.maxHp == 22 and preview.current.maxHp == 12, "preview projects +10 MxHP without committing")
	_check(preview.projected.equipment.duster.name == "Duster High", "preview includes the hypothetical item")
	_check(_hasDelta(preview.deltas, "maxHp", 10), "preview reports the MxHP delta")
	var result = party.equipItem("Walker Langley", highId)
	_check(result.success and result.slot == "duster" and result.returnedInstanceId == "", "empty-slot equip succeeds")
	_check(party.inventory.is_empty(), "equipping from an empty slot consumes the inventory entry")
	_check(party.party["Walker Langley"].equipment.duster.instanceId == highId, "candidate becomes canonical equipment")
	_check(inventorySignals.size() == 2 and equipmentSignals.size() == 1, "one inventory signal per mutation and one equipment signal")
	var fightData = party.getFightData("Walker Langley")
	_check(fightData.maxHp == preview.projected.maxHp, "committed stats match preview")

	print("\n--- Party: replacement, HP clamp and returned gear ---")
	var walker = party.party["Walker Langley"]
	walker.hp = fightData.maxHp
	var lowDuster = party.addItem(_duster("Duster Low", 0))
	var lowId = lowDuster.acceptedInstanceIds[0]
	preview = party.getEquipmentPreview("Walker Langley", lowId)
	_check(preview.projected.maxHp == 12, "replacement preview drops MxHP to 12")
	result = party.equipItem("Walker Langley", lowId)
	_check(result.success and result.returnedInstanceId == highId, "replacement returns the old instance id")
	_check(walker.equipment.duster.instanceId == lowId, "replacement installs the candidate")
	_check(party.inventory[0].instanceId == highId, "old gear occupies the candidate's inventory index")
	_check(walker.hp == 12, "lower MxHP clamps persistent HP without healing")
	_check(party.getInventorySnapshot().members[0].equipment.duster.instanceId == lowId, "snapshot follows committed equipment")

	print("\n--- Party: full inventory replacement and validation ---")
	var fullParty = PartyScript.new()
	fullParty.configureInventory(catalog, classes)
	fullParty.setInventoryManagementAllowed(true)
	fullParty.party["Walker Langley"]["equipment"]["duster"] = _withInstance(_duster("Old Duster", 0), "old_duster")
	var fullCandidate = _withInstance(_duster("Full Candidate", 0), "candidate_duster")
	fullParty.inventory = [fullCandidate]
	for index in 23:
		fullParty.inventory.append({ "instanceId": "filler_%d" % index, "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 })
	_check(fullParty.inventory.size() == 24, "replacement setup starts at full capacity")
	result = fullParty.equipItem("Walker Langley", "candidate_duster")
	_check(result.success and fullParty.inventory.size() == 24, "replacement works at full capacity without growth")
	_check(fullParty.inventory[0].instanceId == "old_duster", "old gear takes the candidate's exact index")
	_check(fullParty.party["Walker Langley"].equipment.duster.instanceId == "candidate_duster", "full-capacity candidate is equipped")
	result = fullParty.equipItem("Walker Langley", "missing")
	_check(!result.success and result.reason == "unknown_item", "unknown equipment id is rejected")
	result = fullParty.equipItem("Missing Member", "old_duster")
	_check(!result.success and result.reason == "unknown_member", "unknown member is rejected")
	fullParty.setInventoryManagementAllowed(false)
	result = fullParty.equipItem("Walker Langley", "old_duster")
	_check(!result.success and result.reason == "management_unavailable", "equip fails closed outside allowed scenes")

	print("\n--- Party: belt-space rejection ---")
	var beltParty = PartyScript.new()
	beltParty.configureInventory(catalog, classes)
	beltParty.inventory = []
	beltParty._nextInstanceNumber = 1
	beltParty.setInventoryManagementAllowed(true)
	var beltOne = beltParty.addItem(_belt(1))
	var beltOneId = beltOne.acceptedInstanceIds[0]
	_check(beltParty.equipItem("Walker Langley", beltOneId).success, "belt with room is equipped")
	beltParty.party["Walker Langley"].items = ["Paregoric", "Paregoric"]
	var beltZero = beltParty.addItem(_belt(0))
	var beltZeroId = beltZero.acceptedInstanceIds[0]
	preview = beltParty.getEquipmentPreview("Walker Langley", beltZeroId)
	_check(preview.success and !preview.beltValid and preview.reason == "belt_loadout_too_large", "preview flags an invalid belt loadout")
	result = beltParty.equipItem("Walker Langley", beltZeroId)
	_check(!result.success and result.reason == "belt_loadout_too_large", "commit rejects an invalid belt loadout")
	_check(beltParty.party["Walker Langley"].equipment.belt.instanceId == beltOneId, "rejected belt swap leaves equipment unchanged")
	_check(beltParty._inventoryRules.inventoryIndex(beltParty.inventory, beltZeroId) >= 0, "rejected candidate stays in inventory")

	fullParty.free()
	beltParty.free()
	party.free()


func _member() -> Dictionary:
	return {
		"actorName": "Test Member",
		"characterClass": "Gunslinger",
		"hp": 12,
		"baseMaxHp": 12,
		"injuryDamage": 4,
		"injuryRate": 4,
		"knockoutDebuffs": [],
		"items": ["Paregoric"],
		"stats": {
			"sixShootin": 3, "highTailin": 6, "taffyin": 2,
			"damage": {
				"lead": { "revolver": 1, "rifle": 1, "shotgun": 1 },
				"explosive": { "gunpowder": 1, "liquid": 1, "shrapnel": 1 },
			},
			"defense": { "style": 2, "sand": 1 },
			"resistances": { "bleed": 0.0, "poison": 0.0 },
		},
		"equipment": {
			"weapon": _weapon("rifle", 4, { "rifleDamage": 5, "revolverDamage": 99, "highTailin": 1 }),
			"headwear": null,
			"bandana": null,
			"duster": _duster("Test Duster", 4, { "style": 3, "sand": 2, "damageTakenReduction": 99 }),
			"belt": _belt(1),
			"trousers": null,
			"justins": null,
		},
	}


func _weapon(family: String, baseDamage: int, stats: Dictionary) -> Dictionary:
	return {
		"definitionId": "test_weapon",
		"quantity": 1,
		"itemType": "weapon",
		"name": "Test Weapon",
		"baseName": "Test Weapon",
		"family": family,
		"baseDamage": baseDamage,
		"stats": stats.duplicate(true),
	}


func _duster(itemName: String, maxHp: int, extraStats := {}) -> Dictionary:
	var stats = { "style": 1, "sand": 1, "mxHp": maxHp }
	for key in extraStats:
		stats[key] = extraStats[key]
	return {
		"definitionId": "test_duster",
		"quantity": 1,
		"itemType": "equipment",
		"slot": "duster",
		"name": itemName,
		"baseName": itemName,
		"stats": stats,
	}


func _belt(space: int) -> Dictionary:
	return {
		"definitionId": "test_belt",
		"quantity": 1,
		"itemType": "equipment",
		"slot": "belt",
		"name": "Test Belt",
		"baseName": "Test Belt",
		"beltSpace": space,
		"stats": {},
	}


func _withInstance(item: Dictionary, instanceId: String) -> Dictionary:
	var result = item.duplicate(true)
	result["instanceId"] = instanceId
	return result


func _hasDelta(rows: Array, path: String, delta: int) -> bool:
	for row in rows:
		if row.path == path and int(row.delta) == delta:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)


