extends SceneTree

## Headless validation for the quest definitions and authoritative state
## (Docs/System Design/Journal/Quests.md, stage 1).
## Run with: godot --headless --script res://Tests/TestQuests.gd

const QuestObjectiveDefinitionScript = preload("res://Data/Quests/QuestObjectiveDefinition.gd")
const QuestDefinitionScript = preload("res://Data/Quests/QuestDefinition.gd")
const QuestCatalogScript = preload("res://Data/Quests/QuestCatalog.gd")
const QuestsScript = preload("res://Globals/Quests.gd")

var failures := 0
var service: Node
var changedQuestIds: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	service = QuestsScript.new()
	service.questStateChanged.connect(func(questId: String) -> void: changedQuestIds.append(questId))

	testValidation()
	testCatalogAvailability()
	testProductionCatalog()
	testInvalidCatalogClearsState()
	testStartRejections()
	testLinearProgress()
	testNoUpcomingObjectives()
	testTargetlessObjective()
	testDeterministicOrdering()
	testProjectionIsolation()
	testReloadClearsRuntimeState()

	service.free()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func testValidation() -> void:
	print("--- Definition validation ---")
	var validObjective := _makeObjective("find_gwyneth", "Find Gwyneth", "Found Gwyneth's trail", "Finch Pond")
	var validDefinition := _makeDefinition("pistoleros_regroup", "Pistoleros Regroup", "Regroup the gang.", 0, [validObjective])
	_check(validDefinition.validate().is_empty(), "a valid definition has no errors")
	_check(validDefinition.objectiveIndex("find_gwyneth") == 0, "objectiveIndex finds the first objective")
	_check(validDefinition.objectiveIndex("missing") == -1, "objectiveIndex returns -1 for an unknown objective")

	var emptyDefinition := _makeDefinition("", "", "", 0, [])
	_check(emptyDefinition.validate().size() == 4, "empty id/title/summary/objectives report four errors, got %d" % emptyDefinition.validate().size())

	var badObjective := _makeObjective("bad id", "", "", "")
	var badObjectiveDefinition := _makeDefinition("quest_one", "Quest One", "Summary.", 0, [badObjective])
	_check(badObjectiveDefinition.validate().size() == 3, "invalid objective id plus empty texts report three errors, got %d" % badObjectiveDefinition.validate().size())

	var duplicateObjectiveDefinition := _makeDefinition("quest_two", "Quest Two", "Summary.", 0, [validObjective, validObjective])
	_check(_hasError(duplicateObjectiveDefinition.validate(), "duplicate objective_id"), "duplicate objective ids are rejected")

	var nullObjectiveDefinition := _makeDefinition("quest_three", "Quest Three", "Summary.", 0, [])
	nullObjectiveDefinition.objectives.append(null)
	_check(_hasError(nullObjectiveDefinition.validate(), "is null"), "null objectives are rejected")

	var duplicateQuestCatalog := _makeCatalog([validDefinition, validDefinition])
	_check(_hasError(duplicateQuestCatalog.validate(), "duplicate quest_id"), "duplicate quest ids are rejected")
	var nullQuestCatalog := _makeCatalog([])
	nullQuestCatalog.definitions.append(null)
	_check(_hasError(nullQuestCatalog.validate(), "is null"), "null catalog definitions are rejected")
	_check(_makeCatalog([]).validate().is_empty(), "an empty catalog is valid")


func testCatalogAvailability() -> void:
	print("\n--- Catalog availability ---")
	_check(!service.isQuestDataAvailable(), "a fresh service is unavailable")
	_check(service.getQuestJournalEntries().is_empty(), "unavailable entries are empty")
	_check(service.getCurrentMapMarkers().is_empty(), "unavailable markers are empty")
	_check(!service.loadCatalog(null), "a null catalog fails to load")
	_check(!service.isQuestDataAvailable(), "a failed load stays unavailable")

	_check(service.loadCatalog(_makeCatalog([])), "an empty catalog loads")
	_check(service.isQuestDataAvailable(), "an empty catalog is available")
	_check(service.getQuestJournalEntries().is_empty(), "an empty catalog has no entries")
	_check(service.getCurrentMapMarkers().is_empty(), "an empty catalog has no markers")


