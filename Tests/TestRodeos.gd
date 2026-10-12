extends SceneTree

## Headless validation for the Rodeo system.
## Run with: godot --headless --script res://Tests/TestRodeos.gd

const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")

const KNOWN_TRIGGERS = ["fight_start", "fight_end", "round_start", "round_end", "turn_start", "turn_end", "always"]
const KNOWN_OPS = ["modify_stat", "move_position", "heal", "modify_loot", "apply_effect", "cleanse_effect", "modify_cylinder", "set_hit_quality_floor", "prevent_effect", "refresh_items"]

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var rodeo = null
	var hp = 10
	var maxHp = 10
	var stats = { "highTailin": 6 }


class FakeTurnManager:
	extends RefCounted
	var shootoutActors = { "player team": {}, "enemy team": {} }
	var roundNumber = 1
	func getRoundNumber() -> int:
		return roundNumber


class FakeShootout:
	extends Node
	var turnManager = FakeTurnManager.new()
	var actors = {}
	func getActor(actorName):
		return actors.get(actorName, null)
	func getPositionForColumn(_actorSide, column):
		return Vector2(column * 10, 0)
	func spawnDamageNumber(_label, _color, _position):
		pass


func _init() -> void:
	call_deferred("_run")


func makeManager(partyLevel := 1) -> RefCounted:
	var manager = RodeoManagerScript.new()
	manager.shootout = FakeShootout.new()
	manager.rodeosData = loadRodeosData()
	manager.partyLevel = partyLevel
	return manager


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


func addActor(manager, actorName: String, rodeo, column: int, side := "player team") -> FakeActor:
	var actor = FakeActor.new()
	actor.name = actorName
	actor.actorName = actorName
	actor.rodeo = rodeo
	manager.shootout.actors[actorName] = actor
	manager.shootout.turnManager.shootoutActors[side][actorName] = { "actorPosition": column }
	manager.registerActor(actor, side, column)
	return actor


