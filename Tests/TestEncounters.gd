extends SceneTree

## Headless validation for encounters (Docs/System Design/Shootout/Encounters.md).
## Run with: godot --headless --script res://Tests/TestEncounters.gd

const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const LoadoutProjectorScript = preload("res://Globals/CombatLoadoutProjector.gd")

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
	# Keep the actor in the tree so the test owns it like the real shootout does;
	# an orphan Node2D would leak its CanvasItem RID at process exit.
	ctx.fake.add_child(actor)
	ctx.fake.actors[nodeName] = actor
	ctx.turnManager.registerActor(side, nodeName, 1)
	return actor


func validateEncounter(data: Dictionary, fileName: String, movesData: Dictionary) -> void:
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
				_check(actorHasOffensiveMove(actorType, actorName, movesData), "%s: %s has no legal offensive Move" % [fileName, actorName])
				_check(actorUsesKnownMoves(actorType, actorName, movesData), "%s: %s references an unknown Move" % [fileName, actorName])
	# Colliding node names are silently rejected by Godot, which breaks the
	# per-actor node paths (hover outline, getActor), so the spawn plan must
	# produce unique indexed names even when both teams use the same actor.
	var seen = {}
	for actor in shootoutScript.actorSpawnPlan(teams):
		_check(!seen.has(actor.indexedName), "%s: duplicate indexed actor name %s" % [fileName, actor.indexedName])
		seen[actor.indexedName] = true
	validateWinCondition(data.get("winCondition", {}), teams, fileName)


## Every combat actor must have at least one legal offensive Move; a fighter
## that can only pass or reposition silently stalls the fight. Class and
## equipment grants count, because the Shootout resolves the same union.
func actorHasOffensiveMove(actorType: String, actorName: String, movesData: Dictionary) -> bool:
	var actorData = loadActorData(actorType, actorName)
	if actorData.is_empty():
		return false
	var resolved: Array = LoadoutProjectorScript.resolvedDirectMoves(actorData, loadClassData(actorData))
	return LoadoutProjectorScript.hasOffensiveMove(resolved, movesData)


## Every Move an actor names must resolve to authored Move data; a typo silently
## removes the only offensive option and stalls the fight. Class and equipment
## grants are checked by the content lint.
func actorUsesKnownMoves(actorType: String, actorName: String, movesData: Dictionary) -> bool:
	var actorData = loadActorData(actorType, actorName)
	if actorData.is_empty():
		return false
	for moveName in actorData.get("moves", []):
		if !movesData.has(str(moveName)):
			return false
	return true


## Authored class data for an actor, or {} when the actor has no class.
func loadClassData(actorData: Dictionary) -> Dictionary:
	var className = str(actorData.get("characterClass", ""))
	if className == "":
		return {}
	var path = "res://Data/Shootout/Classes/%s.gd" % className.replace(" ", "")
	if !ResourceLoader.exists(path):
		return {}
	var holder = load(path).new()
	var classData = holder.get("data") if ("data" in holder) else null
	if holder is Node:
		holder.free()
	return classData if classData is Dictionary else {}


func loadActorData(actorType: String, actorName: String) -> Dictionary:
	var path = "res://Data/Actors/{actorType}/{actorName}.gd".format({
		"actorType": actorType,
		"actorName": actorName.capitalize().replace(" ", ""),
	})
	if !ResourceLoader.exists(path):
		# Party members are starter Party data, mirrored by their actor file.
		path = "res://Data/Actors/Named People/{actorName}.gd".format({ "actorName": actorName.capitalize().replace(" ", "") })
	if !ResourceLoader.exists(path):
		return {}
	var holder = load(path).new()
	var data = holder.data if holder != null and ("data" in holder) else {}
	if holder is Node:
		holder.free()
	return data


func validateWinCondition(condition: Dictionary, teams: Dictionary, fileName: String) -> void:
	if condition.get("type", "rout") != "hp_below":
		return
	_check(str(condition.get("actorName", "")) != "", "%s: hp_below requires actorName" % fileName)
	# Side-total fields contradict a per-actor threshold; they must not coexist.
	for contradictory in ["target", "side", "sideTotal", "team"]:
		_check(!condition.has(contradictory), "%s: hp_below rejects side-total field '%s'" % [fileName, contradictory])
	_check(condition.has("fraction") != condition.has("amount"), "%s: hp_below requires exactly one of fraction/amount" % fileName)
	if condition.has("fraction"):
		var fraction = float(condition.fraction)
		_check(fraction > 0.0 and fraction <= 1.0, "%s: hp_below fraction out of range" % fileName)
	if condition.has("amount"):
		_check(int(condition.amount) > 0, "%s: hp_below amount must be positive" % fileName)
	if condition.has("stat"):
		_check(str(condition.stat) in ["hp", "maxHp"], "%s: hp_below stat must be hp or maxHp" % fileName)
	if condition.has("winner"):
		_check(SIDES.has(str(condition.winner)), "%s: hp_below winner must be a known side" % fileName)
	var actors = []
	for side in teams:
		for actorType in teams[side]:
			for actorName in teams[side][actorType]:
				actors.append(actorName)
	_check(actors.has(str(condition.get("actorName", ""))), "%s: hp_below actorName is not in the encounter" % fileName)


