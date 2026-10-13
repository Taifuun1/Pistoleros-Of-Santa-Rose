extends SceneTree

## Headless validation for the Shootout UI building blocks (Docs/System Design/Shootout/Shootout UI.md).
## Run with: godot --headless --script res://Tests/TestShootoutUI.gd

const CylinderRowScript = preload("res://Shootout/UI/CylinderRow.gd")
const TurnOrderStripScript = preload("res://Shootout/UI/TurnOrderStrip.gd")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")

var failures = 0


class FakeShootout:
	extends Node2D
	var actors = {}
	var turnManager = null
	func getActor(actorName):
		return actors.get(actorName, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Cylinder pips ---")
	var row = CylinderRowScript.new()
	root.add_child(row)
	row.setCylinder([2, 3, "reload", 0], 2)
	_check(row.get_child_count() == 4, "one pip per chamber, got %d" % row.get_child_count())
	_check(row.get_child(0).text == "H", "Hit pip, got %s" % row.get_child(0).text)
	_check(row.get_child(1).text == "C", "Critical pip, got %s" % row.get_child(1).text)
	_check(row.get_child(2).text == "[R]", "current special chamber is marked, got %s" % row.get_child(2).text)
	_check(row.get_child(3).text == "M", "Miss pip, got %s" % row.get_child(3).text)
	row.setCylinder([1, 2], 0)
	_check(row.get_child_count() == 2, "rebuilding swaps pips")
	_check(row.get_child(0).text == "[G]", "current numeric chamber is marked, got %s" % row.get_child(0).text)

	print("\n--- Turn order strip ---")
	var strip = TurnOrderStripScript.new()
	root.add_child(strip)
	strip.setTurnOrder(["Walker0", "Rat0", "Rat1"])
	_check(strip.get_child_count() == 3, "one label per actor")
	_check(strip.get_child(0).text.begins_with("> "), "current actor is marked, got %s" % strip.get_child(0).text)
	_check(!strip.get_child(1).text.begins_with(">"), "later actors are not marked")
	strip.setTurnOrder(["Rat0"])
	_check(strip.get_child_count() == 1, "strip rebuilds per round order")

	print("\n--- Usability reasons for greyed-out acts ---")
	var fake = FakeShootout.new()
	root.add_child(fake)
	var turnManager = TurnManagerScript.new()
	turnManager.init(fake)
	fake.turnManager = turnManager
	var targeting = TargetingManagerScript.new()
	targeting.init(turnManager)
	turnManager.registerActor('player team', 'Mover', 1)
	var movesData = {
		"Long Shot": { "name": "Long Shot", "category": "ability", "positions": { "actorUser": [3, 4], "targets": { "columns": [1] } } },
		"Sharp": { "name": "Sharp", "category": "attack_ability", "positions": { "actorUser": [1, 2], "targets": { "columns": [1] } } },
		"Duck Down": { "name": "Duck Down", "category": "duck", "positions": { "targets": { "columns": [1] } } }
	}
	var usability = targeting.moveUsability(["Long Shot", "Sharp", "Duck Down"], "Mover", false, movesData)
	_check(usability["Long Shot"].usable == false, "out-of-column move is unusable")
	_check(usability["Long Shot"].reason != "", "unusable move has a reason")
	_check(usability["Sharp"].usable, "in-column move is usable")
	_check(usability["Duck Down"].usable, "duck is usable")
	usability = targeting.moveUsability(["Long Shot", "Sharp", "Duck Down"], "Mover", true, movesData)
	_check(!usability["Sharp"].usable and usability["Sharp"].reason == "Silenced", "silence greys out abilities with a reason")
	_check(usability["Duck Down"].usable, "silence keeps ducks usable")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
