class_name ShootoutRodeoManager
extends RefCounted


const TRIGGER_FIGHT_START = "fight_start"
const TRIGGER_FIGHT_END = "fight_end"
const TRIGGER_ROUND_START = "round_start"
const TRIGGER_ROUND_END = "round_end"
const TRIGGER_TURN_START = "turn_start"
const TRIGGER_TURN_END = "turn_end"
const TRIGGER_ALWAYS = "always"

const TEAM_PLAYER = "player team"
const TEAM_ENEMY = "enemy team"

# Stats that live directly on the actor node instead of inside actor.stats.
const DIRECT_STATS = ["maxHp"]

const RODEO_POPUP_COLOR = "yellow"
const RODEO_POPUP_OFFSET = Vector2(-4, -36)

var shootout
var rodeosData = {}
var partyLevel = 1

# actorName -> { data, side, column, state }
var rodeos = {}
# Triggered modify_stat effects on the query pipeline:
# { targetName, stat, amount, turnsLeft (-1 = rest of fight), source }
var activeModifiers = []
# modify_stat effects on DIRECT_STATS, reverted at fight end:
# { targetName, stat, amount }
var directStatReverts = []
var lootModifiers = { "money": 0, "resources": 0 }
var lootMultipliers = { "money": 1.0, "resources": 1.0 }


func init(shootoutRoot) -> void:
	shootout = shootoutRoot
	# Resolved through the tree instead of the autoload identifiers so the
	# manager stays loadable in headless test runs, where autoloads don't exist.
	var shootoutGlobals = shootoutRoot.get_node_or_null("/root/Shootout")
	if shootoutGlobals != null:
		rodeosData = shootoutGlobals.rodeosData
	var partyGlobals = shootoutRoot.get_node_or_null("/root/Party")
	if partyGlobals != null:
		partyLevel = partyGlobals.level


func registerActor(actor, actorSide: String, actorColumn) -> void:
	if actor.rodeo == null:
		return
	var rodeoData = findRodeoData(actor.rodeo)
	if rodeoData == null:
		push_warning("ShootoutRodeoManager: unknown rodeo '{rodeo}' on actor '{actorName}'".format({
			"rodeo": actor.rodeo,
			"actorName": actor.name
		}))
		return
	rodeos[actor.name] = {
		"data": applyLevelScaling(rodeoData),
		"side": actorSide,
		"column": actorColumn,
		"state": { "turnsElapsed": 0, "usedThisFight": false }
	}


func unregisterActor(actorName: String) -> void:
	rodeos.erase(actorName)
	activeModifiers = activeModifiers.filter(func(mod):
		return mod.targetName != actorName and mod.source != actorName
	)


func findRodeoData(rodeoName: String):
	for dataName in rodeosData:
		if dataName.to_lower() == rodeoName.to_lower():
			return rodeosData[dataName]
	return null


func applyLevelScaling(rodeoData: Dictionary) -> Dictionary:
	var scaling = rodeoData.get("scaling", {})
	if scaling.is_empty() or scaling.get("stat", "") != "level":
		return rodeoData
	var scaledData = rodeoData.duplicate(true)
	var bonus = scaling.get("perLevel", 0) * (partyLevel - 1)
	for effect in scaledData.get("effects", []):
		if effect.has(scaling.get("appliesTo", "")):
			effect[scaling.appliesTo] += bonus
	return scaledData


func getRodeoDisplayName(actor) -> String:
	if actor != null and rodeos.has(actor.name):
		return rodeos[actor.name].data.get("name", "-")
	return "-"


# The round counter is owned by the turn manager (single source of truth);
# the Rodeo manager only reads it.
func getRoundNumber() -> int:
	if shootout != null:
		var turnManager = shootout.get("turnManager")
		if turnManager != null and turnManager.has_method("getRoundNumber"):
			return turnManager.getRoundNumber()
	return 1


## Hit quality floor from always-on Rodeos (reserved op
## "set_hit_quality_floor"); the cylinder manager clamps Miss/Graze up to this.
func getHitQualityFloor(actor) -> int:
	if actor == null or !rodeos.has(actor.name):
		return 0
	var entry = rodeos[actor.name]
	if entry.data.get("trigger", "") != TRIGGER_ALWAYS:
		return 0
	if !passesConditions(entry, actor, {}):
		return 0
	var floor = 0
	for effect in entry.data.get("effects", []):
		if effect.get("op", "") == "set_hit_quality_floor":
			floor = maxi(floor, int(effect.get("value", 0)))
	return floor


