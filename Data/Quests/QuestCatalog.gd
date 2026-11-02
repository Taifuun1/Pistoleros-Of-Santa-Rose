extends Resource
class_name QuestCatalog

## Runtime loading entry point for quest definitions
## (Docs/System Design/Journal/Quests.md). An empty valid catalog is a valid
## "no quests" state; an invalid catalog is unavailable, never partial.

@export var definitions: Array[QuestDefinition] = []


## Returns every validation error across the whole catalog.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var seenQuestIds := {}
	for index in definitions.size():
		var definition := definitions[index]
		if definition == null:
			errors.append("catalog definition %d is null" % index)
			continue
		if seenQuestIds.has(definition.quest_id):
			errors.append("catalog has duplicate quest_id '%s'" % definition.quest_id)
		seenQuestIds[definition.quest_id] = true
		errors.append_array(definition.validate())
	return errors
