extends SceneTree

## Headless validation for the Effects system (Docs/System Design/Shootout/Effects.md).
## Run with: godot --headless --script res://Tests/TestEffects.gd

const EffectManagerScript = preload("res://Shootout/ShootoutEffectManager.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 30
	var maxHp = 30
	var stats = { "resistances": { "bleed": 0.0, "poison": 0.0 } }


class FakeTurnManager:
	extends RefCounted
	var shootoutActors = {
		"player team": { "Tank": { "actorPosition": 1 }, "Weak": { "actorPosition": 2 } },
		"enemy team": { "Rat": { "actorPosition": 1 } }
	}


class FakeCylinderManager:
	extends RefCounted
	var applied = []
	func _init():
		applied = []
	func applyCylinderModifier(actorName, modifier):
		applied.append({ "actorName": actorName, "modifier": modifier })


class FakeShootout:
	extends Node2D
	var actors = {}
	var turnManager = FakeTurnManager.new()
	var cylinderManager = FakeCylinderManager.new()
	var damageNumbers = []
	func _init():
		actors = {}
		damageNumbers = []
	func getActor(actorName):
		return actors.get(actorName, null)
	func spawnDamageNumber(label, _color, _position):
		damageNumbers.append(str(label))


func _init() -> void:
	call_deferred("_run")


func makeManager() -> Dictionary:
	var fake = FakeShootout.new()
	root.add_child(fake)
	var manager = EffectManagerScript.new()
	manager.init(fake)
	for actorName in ["Tank", "Weak", "Rat"]:
		var actor = FakeActor.new()
		actor.name = actorName
		actor.actorName = actorName
		# Default Dictionary members are shared between class instances; duplicate first.
		actor.stats = actor.stats.duplicate(true)
		fake.actors[actorName] = actor
	return { "fake": fake, "manager": manager }


func _run() -> void:
	print("--- Bleed: highest ticks, stored stacks take over ---")
	var ctx = makeManager()
	var fake = ctx.fake
	var manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "bleed", "amount": 2 }, "Rat")
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "bleed", "amount": 5 }, "Rat")
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "bleed", "amount": 3 }, "Rat")
	manager.onTurnStart("Weak")
	_check(fake.actors["Weak"].hp == 25, "only the highest bleed ticks (5), got %d damage" % (30 - fake.actors["Weak"].hp))
	manager.cleanse("Weak", "bleed", 1)
	manager.onTurnStart("Weak")
	_check(fake.actors["Weak"].hp == 22, "after cleansing the highest, the next stack ticks (3), got %d" % (25 - fake.actors["Weak"].hp))
	manager.cleanse("Weak", "bleed", 2)
	manager.onTurnStart("Weak")
	_check(fake.actors["Weak"].hp == 22, "cleansed bleed stops ticking")

	print("\n--- Bleed resistance ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	fake.actors["Weak"].stats.resistances.bleed = 0.5
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "bleed", "amount": 4 }, "Rat")
	manager.onTurnStart("Weak")
	_check(fake.actors["Weak"].hp == 28, "50%% bleed resistance halves the tick (4 -> 2)")

	print("\n--- Poison: stacks tick per Round and wear off ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "poison", "amount": 3 }, "Rat")
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "poison", "amount": 2 }, "Rat")
	manager.onRoundStart()
	_check(fake.actors["Weak"].hp == 25, "both poison stacks tick at round start (5), got %d" % (30 - fake.actors["Weak"].hp))
	manager.onRoundEnd()
	manager.onRoundStart()
	_check(fake.actors["Weak"].hp == 23, "after 35%% wear-off the stacks tick 1 + 1 = 2, got %d" % (25 - fake.actors["Weak"].hp))
	manager.onRoundEnd()
	manager.onRoundStart()
	_check(fake.actors["Weak"].hp == 23, "stacks below 1 are dropped and stop ticking")

	print("\n--- Poison duration ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "poison", "amount": 3, "rounds": 1 }, "Rat")
	manager.onRoundStart()
	_check(fake.actors["Weak"].hp == 27, "timed poison ticks")
	manager.onRoundEnd()
	_check(manager.getEffects("Weak", "poison").is_empty(), "poison with rounds: 1 expires at round end")

	print("\n--- Mark: primes one Round, bonus damage consumes it ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "mark", "extraDamage": 4, "effects": [{ "op": "apply_effect", "effect": "bleed", "amount": 2 }] }, "Rat")
	_check(manager.applyIncomingModifiers(fake.actors["Weak"], 10.0, "lead") == 10.0, "priming mark does not trigger")
	manager.onRoundEnd()
	_check(manager.applyIncomingModifiers(fake.actors["Weak"], 10.0, "lead") == 14.0, "active mark adds its bonus damage")
	_check(manager.getEffects("Weak", "bleed").size() == 1, "mark applies its follow-up effects")
	_check(manager.getEffects("Weak", "mark").is_empty(), "triggering consumes the mark")
	_check(manager.applyIncomingModifiers(fake.actors["Weak"], 10.0, "lead") == 10.0, "consumed mark does not trigger again")

	print("\n--- Mark expiry ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "mark", "extraDamage": 4, "rounds": 1 }, "Rat")
	manager.onRoundEnd()
	_check(manager.getEffects("Weak", "mark").is_empty(), "untriggered mark expires after its rounds")
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "mark", "extraDamage": 4 }, "Rat")
	manager.cleanse("Weak", "mark", 1)
	_check(manager.getEffects("Weak", "mark").is_empty(), "marks can be cleansed")

	print("\n--- Damage type mark ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "damage_type_mark", "damageType": "lead", "extraDamage": 2 }, "Rat")
	_check(manager.applyIncomingModifiers(fake.actors["Weak"], 10.0, "lead") == 12.0, "matching damage type gets the bonus")
	_check(manager.applyIncomingModifiers(fake.actors["Weak"], 10.0, "explosive") == 10.0, "other damage types are unaffected")
	manager.onRoundEnd()
	_check(manager.getEffects("Weak", "damage_type_mark").is_empty(), "damage type marks last one Round")

	print("\n--- Piercing caps at the blocked amount ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Tank", { "op": "apply_effect", "effect": "piercing", "damageType": "style", "amount": 10, "turns": 1 }, "Tank")
	_check(manager.applyOutgoingModifiers(fake.actors["Tank"], 6.0, 4.0) == 10.0, "piercing reclaims only the blocked amount (4), got %f" % manager.applyOutgoingModifiers(fake.actors["Tank"], 6.0, 4.0))
	_check(manager.applyOutgoingModifiers(fake.actors["Tank"], 6.0, 0.0) == 6.0, "nothing blocked, nothing pierced")
	manager.applyEffect("Tank", { "op": "apply_effect", "effect": "decrease", "amount": 2, "turns": 2 }, "Rat")
	_check(manager.applyOutgoingModifiers(fake.actors["Tank"], 6.0, 0.0) == 4.0, "damage decrease subtracts flat")
	manager.onTurnEnd("Tank")
	_check(manager.getEffects("Tank", "piercing").is_empty(), "piercing expires after its turns")
	_check(manager.getEffects("Tank", "decrease").size() == 1, "decrease still has turns left")
	manager.onTurnEnd("Tank")
	_check(manager.getEffects("Tank", "decrease").is_empty(), "decrease expires too")

	print("\n--- Taunt redirect ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Tank", { "op": "apply_effect", "effect": "taunt", "positions": [2], "rounds": 2 }, "Tank")
	_check(manager.redirectTaunt("enemy team", "Weak") == "Tank", "attack on a taunted position redirects to the caster")
	_check(manager.redirectTaunt("enemy team", "Tank") == "", "the caster is not redirected to themselves")
	_check(manager.redirectTaunt("player team", "Weak") == "", "friendly attacks are not redirected")
	_check(manager.redirectTaunt("enemy team", "Rat") == "", "attacks outside protected positions are not redirected")
	manager.onRoundEnd()
	manager.onRoundEnd()
	_check(manager.redirectTaunt("enemy team", "Weak") == "", "taunt expires after its Rounds")
	manager.applyEffect("Tank", { "op": "apply_effect", "effect": "taunt", "rounds": 2 }, "Tank")
	_check(manager.redirectTaunt("enemy team", "Weak") == "Tank", "taunt without positions protects current ally positions")

	print("\n--- Silence ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "silence", "turns": 2 }, "Rat")
	_check(manager.isSilenced("Weak"), "silenced actor is detected")
	_check(!manager.isSilenced("Tank"), "other actors are unaffected")
	manager.onTurnEnd("Weak")
	_check(manager.isSilenced("Weak"), "silence still active after one turn")
	manager.onTurnEnd("Weak")
	_check(!manager.isSilenced("Weak"), "silence expires after its turns")

	print("\n--- Cylinder effect delegates to the cylinder manager ---")
	manager.applyEffect("Weak", { "op": "modify_cylinder", "chambers": [1], "amount": -1 }, "Rat")
	_check(fake.cylinderManager.applied.size() == 1 and fake.cylinderManager.applied[0].modifier.amount == -1, "modify_cylinder delegates")
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "cylinder", "chambers": "all", "amount": 1 }, "Rat")
	_check(fake.cylinderManager.applied.size() == 2, "apply_effect cylinder delegates too")

	print("\n--- Death cleanup ---")
	ctx = makeManager()
	fake = ctx.fake
	manager = ctx.manager
	manager.applyEffect("Weak", { "op": "apply_effect", "effect": "mark", "extraDamage": 4 }, "Rat")
	manager.applyEffect("Tank", { "op": "apply_effect", "effect": "taunt", "positions": [2], "rounds": 3 }, "Tank")
	manager.unregisterActor("Rat")
	_check(manager.getEffects("Weak", "mark").is_empty(), "marks sourced by the dead actor are removed")
	manager.unregisterActor("Tank")
	_check(manager.redirectTaunt("enemy team", "Weak") == "", "taunts whose caster died are removed")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
