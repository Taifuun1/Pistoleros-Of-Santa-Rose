class_name ShootoutActionResolver
extends RefCounted


const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")

const DAMAGE_NUMBER_OFFSET = Vector2(-4, -48)

# Attack abilities advance the Cylinder (decided); everything else doesn't.
const ATTACK_ABILITY_CATEGORY = "attack_ability"

# Damage number label per hit quality.
const CHAMBER_COLORS = ["white", "orange", "red", "yellow"]

var shootout


func init(shootoutRoot) -> void:
	shootout = shootoutRoot

# Data lookups resolve the Shootout autoload through the tree (matching the
# Rodeo manager pattern) so headless test fakes can inject dictionaries on the
# fake shootout root instead.
func getDataSet(dataSet: String) -> Dictionary:
	var injected = shootout.get(dataSet)
	if injected is Dictionary:
		return injected
	var globals = shootout.get_node_or_null("/root/Shootout")
	if globals != null and globals.get(dataSet) is Dictionary:
		return globals.get(dataSet)
	return {}

## The shared target-set entry point (Docs/System Design/Shootout/Positions and
## Targeting.md). The act's Cylinder roll, belt consumption and other per-act
## costs happen exactly once, then the result applies to every living target in
## order. Empty/dead-only sets consume nothing.
func resolveActTargets(actType: String, actName: String, actingActor, targetActors: Array) -> void:
	match actType:
		"Attack":
			resolveAttackTargets(actingActor, targetActors)
		"Moves":
			resolveMoveTargets(actName, actingActor, targetActors)
		"Items":
			resolveItemTargets(actName, actingActor, targetActors)


func resolveAttack(actingActor, targetActor) -> void:
	resolveAttackTargets(actingActor, [targetActor])


func resolveAttackTargets(actingActor, targetActors: Array) -> void:
	var targets = _livingTargetActors(targetActors)
	if targets.is_empty():
		return
	# One Cylinder roll per act, not per target (the target set shares the shot).
	var quality = getHitQuality(actingActor)
	if quality is String:
		resolveSpecialChamber(quality, actingActor, targets[0])
		return
	if quality == CylinderManagerScript.CHAMBER_MISS:
		# A Miss consumes the Chamber but no on-hit effects or marks.
		for targetActor in targets:
			applyHitDamage(targetActor, 0, quality)
		advanceCylinder(actingActor)
		return
	for targetActor in targets:
		var damage = calculateAttackDamage(actingActor, targetActor, quality)
		applyHitDamage(targetActor, damage, quality)
	advanceCylinder(actingActor)

func resolveMove(moveName: String, actingActor, targetActor) -> void:
	resolveMoveTargets(moveName, actingActor, [targetActor])

func resolveMoveTargets(moveName: String, actingActor, targetActors: Array) -> void:
	var moveData = getDataSet("movesData").get(moveName, null)
	if moveData == null:
		push_warning("ShootoutActionResolver: unknown move '{moveName}'".format({ "moveName": moveName }))
		return
	var targets = _livingTargetActors(targetActors)
	if targets.is_empty():
		return
	var amount = int(moveData.get("baseAmount", 0))
	if moveData.has("scalingStat"):
		amount += int(moveData.statScaling * actingActor.stats[moveData.scalingStat])
	if moveData.get("category", "") == ATTACK_ABILITY_CATEGORY:
		# Attack abilities use the Cylinder like basic attacks (decided), and
		# one roll covers the whole target set.
		var quality = getHitQuality(actingActor)
		if quality is String:
			resolveSpecialChamber(quality, actingActor, targets[0])
			return
		if quality == CylinderManagerScript.CHAMBER_MISS:
			# No on-hit effects on a Miss for attack abilities either.
			for targetActor in targets:
				applyHitDamage(targetActor, 0, quality)
			advanceCylinder(actingActor)
			return
		# Attack abilities roll quality on their own amount; weapon family
		# defense rules don't apply (the ability amount isn't weapon damage).
		var abilityDamage = maxi(0, roundi(amount * CylinderManagerScript.CHAMBER_DAMAGE_MULT[quality]))
		for targetActor in targets:
			applyHitDamage(targetActor, abilityDamage, quality)
		advanceCylinder(actingActor)
	elif moveData.get("category", "") == "duck":
		# Ducks are defensive buffs: effects only, no damage (decided).
		for targetActor in targets:
			applyActEffects(moveData.get("effects", []), targetActor, actingActor.name)
	else:
		# Non-attack abilities don't interact with the Cylinder at all (decided).
		for targetActor in targets:
			applyDamage(targetActor, amount)
			applyActEffects(moveData.get("effects", []), targetActor, actingActor.name)

func resolveItem(itemName: String, actingActor, targetActor) -> void:
	resolveItemTargets(itemName, actingActor, [targetActor])

