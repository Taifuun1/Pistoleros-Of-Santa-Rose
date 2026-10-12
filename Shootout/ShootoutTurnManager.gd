class_name ShootoutTurnManager
extends RefCounted


signal battleEnded(winningSide)

var shootoutActors = {
	Shootout.TEAM_PLAYER: {},
	Shootout.TEAM_ENEMY: {}
}
var turnOrder = []
var battleOver = false

var shootout


func init(shootoutRoot) -> void:
	shootout = shootoutRoot

func registerActor(actorSide: String, actorName: String, actorPosition) -> void:
	shootoutActors[actorSide][actorName] = { "actorPosition": actorPosition }

func createTurnOrder() -> void:
	var actorsHighTailin = []
	for actorSide in shootoutActors:
		for actorName in shootoutActors[actorSide]:
			var actor = shootout.getActor(actorName)
			actorsHighTailin.append({
				"actorName": actorName,
				"highTailin": shootout.rodeoManager.getStatModifier(actor, "highTailin", actor.stats.highTailin)
			})
	actorsHighTailin.sort_custom(HelperFunctions.sortToTurnOrder)
	turnOrder.clear()
	for actor in actorsHighTailin:
		turnOrder.append(actor.actorName)

func currentActorName() -> String:
	if turnOrder.is_empty():
		return ""
	return turnOrder.front()

func advanceTurn() -> void:
	if !turnOrder.is_empty():
		turnOrder.pop_front()

func sideOfActor(actorName: String) -> String:
	for actorSide in shootoutActors:
		if shootoutActors[actorSide].has(actorName):
			return actorSide
	return ""

func isPlayerActing(actorName: String) -> bool:
	return shootoutActors[Shootout.TEAM_PLAYER].has(actorName)

func checkActorDead(actor) -> bool:
	if actor == null or actor.hp > 0:
		return false
	turnOrder.erase(actor.name)
	for actorSide in shootoutActors:
		shootoutActors[actorSide].erase(actor.name)
	shootout.rodeoManager.unregisterActor(actor.name)
	actor.queue_free()
	checkBattleEnd()
	return true

func checkBattleEnd() -> void:
	if battleOver:
		return
	if shootoutActors[Shootout.TEAM_PLAYER].is_empty():
		battleOver = true
		battleEnded.emit(Shootout.TEAM_ENEMY)
	elif shootoutActors[Shootout.TEAM_ENEMY].is_empty():
		battleOver = true
		battleEnded.emit(Shootout.TEAM_PLAYER)
