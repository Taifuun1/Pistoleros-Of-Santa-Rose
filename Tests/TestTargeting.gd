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
	print("--- Occupancy: the mover takes the spot, displaced occupants shift toward the vacated spot ---")
	var ctx = makeFight()
	addActor(ctx, "A", "player team", 1)
	addActor(ctx, "B", "player team", 2)
	addActor(ctx, "C", "player team", 3)
	# Example 1 from Docs/Features and Issues.md: moving 1 -> 2 swaps the
	# two, leaving 2, 1, 3.
	_check(ctx.turnManager.setActorPosition("A", 2), "a one-column move into an occupied spot succeeds as a swap")
	_check(ctx.turnManager.getActorPosition("A") == 2, "mover takes the spot")
	_check(ctx.turnManager.getActorPosition("B") == 1, "the target's occupant takes the mover's vacated spot")
	_check(ctx.turnManager.getActorPosition("C") == 3, "fighters beyond the swap stay put")
	_check(ctx.fake.actors["A"].position == Vector2(20, 0), "mover node moved")
	_check(ctx.fake.actors["B"].position == Vector2(10, 0), "swapped actor node moved into the vacated spot")

	print("\n--- Multi-column move shuffles the line (example 2: 4 -> 2, end 1, 4, 2, 3) ---")
	ctx = makeFight()
	addActor(ctx, "A", "player team", 1)
	addActor(ctx, "B", "player team", 2)
	addActor(ctx, "C", "player team", 3)
	addActor(ctx, "D", "player team", 4)
	_check(ctx.turnManager.setActorPosition("D", 2), "a multi-column move into the line succeeds")
	_check(ctx.turnManager.getActorPosition("D") == 2, "the mover lands on the target column")
	_check(ctx.turnManager.getActorPosition("B") == 3, "the target's occupant shifts toward the vacated spot")
	_check(ctx.turnManager.getActorPosition("C") == 4, "the in-between occupant fills the vacated spot")
	_check(ctx.turnManager.getActorPosition("A") == 1, "fighters before the target stay put")

	print("\n--- Forward moves work in an occupied row ---")
	ctx = makeFight()
	addActor(ctx, "B", "player team", 1)
	addActor(ctx, "A", "player team", 2)
	addActor(ctx, "C", "player team", 3)
	# Forward from position 2 into the occupied front used to fail (the old
	# push chain ran past the front of the row); with squeeze repositioning
	# it is a swap.
	_check(ctx.turnManager.canMoveActor("A", 1), "forward into an occupied column is legal under squeeze repositioning")
	_check(ctx.turnManager.setActorPosition("A", 1), "the forward move resolves in a full row")
	_check(ctx.turnManager.getActorPosition("A") == 1, "the mover takes the front spot")
	_check(ctx.turnManager.getActorPosition("B") == 2, "the front blocker swaps into the vacated spot")
	_check(ctx.turnManager.getActorPosition("C") == 3, "the fighter behind stays put")

	print("\n--- A full row never blocks repositioning ---")
	ctx = makeFight()
	addActor(ctx, "A", "player team", 1)
	addActor(ctx, "B", "player team", 2)
	addActor(ctx, "C", "player team", 3)
	addActor(ctx, "D", "player team", 4)
	_check(ctx.turnManager.setActorPosition("A", 2), "the row being full cannot fail a move: the chain fills the vacated span")
	_check(
		ctx.turnManager.getActorPosition("B") == 1 and
		ctx.turnManager.getActorPosition("C") == 3 and
		ctx.turnManager.getActorPosition("D") == 4,
		"only the swapped pair moved"
	)

	print("\n--- Bounds and no-op moves ---")
	ctx = makeFight()
	addActor(ctx, "A", "player team", 1)
	addActor(ctx, "D", "player team", 4)
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

	print("\n--- Act sides are relative to the caster ---")
	ctx = makeFight()
	ctx.fake.movesData = { "Sharp Shot": {
		"name": "Sharp Shot", "side": "enemy",
		"positions": { "type": "single", "actorUser": [1, 2, 3, 4], "targets": { "columns": [1, 2, 3, 4] } }
	} }
	addActor(ctx, "Enemy Shooter", "enemy team", 1)
	addActor(ctx, "Enemy Friend", "enemy team", 2)
	addActor(ctx, "Player Target", "player team", 2)
	var enemyShot = { "type": "Moves", "name": "Sharp Shot" }
	_check(ctx.targeting.isValidTarget(enemyShot, "Player Target", "Enemy Shooter"), "a hostile move cast by an enemy targets the player side")
	_check(!ctx.targeting.isValidTarget(enemyShot, "Enemy Friend", "Enemy Shooter"), "a hostile move cast by an enemy cannot target its own side")
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "player", "positions": { "type": "single", "targets": { "columns": [1, 2, 3, 4] } } } }
	addActor(ctx, "Enemy Healer", "enemy team", 3)
	var enemyHeal = { "type": "Items", "name": "Paregoric" }
	_check(ctx.targeting.isValidTarget(enemyHeal, "Enemy Friend", "Enemy Healer"), "a friendly item cast by an enemy targets its own side")
	_check(!ctx.targeting.isValidTarget(enemyHeal, "Player Target", "Enemy Healer"), "a friendly item cast by an enemy cannot target the player side")

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
