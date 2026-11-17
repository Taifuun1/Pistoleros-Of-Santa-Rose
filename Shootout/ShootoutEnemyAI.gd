class_name ShootoutEnemyAI
extends RefCounted

## Enemy decision making (Docs/System Design/Shootout/Enemy AI.md): gathers the
## legal acts using the same validation as the player, scores each act/target
## pair by archetype, and picks from the top with some randomness. Bosses can
## override scoring with data-driven priority scripts.

# How many top-scored acts are candidates for the random pick when neither the
# encounter kind nor the actor profile says otherwise (today's Dust-up width).
const PICK_FROM_TOP = 2
# A Showdown is a best-act duel: only the highest-scored act is a candidate.
const SHOWDOWN_PICK_FROM_TOP = 1
# Score bonus for an act that kills its target.
const KILL_BONUS = 50.0
# Validated profile values (commit 13, Docs/System Design/Shootout/Enemy AI.md).
const ARCHETYPES = ["damage", "support", "tank"]
const ACTION_FAMILIES = ["offense", "support", "defense", "reposition"]

var shootout


func init(shootoutRoot) -> void:
	shootout = shootoutRoot


## Returns an act dict { "type", "name"?, "targetName"?, "direction"? } or an
## empty Dictionary when nothing is legal (the caller passes the turn).
func chooseAct(actorName: String) -> Dictionary:
	var scriptAct = chooseScriptedAct(actorName)
	if !scriptAct.is_empty():
		return scriptAct
	var scored = scoreActs(actorName, gatherLegalActs(actorName))
	if scored.is_empty():
		return {}
	return pickFromTop(scored, actorName)


## Boss scripts: priority rules from Data/Shootout/AI/*.gd (or injected aiData).
## The first rule whose `when` conditions pass wins, before any scoring.
func chooseScriptedAct(actorName: String) -> Dictionary:
	var actingActor = getActor(actorName)
	if actingActor == null:
		return {}
	var aiBlock = actingActor.get("ai")
	if !(aiBlock is Dictionary):
		return {}
	var scriptName = aiBlock.get("script", "")
	if scriptName == "":
		return {}
	var scriptData = dataSet("aiData").get(scriptName, null)
	if scriptData == null:
		push_warning("ShootoutEnemyAI: unknown AI script '{scriptName}'".format({ "scriptName": scriptName }))
		return {}
	for rule in scriptData.get("rules", []):
		if rulePasses(rule.get("when", {}), actingActor):
			return resolveScriptedAct(rule.get("act", {}), actorName)
	return {}

func rulePasses(when: Dictionary, actingActor) -> bool:
	if when.has("hpBelow") and float(actingActor.hp) / actingActor.maxHp >= float(when.hpBelow):
		return false
	if when.has("hpAbove") and float(actingActor.hp) / actingActor.maxHp <= float(when.hpAbove):
		return false
	return true

func resolveScriptedAct(act: Dictionary, actorName: String) -> Dictionary:
	var resolved = act.duplicate(true)
	match act.get("targetName", ""):
		"self":
			resolved.targetName = actorName
		"lowestHpAlly":
			resolved.targetName = lowestHpName(ownSide(actorName))
		"lowestHpEnemy":
			resolved.targetName = lowestHpName(enemySide(actorName))
	return resolved


## Every act/target pair the rules currently allow (same validation as the
## player UI).
func gatherLegalActs(actorName: String) -> Array:
	var legal = []
	var actingActor = getActor(actorName)
	if actingActor == null:
		return legal
	var targetingManager = getManager("targetingManager")
	if targetingManager == null:
		return legal
	# Offense goes through authored Moves only (Docs/System Design/System
	# Coherence.md): there is no basic Attack branch.
	# Moves (silence and column filtering included).
	var silenced = isSilenced(actorName)
	for moveName in targetingManager.usableMoves(actorList(actingActor, "moves"), actorName, silenced, dataSet("movesData")):
		appendLegalActEntries(legal, { "type": "Moves", "name": moveName }, actorName, targetingManager)
	# Items.
	for itemName in actorList(actingActor, "items"):
		appendLegalActEntries(legal, { "type": "Items", "name": itemName }, actorName, targetingManager)
	# Repositioning is legal when the destination move can actually happen.
	var turnManager = getManager("turnManager")
	if turnManager != null:
		var column = turnManager.getActorPosition(actorName)
		for direction in ["forward", "backward"]:
			var delta = -1 if direction == "forward" else 1
			if turnManager.canMoveActor(actorName, column + delta):
				legal.append({ "type": "Reposition", "direction": direction })
	return legal


