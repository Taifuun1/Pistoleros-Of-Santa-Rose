class_name ShootoutActionResolver
extends RefCounted


const DAMAGE_NUMBER_OFFSET = Vector2(-4, -24)

var shootout


func init(shootoutRoot) -> void:
	shootout = shootoutRoot

func resolveAttack(actingActor, targetActor) -> void:
	var damage
	if actingActor.weapon.type == "melee":
		damage = 2
	else:
		damage = actingActor.stats.damage[actingActor.weapon.type][actingActor.weapon.weapon]
	applyDamage(targetActor, damage)

func resolveMove(moveName: String, actingActor, targetActor) -> void:
	var moveData = Shootout.movesData.get(moveName, null)
	if moveData == null:
		push_warning("ShootoutActionResolver: unknown move '{moveName}'".format({ "moveName": moveName }))
		return
	var amount = moveData.baseAmount
	if moveData.has("scalingStat"):
		amount += int(moveData.statScaling * actingActor.stats[moveData.scalingStat])
	applyDamage(targetActor, amount)

func resolveItem(itemName: String, _actingActor, targetActor) -> void:
	var itemData = Shootout.itemsData.get(itemName, null)
	if itemData == null:
		push_warning("ShootoutActionResolver: unknown item '{itemName}'".format({ "itemName": itemName }))
		return
	var amount = itemData.baseAmount
	targetActor.hp = mini(targetActor.hp + amount, targetActor.maxHp)
	shootout.spawnDamageNumber("+{amount}".format({ "amount": amount }), "green", targetActor.position + DAMAGE_NUMBER_OFFSET)

func applyDamage(targetActor, damage) -> void:
	targetActor.hp -= damage
	shootout.spawnDamageNumber(damage, "red", targetActor.position + DAMAGE_NUMBER_OFFSET)