func trigger(triggerName: String, context := {}) -> void:
	context["round"] = getRoundNumber()
	for actorName in rodeos:
		var entry = rodeos[actorName]
		if entry.data.get("trigger", "") != triggerName:
			continue
		var ownerActor = shootout.getActor(actorName)
		if ownerActor == null:
			continue
		if triggerName == TRIGGER_TURN_END and context.get("actor") == ownerActor:
			entry.state.turnsElapsed += 1
		if !passesConditions(entry, ownerActor, context):
			continue
		fireRodeo(actorName, entry, ownerActor)
	if triggerName == TRIGGER_TURN_END and context.get("actor") != null:
		tickModifiers(context.actor.name)
	if triggerName == TRIGGER_FIGHT_END:
		cleanupFightModifiers()


func passesConditions(entry: Dictionary, ownerActor, context: Dictionary) -> bool:
	var conditions = entry.data.get("conditions", {})
	if conditions.has("winningSide") and context.get("winningSide", "") != conditions.winningSide:
		return false
	if conditions.has("everyOtherTurn"):
		var every = int(conditions.everyOtherTurn)
		if every <= 0 or entry.state.turnsElapsed == 0 or entry.state.turnsElapsed % every != 0:
			return false
	if conditions.has("oncePerFight") and entry.state.usedThisFight:
		return false
	if conditions.has("position") and !(entry.column in conditions.position):
		return false
	if conditions.has("hpBelow") and float(ownerActor.hp) / ownerActor.maxHp >= conditions.hpBelow:
		return false
	if conditions.has("hpAbove") and float(ownerActor.hp) / ownerActor.maxHp <= conditions.hpAbove:
		return false
	return true


func fireRodeo(actorName: String, entry: Dictionary, ownerActor) -> void:
	var conditions = entry.data.get("conditions", {})
	var targets = resolveTargets(conditions.get("target", "self"), actorName, entry)
	for effect in entry.data.get("effects", []):
		applyEffect(effect, targets, actorName)
	if conditions.has("oncePerFight"):
		entry.state.usedThisFight = true
	showRodeoPopup(entry.data.get("name", ""), ownerActor)


func resolveTargets(targetType: String, ownerName: String, ownerEntry: Dictionary) -> Array:
	var enemySide = TEAM_ENEMY if ownerEntry.side == TEAM_PLAYER else TEAM_PLAYER
	match targetType:
		"self":
			return [ownerName]
		"allies":
			return getSideActors(ownerEntry.side)
		"enemies":
			return getSideActors(enemySide)
		"all":
			return getSideActors(ownerEntry.side) + getSideActors(enemySide)
		"adjacent_allies":
			return getAdjacentAllies(ownerName, ownerEntry, [-1, 1])
		"ally_in_front":
			return getAdjacentAllies(ownerName, ownerEntry, [-1])
		"ally_behind":
			return getAdjacentAllies(ownerName, ownerEntry, [1])
	push_warning("ShootoutRodeoManager: unknown target type '{targetType}'".format({ "targetType": targetType }))
	return []


func getSideActors(actorSide: String) -> Array:
	return shootout.turnManager.shootoutActors.get(actorSide, {}).keys()


func getAdjacentAllies(ownerName: String, ownerEntry: Dictionary, offsets: Array) -> Array:
	var targets = []
	for actorName in getSideActors(ownerEntry.side):
		if actorName == ownerName:
			continue
		var column = getActorColumn(actorName, ownerEntry.side)
		if column - ownerEntry.column in offsets:
			targets.append(actorName)
	return targets


func getActorSide(actorName: String) -> String:
	for actorSide in shootout.turnManager.shootoutActors:
		if shootout.turnManager.shootoutActors[actorSide].has(actorName):
			return actorSide
	return ""


func getActorColumn(actorName: String, actorSide: String):
	if rodeos.has(actorName):
		return rodeos[actorName].column
	return shootout.turnManager.shootoutActors[actorSide][actorName].actorPosition


func setActorColumn(actorName: String, actorSide: String, column) -> void:
	if rodeos.has(actorName):
		rodeos[actorName].column = column
	shootout.turnManager.shootoutActors[actorSide][actorName].actorPosition = column


