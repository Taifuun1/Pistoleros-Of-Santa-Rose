extends Node

## Scene-run validation for the cutscene quest shot and the Pistoleros Regroup
## progression data (Docs/System Design/Journal/Quests.md, stage 4). Runs as a
## scene because the shot calls the Quests autoload.

const CutsceneScript = preload("res://Cutscenes/Cutscene.gd")
const QuestObjectiveDefinitionScript = preload("res://Data/Quests/QuestObjectiveDefinition.gd")
const QuestDefinitionScript = preload("res://Data/Quests/QuestDefinition.gd")
const QuestCatalogScript = preload("res://Data/Quests/QuestCatalog.gd")

const PRODUCTION_CATALOG_PATH := "res://Data/Quests/QuestCatalog.tres"
const CUTSCENE_DIR := "res://Data/Cutscenes/Pistoleros Regroup/"
const QUEST_ID := "pistoleros_regroup"

## Location scene, expected cutscene trigger name (empty = none) and next exit.
const PROLOGUE_LOCATIONS := {
	"Finch Pond": {
		"path": "res://Location/Locations/Pistoleros Regroup/Finch Pond/FinchPond.tscn",
		"cutscene": "",
		"exit": "Pine Meadows",
	},
	"Pine Meadows": {
		"path": "res://Location/Locations/Pistoleros Regroup/Pine Meadows/PineMeadows.tscn",
		"cutscene": "Pine Meadows",
		"exit": "Great Fall Ridge",
	},
	"Great Fall Ridge": {
		"path": "res://Location/Locations/Pistoleros Regroup/Great Fall Ridge/GreatFallRidge.tscn",
		"cutscene": "Great Fall Ridge",
		"exit": "Blackberry Retreat",
	},
	"Blackberry Retreat": {
		"path": "res://Location/Locations/Pistoleros Regroup/Blackberry Retreat/BlackberryRetreat.tscn",
		"cutscene": "Blackberry Retreat",
		"exit": "Littlehill Grove",
	},
	"Littlehill Grove": {
		"path": "res://Location/Locations/Pistoleros Regroup/Littlehill Grove/LittlehillGrove.tscn",
		"cutscene": "Littlehill Grove",
		"exit": "",
	},
}

## End shots authored into each Pistoleros Regroup cutscene data file, in order.
const EXPECTED_SHOTS := {
	"FinchPond.gd": [
		{ "action": "start", "objective_id": "" },
	],
	"PineMeadows.gd": [
		{ "action": "complete_objective", "objective_id": "find_gwyneth" },
	],
	"GreatFallRidge.gd": [
		{ "action": "complete_objective", "objective_id": "find_aiyana" },
	],
	"BlackberryRetreat.gd": [
		{ "action": "complete_objective", "objective_id": "find_manuel" },
	],
	"LittlehillGrove.gd": [
		{ "action": "complete_objective", "objective_id": "find_morrison" },
		{ "action": "complete_objective", "objective_id": "regroup_pistoleros_of_santa_rose" },
	],
}

## Cutscene file order must match the quest's objective order.
const EXPECTED_SHOT_FILES := [
	"FinchPond.gd",
	"PineMeadows.gd",
	"GreatFallRidge.gd",
	"BlackberryRetreat.gd",
	"LittlehillGrove.gd",
]

var failures := 0
var progressionSignals: Array[String] = []


func _ready() -> void:
	var productionCatalog = load(PRODUCTION_CATALOG_PATH)
	check(productionCatalog is QuestCatalog, "the production catalog loads as QuestCatalog")
	if !(productionCatalog is QuestCatalog):
		_finish(null)
		return

	await testProductionCutsceneShots(productionCatalog)
	await testLocationScenes()
	await testFullProgression(productionCatalog)
	await testQuestShotDispatch()
	await testPlayedCutsceneKeys()

	# Leave the autoload on the production catalog for any later test/run.
	Quests.loadCatalog(productionCatalog)
	_finish(productionCatalog)


func _finish(_productionCatalog) -> void:
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("CHECK FAILED: ", message)


func _makeCatalog() -> QuestCatalog:
	var first = QuestObjectiveDefinitionScript.new()
	first.objective_id = "first_objective"
	first.objective_text = "Do the first thing."
	first.history_text = "Did the first thing."
	var second = QuestObjectiveDefinitionScript.new()
	second.objective_id = "second_objective"
	second.objective_text = "Do the second thing."
	second.history_text = "Did the second thing."
	var definition = QuestDefinitionScript.new()
	definition.quest_id = "test_quest"
	definition.title = "Test Quest"
	definition.summary = "A test quest."
	definition.objectives.assign([first, second])
	var catalog = QuestCatalogScript.new()
	catalog.definitions.assign([definition])
	return catalog


func _currentObjectiveId() -> String:
	var entries: Array[Dictionary] = Quests.getQuestJournalEntries()
	for entry in entries:
		if entry["quest_id"] == "test_quest":
			return str(entry["current_objective"].get("objective_id", ""))
	return ""


