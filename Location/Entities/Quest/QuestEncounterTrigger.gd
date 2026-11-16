extends "res://Nodes/Interaction/LocationInteractable.gd"

## Proximity trigger that launches an authored quest Shootout. The request is
## validated by SceneManager; objective completion happens centrally from the
## acknowledged Shootout result, never from this node.

@export var questId := ""
@export var objectiveId := ""
@export var encounterPath := ""
@export var zoneId := ""


func canActivate() -> bool:
	if !enabled or !playerNearby:
		return false
	if questId.is_empty() or objectiveId.is_empty() or encounterPath.is_empty() or zoneId.is_empty():
		return false
	return Quests != null and Quests.call("isCurrentObjective", questId, objectiveId)


func activate() -> void:
	if !canActivate():
		return
	var sceneManager := HelperFunctions.sceneManagerNode()
	if sceneManager == null or !sceneManager.has_method("launchShootout"):
		push_warning("QuestEncounterTrigger: SceneManager is unavailable.")
		return
	var launched: bool = sceneManager.call("launchShootout", {
		"encounterPath": encounterPath,
		"zoneId": zoneId,
		"source": "quest",
		"sourceId": "%s:%s" % [questId, objectiveId],
		"progression": {
			"questId": questId,
			"objectiveId": objectiveId,
			"band": "early",
		},
	})
	if launched:
		enabled = false
		activated.emit(self)
	else:
		push_warning("QuestEncounterTrigger: SceneManager rejected '%s:%s'." % [questId, objectiveId])
