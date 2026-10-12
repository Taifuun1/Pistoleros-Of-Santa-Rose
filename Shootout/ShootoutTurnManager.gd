class_name ShootoutTurnManager
extends RefCounted


signal battleEnded(winningSide)

# Local copies of the team names (same values as the Shootout autoload constants)
# so the manager stays loadable in headless test runs, where autoloads don't exist.
const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"

# Placeholder initiative roll size; confirmed as a balance placeholder (see
# Docs/System Design/Shootout/Turns and Initiative.md).
const RANDOM_ROLL_MAX = 4

var shootoutActors = {
	TEAM_PLAYER: {},
	TEAM_ENEMY: {}
}
var turnOrder = []
var battleOver = false
var roundNumber = 1
var turnNumber = 0
var firstOrderCreated = false

var shootout


func init(shootoutRoot) -> void:
	shootout = shootoutRoot

func registerActor(actorSide: String, actorName: String, actorPosition) -> void:
	shootoutActors[actorSide][actorName] = { "actorPosition": actorPosition }

func createTurnOrder() -> void:
	if firstOrderCreated:
		roundNumber += 1
	else:
		firstOrderCreated = true
	var initiatives = []
	for actorSide in shootoutActors:
		for actorName in shootoutActors[actorSide]:
			var actor = shootout.getActor(actorName)
			if actor == null:
				continue
			var highTailin = shootout.rodeoManager.getStatModifier(actor, "highTailin", actor.stats.highTailin)
			initiatives.append({
				"actorName": actorName,
				"initiative": int(highTailin) + randi_range(0, RANDOM_ROLL_MAX),
				"tiebreak": randf()
			})
	initiatives.sort_custom(sortByInitiative)
	turnOrder.clear()
	for entry in initiatives:
		turnOrder.append(entry.actorName)

# Descending initiative; equal initiative is broken by a random tiebreak so
# even stats produce a random order ("On even stats, turn order is random").
static func sortByInitiative(a, b) -> bool:
	if int(a.initiative) == int(b.initiative):
		return float(a.tiebreak) < float(b.tiebreak)
	return int(a.initiative) > int(b.initiative)

func getRoundNumber() -> int:
	return roundNumber

func getTurnNumber() -> int:
	return turnNumber

func currentActorName() -> String:
	if turnOrder.is_empty():
		return ""
	return turnOrder.front()

func advanceTurn() -> void:
	if !turnOrder.is_empty():
		turnOrder.pop_front()
		turnNumber += 1

func sideOfActor(actorName: String) -> String:
	for actorSide in shootoutActors:
		if shootoutActors[actorSide].has(actorName):
			return actorSide
	return ""

func isPlayerActing(actorName: String) -> bool:
	return shootoutActors[TEAM_PLAYER].has(actorName)

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
	if shootoutActors[TEAM_PLAYER].is_empty():
		battleOver = true
		battleEnded.emit(TEAM_ENEMY)
	elif shootoutActors[TEAM_ENEMY].is_empty():
		battleOver = true
		battleEnded.emit(TEAM_PLAYER)