func testProductionCutsceneShots(productionCatalog: QuestCatalog) -> void:
	print("--- Production cutscene quest shots ---")
	var definition: QuestDefinition = productionCatalog.definitions[0]
	var completedObjectiveIds: Array[String] = []
	for fileName in EXPECTED_SHOT_FILES:
		var expectedShots: Array = EXPECTED_SHOTS[fileName]
		var path: String = CUTSCENE_DIR + fileName
		check(ResourceLoader.exists(path), "cutscene data '%s' exists" % fileName)
		if !ResourceLoader.exists(path):
			continue
		var cutsceneData = load(path).new().data
		check(cutsceneData is Dictionary, "cutscene data '%s' loads as a Dictionary" % fileName)
		if !(cutsceneData is Dictionary):
			continue
		var shots: Array = cutsceneData.get("shots", [])
		check(!shots.is_empty(), "cutscene '%s' has shots" % fileName)

		var questShots: Array = []
		var firstQuestShot := -1
		for index in shots.size():
			var shot = shots[index]
			if !(shot is Dictionary):
				continue
			var shotDictionary := shot as Dictionary
			if str(shotDictionary.get("object", "")) != "quest":
				continue
			if firstQuestShot < 0:
				firstQuestShot = index
			questShots.append(shotDictionary.get("data", {}))
		check(questShots.size() == expectedShots.size(), "cutscene '%s' has %d quest shot(s), got %d" % [fileName, expectedShots.size(), questShots.size()])
		check(firstQuestShot >= 0 and firstQuestShot + questShots.size() == shots.size(), "cutscene '%s' quest shots are its final shots" % fileName)

		for index in mini(expectedShots.size(), questShots.size()):
			var expected: Dictionary = expectedShots[index]
			var actual: Dictionary = questShots[index]
			check(str(actual.get("action", "")) == str(expected["action"]), "cutscene '%s' shot %d action is '%s'" % [fileName, index, expected["action"]])
			check(str(actual.get("quest_id", "")) == QUEST_ID, "cutscene '%s' shot %d targets %s" % [fileName, index, QUEST_ID])
			var expectedObjectiveId := str(expected["objective_id"])
			if expectedObjectiveId.is_empty():
				continue
			check(str(actual.get("objective_id", "")) == expectedObjectiveId, "cutscene '%s' shot %d objective is '%s'" % [fileName, index, expectedObjectiveId])
			check(definition.objectiveIndex(expectedObjectiveId) >= 0, "cutscene objective '%s' exists in the production quest" % expectedObjectiveId)
			completedObjectiveIds.append(expectedObjectiveId)

	var expectedObjectiveOrder := []
	for objective in definition.objectives:
		expectedObjectiveOrder.append(objective.objective_id)
	check(completedObjectiveIds == expectedObjectiveOrder, "cutscene shots complete objectives in production order, got %s" % [completedObjectiveIds])


func testLocationScenes() -> void:
	print("\n--- Prologue location scenes ---")
	for locationName in PROLOGUE_LOCATIONS:
		var expected: Dictionary = PROLOGUE_LOCATIONS[locationName]
		var path := str(expected["path"])
		check(ResourceLoader.exists(path), "location scene '%s' exists" % locationName)
		if !ResourceLoader.exists(path):
			continue
		var packed = load(path)
		check(packed is PackedScene, "location scene '%s' loads as a PackedScene" % locationName)
		if !(packed is PackedScene):
			continue
		var instance = packed.instantiate()
		check(instance.get_node_or_null("Fade") != null, "location '%s' has its fade" % locationName)

		var cutsceneName := str(expected["cutscene"])
		if !cutsceneName.is_empty():
			var trigger = instance.get_node_or_null("Cutscenes/%s/Cutscene" % cutsceneName)
			check(trigger != null, "location '%s' has its cutscene trigger" % locationName)
			if trigger != null:
				check(str(trigger.cutsceneName) == cutsceneName, "location '%s' trigger names '%s'" % [locationName, cutsceneName])

		var exitName := str(expected["exit"])
		if !exitName.is_empty():
			var exitNode = instance.get_node_or_null("Exits/%s/Exit" % exitName)
			check(exitNode != null, "location '%s' exits to '%s'" % [locationName, exitName])
			if exitNode != null:
				var exitToValue = exitNode.exitTo
				check(exitToValue is Dictionary, "location '%s' exit data is a Dictionary" % locationName)
				if exitToValue is Dictionary:
					var exitTo := exitToValue as Dictionary
					check(str(exitTo.get("location", "")) == exitName, "location '%s' exit target is '%s'" % [locationName, exitName])
					check(exitTo.has("playerPosition"), "location '%s' exit provides a player position" % locationName)
		instance.free()


func _onProgressionSignal(questId: String) -> void:
	progressionSignals.append(questId)