func testProductionCatalog() -> void:
	print("\n--- Production catalog ---")
	var catalog = load("res://Data/Quests/QuestCatalog.tres")
	_check(catalog is QuestCatalog, "the production catalog resource loads as QuestCatalog")
	if !(catalog is QuestCatalog):
		return
	_check(catalog.definitions.size() == 1, "the production catalog contains Pistoleros Regroup")
	_check(catalog.validate().is_empty(), "the production catalog is valid")
	_check(service.loadCatalog(catalog), "the production catalog loads through the service")
	_check(service.isQuestDataAvailable(), "the production catalog is available")
	_check(service.getQuestJournalEntries().is_empty(), "the production catalog has no known quests before start")
	_check(service.getCurrentMapMarkers().is_empty(), "the production catalog has no markers before start")

	var definition: QuestDefinition = catalog.definitions[0]
	_check(definition.quest_id == "pistoleros_regroup" and definition.title == "Pistoleros Regroup", "the production quest identity is correct")
	var expectedObjectiveIds := [
		"find_gwyneth",
		"find_aiyana",
		"find_manuel",
		"find_morrison",
		"regroup_pistoleros_of_santa_rose",
	]
	var actualObjectiveIds := []
	for objective in definition.objectives:
		actualObjectiveIds.append(objective.objective_id)
	_check(actualObjectiveIds == expectedObjectiveIds, "the production objective order is find Gwyneth, Aiyana, Manuel, Morrison, regroup, got %s" % [actualObjectiveIds])
	var mapData = load("res://Data/Overworld/OverworldMapData.tres") as OverworldMapData
	for objective in definition.objectives:
		if objective.map_target_id.is_empty():
			continue
		_check(mapData != null and !mapData.resolveLocation(objective.map_target_id).is_empty(), "objective '%s' map target '%s' resolves through the manifest" % [objective.objective_id, objective.map_target_id])

	_check(service.startQuest("pistoleros_regroup"), "the production quest starts")
	var entry := _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(entry["current_objective"]["objective_id"] == "find_gwyneth", "the production quest starts at find_gwyneth")
	_check(service.getCurrentMapMarkers().is_empty(), "the production quest has no map markers while all targets are empty")


func testInvalidCatalogClearsState() -> void:
	print("\n--- Invalid catalog fails closed ---")
	_loadSingleQuestCatalog()
	_check(service.startQuest("pistoleros_regroup"), "the valid catalog starts a quest")
	_check(!service.getQuestJournalEntries().is_empty(), "the started quest has an entry")

	var invalidDefinition := _makeDefinition("broken_quest", "", "", 0, [])
	_check(!service.loadCatalog(_makeCatalog([invalidDefinition])), "an invalid catalog fails to load")
	_check(!service.isQuestDataAvailable(), "an invalid catalog is unavailable")
	_check(service.getQuestJournalEntries().is_empty(), "an invalid catalog clears entries")
	_check(service.getCurrentMapMarkers().is_empty(), "an invalid catalog clears markers")
	_check(!service.startQuest("pistoleros_regroup"), "commands fail while unavailable")


func testStartRejections() -> void:
	print("\n--- Start rejections ---")
	_loadSingleQuestCatalog()
	changedQuestIds.clear()
	_check(service.startQuest("unknown_quest") == false, "an unknown quest cannot start")
	_check(changedQuestIds.is_empty(), "an unknown quest emits no signal")
	_check(service.startQuest("pistoleros_regroup"), "the known quest starts")
	_check(changedQuestIds == ["pistoleros_regroup"], "starting emits once, got %s" % [changedQuestIds])
	_check(service.startQuest("pistoleros_regroup") == false, "a known quest cannot start twice")
	_check(changedQuestIds == ["pistoleros_regroup"], "a duplicate start emits no signal")


