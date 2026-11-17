class_name ShootoutEffectManager
extends RefCounted

## Combat effects (Docs/System Design/Shootout/Effects.md): bleed, poison,
## marks, damage-type marks, damage piercing/decrease, taunt and silence,
## plus the Cylinder effect type delegated to the cylinder manager.

const CombatStatRegistryScript = preload("res://Globals/CombatStatRegistry.gd")

const DAMAGE_NUMBER_OFFSET = Vector2(-4, -48)

# Placeholder: damage piercing/decrease stack up to this many instances.
const MODIFIER_STACK_LIMIT = 4
# Placeholder: poison wears off by this fraction of its amount per Round.
const POISON_WEAR_OFF = 0.65
# Placeholder: marks expire this many Rounds after application if not triggered.
const MARK_EXPIRY_ROUNDS = 2

const AFFLICTIONS = ["bleed", "poison", "mark", "damage_type_mark", "piercing", "decrease", "silence", "taunt"]
# Beneficial effect types: heal instantly or over time, or a flat combat stat
# modifier (never picked by random cleanses).
const BENEFICIALS = ["heal", "heal_over_time", "stat_modifier"]

var shootout

# actorName -> { effectType: [effectInstance, ...] }
var effects = {}


func init(shootoutRoot) -> void:
	shootout = shootoutRoot