func resolveItemTargets(itemName: String, actingActor, targetActors: Array) -> void:
	var itemData = getDataSet("itemsData").get(itemName, null)
	if itemData == null:
		push_warning("ShootoutActionResolver: unknown item '{itemName}'".format({ "itemName": itemName }))
		return
	var targets = _livingTargetActors(targetActors)
	if targets.is_empty():
		# Invalid/empty target set: the act consumes nothing.
		return
	# One belt use pays for every legal target of a multi-heal.
	if !_consumeBeltItem(actingActor, itemName):
		return
	var amount = int(itemData.get("baseAmount", 0))
	var effectManager = shootout.get("effectManager")
	for targetActor in targets:
		if effectManager != null and effectManager.has_method("healActor"):
			effectManager.healActor(targetActor.name, amount)
		else:
			targetActor.hp = mini(targetActor.hp + amount, targetActor.maxHp)
			shootout.spawnDamageNumber("+{amount}".format({ "amount": amount }), "green", targetActor.position + DAMAGE_NUMBER_OFFSET)
		applyActEffects(itemData.get("effects", []), targetActor, actingActor.name)


## Dead targets are dropped before any cost is charged. The same actor may
## appear more than once when taunt redirects several protected positions to it
## (Decided Open Question 4): each redirected position keeps its own hit.
func _livingTargetActors(targetActors: Array) -> Array:
	var living := []
	for targetActor in targetActors:
		if targetActor != null and is_instance_valid(targetActor) and int(targetActor.get("hp")) > 0:
			living.append(targetActor)
	return living


## Consumes one use. Party actors consume the matching reservation and report it
## for the one-shot Party write-back; enemy actor belts keep the legacy name-only
## behavior. A reservation mismatch consumes nothing.
func _consumeBeltItem(actingActor, itemName: String) -> bool:
	var reservations = actingActor.get("beltReservations")
	if reservations is Array and !reservations.is_empty():
		for reservationValue in reservations:
			if !(reservationValue is Dictionary):
				continue
			var reservation: Dictionary = reservationValue
			if str(reservation.get("combatId", "")) != itemName or int(reservation.get("quantity", 0)) <= 0:
				continue
			reservation["quantity"] = int(reservation.quantity) - 1
			_eraseOneBeltName(actingActor, itemName)
			if shootout != null and shootout.has_method("recordBeltConsumption"):
				shootout.recordBeltConsumption(str(reservation.get("instanceId", "")), itemName)
			return true
		push_warning("ShootoutActionResolver: '{itemName}' has no matching Party belt reservation.".format({ "itemName": itemName }))
		return false
	_eraseOneBeltName(actingActor, itemName)
	return true


func _eraseOneBeltName(actingActor, itemName: String) -> void:
	var belt = actingActor.items
	if belt is Array:
		belt.erase(itemName)

## The full damage pipeline (Docs/System Design/Shootout/Damage and Stats.md):
## quality multiplier, weapon + offensive stat base, weapon family defense
## rules, then piercing/marks hooks (no-ops until the Effects system lands).
func calculateAttackDamage(actingActor, targetActor, quality: int, consumeEffects := true) -> int:
	var base = float(actingActor.weapon.get("baseDamage", 0)) + offensiveStat(actingActor)
	var preDefense = base * CylinderManagerScript.CHAMBER_DAMAGE_MULT[quality]
	var damage = applyWeaponFamilyRule(preDefense, actingActor.weapon, targetDefense(targetActor))
	var blocked = maxf(0.0, preDefense - damage)
	damage = applyOutgoingModifiers(actingActor, damage, blocked)
	damage = applyIncomingModifiers(targetActor, damage, actingActor.weapon.get("type", ""), consumeEffects)
	return maxi(0, roundi(damage))

# The relevant offensive stat per weapon family:
# - Lead: the matching stats.damage.lead entry, Rodeo-modified.
# - Explosive: the stats entry plus the class explosive base.
# - Lasso/melee: none — lassos are weapon base damage only (decided).
## Journey injuries (Docs/System Design/Shootout/Death Injury and Retreat.md):
## all damage accumulates on the actor node; the shootout root writes it back
## to the party at fight end. Only nodes with the field are tracked.
func recordInjury(targetActor, damage: int) -> void:
	if targetActor.get("injuryDamage") != null:
		targetActor.injuryDamage += damage

func offensiveStat(actingActor) -> float:
	if actingActor.weapon.type == "lasso" or actingActor.weapon.type == "melee":
		return 0.0
	var base = float(actingActor.stats.damage[actingActor.weapon.type][actingActor.weapon.weapon])
	if actingActor.weapon.type == "explosive":
		return base + classExplosiveBase(actingActor)
	var statPath = "damage.{type}.{weapon}".format({
		"type": actingActor.weapon.type,
		"weapon": actingActor.weapon.weapon
	})
	return shootout.rodeoManager.getStatModifier(actingActor, statPath, base)

func classExplosiveBase(actingActor) -> int:
	var cylinderManager = shootout.get("cylinderManager")
	if cylinderManager == null:
		return 0
	var characterClass = actingActor.get("characterClass")
	if characterClass == null or !cylinderManager.classesData.has(characterClass):
		return 0
	return int(cylinderManager.classesData[characterClass].get("explosiveBase", 0))

