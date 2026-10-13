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
	var base = attackBaseDamage(actingActor)
	applyHitDamage(targetActor, base, quality)
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
		applyHitDamage(targetActor, amount, quality)
		advanceCylinder(actingActor)
	else:
		# Non-attack abilities don't interact with the Cylinder at all (decided).
		applyDamage(targetActor, amount)

func resolveItem(itemName: String, _actingActor, targetActor) -> void:
	var itemData = getDataSet("itemsData").get(itemName, null)
	if itemData == null:
		push_warning("ShootoutActionResolver: unknown item '{itemName}'".format({ "itemName": itemName }))
		return
	var amount = itemData.baseAmount
	targetActor.hp = mini(targetActor.hp + amount, targetActor.maxHp)
	shootout.spawnDamageNumber("+{amount}".format({ "amount": amount }), "green", targetActor.position + DAMAGE_NUMBER_OFFSET)

func attackBaseDamage(actingActor) -> float:
	if actingActor.weapon.type == "melee":
		return 2.0
	var statPath = "damage.{type}.{weapon}".format({
		"type": actingActor.weapon.type,
		"weapon": actingActor.weapon.weapon
	})
	return shootout.rodeoManager.getStatModifier(
		actingActor,
		statPath,
		actingActor.stats.damage[actingActor.weapon.type][actingActor.weapon.weapon]
	)

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

func applyHitDamage(targetActor, baseDamage, quality: int) -> void:
	var mult = CylinderManagerScript.CHAMBER_DAMAGE_MULT[quality]
	var damage = maxi(0, roundi(baseDamage * mult))
	var label = "Miss" if quality == CylinderManagerScript.CHAMBER_MISS else str(damage)
	targetActor.hp -= damage
	shootout.spawnDamageNumber(label, CHAMBER_COLORS[quality], targetActor.position + DAMAGE_NUMBER_OFFSET)

func applyDamage(targetActor, damage) -> void:
	targetActor.hp -= damage
	shootout.spawnDamageNumber(damage, "red", targetActor.position + DAMAGE_NUMBER_OFFSET)