func testFullProgression(productionCatalog: QuestCatalog) -> void:
	print("\n--- Full production progression ---")
	check(Quests.loadCatalog(productionCatalog), "the production catalog loads for the full run")
	progressionSignals.clear()
	Quests.questStateChanged.connect(_onProgressionSignal)
	var handler = CutsceneScript.new()

	for fileName in EXPECTED_SHOT_FILES:
		var path: String = CUTSCENE_DIR + fileName
		var cutsceneData = load(path).new().data
		if !(cutsceneData is Dictionary):
			continue
		var shots: Array = cutsceneData.get("shots", [])
		for shotValue in shots:
			if !(shotValue is Dictionary):
				continue
			var shot := shotValue as Dictionary
			if str(shot.get("object", "")) != "quest":
				continue
			handler.cutscene = { "shots": [shot] }
			handler.wait = false
			handler.advanceScene()

	var entries: Array[Dictionary] = Quests.getQuestJournalEntries()
	check(entries.size() == 1, "the full run leaves exactly one known quest")
	if entries.size() == 1:
		var entry: Dictionary = entries[0]
		check(entry["status"] == "completed", "the full run completes Pistoleros Regroup")
		check(entry["current_objective"].is_empty(), "the completed quest has no current objective")
		var history: Array = entry["history"]
		var historyIds := []
		for historyEntry in history:
			historyIds.append(historyEntry["objective_id"])
		var expectedIds := [
			"find_gwyneth",
			"find_aiyana",
			"find_manuel",
			"find_morrison",
			"regroup_pistoleros_of_santa_rose",
		]
		check(history.size() == 5, "the full run records five completed objectives, got %d" % history.size())
		check(historyIds == expectedIds, "the full run history is in objective order, got %s" % [historyIds])
	check(Quests.getCurrentMapMarkers().is_empty(), "the completed quest leaves no current map markers")
	check(progressionSignals.size() == 6, "the full run emits start plus five completions, got %d" % progressionSignals.size())

	handler.cutscene = {
		"shots": [{ "object": "quest", "data": { "action": "complete_objective", "quest_id": QUEST_ID, "objective_id": "regroup_pistoleros_of_santa_rose" } }],
	}
	handler.advanceScene()
	entries = Quests.getQuestJournalEntries()
	check(entries.size() == 1 and entries[0]["history"].size() == 5, "replaying the final shot does not duplicate history")
	check(progressionSignals.size() == 6, "replaying the final shot emits no extra signal")

	Quests.questStateChanged.disconnect(_onProgressionSignal)
	handler.free()


func testQuestShotDispatch() -> void:
	print("\n--- Quest shot dispatch ---")
	check(Quests.loadCatalog(_makeCatalog()), "the dispatch test catalog loads")
	var handler = CutsceneScript.new()
	handler.wait = false
	handler.cutscene = {
		"shots": [{ "object": "quest", "data": { "action": "start", "quest_id": "test_quest" } }],
	}
	handler.advanceScene()
	check(handler.wait == false, "a quest shot does not block the cutscene")
	check(_currentObjectiveId() == "first_objective", "the start shot makes the first objective current")

	handler.cutscene = {
		"shots": [{ "object": "quest", "data": { "action": "complete_objective", "quest_id": "test_quest", "objective_id": "first_objective" } }],
	}
	handler.advanceScene()
	check(_currentObjectiveId() == "second_objective", "a complete_objective shot advances the quest")
	check(handler.wait == false, "an advancing quest shot does not block the cutscene")

	handler.cutscene = {
		"shots": [{ "object": "quest", "data": { "action": "complete_objective", "quest_id": "test_quest", "objective_id": "missing_objective" } }],
	}
	handler.advanceScene()
	check(_currentObjectiveId() == "second_objective", "a rejected objective leaves progress unchanged")
	check(handler.wait == false, "a rejected objective does not block the cutscene")

	handler.cutscene = {
		"shots": [{ "object": "quest", "data": { "action": "not_a_real_action", "quest_id": "test_quest" } }],
	}
	handler.advanceScene()
	check(_currentObjectiveId() == "second_objective", "an unknown action leaves progress unchanged")
	check(handler.wait == false, "an unknown action does not block the cutscene")

	check(Quests.loadCatalog(_makeCatalog()), "the catalog reloads for the unknown-quest check")
	handler.cutscene = {
		"shots": [{ "object": "quest", "data": { "action": "start", "quest_id": "missing_quest" } }],
	}
	handler.advanceScene()
	check(Quests.getQuestJournalEntries().is_empty(), "an unknown quest is rejected without creating state")
	handler.free()


func testPlayedCutsceneKeys() -> void:
	print("\n--- Played cutscene keys ---")
	var cutsceneAutoload = get_tree().root.get_node_or_null("Cutscene")
	check(cutsceneAutoload != null, "the Cutscene autoload is available")
	if cutsceneAutoload == null:
		return
	var actualKeys: Array = cutsceneAutoload.playedCutscenes.keys()
	actualKeys.sort()
	var expectedKeys := ["Blackberry Retreat", "Finch Pond", "Great Fall Ridge", "Littlehill Grove", "Pine Meadows"]
	expectedKeys.sort()
	check(actualKeys == expectedKeys, "playedCutscenes tracks the five Pistoleros Regroup cutscene names, got %s" % [actualKeys])
