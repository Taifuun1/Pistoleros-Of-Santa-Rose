class_name ShootoutTargetingManager
extends RefCounted


var turnManager


func init(turnManagerInit) -> void:
	turnManager = turnManagerInit

func isValidTarget(act: Dictionary, targetActorName: String, actingActorName: String) -> bool:
	var actingSide = turnManager.sideOfActor(actingActorName)
	var targetSide = turnManager.sideOfActor(targetActorName)
	if actingSide == "" or targetSide == "":
		return false
	match act.type:
		Shootout.ACT_TYPE_ATTACK:
			return actingSide != targetSide
		Shootout.ACT_TYPE_MOVES:
			return targetSide == getActSide(Shootout.movesData, act.get("name", ""))
		Shootout.ACT_TYPE_ITEMS:
			return targetSide == getActSide(Shootout.itemsData, act.get("name", ""))
	return false

func getActSide(dataSet: Dictionary, actName: String) -> String:
	var actData = dataSet.get(actName, null)
	if actData == null:
		return ""
	if actData.get("side", "") == "player":
		return Shootout.TEAM_PLAYER
	return Shootout.TEAM_ENEMY
