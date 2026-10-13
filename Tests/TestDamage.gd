extends SceneTree

## Headless validation for the damage pipeline (Docs/System Design/Shootout/Damage and Stats.md).
## Run with: godot --headless --script res://Tests/TestDamage.gd

const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 50
	var maxHp = 50
	var stats = {
		"sixShootin": 3,
		"damage": {
			"lead": { "revolver": 10, "rifle": 10, "shotgun": 10 },
			"explosive": { "gunpowder": 2, "liquid": 2, "shrapnel": 2 },
			"lasso": 0
		},
		"defense": { "style": 0, "sand": 0 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	}
	var weapon = { "type": "lead", "weapon": "revolver", "baseDamage": 0 }
	var characterClass = null
	var characterMagazine = null


class FakeRodeoManager:
	extends RefCounted
	# statName -> flat bonus
	var modifiers = {}
	func getStatModifier(_actor, statName, baseValue):
		return baseValue + modifiers.get(statName, 0)


class FakeShootout:
	extends Node2D
	var actors = {}
	var cylinderManager = null
	var rodeoManager = FakeRodeoManager.new()
	var movesData = {}
	var damageNumbers = []
	func getActor(actorName):
		return actors.get(actorName, null)
	func spawnDamageNumber(label, color, _position):
		damageNumbers.append({ "label": str(label), "color": color })


func _init() -> void:
	call_deferred("_run")


var fake
var resolver
var cylinderManager


func makeFight() -> void:
	fake = FakeShootout.new()
	root.add_child(fake)
	resolver = ActionResolverScript.new()
	resolver.init(fake)
	cylinderManager = CylinderManagerScript.new()
	cylinderManager.shootout = fake
	fake.cylinderManager = cylinderManager


func addActor(actorName: String, weaponType: String, weaponId: String, baseDamage: int, defense: Dictionary) -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.weapon = { "type": weaponType, "weapon": weaponId, "baseDamage": baseDamage }
	# Default Dictionary members are shared between class instances; duplicate first.
	actor.stats = actor.stats.duplicate(true)
	actor.stats.defense = defense
	fake.actors[actorName] = actor
	return actor


func setCylinder(actorName: String, cylinder: Array, index: int = 0) -> void:
	cylinderManager.cylinders[actorName] = {
		"cylinder": cylinder,
		"chamberIndex": index,
		"characterMagazine": [], "classMagazine": [], "weaponMagazine": [], "modifier": null
	}


func attackDamage(attacker, target, quality: int) -> int:
	var hpBefore = target.hp
	resolver.applyHitDamage(target, resolver.calculateAttackDamage(attacker, target, quality), quality)
	return hpBefore - target.hp


func _run() -> void:
	print("--- Docs/Combat.md worked example ---")
	makeFight()
	var shooter = addActor("Shooter", "lead", "revolver", 0, { "style": 0, "sand": 0 })
	var target = addActor("Target", "lead", "revolver", 0, { "style": 4, "sand": 1 })
	setCylinder("Shooter", [2, 3, 1, 0])
	resolver.resolveAttack(shooter, target)   # first attack: Chamber 2 (Hit)
	_check(target.hp == 44, "first attack: 10 * 100%% - max(4, 1) = 6, got %d damage" % (50 - target.hp))
	resolver.resolveAttack(shooter, target)   # second attack: Chamber 3 (Critical)
	_check(target.hp == 33, "second attack: 10 * 150%% - 4 = 11, got %d damage" % (50 - target.hp))

	print("\n--- Weapon family rules ---")
	var styleTarget = addActor("StyleTarget", "lead", "revolver", 0, { "style": 8, "sand": 1 })
	var sandTarget = addActor("SandTarget", "lead", "revolver", 0, { "style": 1, "sand": 8 })
	var rifleman = addActor("Rifleman", "lead", "rifle", 0, {})
	var shotgunner = addActor("Shotgunner", "lead", "shotgun", 0, {})
	_check(attackDamage(rifleman, styleTarget, 2) == 17, "rifle vs high Style: 10 + 8 - 1 = 17")
	_check(attackDamage(rifleman, sandTarget, 2) == 3, "rifle vs high Sand: 10 + 1 - 8 = 3")
	_check(attackDamage(shotgunner, sandTarget, 2) == 17, "shotgun vs high Sand: 10 + 8 - 1 = 17")
	_check(attackDamage(shotgunner, styleTarget, 2) == 3, "shotgun vs high Style: 10 + 1 - 8 = 3")
	_check(attackDamage(shooter, styleTarget, 2) == 2, "revolver loses the higher value: 10 - 8 = 2")

	print("\n--- Lasso ignores stats ---")
	var weakRoper = addActor("WeakRoper", "lasso", "lasso", 6, {})
	weakRoper.stats.sixShootin = 0
	var strongRoper = addActor("StrongRoper", "lasso", "lasso", 6, {})
	strongRoper.stats.sixShootin = 99
	_check(attackDamage(weakRoper, styleTarget, 2) == 6, "lasso is weapon base damage only")
	_check(attackDamage(strongRoper, styleTarget, 2) == 6, "lasso damage identical regardless of stats")
	_check(attackDamage(weakRoper, styleTarget, 0) == 0, "lasso still rolls quality (Miss = 0)")

	print("\n--- Damage floor and quality ---")
	var tanky = addActor("Tanky", "lead", "revolver", 0, { "style": 20, "sand": 20 })
	_check(attackDamage(shooter, tanky, 2) == 0, "defense can't push damage below 0")
	_check(attackDamage(shooter, tanky, 3) == 0, "even a crit clamps at 0")

	print("\n--- Explosive: class base, no defense interaction ---")
	cylinderManager.classesData = { "Dust Whisperer": { "name": "Dust Whisperer", "explosiveBase": 3 } }
	var whisperer = addActor("Whisperer", "explosive", "gunpowder", 1, {})
	whisperer.characterClass = "Dust Whisperer"
	_check(attackDamage(whisperer, tanky, 2) == 6, "explosive: 1 base + 2 stat + 3 class, defense ignored")

	print("\n--- Melee ---")
	var rat = addActor("Rat", "melee", "scratch", 2, {})
	_check(attackDamage(rat, tanky, 2) == 2, "melee uses weapon base damage, defense ignored")

	print("\n--- Attack abilities skip family rules ---")
	fake.movesData = { "Sharp": { "name": "Sharp", "category": "attack_ability", "baseAmount": 5, "scalingStat": "sixShootin", "statScaling": 0.25, "side": "enemy" } }
	setCylinder("Shooter", [2, 2])
	var hpBefore = styleTarget.hp
	resolver.resolveMove("Sharp", shooter, styleTarget)
	_check(hpBefore - styleTarget.hp == 5, "ability amount not reduced by defense: 5, got %d" % (hpBefore - styleTarget.hp))

	print("\n--- Rodeo stat modifiers feed the pipeline ---")
	fake.rodeoManager.modifiers["damage.lead.revolver"] = 2
	_check(attackDamage(shooter, target, 2) == 8, "modified stat: (10 + 2) - 4 = 8")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
