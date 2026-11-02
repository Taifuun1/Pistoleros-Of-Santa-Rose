extends Resource
class_name QuestObjectiveDefinition

## Authored quest objective (Docs/System Design/Journal/Quests.md). Immutable at
## runtime: the quest service owns progress and only reads these fields.

@export var objective_id: String = ""
## Shown as the current "Next" objective.
@export_multiline var objective_text: String = ""
## Added to progress history once this objective is completed.
@export_multiline var history_text: String = ""
## Optional stable Location/key-point id in the generated Overworld map.
@export var map_target_id: String = ""
