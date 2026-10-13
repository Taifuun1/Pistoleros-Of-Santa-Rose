extends SceneTree

## Headless validation for positions and targeting (Docs/System Design/Shootout/Positions and Targeting.md).
## Run with: godot --headless --script res://Tests/TestTargeting.gd

const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")
const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 10
	var maxHp = 10
	var stats = { "highTailin": 5 }
	var weapon = { "type": "lead", "weapon": "revolver", "baseDamage": 2 }
	var characterClass = null
	var characterMagazine = null
	var rodeo = null


class FakeShootout:
	extends Node2D
	var actors = {}
	var turnManager = null
	var movesData = {}
	var itemsData = {}
	func getActor(actorName):
		return actors.get(actorName, null)
	func getPositionForColumn(_actorSide, column):
		return Vector2(column * 10, 0)


func _init() -> void:
	call_deferred("_run")


func makeFight() -> Dictionary:
	var fake = FakeShootout.new()
	root.add_child(fake)
	var turnManager = TurnManagerScript.new()
	turnManager.init(fake)
	fake.turnManager = turnManager
	var targeting = TargetingManagerScript.new()
	targeting.init(turnManager)
	return { "fake": fake, "turnManager": turnManager, "targeting": targeting }


func addActor(ctx: Dictionary, actorName: String, side: String, column: int, weaponId := "revolver") -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.weapon = { "type": "lead", "weapon": weaponId, "baseDamage": 2 }
	ctx.fake.actors[actorName] = actor
	ctx.turnManager.registerActor(side, actorName, column)
	return actor


func _run() -> void:
	print("--- Occupancy: the moving character takes the spot, occupants push ---")
	var ctx = makeFight()
	addActor(ctx, "A", "player team", 1)
	addActor(ctx, "B", "player team", 2)
	addActor(ctx, "C", "player team", 3)
	_check(ctx.turnManager.setActorPosition("A", 2), "move into an occupied spot should succeed with push")
	_check(ctx.turnManager.getActorPosition("A") == 2, "mover takes the spot")
	_check(ctx.turnManager.getActorPosition("B") == 3, "occupant B pushed one step")
	_check(ctx.turnManager.getActorPosition("C") == 4, "occupant C pushed one step")
	_check(ctx.fake.actors["B"].position == Vector2(30, 0), "pushed actor node moved")
	_check(ctx.fake.actors["A"].position == Vector2(20, 0), "mover node moved")

	print("\n--- Blocked end: the move fails ---")
	ctx = makeFight()
	addActor(ctx, "A", "player team", 1)
	addActor(ctx, "B", "player team", 2)
	addActor(ctx, "C", "player team", 3)
	addActor(ctx, "D", "player team", 4)
	_check(!ctx.turnManager.setActorPosition("A", 2), "push chain running past the end fails")
	_check(ctx.turnManager.getActorPosition("A") == 1, "failed move changes nothing (A)")
	_check(ctx.turnManager.getActorPosition("D") == 4, "failed move changes nothing (D)")

	print("\n--- Bounds and no-op moves ---")
	_check(!ctx.turnManager.setActorPosition("A", 0), "below position 1 is clamped to a no-op")
	_check(!ctx.turnManager.setActorPosition("D", 5), "past position 4 is clamped to a no-op")
	_check(ctx.turnManager.getActorPosition("A") == 1, "no-op leaves positions alone")

	print("\n--- Move ranges (actorUser / target columns) ---")
	ctx = makeFight()
	ctx.fake.movesData = { "Long Shot": {
		"name": "Long Shot", "side": "enemy",
		"positions": { "type": "single", "actorUser": [3, 4], "targets": { "columns": [1, 2] } }
	} }
	addActor(ctx, "Shooter", "player team", 1)
	addActor(ctx, "Target", "enemy team", 2)
	var longShot = { "type": "Moves", "name": "Long Shot" }
	_check(!ctx.targeting.isValidTarget(longShot, "Target", "Shooter"), "move invalid from column 1")
	ctx.turnManager.setActorPosition("Shooter", 4)
	_check(ctx.targeting.isValidTarget(longShot, "Target", "Shooter"), "move valid from column 4 to column 2 target")
	ctx.turnManager.setActorPosition("Target", 3)
	_check(!ctx.targeting.isValidTarget(longShot, "Target", "Shooter"), "target column outside the move's range is invalid")

	print("\n--- Weapon ranges ---")
	ctx = makeFight()
	addActor(ctx, "Revolver", "player team", 1, "revolver")
	addActor(ctx, "Rifleman", "player team", 2, "rifle")
	addActor(ctx, "Rat", "enemy team", 2, "scratch")
	var attack = { "type": "Attack" }
	_check(ctx.targeting.isValidTarget(attack, "Rat", "Revolver"), "revolver fires from 1 at 2")
	_check(!ctx.targeting.isValidTarget(attack, "Rat", "Rifleman"), "rifle cannot fire from column 2")
	ctx.turnManager.setActorPosition("Rifleman", 3)
	_check(ctx.targeting.isValidTarget(attack, "Rat", "Rifleman"), "rifle fires from column 3")
	_check(!ctx.targeting.isValidTarget(attack, "Revolver", "Rifleman"), "attacks on allies are invalid")
	ctx.turnManager.setActorPosition("Rat", 4)
	_check(!ctx.targeting.isValidTarget(attack, "Rifleman", "Rat"), "scratch (melee) cannot attack from column 4")
	ctx.turnManager.setActorPosition("Rat", 2)
	_check(!ctx.targeting.isValidTarget(attack, "Rifleman", "Rat"), "scratch (melee) cannot reach a column 3 target")

	print("\n--- Items target allies in any position ---")
	ctx = makeFight()
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "player", "positions": { "type": "single", "targets": { "columns": [1, 2, 3, 4] } } } }
	addActor(ctx, "Healer", "player team", 1)
	addActor(ctx, "Hurt", "player team", 4)
	var heal = { "type": "Items", "name": "Paregoric" }
	_check(ctx.targeting.isValidTarget(heal, "Hurt", "Healer"), "item usable on an ally at any position")
	_check(!ctx.targeting.isValidTarget(heal, "Enemy", "Healer"), "unknown actors are never valid targets")

	print("\n--- Position-conditional Rodeos follow repositioning ---")
	ctx = makeFight()
	var fake = ctx.fake
	var rodeoManager = RodeoManagerScript.new()
	rodeoManager.shootout = fake
	var data = load("res://Data/Shootout/Rodeos/HappyShot.gd").new().data
	rodeoManager.rodeosData = { data.name: data }
	var gunslinger = addActor(ctx, "Sharp", "player team", 1)
	gunslinger.rodeo = "happy shot"
	rodeoManager.registerActor(gunslinger, "player team", 1)
	_check(rodeoManager.getStatModifier(gunslinger, "highTailin", 6) == 8, "Happy Shot applies in column 1")
	ctx.turnManager.setActorPosition("Sharp", 2)
	_check(rodeoManager.getStatModifier(gunslinger, "highTailin", 6) == 6, "Happy Shot stops applying after repositioning")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