func testLinearProgress() -> void:
	print("\n--- Linear objective progress ---")
	_loadProgressCatalog()
	changedQuestIds.clear()
	_check(service.startQuest("pistoleros_regroup"), "the three-objective quest starts")
	var entry := _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(entry["status"] == "active", "a started quest is active")
	_check(entry["current_objective"]["objective_id"] == "find_gwyneth", "the first objective is current")
	_check(entry["history"].is_empty(), "a started quest has no history")
	var markers: Array[Dictionary] = service.getCurrentMapMarkers()
	_check(markers.size() == 1 and markers[0]["objective_id"] == "find_gwyneth" and markers[0]["target_id"] == "Finch Pond", "the current objective produces its map marker")
	_check(markers[0]["icon"] == "quest_current", "markers use the quest_current icon")

	_check(!service.completeCurrentObjective("pistoleros_regroup", "regroup_camp"), "a non-current objective cannot complete")
	_check(!service.completeCurrentObjective("unknown_quest", "find_gwyneth"), "an unknown quest cannot complete")
	_check(changedQuestIds == ["pistoleros_regroup"], "rejected completions emit no signal")

	_check(service.completeCurrentObjective("pistoleros_regroup", "find_gwyneth"), "the current objective completes")
	entry = _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(entry["current_objective"]["objective_id"] == "regroup_camp", "the next objective becomes current")
	_check(entry["history"].size() == 1 and entry["history"][0]["objective_id"] == "find_gwyneth", "completed history records the objective")
	_check(entry["history"][0]["text"] == "Found Gwyneth's trail", "history uses history_text")
	_check(service.getCurrentMapMarkers().is_empty(), "a targetless current objective produces no marker")

	_check(!service.completeCurrentObjective("pistoleros_regroup", "find_gwyneth"), "a completed objective cannot complete again")
	_check(!service.completeCurrentObjective("pistoleros_regroup", "reach_lazysprings"), "an out-of-order objective cannot complete")
	entry = _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(entry["current_objective"]["objective_id"] == "regroup_camp" and entry["history"].size() == 1, "rejected completions leave state unchanged")

	_check(service.completeCurrentObjective("pistoleros_regroup", "regroup_camp"), "the second objective completes")
	markers = service.getCurrentMapMarkers()
	_check(markers.size() == 1 and markers[0]["target_id"] == "Lazysprings", "the third objective exposes its map target")

	_check(service.completeCurrentObjective("pistoleros_regroup", "reach_lazysprings"), "the final objective completes")
	entry = _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(entry["status"] == "completed", "the final objective completes the quest")
	_check(entry["current_objective"].is_empty(), "a completed quest has no current objective")
	_check(entry["history"].size() == 3, "all completed objectives remain in history")
	_check(entry["history"][2]["objective_id"] == "reach_lazysprings", "history preserves completion order")
	_check(service.getCurrentMapMarkers().is_empty(), "a completed quest produces no marker")
	_check(!service.completeCurrentObjective("pistoleros_regroup", "reach_lazysprings"), "a completed quest rejects further progress")
	_check(changedQuestIds.size() == 4, "start plus three completions emit four signals, got %d" % changedQuestIds.size())


func testNoUpcomingObjectives() -> void:
	print("\n--- Upcoming objectives stay hidden ---")
	_loadProgressCatalog()
	service.startQuest("pistoleros_regroup")
	var entry := _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(!str(entry).contains("Regroup at camp"), "the second objective text is not exposed")
	_check(!str(entry).contains("Reach Lazysprings"), "the third objective text is not exposed")
	service.completeCurrentObjective("pistoleros_regroup", "find_gwyneth")
	entry = _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(!str(entry).contains("Reach Lazysprings"), "the next future objective stays hidden after advancing")
	_check(str(entry).contains("Regroup at camp"), "the current objective becomes visible after advancing")


func testTargetlessObjective() -> void:
	print("\n--- Targetless objectives ---")
	var definition := _makeDefinition("targetless_quest", "Targetless", "No map target.", 0, [
		_makeObjective("look_around", "Look around", "Looked around", ""),
	])
	_check(service.loadCatalog(_makeCatalog([definition])), "the targetless catalog loads")
	service.startQuest("targetless_quest")
	var entry := _entryById(service.getQuestJournalEntries(), "targetless_quest")
	_check(entry["current_objective"]["target_id"] == "", "a targetless objective exposes an empty target id")
	_check(service.getCurrentMapMarkers().is_empty(), "a targetless objective produces no marker")


func testDeterministicOrdering() -> void:
	print("\n--- Deterministic ordering ---")
	var questA := _makeDefinition("quest_a", "Quest A", "Summary.", 1, [_makeObjective("objective_a", "A next", "A history", "Alpha")])
	var questC := _makeDefinition("quest_c", "Quest C", "Summary.", 1, [_makeObjective("objective_c", "C next", "C history", "Beta")])
	var questB := _makeDefinition("quest_b", "Quest B", "Summary.", 2, [_makeObjective("objective_b", "B next", "B history", "")])
	_check(service.loadCatalog(_makeCatalog([questB, questC, questA])), "the out-of-order catalog loads")
	service.startQuest("quest_b")
	service.startQuest("quest_c")
	service.startQuest("quest_a")

	var entries: Array[Dictionary] = service.getQuestJournalEntries()
	_check(entries.size() == 3, "all known quests are projected")
	_check(entries[0]["quest_id"] == "quest_a" and entries[1]["quest_id"] == "quest_c" and entries[2]["quest_id"] == "quest_b", "entries sort by sort_order then quest_id, got %s" % [_questIds(entries)])
	var markers: Array[Dictionary] = service.getCurrentMapMarkers()
	_check(_questIds(markers) == ["quest_a", "quest_c"], "markers follow the same order and skip targetless objectives, got %s" % [_questIds(markers)])


