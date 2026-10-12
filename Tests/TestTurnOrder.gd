extends SceneTree

## Headless validation for the turn order system (Docs/System Design/Shootout/Turns and Initiative.md).
## Run with: godot --headless --script res://Tests/TestTurnOrder.gd

const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var stats = { "highTailin": 5 }
	var hp = 10
	var maxHp = 10


class FakeRodeoManager:
	extends RefCounted
	# actorName -> initiative bonus
	var highTailinModifiers = {}
	var unregistered = []
	func getStatModifier(actor, statName, baseValue):
		if statName == "highTailin" and highTailinModifiers.has(actor.actorName):
			return baseValue + highTailinModifiers[actor.actorName]
		return baseValue
	func unregisterActor(actorName):
		unregistered.append(actorName)


class FakeShootout:
	extends Node
	var actors = {}
	var rodeoManager = FakeRodeoManager.new()
	func getActor(actorName):
		return actors.get(actorName, null)


func _init() -> void:
	call_deferred("_run")


func makeManager() -> RefCounted:
	var manager = TurnManagerScript.new()
	manager.init(FakeShootout.new())
	return manager


func addActor(manager, actorName: String, highTailin: int, side := "player team") -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.stats = { "highTailin": highTailin }
	manager.shootout.actors[actorName] = actor
	manager.registerActor(side, actorName, 1)
	return actor


func _run() -> void:
	seed(12345)

	print("--- Round and turn counters ---")
	var manager = makeManager()
	_check(manager.getRoundNumber() == 1, "round starts at 1")
	_check(manager.getTurnNumber() == 0, "turn starts at 0")
	addActor(manager, "A", 5)
	addActor(manager, "B", 5, "enemy team")
	manager.createTurnOrder()
	_check(manager.getRoundNumber() == 1, "first createTurnOrder must not increment the round")
	manager.advanceTurn()
	_check(manager.getTurnNumber() == 1, "advanceTurn increments turnNumber")
	manager.turnOrder.clear()
	manager.createTurnOrder()
	_check(manager.getRoundNumber() == 2, "rebuild increments the round")

	print("\n--- High Tailin' decides when the roll cannot bridge the gap ---")
	manager = makeManager()
	addActor(manager, "Fast", 10)
	addActor(manager, "Slow", 1)
	var consistentFirst = true
	for i in 30:
		manager.createTurnOrder()
		if manager.turnOrder[0] != "Fast":
			consistentFirst = false
			break
	_check(consistentFirst, "an actor 9 High Tailin' ahead always acts first (roll max %d)" % TurnManagerScript.RANDOM_ROLL_MAX)

	print("\n--- Even stats produce a random order ---")
	manager = makeManager()
	addActor(manager, "Tied1", 6)
	addActor(manager, "Tied2", 6)
	var orders = {}
	for i in 50:
		manager.createTurnOrder()
		orders["%s,%s" % [manager.turnOrder[0], manager.turnOrder[1]]] = true
	_check(orders.size() > 1, "equal High Tailin' should produce varying orders (got %d distinct)" % orders.size())

	print("\n--- Rodeo initiative modifiers apply ---")
	manager = makeManager()
	addActor(manager, "Base", 5)
	addActor(manager, "Buffed", 1)
	manager.shootout.rodeoManager.highTailinModifiers["Buffed"] = 100
	var buffedFirst = true
	for i in 30:
		manager.createTurnOrder()
		if manager.turnOrder[0] != "Buffed":
			buffedFirst = false
			break
	_check(buffedFirst, "modified High Tailin' feeds the initiative roll")

	print("\n--- Death removes actors from the fight ---")
	manager = makeManager()
	addActor(manager, "Player1", 5)
	addActor(manager, "Enemy1", 5, "enemy team")
	addActor(manager, "Enemy2", 5, "enemy team")
	var battleEndedCalls = []
	manager.battleEnded.connect(func(winningSide): battleEndedCalls.append(winningSide))
	manager.createTurnOrder()
	var enemy1 = manager.shootout.actors["Enemy1"]
	enemy1.hp = 0
	_check(manager.checkActorDead(enemy1), "dead actor is removed")
	_check(manager.shootout.rodeoManager.unregistered.has("Enemy1"), "dead actor's rodeo is unregistered")
	_check(!("Enemy1" in manager.turnOrder), "dead actor leaves the turn order")
	_check(battleEndedCalls.size() == 0, "battle continues while both sides have actors")
	var player1 = manager.shootout.actors["Player1"]
	player1.hp = 0
	manager.checkActorDead(player1)
	manager.checkActorDead(player1)
	_check(battleEndedCalls.size() == 1, "battleEnded emits exactly once")
	_check(battleEndedCalls[0] == "enemy team", "last side standing wins")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
