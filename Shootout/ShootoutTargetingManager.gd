class_name ShootoutTargetingManager
extends RefCounted


const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")

const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"
const ACT_TYPE_ATTACK = "Attack"
const ACT_TYPE_MOVES = "Moves"
const ACT_TYPE_ITEMS = "Items"

var turnManager
var weaponRanges = {}


func init(turnManagerInit) -> void:
	turnManager = turnManagerInit
	var weaponData = WeaponDataScript.new()
	var ranges = weaponData.get("ranges")
	weaponRanges = ranges.duplicate(true) if ranges is Dictionary else {}

func isValidTarget(act: Dictionary, targetActorName: String, actingActorName: String) -> bool:
	var actingSide = turnManager.sideOfActor(actingActorName)
	var targetSide = turnManager.sideOfActor(targetActorName)
	if actingSide == "" or targetSide == "":
		return false
	match act.type:
		ACT_TYPE_ATTACK:
			return actingSide != targetSide and weaponRangeCheck(actingActorName, targetActorName)
		ACT_TYPE_MOVES:
			var moveData = getDataSet("movesData")
			return targetSide == getActSide(moveData, act.get("name", ""), actingActorName) and actRangeCheck(act, actingActorName, targetActorName, moveData)
		ACT_TYPE_ITEMS:
			# Items can target allies in any position (decided): no range check.
			return targetSide == getActSide(getDataSet("itemsData"), act.get("name", ""), actingActorName)
	return false

func getDataSet(dataSet: String) -> Dictionary:
	var shootout = getActorShootout()
	if shootout != null:
		var injected = shootout.get(dataSet)
		if injected is Dictionary:
			return injected
		var globals = shootout.get_node_or_null("/root/Shootout")
		if globals != null and globals.get(dataSet) is Dictionary:
			return globals.get(dataSet)
	return {}

func moveUsability(moveNames: Array, actingActorName: String, silenced: bool, dataSet: Dictionary) -> Dictionary:
	var usability = {}
	for moveName in moveNames:
		var moveData = dataSet.get(moveName, {})
		var category = moveData.get("category", "ability")
		if silenced and category != "duck":
			usability[moveName] = { "usable": false, "reason": "Silenced" }
			continue
		var positions = moveData.get("positions", {})
		if positions.has("actorUser") and !(getActorColumn(actingActorName) in positions.actorUser):
			usability[moveName] = { "usable": false, "reason": "Needs position {columns}".format({ "columns": positions.actorUser }) }
			continue
		usability[moveName] = { "usable": true, "reason": "" }
	return usability

func usableMoves(moveNames: Array, actingActorName: String, silenced: bool, dataSet: Dictionary) -> Array:
	var usable = []
	var usability = moveUsability(moveNames, actingActorName, silenced, dataSet)
	for moveName in usability:
		if usability[moveName].usable:
			usable.append(moveName)
	return usable

func getActSide(dataSet: Dictionary, actName: String, actingActorName: String) -> String:
	var actData = dataSet.get(actName, null)
	if actData == null:
		return ""
	var actingSide = turnManager.sideOfActor(actingActorName)
	if actData.get("side", "") == "enemy":
		return TEAM_ENEMY if actingSide == TEAM_PLAYER else TEAM_PLAYER
	return actingSide

func actRangeCheck(act: Dictionary, actingActorName: String, targetActorName: String, dataSet: Dictionary) -> bool:
	var actData = dataSet.get(act.get("name", ""), null)
	if actData == null:
		return true
	return positionBlockAllows(actData.get("positions", {}), actingActorName, targetActorName)

func weaponRangeCheck(actingActorName: String, targetActorName: String) -> bool:
	var actingActor = getActor(actingActorName)
	if actingActor == null:
		return false
	var weapon = actingActor.get("weapon")
	var rangeData = {}
	if weapon is Dictionary and weapon.get("weapon", null) != null:
		rangeData = weaponRanges.get(weapon.weapon, {})
	return positionBlockAllows(rangeData, actingActorName, targetActorName)

func positionBlockAllows(positions: Dictionary, actingActorName: String, targetActorName: String) -> bool:
	var actingColumn = getActorColumn(actingActorName)
	var targetColumn = getActorColumn(targetActorName)
	if actingColumn == -1 or targetColumn == -1:
		return false
	if positions.has("actorUser") and !(actingColumn in positions.actorUser):
		return false
	if positions.has("targets") and !targetColumnsAllowed(positions.targets, targetColumn):
		return false
	return true

## Targets come in two shapes: a nested { "columns": [...] } block (moves and
## abilities) or a flat column array (weapon ranges in Data/Items/WeaponData.gd).
## Anything unrecognised stays unrestricted.
func targetColumnsAllowed(targets, targetColumn: int) -> bool:
	if targets is Dictionary:
		if targets.has("columns"):
			return targetColumn in targets.columns
		return true
	if targets is Array:
		return targetColumn in targets
	return true

func getActorColumn(actorName: String) -> int:
	if turnManager.has_method("getActorPosition"):
		return turnManager.getActorPosition(actorName)
	for actorSide in turnManager.shootoutActors:
		if turnManager.shootoutActors[actorSide].has(actorName):
			return int(turnManager.shootoutActors[actorSide][actorName].actorPosition)
	return -1

func getActor(actorName: String):
	var shootout = getActorShootout()
	if shootout != null and shootout.has_method("getActor"):
		return shootout.getActor(actorName)
	return null

func getActorShootout():
	var shootout = turnManager.get("shootout")
	if shootout != null and shootout.has_method("getActor"):
		return shootout
	return null