func applyEffect(effect: Dictionary, targets: Array, sourceName: String) -> void:
	match effect.get("op", ""):
		"modify_stat":
			applyModifyStat(effect, targets, sourceName)
		"move_position":
			applyMovePosition(effect, targets)
		"heal":
			applyHeal(effect, targets)
		"modify_loot":
			applyModifyLoot(effect)
		"apply_effect", "cleanse_effect", "modify_cylinder":
			var effectManager = shootout.get("effectManager")
			if effectManager != null and effectManager.has_method("applyEffect"):
				for targetName in targets:
					effectManager.applyEffect(targetName, effect, sourceName)
			else:
				push_warning("ShootoutRodeoManager: effect op '{op}' needs the effect manager".format({ "op": effect.get("op", "") }))
		_:
			push_warning("ShootoutRodeoManager: unknown or unimplemented rodeo op '{op}'".format({
				"op": effect.get("op", "")
			}))


func applyModifyStat(effect: Dictionary, targets: Array, sourceName: String) -> void:
	for targetName in targets:
		if effect.stat in DIRECT_STATS:
			var actorNode = shootout.getActor(targetName)
			if actorNode == null:
				continue
			actorNode.set(effect.stat, actorNode.get(effect.stat) + effect.get("amount", 0))
			directStatReverts.append({
				"targetName": targetName,
				"stat": effect.stat,
				"amount": effect.get("amount", 0)
			})
		else:
			activeModifiers.append({
				"targetName": targetName,
				"stat": effect.stat,
				"amount": effect.get("amount", 0),
				"turnsLeft": -1 if effect.get("duration", "fight") == "fight" else int(effect.duration),
				"source": sourceName
			})


func applyMovePosition(effect: Dictionary, targets: Array) -> void:
	for targetName in targets:
		var actorSide = getActorSide(targetName)
		if actorSide == "":
			continue
		var column = getActorColumn(targetName, actorSide)
		var direction = -1 if effect.get("direction", "backward") == "forward" else 1
		var newColumn = clampi(column + direction * int(effect.get("amount", 1)), 1, 4)
		if newColumn == column:
			continue
		setActorColumn(targetName, actorSide, newColumn)
		var actorNode = shootout.getActor(targetName)
		if actorNode != null:
			actorNode.position = shootout.getPositionForColumn(actorSide, newColumn)


func applyHeal(effect: Dictionary, targets: Array) -> void:
	for targetName in targets:
		var actorNode = shootout.getActor(targetName)
		if actorNode == null:
			continue
		actorNode.hp = mini(actorNode.hp + int(effect.get("amount", 0)), actorNode.maxHp)


func applyModifyLoot(effect: Dictionary) -> void:
	var stat = effect.get("stat", "money")
	if effect.has("multiplier"):
		lootMultipliers[stat] = lootMultipliers.get(stat, 1.0) * effect.multiplier
	else:
		lootModifiers[stat] = lootModifiers.get(stat, 0) + int(effect.get("amount", 0))


func getStatModifier(actor, statName: String, baseValue):
	if actor == null:
		return baseValue
	var value = baseValue
	var actorName = actor.name
	if rodeos.has(actorName):
		var entry = rodeos[actorName]
		if entry.data.get("trigger", "") == TRIGGER_ALWAYS:
			for effect in entry.data.get("effects", []):
				if(
					effect.get("op", "") == "modify_stat" and
					effect.get("stat", "") == statName and
					passesConditions(entry, actor, {})
				):
					value += effect.get("amount", 0)
	for mod in activeModifiers:
		if mod.targetName == actorName and mod.stat == statName:
			value += mod.amount
	return value


func tickModifiers(actorName: String) -> void:
	var kept = []
	for mod in activeModifiers:
		if mod.targetName == actorName and mod.turnsLeft > 0:
			mod.turnsLeft -= 1
			if mod.turnsLeft <= 0:
				continue
		kept.append(mod)
	activeModifiers = kept


func cleanupFightModifiers() -> void:
	for revert in directStatReverts:
		var actorNode = shootout.getActor(revert.targetName)
		if actorNode != null:
			actorNode.set(revert.stat, actorNode.get(revert.stat) - revert.amount)
	directStatReverts.clear()
	activeModifiers.clear()


func consumeLootModifiers() -> Dictionary:
	var loot = { "amounts": lootModifiers, "multipliers": lootMultipliers }
	lootModifiers = { "money": 0, "resources": 0 }
	lootMultipliers = { "money": 1.0, "resources": 1.0 }
	return loot


func showRodeoPopup(rodeoName: String, ownerActor) -> void:
	if shootout.has_method("spawnDamageNumber"):
		shootout.spawnDamageNumber(rodeoName, RODEO_POPUP_COLOR, ownerActor.position + RODEO_POPUP_OFFSET)

