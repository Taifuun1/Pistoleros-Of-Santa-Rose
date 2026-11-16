class_name ShootoutTargetingManager
extends RefCounted


const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")

const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"
const ACT_TYPE_ATTACK = "Attack"
const ACT_TYPE_MOVES = "Moves"
const ACT_TYPE_ITEMS = "Items"
const TARGET_TYPE_SINGLE = "single"
const TARGET_TYPE_MULTI = "multi"
const DEFAULT_TARGET_COLUMNS := [1, 2, 3, 4]

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


## The authored data entry backing an act, or null for basic Attacks/unknown ids.
func getActData(act: Dictionary) -> Variant:
	match str(act.get("type", "")):
		ACT_TYPE_MOVES:
			return getDataSet("movesData").get(str(act.get("name", "")), null)
		ACT_TYPE_ITEMS:
			return getDataSet("itemsData").get(str(act.get("name", "")), null)
	return null


## Ordered, living targets for one act. A single-target act returns exactly the
## clicked/primary target. A `positions.type: "multi"` act expands to every
## legal living actor on its target side and authored columns, sorted by column
## then stable actor name. Dead actors and empty sets return [].
func expandTargets(act: Dictionary, primaryTargetName: String, actingActorName: String) -> Array:
	if primaryTargetName == "" or !isValidTarget(act, primaryTargetName, actingActorName):
		return []
	var actData = getActData(act)
	if actData == null:
		return [primaryTargetName]
	var positions = actData.get("positions", {})
	if str(positions.get("type", TARGET_TYPE_SINGLE)) != TARGET_TYPE_MULTI:
		return [primaryTargetName]
	var targetSide = getActSide(getDataSet(actDataSetName(act)), str(act.get("name", "")), actingActorName)
	if targetSide == "":
		return []
	var allowedColumns = targetColumnsFor(positions)
	var candidates := []
	for actorName in livingActorsOfSide(targetSide):
		var column = getActorColumn(actorName)
		if !allowedColumns.is_empty() and !(column in allowedColumns):
			continue
		candidates.append({ "name": actorName, "column": column })
	candidates.sort_custom(func(a, b) -> bool:
		if int(a.column) != int(b.column):
			return int(a.column) < int(b.column)
		return str(a.name) < str(b.name)
	)
	var names := []
	for candidate in candidates:
		names.append(str(candidate.name))
	# The primary target anchors the act's legal range. A multi act whose target
	# columns exclude it is not a usable act for that click.
	if !names.has(primaryTargetName):
		return []
	return names


## True when the act's authored side is the side opposite the acting actor.
func targetsOpposingSide(act: Dictionary, actingActorName: String) -> bool:
	if str(act.get("type", "")) == ACT_TYPE_ATTACK:
		return true
	var dataSet = getDataSet(actDataSetName(act))
	var targetSide = getActSide(dataSet, str(act.get("name", "")), actingActorName)
	return targetSide != "" and targetSide != turnManager.sideOfActor(actingActorName)


## True when the authored act expands to a target set.
func isMultiTargetAct(act: Dictionary) -> bool:
	var actData = getActData(act)
	if actData == null:
		return false
	var positions = actData.get("positions", {})
	return str(positions.get("type", TARGET_TYPE_SINGLE)) == TARGET_TYPE_MULTI


## Authored target columns for a positions block; [] means unrestricted/all.
func targetColumnsFor(positions: Dictionary) -> Array:
	var targets = positions.get("targets", {})
	if targets is Dictionary and targets.has("columns"):
		var columns = targets.columns
		return columns.duplicate() if columns is Array else []
	if targets is Array:
		return targets.duplicate()
	return []


## Living actors on one side, filtered from the turn manager registry. The
## registry keeps dead actors until cleanup, so callers must never treat its
## keys as live targets.
func livingActorsOfSide(side: String) -> Array:
	var living := []
	if turnManager == null:
		return living
	for actorName in turnManager.shootoutActors.get(side, {}):
		var actor = getActor(actorName)
		if actor != null and int(actor.get("hp")) > 0:
			living.append(actorName)
	return living


func actDataSetName(act: Dictionary) -> String:
	match str(act.get("type", "")):
		ACT_TYPE_MOVES:
			return "movesData"
		ACT_TYPE_ITEMS:
			return "itemsData"
	return ""

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
