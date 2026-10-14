extends SceneTree

## Headless validation for encounters (Docs/System Design/Shootout/Encounters.md).
## Run with: godot --headless --script res://Tests/TestEncounters.gd

const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")

const SIDES = ["player team", "enemy team"]

var failures = 0
var shootoutScript: GDScript = null


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 10
	var maxHp = 50
	var stats = { "highTailin": 5 }
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
	func _init():
		actors = {}
	func getActor(actorName):
		return actors.get(actorName, null)


func _init() -> void:
	call_deferred("_run")


func makeManager() -> Dictionary:
	var fake = FakeShootout.new()
	root.add_child(fake)
	var turnManager = TurnManagerScript.new()
	turnManager.init(fake)
	return { "fake": fake, "turnManager": turnManager }


func addActor(ctx: Dictionary, nodeName: String, baseName: String, side: String, hp := 10, maxHp := 50) -> FakeActor:
	var actor = FakeActor.new()
	actor.name = nodeName
	actor.actorName = baseName
	actor.hp = hp
	actor.maxHp = maxHp
	ctx.fake.actors[nodeName] = actor
	ctx.turnManager.registerActor(side, nodeName, 1)
	return actor


func validateEncounter(data: Dictionary, fileName: String) -> void:
	var teams = data.get("teams", data)
	for side in teams:
		_check(SIDES.has(side), "%s: unknown side '%s'" % [fileName, side])
		var columns = {}
		for actorType in teams[side]:
			for actorName in teams[side][actorType]:
				var positions = teams[side][actorType][actorName].get("positions", [])
				_check(!positions.is_empty(), "%s: %s has no positions" % [fileName, actorName])
				_check(positions.size() <= 4, "%s: %s has more than 4 copies" % [fileName, actorName])
				for position in positions:
					_check(position >= 1 and position <= 4, "%s: %s position %d out of range" % [fileName, actorName, position])
					_check(!columns.has(position), "%s: two actors on %s position %d" % [fileName, side, position])
					columns[position] = true
	# Colliding node names are silently rejected by Godot, which breaks the
	# per-actor node paths (hover outline, getActor), so the spawn plan must
	# produce unique indexed names even when both teams use the same actor.
	var seen = {}
	for actor in shootoutScript.actorSpawnPlan(teams):
		_check(!seen.has(actor.indexedName), "%s: duplicate indexed actor name %s" % [fileName, actor.indexedName])
		seen[actor.indexedName] = true


func _run() -> void:
	# Loaded at runtime: Shootout.gd references autoloads, which are not
	# registered while the --script main loop compiles its preloads.
	shootoutScript = load("res://Shootout/Shootout.gd")
	print("--- Encounter files are valid ---")
	var fileCount = 0
	for fileName in DirAccess.get_files_at("res://Data/Shootout/Encounters"):
		if !fileName.ends_with(".gd"):
			continue
		fileCount += 1
		var data = load("res://Data/Shootout/Encounters/{fileName}".format({ "fileName": fileName })).new().data
		_check(data is Dictionary and !data.is_empty(), "%s: empty encounter data" % fileName)
		validateEncounter(data, fileName)
		_check(data.has("winCondition") and data.winCondition.get("type", "rout") in ["rout", "defeat_actor", "survive_rounds", "hp_below"], "%s: bad winCondition" % fileName)
	_check(fileCount > 0, "expected at least one encounter file")

	print("\n--- Metadata and legacy defaults ---")
	var rat = load("res://Data/Shootout/Encounters/RatAmbush.gd").new().data
	_check(rat.has("name") and rat.has("kind") and rat.has("teams"), "RatAmbush carries encounter metadata")
	var legacyTeams = rat.get("teams", rat)
	_check(legacyTeams.has("player team") and legacyTeams.has("enemy team"), "teams extraction works for the new format")
	var legacy = { "player team": {}, "enemy team": {} }
	_check(legacy.get("teams", legacy) == legacy, "legacy format (teams at root) still resolves")

	print("\n--- Same actor name on both teams stays unique ---")
	var plan = shootoutScript.actorSpawnPlan({
		"player team": { "Named People": { "Walker Langley": { "positions": [1, 2] } } },
		"enemy team": { "Named People": { "Walker Langley": { "positions": [1, 2] } } }
	})
	_check(plan.size() == 4, "one plan entry per actor copy, got %d" % plan.size())
	var names = []
	for actor in plan:
		names.append(actor.indexedName)
	_check(names == ["Walker Langley0", "Walker Langley1", "Walker Langley2", "Walker Langley3"], "the index continues across teams so names never collide, got %s" % [names])

	print("\n--- Win condition: defeat_actor ---")
	var ctx = makeManager()
	var wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team")
	addActor(ctx, "Boss0", "Boss", "enemy team")
	addActor(ctx, "Minion0", "Minion", "enemy team")
	ctx.turnManager.setWinCondition({ "type": "defeat_actor", "actorName": "Boss" })
	var minion = ctx.fake.actors["Minion0"]
	minion.hp = 0
	ctx.turnManager.checkActorDead(minion)
	_check(wins.is_empty(), "killing a minion does not end a defeat_actor fight")
	var boss = ctx.fake.actors["Boss0"]
	boss.hp = 0
	ctx.turnManager.checkActorDead(boss)
	_check(wins == ["player team"], "defeating the named actor wins, got %s" % [wins])

	print("\n--- Win condition: survive_rounds ---")
	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team")
	addActor(ctx, "Enemy0", "Enemy", "enemy team")
	ctx.turnManager.setWinCondition({ "type": "survive_rounds", "rounds": 2 })
	ctx.turnManager.createTurnOrder()
	ctx.turnManager.checkBattleEnd()
	_check(wins.is_empty(), "round 1 of 2 survived")
	ctx.turnManager.turnOrder.clear()
	ctx.turnManager.createTurnOrder()
	ctx.turnManager.checkBattleEnd()
	_check(wins.is_empty(), "round 2 of 2 not over yet")
	ctx.turnManager.turnOrder.clear()
	ctx.turnManager.createTurnOrder()
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["player team"], "surviving the round count wins, got %s" % [wins])

	print("\n--- Win condition: hp_below ---")
	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team", 10, 50)
	addActor(ctx, "Enemy0", "Enemy", "enemy team", 50, 50)
	ctx.turnManager.setWinCondition({ "type": "hp_below", "target": "party", "fraction": 0.5 })
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["enemy team"], "party below the HP fraction loses, got %s" % [wins])
	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team", 50, 50)
	addActor(ctx, "Enemy0", "Enemy", "enemy team", 30, 50)
	ctx.turnManager.setWinCondition({ "type": "hp_below", "target": "enemy", "amount": 40 })
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["player team"], "enemy below the HP amount loses, got %s" % [wins])
	_check(ctx.turnManager.battleOver, "endBattle sets battleOver")

	print("\n--- Rout remains the default ---")
	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team")
	ctx.turnManager.setWinCondition({})
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["player team"], "wiping the enemy side wins by rout")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
