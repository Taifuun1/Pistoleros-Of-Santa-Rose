class_name ShootoutActionResolver
extends RefCounted


const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")

const DAMAGE_NUMBER_OFFSET = Vector2(-4, -24)

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

func resolveAttack(actingActor, targetActor) -> void:
	var quality = getHitQuality(actingActor)
	if quality is String:
		resolveSpecialChamber(quality, actingActor)
		return
	var damage = calculateAttackDamage(actingActor, targetActor, quality)
	applyHitDamage(targetActor, damage, quality)
	advanceCylinder(actingActor)

func resolveMove(moveName: String, actingActor, targetActor) -> void:
	var moveData = getDataSet("movesData").get(moveName, null)
	if moveData == null:
		push_warning("ShootoutActionResolver: unknown move '{moveName}'".format({ "moveName": moveName }))
		return
	var amount = moveData.baseAmount
	if moveData.has("scalingStat"):
		amount += int(moveData.statScaling * actingActor.stats[moveData.scalingStat])
	if moveData.get("category", "") == ATTACK_ABILITY_CATEGORY:
		# Attack abilities use the Cylinder like basic attacks (decided).
		var quality = getHitQuality(actingActor)
		if quality is String:
			resolveSpecialChamber(quality, actingActor)
			return
		# Attack abilities roll quality on their own amount; weapon family
		# defense rules don't apply (the ability amount isn't weapon damage).
		var abilityDamage = maxi(0, roundi(amount * CylinderManagerScript.CHAMBER_DAMAGE_MULT[quality]))
		applyHitDamage(targetActor, abilityDamage, quality)
		advanceCylinder(actingActor)
	else:
		# Non-attack abilities don't interact with the Cylinder at all (decided).
		applyDamage(targetActor, amount)
	applyActEffects(moveData.get("effects", []), targetActor, actingActor.name)

func resolveItem(itemName: String, actingActor, targetActor) -> void:
	var itemData = getDataSet("itemsData").get(itemName, null)
	if itemData == null:
		push_warning("ShootoutActionResolver: unknown item '{itemName}'".format({ "itemName": itemName }))
		return
	var amount = itemData.baseAmount
	targetActor.hp = mini(targetActor.hp + amount, targetActor.maxHp)
	shootout.spawnDamageNumber("+{amount}".format({ "amount": amount }), "green", targetActor.position + DAMAGE_NUMBER_OFFSET)
	applyActEffects(itemData.get("effects", []), targetActor, actingActor.name)

## The full damage pipeline (Docs/System Design/Shootout/Damage and Stats.md):
## quality multiplier, weapon + offensive stat base, weapon family defense
## rules, then piercing/marks hooks (no-ops until the Effects system lands).
func calculateAttackDamage(actingActor, targetActor, quality: int) -> int:
	var base = float(actingActor.weapon.get("baseDamage", 0)) + offensiveStat(actingActor)
	var preDefense = base * CylinderManagerScript.CHAMBER_DAMAGE_MULT[quality]
	var damage = applyWeaponFamilyRule(preDefense, actingActor.weapon, targetDefense(targetActor))
	var blocked = maxf(0.0, preDefense - damage)
	damage = applyOutgoingModifiers(actingActor, damage, blocked)
	damage = applyIncomingModifiers(targetActor, damage, actingActor.weapon.get("type", ""))
	return maxi(0, roundi(damage))

# The relevant offensive stat per weapon family:
# - Lead: the matching stats.damage.lead entry, Rodeo-modified.
# - Explosive: the stats entry plus the class explosive base.
# - Lasso/melee: none — lassos are weapon base damage only (decided).
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

func applyIncomingModifiers(targetActor, damage: float, damageType := "") -> float:
	var effectManager = shootout.get("effectManager")
	if effectManager != null and effectManager.has_method("applyIncomingModifiers"):
		return effectManager.applyIncomingModifiers(targetActor, damage, damageType)
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

# Reload spends the Move without attacking; Jammed fails the attack. Both
# consume the Chamber (the action resolver advances after this returns).
func resolveSpecialChamber(quality: String, actingActor) -> void:
	match quality:
		"reload":
			shootout.spawnDamageNumber("Reload", "white", actingActor.position + DAMAGE_NUMBER_OFFSET)
		"jammed":
			shootout.spawnDamageNumber("Jammed!", "yellow", actingActor.position + DAMAGE_NUMBER_OFFSET)
		_:
			push_warning("ShootoutActionResolver: unknown special chamber '{quality}'".format({ "quality": quality }))
	advanceCylinder(actingActor)

func applyHitDamage(targetActor, damage: int, quality: int) -> void:
	var label = "Miss" if quality == CylinderManagerScript.CHAMBER_MISS else str(damage)
	targetActor.hp -= damage
	shootout.spawnDamageNumber(label, CHAMBER_COLORS[quality], targetActor.position + DAMAGE_NUMBER_OFFSET)

func applyDamage(targetActor, damage) -> void:
	targetActor.hp -= damage
	shootout.spawnDamageNumber(damage, "red", targetActor.position + DAMAGE_NUMBER_OFFSET)