func targetDefense(targetActor) -> Dictionary:
	var stats = targetActor.get("stats")
	if stats is Dictionary:
		return stats.get("defense", { "style": 0, "sand": 0 })
	return { "style": 0, "sand": 0 }

# Weapon family rules (Docs/Combat.md): revolvers lose the higher of Style/Sand,
# rifles gain Style but lose Sand, shotguns gain Sand but lose Style;
# explosives, lassos and melee don't interact with defense.
func applyWeaponFamilyRule(damage: float, weapon: Dictionary, defense: Dictionary) -> float:
	var style = int(defense.get("style", 0))
	var sand = int(defense.get("sand", 0))
	match weapon.get("weapon", ""):
		"revolver":
			return damage - maxi(style, sand)
		"rifle":
			return damage + style - sand
		"shotgun":
			return damage + sand - style
		_:
			return damage

# Effect hooks: damage piercing/decrease (outgoing; piercing can only reclaim
# the amount actually blocked by defense) and marks/flat modifiers (incoming).
# The Effects system implements these; the guards keep plain fakes working.
func applyOutgoingModifiers(actingActor, damage: float, blocked := 0.0) -> float:
	var effectManager = shootout.get("effectManager")
	if effectManager != null and effectManager.has_method("applyOutgoingModifiers"):
		return effectManager.applyOutgoingModifiers(actingActor, damage, blocked)
	return damage

func applyIncomingModifiers(targetActor, damage: float, damageType := "", consume := true) -> float:
	var effectManager = shootout.get("effectManager")
	if effectManager != null and effectManager.has_method("applyIncomingModifiers"):
		return effectManager.applyIncomingModifiers(targetActor, damage, damageType, consume)
	return damage

# Instant damage/healing resolves first, then the act's effect list is applied.
func applyActEffects(effectList, targetActor, sourceName: String) -> void:
	if !(effectList is Array) or targetActor == null:
		return
	var effectManager = shootout.get("effectManager")
	if effectManager == null or !effectManager.has_method("applyEffect"):
		return
	for effect in effectList:
		effectManager.applyEffect(targetActor.name, effect, sourceName)

func getHitQuality(actingActor):
	var cylinderManager = shootout.get("cylinderManager")
	if cylinderManager == null or !cylinderManager.has_method("hitQuality"):
		return CylinderManagerScript.CHAMBER_HIT
	return cylinderManager.hitQuality(actingActor.name)

func advanceCylinder(actingActor) -> void:
	var cylinderManager = shootout.get("cylinderManager")
	if cylinderManager != null and cylinderManager.has_method("advance"):
		cylinderManager.advance(actingActor.name)

# Reload spends the Move without attacking; Jammed fails the attack and applies
# the authored class payload (target: self by default). Both consume the Chamber.
func resolveSpecialChamber(quality: String, actingActor, targetActor = null) -> void:
	match quality:
		"reload":
			shootout.spawnDamageNumber("Reload", "white", actingActor.position + DAMAGE_NUMBER_OFFSET)
		"jammed":
			var payload := _jammedPayload(actingActor)
			if payload.is_empty():
				push_warning("ShootoutActionResolver: '{actor}' has no authored Jammed payload".format({ "actor": actingActor.actorName }))
			else:
				var jammedTarget = targetActor if str(payload.get("target", "self")) == "selectedActor" else actingActor
				applyActEffects(payload.get("effects", []), jammedTarget, actingActor.name)
			shootout.spawnDamageNumber("Jammed!", "yellow", actingActor.position + DAMAGE_NUMBER_OFFSET)
		_:
			push_warning("ShootoutActionResolver: unknown special chamber '{quality}'".format({ "quality": quality }))
	advanceCylinder(actingActor)


## Jammed buff/debuff source (Docs/System Design/Shootout/Cylinders.md): class
## data may author `jammed: { target: "self"|"selectedActor", effects: [...] }`.
func _jammedPayload(actingActor) -> Dictionary:
	var cylinderManager = shootout.get("cylinderManager")
	if cylinderManager == null:
		return {}
	var classData = cylinderManager.get("classesData")
	if !(classData is Dictionary):
		return {}
	var payload = classData.get(actingActor.get("characterClass"), {}).get("jammed", null)
	return payload if payload is Dictionary else {}

func applyHitDamage(targetActor, damage: int, quality: int) -> void:
	var label = "Miss" if quality == CylinderManagerScript.CHAMBER_MISS else str(damage)
	targetActor.hp -= damage
	recordInjury(targetActor, damage)
	shootout.spawnDamageNumber(label, CHAMBER_COLORS[quality], targetActor.position + DAMAGE_NUMBER_OFFSET)

func applyDamage(targetActor, damage) -> void:
	targetActor.hp -= damage
	recordInjury(targetActor, damage)
	shootout.spawnDamageNumber(damage, "red", targetActor.position + DAMAGE_NUMBER_OFFSET)