func unregisterActor(actorName: String) -> void:
	# Effects on the dead actor go away; marks and stat modifiers they placed on
	# others do too.
	effects.erase(actorName)
	for otherName in effects.keys():
		for effectType in ["mark", "damage_type_mark", "stat_modifier"]:
			for instance in effects[otherName].get(effectType, []):
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
	if effectType == "silence" and hasSilenceImmunity(targetName):
		# Equipment silenceImmunity affix (commit 12): the silence is refused
		# before it is stored; other effects still apply normally.
		return
	if effectType == "heal":
		healActor(targetName, int(effect.get("amount", 0)))
		return
	if !AFFLICTIONS.has(effectType) and !BENEFICIALS.has(effectType) and effectType != "cylinder":
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
			# Combined-stack bleed (decided): each application adds stacks;
			# every two total stacks deal one damage before resistance.
			ensureList(list, "bleed").append({ "stacks": maxi(1, int(effect.get("amount", 1))), "source": sourceName })
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
		"heal_over_time":
			ensureList(list, "heal_over_time").append({
				"amount": int(effect.get("amount", 0)),
				"turnsLeft": int(effect.get("turns", 1)),
				"source": sourceName
			})
		"stat_modifier":
			var statPath := str(effect.get("stat", ""))
			var statError := CombatStatRegistryScript.validateStatModifierPath(statPath)
			if !statError.is_empty():
				push_warning("ShootoutEffectManager: {statError}".format({ "statError": statError }))
				return
			ensureList(list, "stat_modifier").append({
				"stat": statPath,
				"amount": int(effect.get("amount", 0)),
				"turnsLeft": int(effect.get("turns", -1)),
				"source": sourceName,
			})
		"taunt":
			list["taunt"] = [{
				"casterName": targetName,
				"positions": effect.get("positions", allyPositions(targetName)),
				"roundsLeft": int(effect.get("rounds", 1)),
				"damageTakenReduction": int(effect.get("damageTakenReduction", 0)),
				"mxHpHealPerTurn": int(effect.get("mxHpHealPerTurn", 0)),
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
			_removeBleedStacks(stacks, 1)
		else:
			stacks.pop_front()
		if stacks.is_empty():
			list.erase(type)


## Removes up to `amount` combined bleed stacks, largest entry first, and drops
## empty entries. Healing routes through this same stack-cleanse path.
func _removeBleedStacks(stacks: Array, amount: int) -> void:
	var remaining = amount
	while remaining > 0:
		var targetIndex = -1
		var targetStacks = 0
		for index in stacks.size():
			var count = int(stacks[index].get("stacks", 0))
			if count > targetStacks:
				targetStacks = count
				targetIndex = index
		if targetIndex < 0:
			return
		var removed = mini(remaining, targetStacks)
		stacks[targetIndex]["stacks"] = targetStacks - removed
		remaining -= removed
		if int(stacks[targetIndex].stacks) <= 0:
			stacks.remove_at(targetIndex)


func randomAfflictionType(list: Dictionary) -> String:
	var present = []
	for effectType in AFFLICTIONS:
		if !list.get(effectType, []).is_empty():
			present.append(effectType)
	if present.is_empty():
		return ""
	# Combat RNG seam (commit 13): seeded shootouts make random cleanses
	# reproducible; the global RNG keeps unseeded runs working.
	var rng = shootout.get("combatRng") if shootout != null else null
	if rng is RandomNumberGenerator:
		return present[rng.randi_range(0, present.size() - 1)]
	return present[randi() % present.size()]


func isSilenced(actorName: String) -> bool:
	return !getEffects(actorName, "silence").is_empty()


## Heal-over-time and combined bleed tick at the start of the actor's Turn.
## Every two bleed stacks deal one damage before resistance.
func onTurnStart(actorName: String) -> void:
	# Taunt's authored defensive upkeep heals the caster at the start of its
	# turn while the taunt is active (before HoT/bleed resolution). The
	# equipment mxHpHealTauntingPerTurn affix (commit 12) adds to the same
	# heal while the actor is taunting.
	var tauntHeal = tauntHealPerTurn(actorName) + equipmentTauntingHeal(actorName)
	if tauntHeal > 0:
		healActor(actorName, tauntHeal)
	var keptHoT = []
	for hot in getEffects(actorName, "heal_over_time"):
		healActor(actorName, hot.amount)
		hot.turnsLeft -= 1
		if hot.turnsLeft > 0:
			keptHoT.append(hot)
	if effects.has(actorName):
		effects[actorName]["heal_over_time"] = keptHoT
	var bleeds = getEffects(actorName, "bleed")
	if bleeds.is_empty():
		return
	var totalStacks = 0
	for bleed in bleeds:
		totalStacks += int(bleed.get("stacks", 0))
	var baseDamage = int(floor(totalStacks / 2.0))
	if baseDamage <= 0:
		return
	dealEffectDamage(actorName, int(round(baseDamage * (1.0 - resistance(actorName, "bleed")))))


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
	for effectType in ["piercing", "decrease", "silence", "stat_modifier"]:
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


## Flat combat stat modifier hook: sums authored stat_modifier instances for
## the requested path on top of the caller's already-Rodeo-modified value.
## Unknown/percent paths never enter `effects` because applyAffliction rejects
## them against the shared CombatStatRegistry.
func getStatModifier(actorName: String, statName: String, baseValue):
	var value = baseValue
	for modifier in getEffects(actorName, "stat_modifier"):
		if str(modifier.get("stat", "")) == statName:
			value += int(modifier.get("amount", 0))
	return value


## The first active taunt instance on a caster, or an empty Dictionary.
func getTaunt(actorName: String) -> Dictionary:
	var taunts = getEffects(actorName, "taunt")
	return taunts[0] if !taunts.is_empty() else {}


## Taunt defensive buffs (author on the taunt effect payload): percent incoming
## damage reduction and flat MxHP healed at the caster's turn start.
func tauntDamageReduction(actorName: String) -> int:
	var taunt = getTaunt(actorName)
	return int(taunt.get("damageTakenReduction", 0)) if !taunt.is_empty() else 0


func tauntHealPerTurn(actorName: String) -> int:
	var taunt = getTaunt(actorName)
	return int(taunt.get("mxHpHealPerTurn", 0)) if !taunt.is_empty() else 0


## Equipment affix reads (commit 12) — the shared actor.stats projection the
## calculator aggregates; fakes without a stats Dictionary read as zero.
func _equipmentStat(actor, statKey: String) -> int:
	if actor == null:
		return 0
	var stats = actor.get("stats")
	if !(stats is Dictionary):
		return 0
	return maxi(0, int((stats as Dictionary).get(statKey, 0)))


func equipmentPiercing(actor) -> int:
	return _equipmentStat(actor, "damagePiercing")


func equipmentDamageVsMarked(actor) -> int:
	return _equipmentStat(actor, "damageVsMarked")


## The taunting-only reductions/heal read as zero unless a taunt is active, so
## the equipment numbers keep the taunt's lifecycle (death/expiration cleanup).
func equipmentDamageReduction(targetActor) -> int:
	var reduction = _equipmentStat(targetActor, "damageTakenReduction")
	if !getTaunt(targetActor.name).is_empty():
		reduction += _equipmentStat(targetActor, "damageTakenReductionTaunting")
	return reduction


func equipmentTauntingHeal(actorName: String) -> int:
	if getTaunt(actorName).is_empty():
		return 0
	var actor = shootout.getActor(actorName) if shootout.has_method("getActor") else null
	return _equipmentStat(actor, "mxHpHealTauntingPerTurn")


func hasSilenceImmunity(targetName: String) -> bool:
	var actor = shootout.getActor(targetName) if shootout.has_method("getActor") else null
	return _equipmentStat(actor, "silenceImmunity") > 0


## Outgoing damage hook: damage piercing adds back up to the amount actually
## blocked by defense (never more), damage decrease subtracts flat. The
## equipment damagePiercing affix (commit 12) joins the same capped pool.
func applyOutgoingModifiers(actingActor, damage: float, blocked := 0.0) -> float:
	var pierce = 0
	for piercing in getEffects(actingActor.name, "piercing"):
		pierce += piercing.amount
	pierce += equipmentPiercing(actingActor)
	var result = damage + minf(float(pierce), blocked)
	for decrease in getEffects(actingActor.name, "decrease"):
		result -= decrease.amount
	return maxf(0.0, result)


## Incoming damage hook: active marks deal extra damage and apply their effects,
## consuming the mark; damage-type marks add extra damage for matching attacks
## and last the Round. The equipment damageVsMarked affix (commit 12) adds flat
## damage against a marked target and the damageTakenReduction /
## damageTakenReductionTaunting affixes reduce incoming damage through the same
## clamped percent lane as the taunt's authored buff.
func applyIncomingModifiers(targetActor, damage: float, damageType := "", consume := true, actingActor = null) -> float:
	var result = damage
	var targetIsMarked = false
	for mark in getEffects(targetActor.name, "mark"):
		if mark.state != "active":
			continue
		targetIsMarked = true
		result += mark.extraDamage
		if !consume:
			# Dry run (enemy AI estimates): count the bonus, keep the mark.
			break
		mark["expired"] = true
		for followUp in mark.get("effects", []):
			applyEffect(targetActor.name, followUp, mark.get("source", ""))
		break
	for typeMark in getEffects(targetActor.name, "damage_type_mark"):
		if typeMark.damageType == damageType:
			targetIsMarked = true
			result += typeMark.extraDamage
	if actingActor != null and targetIsMarked:
		result += equipmentDamageVsMarked(actingActor)
	var reductionPercent = tauntDamageReduction(targetActor.name) + equipmentDamageReduction(targetActor)
	if reductionPercent > 0:
		result = maxf(0.0, result * (1.0 - clampf(float(reductionPercent) / 100.0, 0.0, 0.9)))
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


## Per-position taunt redirect for a whole target set (Decided Open Question 4):
## each protected position redirects its own hit, so a caster protecting two hit
## positions appears twice and takes two hits. Unprotected positions keep their
## original target.
func redirectTauntSet(actingSide: String, targetNames: Array) -> Array:
	var resolved := []
	for targetName in targetNames:
		var redirect = redirectTaunt(actingSide, str(targetName))
		resolved.append(redirect if redirect != "" else str(targetName))
	return resolved


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


func healActor(actorName: String, amount: int) -> void:
	if amount <= 0:
		return
	var actor = shootout.getActor(actorName) if shootout.has_method("getActor") else null
	if actor == null:
		return
	# Healing also removes the authored number of bleed stacks through the
	# shared cleanse path (Docs/System Design/System Coherence.md).
	cleanse(actorName, "bleed", amount)
	var before = int(actor.hp)
	actor.hp = mini(actor.hp + amount, actor.maxHp)
	var healed = int(actor.hp) - before
	if healed > 0:
		shootout.spawnDamageNumber("+{amount}".format({ "amount": healed }), "green", actor.position + DAMAGE_NUMBER_OFFSET)


func dealEffectDamage(actorName: String, damage: int) -> void:
	if damage <= 0:
		return
	var actor = shootout.getActor(actorName) if shootout.has_method("getActor") else null
	if actor == null:
		return
	actor.hp -= damage
	if actor.get("injuryDamage") != null:
		actor.injuryDamage += damage
	shootout.spawnDamageNumber(damage, "red", actor.position + DAMAGE_NUMBER_OFFSET)


## Display list for the UI: one summary line per active effect type.
func displayEffects(actorName: String) -> Array:
	var lines = []
	for effectType in effects.get(actorName, {}):
		var stacks = effects[actorName][effectType]
		if stacks.is_empty():
			continue
		var count = stacks.size()
		if effectType == "bleed":
			count = 0
			for bleed in stacks:
				count += int(bleed.get("stacks", 0))
		if count > 1:
			lines.append("{type} x{count}".format({ "type": effectType, "count": count }))
		else:
			lines.append(effectType)
	return lines
