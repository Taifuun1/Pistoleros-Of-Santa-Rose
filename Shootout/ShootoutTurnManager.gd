class_name ShootoutTurnManager
extends RefCounted


signal battleEnded(winningSide)

const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"

const RANDOM_ROLL_MAX = 4

const FLEE_TURN_THRESHOLD = 10

var shootoutActors = {
	TEAM_PLAYER: {},
	TEAM_ENEMY: {}
}
var turnOrder = []
var battleOver = false
var winCondition = {}
var encounterKind = "dustup"
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

static func sortByInitiative(a, b) -> bool:
	if int(a.initiative) == int(b.initiative):
		return float(a.tiebreak) < float(b.tiebreak)
	return int(a.initiative) > int(b.initiative)

func currentActorName() -> String:
	if turnOrder.is_empty():
		return ""
	return turnOrder.front()

func advanceTurn() -> void:
	if !turnOrder.is_empty():
		turnOrder.pop_front()
		turnNumber += 1

func getRoundNumber() -> int:
	return roundNumber

func getTurnNumber() -> int:
	return turnNumber

func getActorPosition(actorName: String) -> int:
	for actorSide in shootoutActors:
		if shootoutActors[actorSide].has(actorName):
			return int(shootoutActors[actorSide][actorName].actorPosition)
	return -1

func actorAtPosition(actorSide: String, column: int) -> String:
	for actorName in shootoutActors[actorSide]:
		if int(shootoutActors[actorSide][actorName].actorPosition) == column:
			return actorName
	return ""

func placeActor(actorName: String, actorSide: String, column: int) -> void:
	shootoutActors[actorSide][actorName].actorPosition = column
	var actor = shootout.getActor(actorName)
	if actor != null:
		actor.position = shootout.getPositionForColumn(actorSide, column)

## Squeeze repositioning (Docs/Features and Issues.md): the mover takes the
## target column, and the occupant of the target plus everyone between the
## target and the mover's old spot shift one column toward the vacated spot.
## A one-column move swaps the two fighters (1 -> 2 leaves 2, 1, 3); a
## multi-column move shuffles the line (from 4 -> 2: 2 -> 3, 3 -> 4, mover
## -> 2, leaving 1, 4, 2, 3). The displaced chain fills exactly the vacated
## span, so the move only fails for unregistered actors, out-of-row targets
## clamped to a no-op — never because the row is full (the old push-past-the-
## end rule is what broke forward moves).
func setActorPosition(actorName: String, column) -> bool:
	var actorSide = sideOfActor(actorName)
	if actorSide == "":
		return false
	column = clampi(int(column), 1, 4)
	var current = getActorPosition(actorName)
	if column == current:
		return false
	# Direction from the target toward the mover's vacated spot: every
	# displaced character slides one column along it, the one nearest the
	# vacated spot first so each place lands on an already-freed column.
	var towardVacated = 1 if current > column else -1
	var toShift = []
	var probe = column
	while probe != current:
		var occupant = actorAtPosition(actorSide, probe)
		if occupant != "":
			toShift.append(occupant)
		probe += towardVacated
	for i in range(toShift.size() - 1, -1, -1):
		placeActor(toShift[i], actorSide, getActorPosition(toShift[i]) + towardVacated)
	placeActor(actorName, actorSide, column)
	return true

## With squeeze repositioning a move inside the row always works: legal
## whenever the (clamped) target differs from the actor's current column.
func canMoveActor(actorName: String, column) -> bool:
	var actorSide = sideOfActor(actorName)
	if actorSide == "":
		return false
	column = clampi(int(column), 1, 4)
	return getActorPosition(actorName) != column

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
	var actorName = str(actor.name)
	turnOrder.erase(actorName)
	for actorSide in shootoutActors:
		shootoutActors[actorSide].erase(actorName)
	shootout.rodeoManager.unregisterActor(actorName)
	if shootout.has_method("recordActorDeath"):
		shootout.recordActorDeath(actor)
	var cylinderManager = shootout.get("cylinderManager")
	if cylinderManager != null and cylinderManager.has_method("unregisterActor"):
		cylinderManager.unregisterActor(actorName)
	var effectManager = shootout.get("effectManager")
	if effectManager != null and effectManager.has_method("unregisterActor"):
		effectManager.unregisterActor(actorName)
	actor.queue_free()
	checkBattleEnd()
	return true

func setWinCondition(condition) -> void:
	winCondition = condition if condition is Dictionary else {}

func setEncounterKind(kind: String) -> void:
	encounterKind = kind

func canFlee() -> bool:
	return encounterKind != "showdown" or turnNumber >= FLEE_TURN_THRESHOLD

func endBattle(winningSide: String) -> void:
	battleOver = true
	battleEnded.emit(winningSide)

func checkBattleEnd() -> void:
	if battleOver:
		return
	if shootoutActors[TEAM_PLAYER].is_empty():
		endBattle(TEAM_ENEMY)
		return
	if shootoutActors[TEAM_ENEMY].is_empty():
		endBattle(TEAM_PLAYER)
		return
	match winCondition.get("type", "rout"):
		"defeat_actor":
			if !isBaseNameAlive(winCondition.get("actorName", "")):
				endBattle(winCondition.get("winner", TEAM_PLAYER))
		"survive_rounds":
			if roundNumber > int(winCondition.get("rounds", 0)):
				endBattle(winCondition.get("winner", TEAM_PLAYER))
		"hp_below":
			var targetSide = TEAM_PLAYER if winCondition.get("target", "enemy") == "party" else TEAM_ENEMY
			if sideBelowThreshold(targetSide, winCondition):
				endBattle(TEAM_ENEMY if targetSide == TEAM_PLAYER else TEAM_PLAYER)

func isBaseNameAlive(baseName: String) -> bool:
	for actorSide in shootoutActors:
		for actorName in shootoutActors[actorSide]:
			var actor = shootout.getActor(actorName)
			if actor != null and actor.get("actorName") == baseName:
				return true
	return false

func sideBelowThreshold(actorSide: String, condition: Dictionary) -> bool:
	var total = 0
	var totalMax = 0
	var useMax = condition.get("stat", "hp") == "maxHp"
	for actorName in shootoutActors[actorSide]:
		var actor = shootout.getActor(actorName)
		if actor == null:
			continue
		totalMax += actor.maxHp
		total += actor.maxHp if useMax else actor.hp
	if totalMax == 0:
		return true
	if condition.has("amount"):
		return total < int(condition.amount)
	return float(total) / totalMax < float(condition.get("fraction", 0.5))