## Single-target acts keep one entry per legal target so scoring can choose the
## best one. Multi acts collapse to one entry whose `targetNames` is the full
## resolved set, so AI scores exactly what will resolve.
func appendLegalActEntries(legal: Array, act: Dictionary, actorName: String, targetingManager) -> void:
	if targetingManager.isMultiTargetAct(act):
		var primaryTarget = firstLegalTarget(act, actorName, targetingManager)
		if primaryTarget != "":
			var expanded = targetingManager.expandTargets(act, primaryTarget, actorName)
			if !expanded.is_empty():
				legal.append({
					"type": act.type,
					"name": act.name,
					"targetName": primaryTarget,
					"targetNames": expanded,
				})
		return
	for targetName in livingActors():
		if targetingManager.isValidTarget(act, str(targetName), actorName):
			legal.append({
				"type": act.type,
				"name": act.name,
				"targetName": str(targetName),
				"targetNames": [str(targetName)],
			})


## First legal anchor target for an act, in deterministic column/name order.
## Multi acts expand from this anchor through `expandTargets`.
func firstLegalTarget(act: Dictionary, actorName: String, targetingManager) -> String:
	var candidates = []
	for side in ["player team", "enemy team"]:
		candidates.append_array(targetingManager.livingActorsOfSide(side))
	candidates.sort_custom(func(a, b) -> bool:
		var columnA = targetingManager.getActorColumn(str(a))
		var columnB = targetingManager.getActorColumn(str(b))
		if columnA != columnB:
			return columnA < columnB
		return str(a) < str(b)
	)
	for targetName in candidates:
		if targetingManager.isValidTarget(act, targetName, actorName):
			return str(targetName)
	return ""


## Adds a "score" to every legal act (archetype-weighted, see the design doc).
func scoreActs(actorName: String, legalActs: Array) -> Array:
	var actingActor = getActor(actorName)
	if actingActor == null:
		return []
	var scored = []
	for act in legalActs:
		var entry = act.duplicate(true)
		entry["score"] = scoreAct(entry, actingActor)
		scored.append(entry)
	scored.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return scored

func scoreAct(act: Dictionary, actingActor) -> float:
	var score = 0.0
	match act.type:
		"Moves":
			# Offensive/support weighting is per action family (commit 13): a
			# defensive Move (Duck) no longer shares the offense multiplier.
			var family = "defense" if moveIsDefensive(act, actingActor) else "offense"
			return scoreMove(act, actingActor) * actionWeight(actingActor, family)
		"Items":
			var family = "support" if itemIsSupport(act, actingActor) else "offense"
			return scoreItem(act, actingActor) * actionWeight(actingActor, family)
		"Reposition":
			score = 1.0 * actionWeight(actingActor, "reposition")
			var preferred = aiValue(actingActor, "preferredColumns", [])
			var turnManager = getManager("turnManager")
			if turnManager != null and !preferred.is_empty() and !(turnManager.getActorPosition(actingActor.name) in preferred):
				score += 2.0
	return score

## Per-family weight from the authored `ai.weights` block. An unprofiled actor
## keeps today's behavior: every Moves/Items family scaled by the legacy
## `aggression` multiplier (1.5 - aggression, default 0.8) and reposition
## unscaled. Authored weights must be positive (content lint).
func actionWeight(actingActor, family: String) -> float:
	var aiBlock = actingActor.get("ai")
	if aiBlock is Dictionary:
		var weights = (aiBlock as Dictionary).get("weights", null)
		if weights is Dictionary and (weights as Dictionary).has(family):
			return maxf(0.0, float((weights as Dictionary).get(family, 1.0)))
	if family == "reposition":
		return 1.0
	return 1.5 - float(aiValue(actingActor, "aggression", 0.7))

