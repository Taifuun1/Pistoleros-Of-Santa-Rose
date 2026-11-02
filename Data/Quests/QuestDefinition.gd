extends Resource
class_name QuestDefinition

## Authored quest definition (Docs/System Design/Journal/Quests.md). Objectives
## are ordered and linear in the first iteration.

@export var quest_id: String = ""
@export var title: String = ""
@export_multiline var summary: String = ""
@export var sort_order: int = 0
@export var objectives: Array[QuestObjectiveDefinition] = []


## Returns every validation error instead of stopping at the first one.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if !quest_id.is_valid_identifier():
		errors.append("quest_id '%s' must be a non-empty identifier" % quest_id)
	if title.strip_edges().is_empty():
		errors.append("quest '%s' has an empty title" % quest_id)
	if summary.strip_edges().is_empty():
		errors.append("quest '%s' has an empty summary" % quest_id)
	if objectives.is_empty():
		errors.append("quest '%s' has no objectives" % quest_id)

	var seenObjectiveIds := {}
	for index in objectives.size():
		var objective := objectives[index]
		if objective == null:
			errors.append("quest '%s' objective %d is null" % [quest_id, index])
			continue
		if !objective.objective_id.is_valid_identifier():
			errors.append("quest '%s' objective %d has invalid objective_id '%s'" % [quest_id, index, objective.objective_id])
		if seenObjectiveIds.has(objective.objective_id):
			errors.append("quest '%s' has duplicate objective_id '%s'" % [quest_id, objective.objective_id])
		seenObjectiveIds[objective.objective_id] = true
		if objective.objective_text.strip_edges().is_empty():
			errors.append("quest '%s' objective '%s' has empty objective_text" % [quest_id, objective.objective_id])
		if objective.history_text.strip_edges().is_empty():
			errors.append("quest '%s' objective '%s' has empty history_text" % [quest_id, objective.objective_id])
		if !objective.map_target_id.is_empty() and objective.map_target_id.strip_edges().is_empty():
			errors.append("quest '%s' objective '%s' has a whitespace map_target_id" % [quest_id, objective.objective_id])
	return errors


## Index of an objective id in authored order, or -1 when absent.
func objectiveIndex(objectiveId: String) -> int:
	for index in objectives.size():
		var objective := objectives[index]
		if objective != null and objective.objective_id == objectiveId:
			return index
	return -1
