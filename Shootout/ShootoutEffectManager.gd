class_name ShootoutEffectManager
extends RefCounted

## Combat effects (Docs/System Design/Shootout/Effects.md): bleed, poison,
## marks, damage-type marks, damage piercing/decrease, taunt and silence,
## plus the Cylinder effect type delegated to the cylinder manager.

const DAMAGE_NUMBER_OFFSET = Vector2(-4, -24)

# Placeholder: damage piercing/decrease stack up to this many instances.
const MODIFIER_STACK_LIMIT = 4
# Placeholder: poison wears off by this fraction of its amount per Round.
const POISON_WEAR_OFF = 0.65
# Placeholder: marks expire this many Rounds after application if not triggered.
const MARK_EXPIRY_ROUNDS = 2

const AFFLICTIONS = ["bleed", "poison", "mark", "damage_type_mark", "piercing", "decrease", "silence", "taunt"]

var shootout

# actorName -> { effectType: [effectInstance, ...] }
var effects = {}


func init(shootoutRoot) -> void:
	shootout = shootoutRoot


func unregisterActor(actorName: String) -> void:
	# Effects on the dead actor go away; marks they placed on others do too.
	effects.erase(actorName)
	for otherName in effects.keys():
		for markType in ["mark", "damage_type_mark"]:
			for instance in effects[otherName].get(markType, []):
				if instance.get("source", "") == actorName:
					instance["expired"] = true
		pruneExpired(otherName)


## Applies one effect dict (from move/item data or a Rodeo) to a target.
## Stacking follows Docs/Combat.md: bleed keeps all stacks (highest ticks),
## poison appends, marks and silence replace, piercing/decrease append up to a
## limit, taunt replaces on the caster, Cylinder delegates to the cylinder manager.
func applyEffect(targetName: String, effect: Dictionary, sourceName := "") -> void:
	match effect.get("op", "apply_effect"):
		"apply_effect":
			applyAffliction(targetName, effect, sourceName)
		"cleanse_effect":
			cleanse(targetName, effect.get("effect", "random"), int(effect.get("amount", 1)))
		"modify_cylinder":
			var cylinderManager = shootout.get("cylinderManager")
			if cylinderManager != null and cylinderManager.has_method("applyCylinderModifier"):
				cylinderManager.applyCylinderModifier(targetName, {
					"chambers": effect.get("chambers", "all"),
					"amount": int(effect.get("amount", 0))
				})
		_:
			push_warning("ShootoutEffectManager: unknown effect op '{op}'".format({ "op": effect.get("op", "") }))


func applyAffliction(targetName: String, effect: Dictionary, sourceName: String) -> void:
	var effectType = effect.get("effect", "")
	if !AFFLICTIONS.has(effectType) and effectType != "cylinder":
		push_warning("ShootoutEffectManager: unknown effect type '{effectType}'".format({ "effectType": effectType }))
		return
	if effectType == "cylinder":
		applyEffect(targetName, { "op": "modify_cylinder", "chambers": effect.get("chambers", "all"), "amount": int(effect.get("amount", 0)) }, sourceName)
		return
	if !effects.has(targetName):
		effects[targetName] = {}
	var list = effects[targetName]
	match effectType:
		"bleed":
			ensureList(list, "bleed").append({ "amount": int(effect.get("amount", 0)), "source": sourceName })
		"poison":
			ensureList(list, "poison").append({
				"amount": int(effect.get("amount", 0)),
				"roundsLeft": int(effect.get("rounds", -1)),
				"source": sourceName
			})
		"mark":
			# Marks don't stack: a new mark replaces the previous one.
			list["mark"] = [{
				"state": "priming",
				"extraDamage": int(effect.get("extraDamage", effect.get("amount", 0))),
				"effects": effect.get("effects", []),
				"roundsUntilExpiry": int(effect.get("rounds", MARK_EXPIRY_ROUNDS)),
				"source": sourceName
			}]
		"damage_type_mark":
			list["damage_type_mark"] = [{
				"damageType": effect.get("damageType", ""),
				"extraDamage": int(effect.get("extraDamage", effect.get("amount", 0))),
				"source": sourceName
			}]
		"piercing", "decrease":
			var stacks = ensureList(list, effectType)
			if stacks.size() < MODIFIER_STACK_LIMIT:
				stacks.append({
					"damageType": effect.get("damageType", ""),
					"amount": int(effect.get("amount", 0)),
					"turnsLeft": int(effect.get("turns", -1)),
					"source": sourceName
				})
		"silence":
			list["silence"] = [{ "turnsLeft": int(effect.get("turns", 1)), "source": sourceName }]
		"taunt":
			list["taunt"] = [{
				"casterName": targetName,
				"positions": effect.get("positions", allyPositions(targetName)),
				"roundsLeft": int(effect.get("rounds", 1)),
				"source": sourceName
			}]


