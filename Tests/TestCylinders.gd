extends SceneTree

## Headless validation for the Cylinder system (Docs/System Design/Shootout/Cylinders.md).
## Run with: godot --headless --script res://Tests/TestCylinders.gd

const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")
const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 30
	var maxHp = 30
	var stats = { "sixShootin": 3, "damage": { "lead": { "revolver": 4 } } }
	var weapon = { "type": "lead", "weapon": "revolver" }
	var characterClass = null
	var characterMagazine = null
	var rodeo = null


class FakeRodeoManager:
	extends RefCounted
	func getStatModifier(_actor, _statName, baseValue):
		return baseValue
	func unregisterActor(_actorName):
		pass


class FakeShootout:
	extends Node2D
	var actors = {}
	var cylinderManager = null
	var rodeoManager = FakeRodeoManager.new()
	var movesData = {}
	var itemsData = {}
	var damageNumbers = []
	func getActor(actorName):
		return actors.get(actorName, null)
	func spawnDamageNumber(label, color, _position):
		damageNumbers.append({ "label": str(label), "color": color })


func _init() -> void:
	call_deferred("_run")


func makeManager(fake) -> RefCounted:
	var manager = CylinderManagerScript.new()
	manager.shootout = fake
	fake.cylinderManager = manager
	return manager


func addActor(fake, actorName: String, characterMagazine, characterClass = null, weaponId := "revolver") -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.characterMagazine = characterMagazine
	actor.characterClass = characterClass
	actor.weapon = { "type": "lead", "weapon": weaponId }
	fake.actors[actorName] = actor
	return actor


func loadRodeosData() -> Dictionary:
	var data = {}
	for fileName in DirAccess.get_files_at("res://Data/Shootout/Rodeos"):
		if !fileName.ends_with(".gd"):
			continue
		var entry = load("res://Data/Shootout/Rodeos/{fileName}".format({ "fileName": fileName })).new()
		var entryData = entry.get("data")
		if entryData != null:
			data[entryData.name] = entryData
	return data


