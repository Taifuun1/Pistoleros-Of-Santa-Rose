extends Node

## Scene-run validation for Vamoose routing/loss and the Party snapshot
## (Docs/System Design/First Steps Implementation Plan.md, commit 5): the
## 15%-of-occupied-stacks rule, deterministic/atomic removal, checkpoint versus
## last-Town destination, no stock reroll, one end-of-Trail/recovery pass and
## the versioned Party snapshot. Run as TestVamooseFlow.tscn.

const PartyScript = preload("res://Globals/Party.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const SceneManagerScene = preload("res://Nodes/Scene Manager/SceneManager.tscn")
const RequestScript = preload("res://Shootout/EncounterRequest.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const QuestCatalogScript = preload("res://Data/Quests/QuestCatalog.gd")
const QuestDefinitionScript = preload("res://Data/Quests/QuestDefinition.gd")
const QuestObjectiveDefinitionScript = preload("res://Data/Quests/QuestObjectiveDefinition.gd")

const CANYON_RATS := "res://Data/Shootout/Encounters/CanyonRats.gd"
const PRODUCTION_QUEST_CATALOG := "res://Data/Quests/QuestCatalog.tres"

var failures := 0
var sceneManager: Node


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	get_tree().root.add_child.call_deferred(sceneManager)
	await get_tree().process_frame
	await get_tree().process_frame
	_testSelectionCounts()
	_testDeterministicAtomicLoss()
	_testDestinationResolution()
	_testSnapshotRoundTrip()
	await _testTownRouting()
	await _testCheckpointRouting()
	await _cleanup()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _testSelectionCounts() -> void:
	print("--- Vamoose removes 15% of occupied stacks, rounded up ---")
	var expected := { 0: 0, 1: 1, 6: 1, 7: 2, 24: 4 }
	for size in expected:
		_check(PartyScript.vamooseLossCount(size) == expected[size], "inventory %d removes %d stack(s)" % [size, expected[size]])
	var catalog = ItemCatalogScript.new()
	for size in expected:
		var party = _freshParty(catalog, _makeInventory(size), 10)
		var retreat: Dictionary = party.vamoose({ "checkpointId": "", "lastTownId": "" })
		_check(retreat.removedItems.size() == expected[size], "Vamoose removes %d of %d occupied stacks" % [expected[size], size])
		_check(party.inventory.size() == size - expected[size], "the remaining stack count is exact for %d" % size)
		party.free()


func _testDeterministicAtomicLoss() -> void:
	print("\n--- Deterministic selection, atomic mutation, no equipped loss ---")
	var catalog = ItemCatalogScript.new()
	var first = _freshParty(catalog, _makeInventory(7), 101)
	var second = _freshParty(catalog, _makeInventory(7), 101)
	# Walker is equipped; Vamoose must never touch equipment.
	first.party["Walker Langley"]["equipment"]["headwear"] = { "instanceId": "equipped_hat", "definitionId": "hat", "itemType": "equipment", "quantity": 1, "stats": {} }
	var equippedBefore = first.party["Walker Langley"]["equipment"].duplicate(true)

	var firstRetreat: Dictionary = first.vamoose({ "rng": _seededRng(4242), "checkpointId": "", "lastTownId": "" })
	var secondRetreat: Dictionary = second.vamoose({ "rng": _seededRng(4242), "checkpointId": "", "lastTownId": "" })
	var firstIds := []
	for item in firstRetreat.removedItems:
		firstIds.append(item.instanceId)
	var secondIds := []
	for item in secondRetreat.removedItems:
		secondIds.append(item.instanceId)
	_check(firstIds == secondIds, "the same seed removes the same stacks")

	var seen := {}
	var unique := true
	for item in first.inventory:
		if seen.has(item.instanceId):
			unique = false
		seen[item.instanceId] = true
	_check(unique, "instance ids stay unique after removal")
	_check(first.party["Walker Langley"]["equipment"] == equippedBefore, "equipped items are not part of the carried-stack loss")
	_check(first.money == 50, "money halving rounds down (101 -> 50)")
	first.free()
	second.free()


func _testDestinationResolution() -> void:
	print("\n--- Quest checkpoint versus last-Town destination ---")
	var catalog = ItemCatalogScript.new()
	var party = _freshParty(catalog, _makeInventory(3), 20)
	var checkpoint: Dictionary = party.vamoose({ "checkpointId": "Clearwater Grove", "lastTownId": "Lazysprings" })
	_check(checkpoint.destination == "Clearwater Grove" and checkpoint.destinationKind == "quest_checkpoint", "an active checkpoint wins over the last Town")
	var town: Dictionary = party.vamoose({ "checkpointId": "", "lastTownId": "Lazysprings" })
	_check(town.destination == "Lazysprings" and town.destinationKind == "town", "without a checkpoint the last Town is used")
	var none: Dictionary = party.vamoose({ "checkpointId": "", "lastTownId": "" })
	_check(none.destination == "" and none.destinationKind == "", "an empty destination is reported when none exists")
	party.free()


func _testSnapshotRoundTrip() -> void:
	print("\n--- Party snapshot round-trip and malformed rollback ---")
	var catalog = ItemCatalogScript.new()
	var source = PartyScript.new()
	source.configureInventory(catalog, { "Gunslinger": { "beltSpace": 1 } })
	source.money = 77
	source.party["Walker Langley"]["injuryDamage"] = 6
	source.inventory = _makeInventory(3)
	source.party["Walker Langley"]["beltReservations"] = [{ "instanceId": "stack_0", "combatId": "Paregoric", "quantity": 1 }]
	var state: Dictionary = source.exportState()
	_check(state.formatVersion == PartyScript.STATE_FORMAT_VERSION, "the snapshot carries its format version")

	var restored = PartyScript.new()
	restored.configureInventory(catalog, { "Gunslinger": { "beltSpace": 1 } })
	_check(restored.importState(state).success, "a valid snapshot imports")
	_check(restored.money == 77 and restored.inventory.size() == 3, "import restores money and inventory")
	_check(restored.party["Walker Langley"]["injuryDamage"] == 6, "import restores member attrition")
	_check(restored.getBeltSnapshot("Walker Langley").used == 1, "import restores belt reservations")

	var target = PartyScript.new()
	target.configureInventory(catalog, { "Gunslinger": { "beltSpace": 1 } })
	var before: Dictionary = target.exportState()
	var malformed := [{ "formatVersion": 2 }]
	var missingMember = state.duplicate(true)
	missingMember.members = { "Ghost": missingMember.members["Walker Langley"] }
	malformed.append(missingMember)
	var duplicateIds = state.duplicate(true)
	duplicateIds.inventory[1].instanceId = "stack_0"
	malformed.append(duplicateIds)
	var orphanReservation = state.duplicate(true)
	orphanReservation.members["Walker Langley"].beltReservations = [{ "instanceId": "missing", "combatId": "Paregoric", "quantity": 1 }]
	malformed.append(orphanReservation)
	var unknownItem = state.duplicate(true)
	unknownItem.inventory[0].definitionId = "not_a_real_item"
	malformed.append(unknownItem)
	var clashEquipment = state.duplicate(true)
	clashEquipment.members["Walker Langley"].equipment["weapon"] = { "instanceId": "stack_0", "definitionId": "starter_rifle", "itemType": "weapon", "family": "rifle", "baseDamage": 4, "stats": {} }
	malformed.append(clashEquipment)
	for index in malformed.size():
		var result: Dictionary = target.importState(malformed[index])
		_check(!result.success, "malformed snapshot %d fails closed (%s)" % [index, result.reason])
		_check(target.exportState() == before, "malformed snapshot %d leaves Party untouched" % index)
	source.free()
	restored.free()
	target.free()


func _testTownRouting() -> void:
	print("\n--- Vamoose router: last-Town destination and one recovery ---")
	Party.resetForNewGame()
	Locations.resetForNewGame()
	Overworld.resetForNewGame()
	Party.money = 101
	Locations.enterTown("Lazysprings")
	Locations.startTrail()
	# Injured after the first recovery so the return pass is observable.
	Party.party["Walker Langley"]["injuryDamage"] = 8
	var departureBefore: int = Locations.trailDepartureId
	var seedBefore: int = Vendors.baseSeed
	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads for the town Vamoose test")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(await _launchVamooseFight(), "the Vamoose fight launches and ends in Vamoose")
	_check(await _awaitSceneKey("pregenerated_location"), "Vamoose returns to the last Town interior")
	_check(Locations.getLastTownId() == "Lazysprings", "the recorded last Town is the destination")
	_check(!Locations.isOnTrail(), "a Town return ends the Trail")
	_check(Party.money == 50, "Vamoose halves money once, got %d" % Party.money)
	_check(int(Party.party["Walker Langley"]["injuryDamage"]) == 0, "the Town return applies recovery once")
	_check(Locations.trailDepartureId == departureBefore and Vendors.baseSeed == seedBefore, "Vamoose does not reroll vendor stock")
	_check(!Locations.canAccessLocation(false) and !Locations.canApplyAttrition() and !Locations.canGrantLoot(), "Off-Trail restrictions are restored after Vamoose")


func _testCheckpointRouting() -> void:
	print("\n--- Vamoose router: non-town quest checkpoint ---")
	Party.resetForNewGame()
	Locations.resetForNewGame()
	Overworld.resetForNewGame()
	Party.money = 40
	_setTestQuestCheckpoint()
	Locations.enterTown("Lazysprings")
	Locations.startTrail()
	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads for the checkpoint Vamoose test")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(Quests.getCurrentObjectiveTarget() == "Clearwater Grove", "the checkpoint resolves from authoritative quest state")
	_check(await _launchVamooseFight(), "the checkpoint Vamoose fight launches and ends in Vamoose")
	_check(await _awaitSceneKey("overworld"), "a non-town checkpoint returns to the Overworld entrance")
	_check(!Locations.isOnTrail(), "the checkpoint return ends the Trail")
	_check(Party.money == 20, "Vamoose halves money once, got %d" % Party.money)
	_check(Overworld.spawnChunk == Vector2i(8, 18) and Overworld.spawnTile == Vector2i(27, 63), "the party lands at the checkpoint's authored Overworld entrance")


## Launches the real canyon encounter from the Overworld, presents a Vamoose
## result and acknowledges the end screen so the router owns the return.
func _launchVamooseFight() -> bool:
	var catalog = ZoneCatalogScript.new()
	var request = RequestScript.make({
		"encounterPath": CANYON_RATS,
		"zoneId": "canyon",
		"source": "overworld_event",
		"sourceId": "vamoose_test",
		"progression": { "band": "early" },
		"trailState": Locations.exportState(),
		"seed": 99,
	}, catalog, Locations)
	if !sceneManager.launchShootout(request):
		return false
	if !await _awaitSceneKey("shootout"):
		return false
	var shootout = sceneManager.get_current_scene()
	shootout.battleOver = true
	shootout.presentFightResults({
		"winningSide": Shootout.TEAM_ENEMY,
		"fled": false,
		"outcome": "vamoose",
		"party": {},
		"rodeoLoot": {},
		"trailState": Locations.exportState(),
		"loot": { "money": 0, "items": [] },
	})
	shootout._on_end_screen_continue_pressed()
	return true


## Loads a one-objective quest whose current objective targets a non-town
## Location so Vamoose exercises the checkpoint branch through Quests state.
func _setTestQuestCheckpoint() -> void:
	var catalog = QuestCatalogScript.new()
	var quest = QuestDefinitionScript.new()
	quest.quest_id = "vamoose_checkpoint_test"
	quest.title = "Checkpoint Test"
	quest.summary = "Vamoose checkpoint routing test."
	quest.sort_order = 0
	var objective = QuestObjectiveDefinitionScript.new()
	objective.objective_id = "reach_clearwater"
	objective.objective_text = "Reach Clearwater Grove."
	objective.history_text = "Reached Clearwater Grove."
	objective.map_target_id = "Clearwater Grove"
	var objectives: Array[QuestObjectiveDefinition] = [objective]
	quest.objectives = objectives
	var definitions: Array[QuestDefinition] = [quest]
	catalog.definitions = definitions
	Quests.loadCatalog(catalog)
	Quests.startQuest("vamoose_checkpoint_test")


func _restoreProductionQuests() -> void:
	if ResourceLoader.exists(PRODUCTION_QUEST_CATALOG):
		Quests.loadCatalog(load(PRODUCTION_QUEST_CATALOG))


func _freshParty(catalog, inventory: Array, money: int):
	var party = PartyScript.new()
	party.configureInventory(catalog, { "Gunslinger": { "beltSpace": 1 } })
	party.inventory = inventory
	party.money = money
	party.party["Walker Langley"]["beltReservations"] = []
	return party


func _makeInventory(count: int) -> Array:
	var items := []
	for index in count:
		items.append({
			"instanceId": "stack_%d" % index,
			"definitionId": "paregoric",
			"itemType": "consumable",
			"quantity": 1,
		})
	return items


func _seededRng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _awaitSceneKey(sceneKey: String, maxFrames := 900) -> bool:
	for _index in maxFrames:
		if sceneManager.currentSceneKey == sceneKey and !sceneManager.transitioning:
			return true
		await get_tree().process_frame
	return false


func _cleanup() -> void:
	_restoreProductionQuests()
	Quests.resetForNewGame()
	Locations.resetForNewGame()
	Overworld.resetForNewGame()
	Party.resetForNewGame()
	OverworldEvents.resetEventState()
	if is_instance_valid(sceneManager):
		var manager = sceneManager
		manager.queue_free()
		if manager.is_inside_tree():
			await manager.tree_exited
	await get_tree().process_frame
	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
	if Overworld._coordinates != null:
		Overworld._coordinates.dispose()
		Overworld._coordinates = null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

