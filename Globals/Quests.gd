extends Node

## Authoritative quest state (Docs/System Design/Journal/Quests.md, stage 1).
## Definitions are authored Resources; this autoload owns only known quests'
## runtime progress and projects it for the Journal and Map read APIs. The
## Journal never mutates state: gameplay triggers call startQuest() and
## completeCurrentObjective().

signal questStateChanged(questId: String)

const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const CATALOG_PATH := "res://Data/Quests/QuestCatalog.tres"

var currentMainQuestLevel = {
	"level": 1,
	"rarity": "common"
}

## quest_id -> QuestDefinition.
var _definitions: Dictionary = {}
## quest_id -> {"status", "current_objective_id", "completed_objective_ids"}.
var _states: Dictionary = {}
var _dataAvailable := false


func _ready() -> void:
	if !ResourceLoader.exists(CATALOG_PATH):
		push_warning("Quests: catalog not found at " + CATALOG_PATH)
		return
	loadCatalog(load(CATALOG_PATH) as QuestCatalog)


## Initialization/test seam. Validation is all-or-nothing: a failure clears
## definitions and runtime state instead of exposing a partial story.
func loadCatalog(catalog: QuestCatalog) -> bool:
	_definitions = {}
	_states = {}
	_dataAvailable = false
	if catalog == null:
		push_warning("Quests: catalog is missing or has the wrong type.")
		return false
	var errors := catalog.validate()
	if !errors.is_empty():
		for error in errors:
			push_warning("Quests catalog: " + error)
		return false
	for definition in catalog.definitions:
		_definitions[definition.quest_id] = definition
	_dataAvailable = true
	return true


## True when a valid catalog (including an empty one) has been loaded.
func isQuestDataAvailable() -> bool:
	return _dataAvailable


## Makes a quest known and active at its first objective.
func startQuest(questId: String) -> bool:
	if !_dataAvailable or !_definitions.has(questId) or _states.has(questId):
		return false
	var definition: QuestDefinition = _definitions[questId]
	_states[questId] = {
		"status": STATUS_ACTIVE,
		"current_objective_id": definition.objectives[0].objective_id,
		"completed_objective_ids": [],
	}
	questStateChanged.emit(questId)
	return true


## Completes the exact current objective once and advances or completes the
## quest. Unknown, duplicate, and out-of-order calls do not change state.
func completeCurrentObjective(questId: String, objectiveId: String) -> bool:
	if !_dataAvailable or !_states.has(questId):
		return false
	var state: Dictionary = _states[questId]
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return false
	if str(state.get("current_objective_id", "")) != objectiveId:
		return false
	var definition: QuestDefinition = _definitions[questId]
	var objectiveIndex := definition.objectiveIndex(objectiveId)
	if objectiveIndex < 0:
		return false
	var completedObjectives: Array = state.get("completed_objective_ids", [])
	if completedObjectives.has(objectiveId):
		return false

	completedObjectives.append(objectiveId)
	if objectiveIndex + 1 < definition.objectives.size():
		state["current_objective_id"] = definition.objectives[objectiveIndex + 1].objective_id
	else:
		state["status"] = STATUS_COMPLETED
		state["current_objective_id"] = ""
	_states[questId] = state
	questStateChanged.emit(questId)
	return true


## UI-facing journal projection. Returns fresh Dictionaries/Arrays on every call
## so callers cannot mutate service state. Upcoming objectives are never exposed.
func getQuestJournalEntries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if !_dataAvailable:
		return entries
	for definition in _sortedDefinitions():
		if !_states.has(definition.quest_id):
			continue
		entries.append(_projectQuest(definition, _states[definition.quest_id]))
	return entries


## Current objectives for the Overworld map, in the same deterministic order as
## the journal projection. Completed quests and targetless objectives are absent.
func getCurrentMapMarkers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if !_dataAvailable:
		return markers
	for definition in _sortedDefinitions():
		if !_states.has(definition.quest_id):
			continue
		var objective := _currentObjectiveFor(definition, _states[definition.quest_id])
		if objective == null or objective.map_target_id.is_empty():
			continue
		markers.append({
			"quest_id": definition.quest_id,
			"objective_id": objective.objective_id,
			"target_id": objective.map_target_id,
			"icon": "quest_current",
		})
	return markers


func _projectQuest(definition: QuestDefinition, state: Dictionary) -> Dictionary:
	var history: Array[Dictionary] = []
	var completedObjectiveIds: Array = state.get("completed_objective_ids", [])
	for objectiveId in completedObjectiveIds:
		var index := definition.objectiveIndex(str(objectiveId))
		if index < 0:
			continue
		var completedObjective := definition.objectives[index]
		history.append({
			"objective_id": completedObjective.objective_id,
			"text": completedObjective.history_text,
		})

	var currentObjective: Dictionary = {}
	var objective := _currentObjectiveFor(definition, state)
	if objective != null:
		currentObjective = {
			"objective_id": objective.objective_id,
			"text": objective.objective_text,
			"target_id": objective.map_target_id,
		}

	return {
		"quest_id": definition.quest_id,
		"title": definition.title,
		"summary": definition.summary,
		"status": str(state.get("status", STATUS_ACTIVE)),
		"sort_order": definition.sort_order,
		"history": history,
		"current_objective": currentObjective,
	}


func _currentObjectiveFor(definition: QuestDefinition, state: Dictionary) -> QuestObjectiveDefinition:
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return null
	var objectiveId := str(state.get("current_objective_id", ""))
	var index := definition.objectiveIndex(objectiveId)
	if index < 0:
		return null
	return definition.objectives[index]


## Authored order: sort_order, then stable quest id as the tie-breaker.
func _sortedDefinitions() -> Array[QuestDefinition]:
	var definitions: Array[QuestDefinition] = []
	for definition in _definitions.values():
		definitions.append(definition as QuestDefinition)
	definitions.sort_custom(func(a: QuestDefinition, b: QuestDefinition) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.quest_id < b.quest_id
	)
	return definitions
