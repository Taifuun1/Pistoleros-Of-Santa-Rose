extends SceneTree

## Headless validation for the enemy AI (Docs/System Design/Shootout/Enemy AI.md).
## Run with: godot --headless --script res://Tests/TestEnemyAI.gd

const EnemyAIScript = preload("res://Shootout/ShootoutEnemyAI.gd")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")
const EffectManagerScript = preload("res://Shootout/ShootoutEffectManager.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")
const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 30
	var maxHp = 50
	var stats = {
		"sixShootin": 1,
		"damage": { "lead": { "revolver": 1, "rifle": 1, "shotgun": 1 }, "explosive": {}, "lasso": 0 },
		"defense": { "style": 0, "sand": 0 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	}
	var weapon = { "type": "lead", "weapon": "revolver", "baseDamage": 1 }
	var moves = []
	var items = []
	var characterClass = null
	var characterMagazine = null
	var ai = null
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
	var rodeoManager = FakeRodeoManager.new()
	var turnManager = null
	var targetingManager = null
	var effectManager = null
	var actionResolver = null
	var cylinderManager = null
	var movesData = {}
	var itemsData = {}
	var aiData = {}
	func _init():
		actors = {}
	func getActor(actorName):
		return actors.get(actorName, null)
	func getPositionForColumn(_actorSide, column):
		return Vector2(column * 10, 0)
	func spawnDamageNumber(_label, _color, _position):
		pass


func _init() -> void:
	call_deferred("_run")


func makeFight() -> Dictionary:
	var fake = FakeShootout.new()
	root.add_child(fake)
	var turnManager = TurnManagerScript.new()
	turnManager.init(fake)
	fake.turnManager = turnManager
	var targetingManager = TargetingManagerScript.new()
	targetingManager.init(turnManager)
	fake.targetingManager = targetingManager
	var effectManager = EffectManagerScript.new()
	effectManager.init(fake)
	fake.effectManager = effectManager
	var cylinderManager = CylinderManagerScript.new()
	cylinderManager.shootout = fake
	fake.cylinderManager = cylinderManager
	var actionResolver = ActionResolverScript.new()
	actionResolver.init(fake)
	fake.actionResolver = actionResolver
	var enemyAI = EnemyAIScript.new()
	enemyAI.init(fake)
	return { "fake": fake, "turnManager": turnManager, "enemyAI": enemyAI, "effectManager": effectManager }


func addActor(ctx: Dictionary, actorName: String, side: String, column: int, weaponId := "revolver") -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.stats = actor.stats.duplicate(true)
	actor.stats.damage = actor.stats.damage.duplicate(true)
	actor.weapon = { "type": "lead", "weapon": weaponId, "baseDamage": 1 }
	actor.moves = []
	actor.items = []
	ctx.fake.actors[actorName] = actor
	ctx.turnManager.registerActor(side, actorName, column)
	return actor


func _run() -> void:
	print("--- Legal acts respect the same validation as the player ---")
	var ctx = makeFight()
	ctx.fake.movesData = {
		"Snipe": { "name": "Snipe", "category": "ability", "side": "enemy", "baseAmount": 3,
			"positions": { "actorUser": [3, 4], "targets": { "columns": [1, 2] } } },
		"Duck Down": { "name": "Duck Down", "category": "duck", "side": "enemy",
			"positions": { "targets": { "columns": [1, 2, 3, 4] } }, "effects": [] }
	}
	var hunter = addActor(ctx, "Hunter", "enemy team", 1)
	addActor(ctx, "Victim", "player team", 1)
	hunter.moves = ["Snipe", "Duck Down"]
	var legal = ctx.enemyAI.gatherLegalActs("Hunter")
	for act in legal:
		_check(!(act.type == "Moves" and act.get("name", "") == "Snipe"), "out-of-column move must not be gathered")
	_check(legal.any(func(act): return act.type == "Moves" and act.name == "Duck Down"), "duck is legal for the enemy")
	var abilitiesGathered = legal.filter(func(act): return act.type == "Moves" and act.get("name", "") == "Snipe")
	_check(abilitiesGathered.is_empty(), "Snipe illegal from column 1 regardless of silence")
	ctx.effectManager.applyEffect("Hunter", { "op": "apply_effect", "effect": "silence", "turns": 2 })
	legal = ctx.enemyAI.gatherLegalActs("Hunter")
	_check(legal.any(func(act): return act.type == "Moves" and act.name == "Duck Down"), "silence keeps ducks legal")
	_check(legal.all(func(act): return act.type != "Moves" or act.name == "Duck Down"), "silence blocks abilities")

	print("\n--- Lethal attacks score above non-lethal ones ---")
	ctx = makeFight()
	var killer = addActor(ctx, "Killer", "enemy team", 1)
	var weakling = addActor(ctx, "Weakling", "player team", 1)
	var tank = addActor(ctx, "TankTarget", "player team", 2)
	weakling.hp = 1
	tank.hp = 50
	var scored = ctx.enemyAI.scoreActs("Killer", ctx.enemyAI.gatherLegalActs("Killer"))
	_check(scored[0].targetName == "Weakling", "the killable target is preferred, got %s" % scored[0].targetName)

	print("\n--- Support archetype heals a wounded ally over attacking ---")
	ctx = makeFight()
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "enemy", "baseAmount": 5 } }
	var medic = addActor(ctx, "Medic", "enemy team", 1)
	medic.items = ["Paregoric"]
	medic.ai = { "archetype": "support", "aggression": 0.2 }
	var hurtAlly = addActor(ctx, "HurtAlly", "enemy team", 2)
	hurtAlly.hp = 10
	var sturdy = addActor(ctx, "Sturdy", "player team", 1)
	sturdy.stats.defense = { "style": 50, "sand": 50 }
	scored = ctx.enemyAI.scoreActs("Medic", ctx.enemyAI.gatherLegalActs("Medic"))
	_check(scored[0].type == "Items" and scored[0].targetName == "HurtAlly", "healing the wounded ally outscores the attack, got %s -> %s" % [scored[0].type, scored[0].targetName])

	print("\n--- Repositioning when nothing else is legal ---")
	ctx = makeFight()
	var stuck = addActor(ctx, "Stuck", "enemy team", 1, "rifle")
	addActor(ctx, "FarTarget", "player team", 4)
	scored = ctx.enemyAI.scoreActs("Stuck", ctx.enemyAI.gatherLegalActs("Stuck"))
	_check(!scored.is_empty() and scored.all(func(act): return act.type == "Reposition"), "only repositioning is legal for a rifle stuck in column 1, got %s" % [scored])
	var act = ctx.enemyAI.chooseAct("Stuck")
	_check(act.type == "Reposition", "AI chooses to reposition")

	print("\n--- Boss scripts beat scoring ---")
	ctx = makeFight()
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "enemy", "baseAmount": 5 } }
	ctx.fake.aiData = { "Rat King": { "name": "Rat King", "rules": [
		{ "when": { "hpBelow": 0.5 }, "act": { "type": "Items", "name": "Paregoric", "targetName": "self" } }
	] } }
	var boss = addActor(ctx, "Boss", "enemy team", 1)
	boss.items = ["Paregoric"]
	boss.ai = { "script": "Rat King" }
	addActor(ctx, "EasyKill", "player team", 1).hp = 1
	boss.hp = 10
	act = ctx.enemyAI.chooseAct("Boss")
	_check(act.type == "Items" and act.targetName == "Boss", "scripted rule fires below the HP threshold, got %s" % [act])
	boss.hp = 50
	_check(ctx.enemyAI.chooseScriptedAct("Boss").is_empty(), "no rule applies above the HP threshold")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