func loadMovesData() -> Dictionary:
	var movesData = {}
	var folder = "res://Data/Shootout/Moves"
	for fileName in DirAccess.get_files_at(folder):
		if !fileName.ends_with(".gd"):
			continue
		var holder = load("{folder}/{fileName}".format({ "folder": folder, "fileName": fileName })).new()
		if holder != null and ("data" in holder):
			var data = holder.data
			if data is Dictionary and str(data.get("name", "")) != "":
				# Duplicate Move names would silently shadow each other.
				_check(!movesData.has(data.name), "duplicate Move data.name '%s' in %s" % [data.name, fileName])
				movesData[data.name] = data
		if holder is Node:
			holder.free()
	return movesData


func _run() -> void:
	# Loaded at runtime: Shootout.gd references autoloads, which are not
	# registered while the --script main loop compiles its preloads.
	shootoutScript = load("res://Shootout/Shootout.gd")
	var movesData = loadMovesData()
	print("--- Encounter files are valid ---")
	var fileCount = 0
	# Duplicate encounter names would silently shadow each other at runtime.
	var encounterNames = {}
	for fileName in DirAccess.get_files_at("res://Data/Shootout/Encounters"):
		if !fileName.ends_with(".gd"):
			continue
		fileCount += 1
		var encounterInstance = load("res://Data/Shootout/Encounters/{fileName}".format({ "fileName": fileName })).new()
		var data = encounterInstance.data
		_check(data is Dictionary and !data.is_empty(), "%s: empty encounter data" % fileName)
		if data is Dictionary and str(data.get("name", "")) != "":
			_check(!encounterNames.has(data.name), "%s: duplicate encounter data.name '%s'" % [fileName, data.name])
			encounterNames[data.name] = true
		validateEncounter(data, fileName, movesData)
		_check(data.has("winCondition") and data.winCondition.get("type", "rout") in ["rout", "defeat_actor", "survive_rounds", "hp_below"], "%s: bad winCondition" % fileName)
		encounterInstance.free()
	_check(fileCount > 0, "expected at least one encounter file")

	print("\n--- Metadata and legacy defaults ---")
	var ratInstance = load("res://Data/Shootout/Encounters/RatAmbush.gd").new()
	var rat = ratInstance.data
	_check(rat.has("name") and rat.has("kind") and rat.has("teams"), "RatAmbush carries encounter metadata")
	var legacyTeams = rat.get("teams", rat)
	_check(legacyTeams.has("player team") and legacyTeams.has("enemy team"), "teams extraction works for the new format")
	var legacy = { "player team": {}, "enemy team": {} }
	_check(legacy.get("teams", legacy) == legacy, "legacy format (teams at root) still resolves")
	ratInstance.free()

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

	print("\n--- Win condition: hp_below per actor ---")
	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team", 50, 50)
	var hpBoss = addActor(ctx, "Boss0", "Boss", "enemy team", 30, 50)
	addActor(ctx, "Minion0", "Minion", "enemy team", 1, 50)
	ctx.turnManager.setWinCondition({ "type": "hp_below", "actorName": "Boss", "fraction": 0.5 })
	ctx.turnManager.checkBattleEnd()
	_check(wins.is_empty(), "the side total being low does not trigger a per-actor threshold")
	hpBoss.hp = 20
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["player team"], "the named boss crossing the fraction ends the fight, got %s" % [wins])

	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team", 50, 50)
	hpBoss = addActor(ctx, "Boss0", "Boss", "enemy team", 30, 50)
	ctx.turnManager.setWinCondition({ "type": "hp_below", "actorName": "Boss", "amount": 25 })
	ctx.turnManager.checkBattleEnd()
	_check(wins.is_empty(), "the boss above the absolute amount does not trigger")
	hpBoss.hp = 20
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["player team"], "the boss below the absolute amount ends the fight, got %s" % [wins])
	_check(ctx.turnManager.battleOver, "endBattle sets battleOver")

	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team", 50, 50)
	addActor(ctx, "Boss0", "Boss", "enemy team", 50, 50)
	ctx.turnManager.setWinCondition({ "type": "hp_below", "actorName": "Missing", "fraction": 0.5 })
	ctx.turnManager.checkBattleEnd()
	_check(wins.is_empty(), "an unknown hp_below actor fails closed")

	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team", 10, 50)
	addActor(ctx, "Boss0", "Boss", "enemy team", 50, 50)
	ctx.turnManager.setWinCondition({ "type": "hp_below", "actorName": "Player", "fraction": 0.5, "winner": "enemy team" })
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["enemy team"], "the optional winner overrides the default side, got %s" % [wins])

	print("\n--- Rout remains the default ---")
	ctx = makeManager()
	wins = []
	ctx.turnManager.battleEnded.connect(func(side): wins.append(side))
	addActor(ctx, "Player0", "Player", "player team")
	ctx.turnManager.setWinCondition({})
	ctx.turnManager.checkBattleEnd()
	_check(wins == ["player team"], "wiping the enemy side wins by rout")

	# Release the fake shootouts (and their actor children) before quitting so
	# the test process exits without node/RID leaks.
	for child in root.get_children():
		if child is FakeShootout:
			child.free()
	shootoutScript = null

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
