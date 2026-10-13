class_name ShootoutTargetingManager
extends RefCounted


const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")

# Local copies of the Shootout autoload constants (same values) so the manager
# stays loadable in headless test runs, where autoloads don't exist.
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
			return targetSide == getActSide(moveData, act.get("name", "")) and actRangeCheck(act, actingActorName, targetActorName, moveData)
		ACT_TYPE_ITEMS:
			# Items can target allies in any position (decided): no range check.
			return targetSide == getActSide(getDataSet("itemsData"), act.get("name", ""))
	return false

# Data lookups resolve the Shootout autoload through the tree (matching the
# other managers) so headless test fakes can inject dictionaries instead.
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

func getActSide(dataSet: Dictionary, actName: String) -> String:
	var actData = dataSet.get(actName, null)
	if actData == null:
		return ""
	if actData.get("side", "") == "player":
		return TEAM_PLAYER
	return TEAM_ENEMY

## Moves/abilities use the `positions` block on their data: `actorUser` lists
## the columns they can be used from, `targets.columns` the targetable columns.
func actRangeCheck(act: Dictionary, actingActorName: String, targetActorName: String, dataSet: Dictionary) -> bool:
	var actData = dataSet.get(act.get("name", ""), null)
	if actData == null:
		return true
	return positionBlockAllows(actData.get("positions", {}), actingActorName, targetActorName)

## Basic attacks use the weapon's range data (placeholders in WeaponData.gd);
## weapons without range data can fire from and at anywhere.
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
	if positions.has("targets") and positions.targets.has("columns") and !(targetColumn in positions.targets.columns):
		return false
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