func _run() -> void:
	print("--- Rodeo data files ---")
	var rodeosData = loadRodeosData()
	_check(rodeosData.size() == 6, "expected 6 rodeo data files, got %d" % rodeosData.size())
	for rodeoName in rodeosData:
		var data = rodeosData[rodeoName]
		_check(data.has("trigger") and data.trigger in KNOWN_TRIGGERS, "bad trigger: %s" % rodeoName)
		_check(data.has("effects") and data.effects is Array and !data.effects.is_empty(), "missing effects: %s" % rodeoName)
		for effect in data.get("effects", []):
			_check(effect.get("op", "") in KNOWN_OPS, "unknown op in %s: %s" % [rodeoName, effect.get("op", "")])

	print("\n--- Leaders Duck moves every other turn end ---")
	var manager = makeManager()
	var walker = addActor(manager, "Walker0", "leaders duck", 2)
	_check(manager.getRodeoDisplayName(walker) == "Leaders Duck", "rodeo display name wrong: %s" % manager.getRodeoDisplayName(walker))
	manager.trigger("turn_end", { "actor": walker })
	_check(manager.rodeos["Walker0"].column == 2, "Leaders Duck fired on first turn end")
	manager.trigger("turn_end", { "actor": walker })
	_check(manager.rodeos["Walker0"].column == 3, "Leaders Duck did not move Walker back on second turn end")
	_check(walker.position == Vector2(30, 0), "Walker node position not updated: %s" % walker.position)
	_check(manager.shootout.turnManager.shootoutActors["player team"]["Walker0"].actorPosition == 3, "turn manager position not updated")
	manager.trigger("turn_end", { "actor": walker })
	_check(manager.rodeos["Walker0"].column == 3, "Leaders Duck fired on odd turn end")

	print("\n--- unregisterActor stops the Rodeo ---")
	manager.unregisterActor("Walker0")
	manager.trigger("turn_end", { "actor": walker })
	manager.trigger("turn_end", { "actor": walker })
	_check(manager.getRodeoDisplayName(walker) == "-", "display name should be '-' after unregister")
	_check(walker.position == Vector2(30, 0), "Rodeo kept firing after unregister")

	print("\n--- Happy Shot passive modifier gated by position ---")
	manager = makeManager()
	var aiyana = addActor(manager, "Aiyana0", "happy shot", 1)
	_check(manager.getStatModifier(aiyana, "highTailin", 6) == 8, "Happy Shot should add 2 in column 1")
	_check(manager.getStatModifier(aiyana, "sixShootin", 3) == 3, "Happy Shot should not touch other stats")
	manager.unregisterActor("Aiyana0")
	aiyana.rodeo = "happy shot"
	manager.registerActor(aiyana, "player team", 2)
	_check(manager.getStatModifier(aiyana, "highTailin", 6) == 6, "Happy Shot should not apply outside column 1")

	print("\n--- Level scaling ---")
	manager = makeManager(3)
	aiyana = addActor(manager, "Aiyana0", "happy shot", 1)
	_check(manager.getStatModifier(aiyana, "highTailin", 6) == 10, "Happy Shot at level 3 should add 2 + 2*(3-1)")

	print("\n--- Camaradería buffs the ally in front ---")
	manager = makeManager()
	addActor(manager, "Manuel0", "camaradería", 2)
	var allyFront = addActor(manager, "AllyFront", null, 1)
	var allyBehind = addActor(manager, "AllyBehind", null, 3)
	manager.trigger("fight_start")
	_check(allyFront.maxHp == 12, "ally in front should gain 2 maxHp, got %d" % allyFront.maxHp)
	_check(allyBehind.maxHp == 10, "ally behind should not be buffed")
	manager.trigger("fight_end", { "winningSide": "enemy team" })
	_check(allyFront.maxHp == 10, "maxHp buff should be reverted at fight end")

	print("\n--- Adjacent ally targeting ---")
	manager = makeManager()
	addActor(manager, "Owner", null, 2)
	addActor(manager, "Front", null, 1)
	addActor(manager, "Back", null, 3)
	addActor(manager, "Far", null, 4)
	var ownerEntry = { "side": "player team", "column": 2 }
	_check(manager.resolveTargets("adjacent_allies", "Owner", ownerEntry) == ["Front", "Back"], "adjacent_allies wrong")
	_check(manager.resolveTargets("ally_in_front", "Owner", ownerEntry) == ["Front"], "ally_in_front wrong")
	_check(manager.resolveTargets("ally_behind", "Owner", ownerEntry) == ["Back"], "ally_behind wrong")
	_check(manager.resolveTargets("self", "Owner", ownerEntry) == ["Owner"], "self wrong")

	print("\n--- Backpocket Check only pays out on a won fight ---")
	manager = makeManager()
	addActor(manager, "Gwyneth0", "backpocket check", 2)
	manager.trigger("fight_end", { "winningSide": "enemy team" })
	_check(manager.lootModifiers.money == 0, "Backpocket Check paid out on a loss")
	manager.trigger("fight_end", { "winningSide": "player team" })
	_check(manager.lootModifiers.money == 10, "Backpocket Check should add 10 money, got %d" % manager.lootModifiers.money)
	var loot = manager.consumeLootModifiers()
	_check(loot.amounts.money == 10, "consumeLootModifiers should return accumulated loot")
	_check(manager.lootModifiers.money == 0, "consumeLootModifiers should reset the accumulator")

	print("\n--- Unknown rodeos and ops warn and skip ---")
	manager = makeManager()
	addActor(manager, "Nobody0", "not a rodeo", 2)
	_check(manager.rodeos.is_empty(), "unknown rodeo should not register")
	manager.rodeosData["Test Rodeo"] = {
		"name": "Test Rodeo",
		"trigger": "turn_end",
		"conditions": { "target": "self" },
		"effects": [{ "op": "bogus" }],
		"scaling": {}
	}
	var nobody = addActor(manager, "Nobody1", "test rodeo", 2)
	manager.trigger("turn_end", { "actor": nobody })
	_check(manager.rodeos.has("Nobody1"), "known rodeo with unknown op should still register")

	print("\n--- Round tracking ---")
	# The turn manager owns the round counter; the Rodeo manager only reads it.
	manager = makeManager()
	_check(manager.getRoundNumber() == 1, "rodeo round should default to the turn manager round (1)")
	manager.shootout.turnManager.roundNumber = 3
	_check(manager.getRoundNumber() == 3, "rodeo round should follow the turn manager counter")
	manager.trigger("round_end")
	_check(manager.getRoundNumber() == 3, "round_end trigger should no longer increment the round itself")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)