func testProjectionIsolation() -> void:
	print("\n--- Projection isolation ---")
	_loadProgressCatalog()
	service.startQuest("pistoleros_regroup")
	var entries: Array[Dictionary] = service.getQuestJournalEntries()
	entries[0]["title"] = "Mutated"
	entries[0]["status"] = "completed"
	entries[0]["history"].append({ "objective_id": "fake", "text": "Fake" })
	entries[0]["current_objective"]["objective_id"] = "fake"
	entries[0]["current_objective"]["target_id"] = "Fake"
	var markers: Array[Dictionary] = service.getCurrentMapMarkers()
	markers[0]["target_id"] = "Fake"

	var freshEntry := _entryById(service.getQuestJournalEntries(), "pistoleros_regroup")
	_check(freshEntry["title"] == "Pistoleros Regroup", "mutating an entry does not change the title")
	_check(freshEntry["status"] == "active", "mutating an entry does not change the status")
	_check(freshEntry["history"].is_empty(), "mutating an entry's history does not change state")
	_check(freshEntry["current_objective"]["objective_id"] == "find_gwyneth", "mutating the current objective does not change state")
	var freshMarkers: Array[Dictionary] = service.getCurrentMapMarkers()
	_check(freshMarkers[0]["target_id"] == "Finch Pond", "mutating a marker does not change the target")


func testReloadClearsRuntimeState() -> void:
	print("\n--- Reload resets runtime state ---")
	var catalog := _progressCatalog()
	_check(service.loadCatalog(catalog), "the catalog loads")
	service.startQuest("pistoleros_regroup")
	_check(!service.getQuestJournalEntries().is_empty(), "the quest is known before reload")
	_check(service.loadCatalog(catalog), "the same catalog reloads")
	_check(service.isQuestDataAvailable(), "the reloaded catalog is available")
	_check(service.getQuestJournalEntries().is_empty(), "reloading clears known quests")
	_check(service.getCurrentMapMarkers().is_empty(), "reloading clears markers")
	_check(service.currentMainQuestLevel == { "level": 1, "rarity": "common" }, "currentMainQuestLevel is preserved")


func _loadSingleQuestCatalog() -> void:
	_check(service.loadCatalog(_makeCatalog([_singleObjectiveDefinition()])), "the single-quest catalog loads")


func _loadProgressCatalog() -> void:
	_check(service.loadCatalog(_progressCatalog()), "the progress catalog loads")


func _singleObjectiveDefinition() -> QuestDefinition:
	return _makeDefinition("pistoleros_regroup", "Pistoleros Regroup", "Regroup the gang.", 0, [
		_makeObjective("find_gwyneth", "Find Gwyneth", "Found Gwyneth's trail", "Finch Pond"),
	])


func _progressCatalog() -> QuestCatalog:
	var definition := _makeDefinition("pistoleros_regroup", "Pistoleros Regroup", "Regroup the gang.", 0, [
		_makeObjective("find_gwyneth", "Find Gwyneth", "Found Gwyneth's trail", "Finch Pond"),
		_makeObjective("regroup_camp", "Regroup at camp", "Regrouped at camp", ""),
		_makeObjective("reach_lazysprings", "Reach Lazysprings", "Reached Lazysprings", "Lazysprings"),
	])
	return _makeCatalog([definition])


func _makeObjective(objectiveId: String, objectiveText: String, historyText: String, mapTargetId: String) -> QuestObjectiveDefinition:
	var objective = QuestObjectiveDefinitionScript.new()
	objective.objective_id = objectiveId
	objective.objective_text = objectiveText
	objective.history_text = historyText
	objective.map_target_id = mapTargetId
	return objective


func _makeDefinition(questId: String, title: String, summary: String, sortOrder: int, objectives: Array) -> QuestDefinition:
	var definition = QuestDefinitionScript.new()
	definition.quest_id = questId
	definition.title = title
	definition.summary = summary
	definition.sort_order = sortOrder
	definition.objectives.assign(objectives)
	return definition


func _makeCatalog(definitions: Array) -> QuestCatalog:
	var catalog = QuestCatalogScript.new()
	catalog.definitions.assign(definitions)
	return catalog


func _entryById(entries: Array[Dictionary], questId: String) -> Dictionary:
	for entry in entries:
		if entry["quest_id"] == questId:
			return entry
	return {}


func _questIds(items: Array[Dictionary]) -> Array:
	var ids := []
	for item in items:
		ids.append(item["quest_id"])
	return ids


func _hasError(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("CHECK FAILED: ", message)
