extends SceneTree

## Headless validation for moves, items and ducks (Docs/System Design/Shootout/Moves Items and Ducks.md).
## Run with: godot --headless --script res://Tests/TestActs.gd

const BaseActorScript = preload("res://Actors/BaseActor.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")
const EffectManagerScript = preload("res://Shootout/ShootoutEffectManager.gd")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 30
	var maxHp = 50
	var stats = { "sixShootin": 3, "damage": { "lead": { "revolver": 4 } } }
	var weapon = { "type": "lead", "weapon": "revolver", "baseDamage": 0 }
	var moves = []
	var items = []
	var characterClass = null
	var characterMagazine = null


class FakeShootout:
	extends Node2D
	var actors = {}
	var turnManager = null
	var effectManager = null
	var movesData = {}
	var itemsData = {}
	var damageNumbers = []
	func _init():
		actors = {}
		damageNumbers = []
	func getActor(actorName):
		return actors.get(actorName, null)
	func getPositionForColumn(_actorSide, column):
		return Vector2(column * 10, 0)
	func spawnDamageNumber(label, _color, _position):
		damageNumbers.append(str(label))


func _init() -> void:
	call_deferred("_run")


func makeFight() -> Dictionary:
	var fake = FakeShootout.new()
	root.add_child(fake)
	var turnManager = TurnManagerScript.new()
	turnManager.init(fake)
	fake.turnManager = turnManager
	var effectManager = EffectManagerScript.new()
	effectManager.init(fake)
	fake.effectManager = effectManager
	var resolver = ActionResolverScript.new()
	resolver.init(fake)
	var targeting = TargetingManagerScript.new()
	targeting.init(turnManager)
	return { "fake": fake, "turnManager": turnManager, "effectManager": effectManager, "resolver": resolver, "targeting": targeting }


func addActor(ctx: Dictionary, actorName: String, side: String, column: int) -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.stats = actor.stats.duplicate(true)
	actor.moves = []
	actor.items = []
	ctx.fake.actors[actorName] = actor
	ctx.turnManager.registerActor(side, actorName, column)
	return actor


func _run() -> void:
	print("--- Loadout limits: move cap and belt space ---")
	var actorData = {
		"actorName": "Test", "hp": 10, "walkingSpeed": 1, "runningSpeed": 1,
		"stats": { "sixShootin": 1, "highTailin": 1, "taffyin": 1, "damage": { "lead": {}, "explosive": {} } },
		"rodeo": null,
		"weapon": { "type": "lead", "weapon": "revolver", "baseDamage": 2 },
		"moves": ["A", "B", "C", "D", "E"],
		"items": ["X", "Y", "Z"]
	}
	var loadoutActor = BaseActorScript.new()
	loadoutActor.init(actorData)
	loadoutActor.applyLoadoutLimits(1)
	_check(loadoutActor.moves.size() == 4, "4-move cap truncates, got %d" % loadoutActor.moves.size())
	_check(loadoutActor.items.size() == 1, "belt space caps items, got %d" % loadoutActor.items.size())
	_check(loadoutActor.moves == ["A", "B", "C", "D"], "first moves are kept")
	var permissive = BaseActorScript.new()
	permissive.init(actorData)
	permissive.applyLoadoutLimits(-1)
	_check(permissive.items.size() == 3, "belt space -1 means no belt limit")

	print("\n--- Item use consumes one instance ---")
	var ctx = makeFight()
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "player", "baseAmount": 5 } }
	var user = addActor(ctx, "User", "player team", 1)
	var target = addActor(ctx, "Target", "player team", 2)
	user.items = ["Paregoric", "Paregoric"]
	ctx.resolver.resolveItem("Paregoric", user, target)
	_check(user.items.size() == 1, "item consumed on use")
	_check(target.hp == 35, "item healed 5, got %d" % target.hp)
	ctx.resolver.resolveItem("Not An Item", user, target)
	_check(user.items.size() == 1, "unknown items are not consumed")
	ctx.resolver.resolveItem("Paregoric", user, target)
	_check(user.items.is_empty(), "second use empties the belt")

	print("\n--- Ducks are buffs: no damage, effects only ---")
	ctx = makeFight()
	ctx.fake.movesData = {
		"Duck Down": { "name": "Duck Down", "category": "duck", "side": "player",
			"positions": { "type": "single", "targets": { "columns": [1, 2, 3, 4] } },
			"effects": [{ "op": "apply_effect", "effect": "heal", "amount": 2 }] }
	}
	var ducker = addActor(ctx, "Ducker", "player team", 1)
	var ally = addActor(ctx, "Ally", "player team", 2)
	ctx.resolver.resolveMove("Duck Down", ducker, ally)
	_check(ally.hp == 32, "duck deals no damage and applies its heal effect, got %d" % ally.hp)
	_check(ctx.targeting.isValidTarget({ "type": "Moves", "name": "Duck Down" }, "Ally", "Ducker"), "duck targets allies")
	var enemy = addActor(ctx, "Enemy", "enemy team", 1)
	_check(!ctx.targeting.isValidTarget({ "type": "Moves", "name": "Duck Down" }, "Enemy", "Ducker"), "duck cannot target enemies")

	print("\n--- Heal over time ticks at turn start ---")
	ctx = makeFight()
	var hotTarget = addActor(ctx, "Hot", "player team", 1)
	hotTarget.hp = 20
	ctx.effectManager.applyEffect("Hot", { "op": "apply_effect", "effect": "heal_over_time", "amount": 2, "turns": 2 })
	ctx.effectManager.onTurnStart("Hot")
	_check(hotTarget.hp == 22, "first heal tick")
	ctx.effectManager.onTurnStart("Hot")
	_check(hotTarget.hp == 24, "second heal tick")
	ctx.effectManager.onTurnStart("Hot")
	_check(hotTarget.hp == 24, "heal expires after its turns")

	print("\n--- Usable move filtering: column and silence ---")
	ctx = makeFight()
	ctx.fake.movesData = {
		"Long Shot": { "name": "Long Shot", "category": "ability", "positions": { "actorUser": [3, 4], "targets": { "columns": [1] } } },
		"Sharp": { "name": "Sharp", "category": "attack_ability", "positions": { "actorUser": [1, 2], "targets": { "columns": [1] } } },
		"Duck Down": { "name": "Duck Down", "category": "duck", "positions": { "targets": { "columns": [1] } } }
	}
	var mover = addActor(ctx, "Mover", "player team", 1)
	var usable = ctx.targeting.usableMoves(["Long Shot", "Sharp", "Duck Down"], "Mover", false, ctx.fake.movesData)
	_check(usable == ["Sharp", "Duck Down"], "out-of-column moves filtered, got %s" % [usable])
	usable = ctx.targeting.usableMoves(["Long Shot", "Sharp", "Duck Down"], "Mover", true, ctx.fake.movesData)
	_check(usable == ["Duck Down"], "silence blocks abilities but not ducks, got %s" % [usable])
	ctx.turnManager.setActorPosition("Mover", 3)
	usable = ctx.targeting.usableMoves(["Long Shot", "Sharp", "Duck Down"], "Mover", false, ctx.fake.movesData)
	_check(usable == ["Long Shot", "Duck Down"], "column filter follows repositioning, got %s" % [usable])

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