func moveIsDefensive(act: Dictionary, actingActor) -> bool:
	var moveData = dataSet("movesData").get(str(act.get("name", "")), {})
	return str(moveData.get("category", "")) == "duck"

func itemIsSupport(act: Dictionary, actingActor) -> bool:
	var itemData = dataSet("itemsData").get(str(act.get("name", "")), {})
	if float(itemData.get("baseAmount", 0)) > 0:
		return true
	for effect in itemData.get("effects", []):
		if str(effect.get("op", "apply_effect")) == "apply_effect" and str(effect.get("effect", "")) in ["heal", "heal_over_time", "taunt"]:
			return true
	return false

## Candidate width for the random pick (commit 13): an authored `ai.pickFromTop`
## narrows or widens the encounter default; a Showdown selects only the
## highest-scored act; a Dust-up keeps today's width for unprofiled actors.
func effectivePickFromTop(actingActor) -> int:
	if actingActor != null:
		var authored = int(aiValue(actingActor, "pickFromTop", 0))
		if authored > 0:
			return authored
	var turnManager = getManager("turnManager")
	var kind = str(turnManager.get("encounterKind")) if turnManager != null else ""
	return SHOWDOWN_PICK_FROM_TOP if kind == "showdown" else PICK_FROM_TOP

## The one combat RNG seam (commit 13): AI picks consume the shootout's seeded
## generator when present; the global RNG keeps unseeded runs working.
func _pickIndex(top: int) -> int:
	var rng = shootout.get("combatRng") if shootout != null else null
	if rng is RandomNumberGenerator:
		return rng.randi_range(0, maxi(1, top) - 1)
	return randi() % maxi(1, top)

func pickFromTop(scored: Array, actorName := "") -> Dictionary:
	var actingActor = getActor(actorName)
	var top = mini(effectivePickFromTop(actingActor), scored.size())
	if top <= 0:
		return {}
	return scored[_pickIndex(top)]

func scoreMove(act: Dictionary, actingActor) -> float:
	var moveData = dataSet("movesData").get(act.name, {})
	var targetNames = actTargetNames(act)
	if targetNames.is_empty():
		return 0.0
	var score = 0.0
	if moveData.get("category", "ability") == "duck":
		var duckScore = 2.0 + woundedAllies(ownSide(actingActor.name)) * 2.0
		if aiValue(actingActor, "archetype", "damage") == "tank":
			duckScore += 3.0
		return duckScore * targetNames.size()
	for targetName in targetNames:
		var target = getActor(str(targetName))
		if target == null:
			continue
		if moveData.get("category", "") == "attack_ability" or moveData.get("baseAmount", 0) > 0:
			var amount = int(moveData.get("baseAmount", 0))
			if moveData.has("scalingStat"):
				amount += int(moveData.statScaling * actingActor.stats[moveData.scalingStat])
			score += float(amount) * 0.8
			if amount >= target.hp:
				score += KILL_BONUS * 0.5
		for effect in moveData.get("effects", []):
			score += effectScore(effect, actingActor, target)
	return score

func scoreItem(act: Dictionary, actingActor) -> float:
	var itemData = dataSet("itemsData").get(act.name, {})
	var score = 0.0
	for targetName in actTargetNames(act):
		var target = getActor(str(targetName))
		if target == null:
			continue
		var amount = int(itemData.get("baseAmount", 0))
		if amount > 0 and isAllied(actingActor.name, str(targetName)):
			# Heal-score by missing HP (design doc), so the support prefers the
			# most wounded ally instead of tying every wounded target at the item
			# amount. A multi-heal sums every affected ally.
			score += float(target.maxHp - target.hp)
		for effect in itemData.get("effects", []):
			score += effectScore(effect, actingActor, target)
	return score


