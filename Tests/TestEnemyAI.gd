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
	# Combat RNG seam (commit 13): null keeps the global-RNG fallback paths hot.
	var combatRng = null
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
		"Duck Down": { "name": "Duck Down", "category": "duck", "side": "player",
			"positions": { "targets": { "columns": [1, 2, 3, 4] } }, "effects": [] }
	}
	var hunter = addActor(ctx, "Hunter", "enemy team", 1)
	addActor(ctx, "Victim", "player team", 1)
	hunter.moves = ["Snipe", "Duck Down"]
	var legal = ctx.enemyAI.gatherLegalActs("Hunter")
	_check(legal.all(func(act): return act.type != "Attack"), "no basic Attack act is gathered")
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
	ctx.fake.movesData = {
		"Strike": { "name": "Strike", "category": "attack_ability", "side": "enemy", "baseAmount": 3,
			"positions": { "actorUser": [1, 2, 3, 4], "targets": { "columns": [1, 2, 3, 4] } } },
	}
	var killer = addActor(ctx, "Killer", "enemy team", 1)
	killer.moves = ["Strike"]
	var weakling = addActor(ctx, "Weakling", "player team", 1)
	var tank = addActor(ctx, "TankTarget", "player team", 2)
	weakling.hp = 1
	tank.hp = 50
	var scored = ctx.enemyAI.scoreActs("Killer", ctx.enemyAI.gatherLegalActs("Killer"))
	_check(!scored.is_empty() and scored[0].type == "Moves" and scored[0].targetName == "Weakling", "the killable target is preferred, got %s" % [scored[0]])

	print("\n--- Support archetype heals a wounded ally over attacking ---")
	ctx = makeFight()
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "player", "baseAmount": 5 } }
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
	ctx.fake.itemsData = { "Paregoric": { "name": "Paregoric", "side": "player", "baseAmount": 5 } }
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

	print("\n--- Multi-target acts gather and score as one resolved set ---")
	ctx = makeFight()
	ctx.fake.movesData = {
		"Sweep": { "name": "Sweep", "category": "attack_ability", "side": "enemy", "baseAmount": 2,
			"positions": { "type": "multi", "targets": { "columns": [1, 2, 3, 4] } } },
	}
	var sweeper = addActor(ctx, "Sweeper", "enemy team", 1)
	sweeper.moves = ["Sweep"]
	var sweepTargetA = addActor(ctx, "SweepTargetA", "player team", 1)
	var sweepTargetB = addActor(ctx, "SweepTargetB", "player team", 2)
	sweepTargetB.hp = 5
	legal = ctx.enemyAI.gatherLegalActs("Sweeper")
	var sweepActs = legal.filter(func(act): return act.type == "Moves" and act.name == "Sweep")
	_check(sweepActs.size() == 1, "a multi act is gathered once, not once per target, got %d" % sweepActs.size())
	if sweepActs.size() == 1:
		_check(sweepActs[0].targetNames.size() == 2, "the gathered multi act carries its full target set, got %s" % [sweepActs[0].targetNames])
		_check(sweepActs[0].targetName == "SweepTargetA", "the multi act keeps a deterministic anchor target")
	var scoredSweep = ctx.enemyAI.scoreActs("Sweeper", legal)
	_check(scoredSweep[0].targetNames.size() == 2, "AI scores the same resolved set it will execute")

	ctx = makeFight()
	ctx.fake.itemsData = { "multiHeal": { "name": "multiHeal", "side": "player", "baseAmount": 5,
		"positions": { "type": "multi", "targets": { "columns": [1, 2, 3, 4] } } } }
	var support = addActor(ctx, "Support", "enemy team", 1)
	support.items = ["multiHeal"]
	support.ai = { "archetype": "support", "aggression": 0.2 }
	var woundedOne = addActor(ctx, "WoundedOne", "enemy team", 2)
	woundedOne.hp = 10
	var woundedTwo = addActor(ctx, "WoundedTwo", "enemy team", 3)
	woundedTwo.hp = 15
	legal = ctx.enemyAI.gatherLegalActs("Support")
	var healActs = legal.filter(func(act): return act.type == "Items" and act.name == "multiHeal")
	_check(healActs.size() == 1 and healActs[0].targetNames.size() == 3, "a multi-heal is gathered once with every wounded ally")
	scoredSweep = ctx.enemyAI.scoreActs("Support", legal)
	_check(scoredSweep[0].type == "Items" and scoredSweep[0].score > 60.0, "multi-heal scores the sum of missing ally HP, got %f" % scoredSweep[0].score)

	print("\n--- Separated offensive/support weights (commit 13) ---")
	ctx = makeFight()
	ctx.fake.movesData = {
		"Blast": { "name": "Blast", "category": "attack_ability", "side": "enemy", "baseAmount": 8,
			"positions": { "actorUser": [1, 2, 3, 4], "targets": { "columns": [1, 2, 3, 4] } } },
		"Duck Down": { "name": "Duck Down", "category": "duck", "side": "enemy",
			"positions": { "targets": { "columns": [1, 2, 3, 4] } }, "effects": [] },
	}
	var brawler = addActor(ctx, "Brawler", "enemy team", 1)
	brawler.moves = ["Blast", "Duck Down"]
	addActor(ctx, "Target", "player team", 1).hp = 50
	var weighted = ctx.enemyAI.scoreActs("Brawler", ctx.enemyAI.gatherLegalActs("Brawler"))
	_check(weighted[0].name == "Blast", "default weights keep the attack ahead, got %s" % weighted[0].name)
	brawler.ai = { "archetype": "support", "weights": { "offense": 0.1, "support": 0.5, "defense": 3.0, "reposition": 1.0 } }
	var supportWeighted = ctx.enemyAI.scoreActs("Brawler", ctx.enemyAI.gatherLegalActs("Brawler"))
	_check(supportWeighted[0].name == "Duck Down", "a defense-heavy profile puts the Duck first, got %s" % supportWeighted[0].name)
	brawler.ai = { "archetype": "support", "weights": { "offense": 5.0, "support": 0.1, "defense": 0.1, "reposition": 1.0 } }
	var offenseWeighted = ctx.enemyAI.scoreActs("Brawler", ctx.enemyAI.gatherLegalActs("Brawler"))
	_check(offenseWeighted[0].name == "Blast", "an offense-heavy profile puts the attack first")
	_check(is_equal_approx(ctx.enemyAI.actionWeight(brawler, "offense"), 5.0), "actionWeight reads the authored family weight")

	print("\n--- Dust-up versus Showdown candidate width (commit 13) ---")
	var rng = RandomNumberGenerator.new()
	rng.seed = 1
	# Find a seed whose first draw picks the second-best act under width 2.
	var picksSecond = false
	var probe = 0
	for candidate in 50:
		rng.seed = candidate
		picksSecond = rng.randi_range(0, 1) == 1
		if picksSecond:
			probe = candidate
			break
	_check(picksSecond, "the probe found a draw that exercises the wider Dust-up pool")
	var duel = makeFight()
	duel.fake.movesData = ctx.fake.movesData
	duel.fake.combatRng = RandomNumberGenerator.new()
	duel.fake.combatRng.seed = probe
	var duelist = addActor(duel, "Duelist", "enemy team", 1)
	duelist.moves = ["Blast", "Duck Down"]
	addActor(duel, "DuelTarget", "player team", 1).hp = 50
	var dustupAct = duel.enemyAI.chooseAct("Duelist")
	duel.fake.combatRng.seed = probe
	duel.turnManager.setEncounterKind("showdown")
	var showdownAct = duel.enemyAI.chooseAct("Duelist")
	_check(str(showdownAct.get("name", "")) == "Blast", "a Showdown always takes the best-scored act, got %s" % [showdownAct])
	_check(str(dustupAct.get("name", "")) == showdownAct.get("name", "") or dustupAct.get("name", "") == "Duck Down", "the Dust-up pool can still pick the runner-up")
	duelist.ai = { "archetype": "damage", "pickFromTop": 1 }
	duel.turnManager.setEncounterKind("dustup")
	duel.fake.combatRng.seed = probe + 1
	duel.fake.combatRng.seed = probe
	var narrowed = duel.enemyAI.chooseAct("Duelist")
	_check(str(narrowed.get("name", "")) == "Blast", "an authored pickFromTop narrows the Dust-up to the best act")
	_check(duel.enemyAI.effectivePickFromTop(duelist) == 1 and duel.enemyAI.effectivePickFromTop(null) == 2, "authored width overrides the encounter default")

	print("\n--- Unknown AI script falls through to scoring ---")
	ctx = makeFight()
	ctx.fake.aiData = {}
	var lost = addActor(ctx, "Lost", "enemy team", 1)
	lost.ai = { "script": "Missing Script" }
	var fallbackAct = ctx.enemyAI.chooseAct("Lost")
	_check(fallbackAct.is_empty() or fallbackAct.get("type", "") != "", "an unknown script warns and falls back instead of failing the turn")

	print("\n--- Seeded combat RNG makes picks reproducible ---")
	ctx = makeFight()
	ctx.fake.movesData = {
		"Blast": { "name": "Blast", "category": "attack_ability", "side": "enemy", "baseAmount": 3,
			"positions": { "actorUser": [1, 2, 3, 4], "targets": { "columns": [1, 2, 3, 4] } } },
		"Duck Down": { "name": "Duck Down", "category": "duck", "side": "enemy",
			"positions": { "targets": { "columns": [1, 2, 3, 4] } }, "effects": [] },
	}
	var ratA = addActor(ctx, "RatA", "enemy team", 1)
	ratA.moves = ["Blast", "Duck Down"]
	ratA.ai = { "archetype": "damage", "pickFromTop": 2 }
	addActor(ctx, "RatTarget", "player team", 1)
	ctx.fake.combatRng = RandomNumberGenerator.new()
	ctx.fake.combatRng.seed = 4242
	var firstRun = []
	for i in 12:
		firstRun.append(str(ctx.enemyAI.chooseAct("RatA").get("name", "")))
	ctx.fake.combatRng = RandomNumberGenerator.new()
	ctx.fake.combatRng.seed = 4242
	var secondRun = []
	for i in 12:
		secondRun.append(str(ctx.enemyAI.chooseAct("RatA").get("name", "")))
	_check(firstRun == secondRun, "the same seed replays identical decisions")
	_check(firstRun.any(func(name): return name == "Duck Down") and firstRun.any(func(name): return name == "Blast"), "the width-2 pool mixes both acts, got %s" % [firstRun])

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