func _run() -> void:
	seed(12345)

	print("--- Magazine summing and clamping ---")
	var fake = FakeShootout.new()
	root.add_child(fake)
	var manager = makeManager(fake)
	manager.classesData = { "TestClass": { "name": "TestClass", "magazine": [0, 1, -1] } }
	manager.weaponMagazines = { "revolver": [2, -1, 0] }
	var actor = addActor(fake, "A", [1, 0, 2], "TestClass")
	manager.registerActor(actor)
	_check(manager.getCylinder("A") == [3, 0, 1], "Docs/Combat.md example: [1,0,2]+[0,1,-1]+[2,-1,0] = [3,0,1], got %s" % [manager.getCylinder("A")])

	var manager2 = makeManager(fake)
	var actor2 = addActor(fake, "B", [-3, -5])
	manager2.registerActor(actor2)
	_check(manager2.getCylinder("B") == [0, 0], "negative sums clamp to 0, got %s" % [manager2.getCylinder("B")])

	var manager3 = makeManager(fake)
	var actor3 = addActor(fake, "C", null)
	actor3.weapon = { "type": "melee", "weapon": "scratch" }
	manager3.registerActor(actor3)
	_check(manager3.getCylinder("C") == [2, 2, 2, 2], "no magazine data anywhere falls back to the default all-Hit cylinder")

	print("\n--- Advance and wrap-around ---")
	var manager4 = makeManager(fake)
	var actor4 = addActor(fake, "D", [2, 3])
	manager4.registerActor(actor4)
	_check(manager4.currentChamber("D") == 2, "starts at the first chamber")
	manager4.advance("D")
	_check(manager4.currentChamber("D") == 3, "advances to the second chamber")
	manager4.advance("D")
	_check(manager4.currentChamber("D") == 2 and manager4.getChamberIndex("D") == 0, "wraps back to the start")

	print("\n--- Special chambers and priority ---")
	var manager5 = makeManager(fake)
	manager5.weaponMagazines = { "revolver": ["jammed", 2] }
	manager5.classesData = { "TestClass": { "name": "TestClass", "magazine": [1, "reload"] } }
	var actor5 = addActor(fake, "E", ["reload", 1], "TestClass")
	manager5.registerActor(actor5)
	_check(manager5.getCylinder("E") == ["jammed", "reload"], "weapon > class > character special priority, got %s" % [manager5.getCylinder("E")])
	_check(manager5.hitQuality("E") == "jammed", "hitQuality passes special chambers through")

	print("\n--- Cylinder modifiers replace, never compound ---")
	var manager6 = makeManager(fake)
	var actor6 = addActor(fake, "F", [1, 0, 2])
	manager6.registerActor(actor6)
	manager6.applyCylinderModifier("F", { "chambers": "all", "amount": 1 })
	_check(manager6.getCylinder("F") == [2, 1, 3], "modifier applies to all chambers, got %s" % [manager6.getCylinder("F")])
	manager6.applyCylinderModifier("F", { "chambers": "all", "amount": 2 })
	_check(manager6.getCylinder("F") == [3, 2, 3], "new modifier re-derives from sources, got %s" % [manager6.getCylinder("F")])
	manager6.applyCylinderModifier("F", { "chambers": [1], "amount": 1 })
	_check(manager6.getCylinder("F") == [1, 1, 2], "chamber-indexed modifier only touches its slots, got %s" % [manager6.getCylinder("F")])
	manager6.clearCylinderModifier("F")
	_check(manager6.getCylinder("F") == [1, 0, 2], "clearing restores the summed cylinder")

	var manager7 = makeManager(fake)
	manager7.weaponMagazines = { "revolver": ["reload"] }
	var actor7 = addActor(fake, "G", [1])
	manager7.registerActor(actor7)
	manager7.applyCylinderModifier("G", { "chambers": "all", "amount": 3 })
	_check(manager7.getCylinder("G")[0] == "reload", "modifiers never change special chambers, got %s" % [manager7.getCylinder("G")])
	_check(manager7.getCylinder("G")[1] == 3, "empty numeric slot still gets the modifier, got %s" % [manager7.getCylinder("G")])

	print("\n--- Rodeo hit quality floor (Natural Gunslinger) ---")
	var rodeoManager = RodeoManagerScript.new()
	rodeoManager.shootout = fake
	rodeoManager.rodeosData = loadRodeosData()
	fake.rodeoManager = rodeoManager
	var gunslinger = addActor(fake, "H", [0, 0])
	gunslinger.rodeo = "natural gunslinger"
	rodeoManager.registerActor(gunslinger, "player team", 1)
	_check(rodeoManager.getHitQualityFloor(gunslinger) == 2, "Natural Gunslinger floors hit quality at 2")
	var manager8 = makeManager(fake)
	manager8.registerActor(gunslinger)
	_check(manager8.hitQuality("H") == 2, "floor raises a Miss chamber to Hit")
	var specialActor = addActor(fake, "I", [1])
	manager8.registerActor(specialActor)
	manager8.cylinders["I"].cylinder = ["reload", 0]
	_check(manager8.hitQuality("I") == "reload", "floor does not override special chambers")

	print("\n--- resolveAttack quality pipeline ---")
	fake.rodeoManager = FakeRodeoManager.new()
	var resolver = ActionResolverScript.new()
	resolver.init(fake)
	var attacker = addActor(fake, "Shooter", [1])
	var target = addActor(fake, "Target", [1])
	var manager9 = makeManager(fake)
	manager9.registerActor(attacker)
	manager9.cylinders["Shooter"].cylinder = [0, 2, 3]
	resolver.resolveAttack(attacker, target)
	_check(target.hp == 30, "Miss deals no damage")
	_check(manager9.getChamberIndex("Shooter") == 1, "Miss still advances the cylinder")
	_check(fake.damageNumbers.back().label == "Miss", "Miss label shown")
	resolver.resolveAttack(attacker, target)
	_check(target.hp == 26, "Hit deals full stat damage (4)")
	_check(fake.damageNumbers.back().color == "red", "Hit uses the hit color")
	resolver.resolveAttack(attacker, target)
	_check(target.hp == 20, "Critical deals 150%% (4 * 1.5 = 6)")
	_check(fake.damageNumbers.back().color == "yellow", "Critical uses the crit color")
	_check(manager9.getChamberIndex("Shooter") == 0, "cylinder wrapped after three attacks")

	print("\n--- Special chambers in resolveAttack ---")
	manager9.cylinders["Shooter"].cylinder = ["reload", 2]
	manager9.cylinders["Shooter"].chamberIndex = 0
	resolver.resolveAttack(attacker, target)
	_check(target.hp == 20, "Reload spends the move without attacking")
	_check(fake.damageNumbers.back().label == "Reload", "Reload label shown")
	_check(manager9.getChamberIndex("Shooter") == 1, "Reload advances the cylinder")
	manager9.cylinders["Shooter"].cylinder = ["jammed", 2]
	manager9.cylinders["Shooter"].chamberIndex = 0
	resolver.resolveAttack(attacker, target)
	_check(target.hp == 20, "Jammed fails the attack")
	_check(fake.damageNumbers.back().label == "Jammed!", "Jammed label shown")

	print("\n--- Attack abilities vs non-attack abilities ---")
	fake.movesData = {
		"Sharp": { "name": "Sharp", "category": "attack_ability", "baseAmount": 5, "scalingStat": "sixShootin", "statScaling": 0.25, "side": "enemy" },
		"Hype": { "name": "Hype", "category": "ability", "baseAmount": 3, "side": "enemy" }
	}
	manager9.cylinders["Shooter"].cylinder = [2, 2]
	manager9.cylinders["Shooter"].chamberIndex = 0
	target.hp = 30
	resolver.resolveMove("Sharp", attacker, target)
	_check(target.hp == 25, "attack ability uses hit quality (5 * 1.0 = 5), got %d" % (30 - target.hp))
	_check(manager9.getChamberIndex("Shooter") == 1, "attack ability advances the cylinder")
	resolver.resolveMove("Hype", attacker, target)
	_check(target.hp == 22, "non-attack ability applies its flat amount, got %d" % target.hp)
	_check(manager9.getChamberIndex("Shooter") == 1, "non-attack ability does not advance the cylinder")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