func ensureList(list: Dictionary, effectType: String) -> Array:
	if !list.has(effectType):
		list[effectType] = []
	return list[effectType]


func getEffects(actorName: String, effectType: String) -> Array:
	return effects.get(actorName, {}).get(effectType, [])


## Removes `amount` instances of an effect type (or a random affliction).
## Bleeds are removed highest-first so the next stored stack takes over.
func cleanse(targetName: String, effectType: String, amount := 1) -> void:
	if !effects.has(targetName):
		return
	var list = effects[targetName]
	for i in amount:
		var type = effectType
		if type == "random":
			type = randomAfflictionType(list)
		if type == "":
			return
		var stacks = list.get(type, [])
		if stacks.is_empty():
			continue
		if type == "bleed":
			var highestIndex = 0
			for j in stacks.size():
				if stacks[j].amount > stacks[highestIndex].amount:
					highestIndex = j
			stacks.remove_at(highestIndex)
		else:
			stacks.pop_front()
		if stacks.is_empty():
			list.erase(type)


func randomAfflictionType(list: Dictionary) -> String:
	var present = []
	for effectType in AFFLICTIONS:
		if !list.get(effectType, []).is_empty():
			present.append(effectType)
	if present.is_empty():
		return ""
	return present[randi() % present.size()]


func isSilenced(actorName: String) -> bool:
	return !getEffects(actorName, "silence").is_empty()


## Bleed ticks at the start of the afflicted character's Turn (highest stack
## only; potency reduced by bleed resistance).
func onTurnStart(actorName: String) -> void:
	var bleeds = getEffects(actorName, "bleed")
	if bleeds.is_empty():
		return
	var highest = bleeds[0]
	for bleed in bleeds:
		if bleed.amount > highest.amount:
			highest = bleed
	dealEffectDamage(actorName, int(round(highest.amount * (1.0 - resistance(actorName, "bleed")))))


## Poison ticks at the start of every Round on each afflicted actor.
func onRoundStart() -> void:
	for actorName in effects.keys():
		for poison in getEffects(actorName, "poison"):
			dealEffectDamage(actorName, int(round(poison.amount * (1.0 - resistance(actorName, "poison")))))


## Round end: poison wears off, damage-type marks expire, marks prime or expire,
## taunt countdown.
func onRoundEnd() -> void:
	for actorName in effects.keys():
		var list = effects[actorName]
		list.erase("damage_type_mark")
		var poisonStacks = []
		for poison in list.get("poison", []):
			poison.amount = int(floor(float(poison.amount) * POISON_WEAR_OFF))
			if poison.roundsLeft > 0:
				poison.roundsLeft -= 1
			if poison.amount >= 1 and poison.roundsLeft != 0:
				poisonStacks.append(poison)
		list["poison"] = poisonStacks
		var markStacks = []
		for mark in list.get("mark", []):
			if mark.state == "priming":
				mark.state = "active"
			mark.roundsUntilExpiry -= 1
			if mark.roundsUntilExpiry > 0:
				markStacks.append(mark)
		list["mark"] = markStacks
		var tauntStacks = []
		for taunt in list.get("taunt", []):
			taunt.roundsLeft -= 1
			if taunt.roundsLeft > 0:
				tauntStacks.append(taunt)
		list["taunt"] = tauntStacks
		pruneExpired(actorName)


## Turn end: piercing/decrease/silence countdown.
func onTurnEnd(actorName: String) -> void:
	if !effects.has(actorName):
		return
	var list = effects[actorName]
	for effectType in ["piercing", "decrease", "silence"]:
		var kept = []
		for instance in list.get(effectType, []):
			if instance.turnsLeft > 0:
				instance.turnsLeft -= 1
				if instance.turnsLeft <= 0:
					continue
			kept.append(instance)
		list[effectType] = kept
	pruneExpired(actorName)