## Every target of the scored act, including the full multi-target set.
func actTargetNames(act: Dictionary) -> Array:
	var names = act.get("targetNames", [])
	if names is Array and !names.is_empty():
		return names
	var primary = str(act.get("targetName", ""))
	return [primary] if primary != "" else []

func effectScore(effect: Dictionary, actingActor, target) -> float:
	match effect.get("op", "apply_effect"):
		"apply_effect":
			match effect.get("effect", ""):
				"bleed", "poison", "mark", "silence", "damage_type_mark":
					return 4.0 if getEffects(target.name, effect.effect).is_empty() else 1.0
				"heal", "heal_over_time":
					return float(target.maxHp - target.hp) * 0.8
				"taunt":
					return 3.0 + woundedAllies(ownSide(actingActor.name))
		_:
			return 0.0
	return 0.0

# --- helpers ---

func livingActors(side := "") -> Array:
	var turnManager = getManager("turnManager")
	if turnManager == null:
		return []
	var names := []
	if side != "":
		names = turnManager.shootoutActors.get(side, {}).keys()
	else:
		for actorSide in turnManager.shootoutActors:
			names.append_array(turnManager.shootoutActors[actorSide].keys())
	var living := []
	for actorName in names:
		var actor = getActor(str(actorName))
		if actor != null and int(actor.get("hp")) > 0:
			living.append(actorName)
	return living

func ownSide(actorName: String) -> String:
	var turnManager = getManager("turnManager")
	return turnManager.sideOfActor(actorName) if turnManager != null else ""

func enemySide(actorName: String) -> String:
	var side = ownSide(actorName)
	return "enemy team" if side == "player team" else "player team"

func isAllied(actorName: String, otherName: String) -> bool:
	var side = ownSide(actorName)
	return side != "" and side == ownSide(otherName)

func woundedAllies(side: String) -> int:
	var wounded = 0
	for actorName in livingActors(side):
		var actor = getActor(actorName)
		if actor != null and float(actor.hp) / actor.maxHp < 0.5:
			wounded += 1
	return wounded

func lowestHpName(side: String) -> String:
	var best = ""
	var bestFraction = 2.0
	for actorName in livingActors(side):
		var actor = getActor(actorName)
		if actor != null and float(actor.hp) / actor.maxHp < bestFraction:
			bestFraction = float(actor.hp) / actor.maxHp
			best = actorName
	return best

func aiValue(actingActor, key: String, fallback):
	var aiBlock = actingActor.get("ai")
	if aiBlock is Dictionary:
		return aiBlock.get(key, fallback)
	return fallback

## Object.get() takes a single argument (default values are a Dictionary-only
## feature), so actor list properties are read defensively.
func actorList(actingActor, key: String) -> Array:
	var value = actingActor.get(key)
	return value if value is Array else []

func getActor(actorName: String):
	return shootout.getActor(actorName) if shootout != null and shootout.has_method("getActor") else null

func getManager(managerName: String):
	return shootout.get(managerName) if shootout != null else null

func isSilenced(actorName: String) -> bool:
	var effectManager = getManager("effectManager")
	return effectManager != null and effectManager.has_method("isSilenced") and effectManager.isSilenced(actorName)

func getEffects(actorName: String, effectType: String) -> Array:
	var effectManager = getManager("effectManager")
	if effectManager != null and effectManager.has_method("getEffects"):
		return effectManager.getEffects(actorName, effectType)
	return []

# Data lookups resolve the Shootout autoload through the tree, with test
# dictionaries injectable on the shootout root (same pattern as the resolver).
func dataSet(dataSetName: String) -> Dictionary:
	var injected = shootout.get(dataSetName)
	if injected is Dictionary:
		return injected
	var globals = shootout.get_node_or_null("/root/Shootout")
	if globals != null and globals.get(dataSetName) is Dictionary:
		return globals.get(dataSetName)
	return {}