func pruneExpired(actorName: String) -> void:
	if !effects.has(actorName):
		return
	var list = effects[actorName]
	for effectType in list.keys():
		list[effectType] = list[effectType].filter(func(instance): return !instance.get("expired", false))
		if list[effectType].is_empty():
			list.erase(effectType)
	if list.is_empty():
		effects.erase(actorName)


## Stat query hook (reserved: no effect type modifies stats yet).
func getStatModifier(_actorName: String, _statName: String, baseValue):
	return baseValue


## Outgoing damage hook: damage piercing adds back up to the amount actually
## blocked by defense (never more), damage decrease subtracts flat.
func applyOutgoingModifiers(actingActor, damage: float, blocked := 0.0) -> float:
	var pierce = 0
	for piercing in getEffects(actingActor.name, "piercing"):
		pierce += piercing.amount
	var result = damage + minf(float(pierce), blocked)
	for decrease in getEffects(actingActor.name, "decrease"):
		result -= decrease.amount
	return maxf(0.0, result)


## Incoming damage hook: active marks deal extra damage and apply their effects,
## consuming the mark; damage-type marks add extra damage for matching attacks
## and last the Round.
func applyIncomingModifiers(targetActor, damage: float, damageType := "") -> float:
	var result = damage
	for mark in getEffects(targetActor.name, "mark"):
		if mark.state != "active":
			continue
		result += mark.extraDamage
		mark["expired"] = true
		for followUp in mark.get("effects", []):
			applyEffect(targetActor.name, followUp, mark.get("source", ""))
		break
	for typeMark in getEffects(targetActor.name, "damage_type_mark"):
		if typeMark.damageType == damageType:
			result += typeMark.extraDamage
	pruneExpired(targetActor.name)
	return result


## Taunt redirect: attacks against a taunted position hit the taunt caster
## instead. Returns the caster's name, or "" when no redirect applies.
func redirectTaunt(actingSide: String, targetName: String) -> String:
	var targetColumn = getActorColumn(targetName)
	if targetColumn == -1:
		return ""
	for actorName in effects.keys():
		if actorName == targetName:
			continue
		var casterSide = getActorSide(actorName)
		if casterSide == "" or casterSide == actingSide:
			continue
		for taunt in effects[actorName].get("taunt", []):
			if targetColumn in taunt.positions:
				return actorName
	return ""


# Columns currently held by other allies of the actor (taunt default).
func allyPositions(actorName: String) -> Array:
	var positions = []
	var side = getActorSide(actorName)
	var turnManager = shootout.get("turnManager")
	if turnManager == null or side == "":
		return positions
	for otherName in turnManager.shootoutActors.get(side, {}):
		if otherName != actorName:
			positions.append(turnManager.shootoutActors[side][otherName].actorPosition)
	return positions


func getActorSide(actorName: String) -> String:
	var turnManager = shootout.get("turnManager")
	if turnManager == null:
		return ""
	for actorSide in turnManager.shootoutActors:
		if turnManager.shootoutActors[actorSide].has(actorName):
			return actorSide
	return ""


func getActorColumn(actorName: String) -> int:
	var turnManager = shootout.get("turnManager")
	if turnManager == null:
		return -1
	for actorSide in turnManager.shootoutActors:
		if turnManager.shootoutActors[actorSide].has(actorName):
			return turnManager.shootoutActors[actorSide][actorName].actorPosition
	return -1


func resistance(actorName: String, effectType: String) -> float:
	var actor = shootout.getActor(actorName) if shootout.has_method("getActor") else null
	if actor == null:
		return 0.0
	var resistances = actor.get("stats")
	if !(resistances is Dictionary):
		return 0.0
	return clampf(float(resistances.get("resistances", {}).get(effectType, 0.0)), 0.0, 1.0)


func dealEffectDamage(actorName: String, damage: int) -> void:
	if damage <= 0:
		return
	var actor = shootout.getActor(actorName) if shootout.has_method("getActor") else null
	if actor == null:
		return
	actor.hp -= damage
	shootout.spawnDamageNumber(damage, "red", actor.position + DAMAGE_NUMBER_OFFSET)
