extends Node

## Scene-run end-to-end check for capacity overflow acknowledgment (Docs/System
## Design/Journal/Inventory and Equipment.md, patch 2). Uses the real Party
## autoload, but isolated fake UI/turn/Rodeo/loot managers so the test never
## starts a live shootout. Run as TestShootoutLoot.tscn.

const ShootoutScript = preload("res://Shootout/Shootout.gd")

var failures := 0


class FakeUI:
	extends Node

	signal endScreenContinuePressed

	var playerHasControl := true
	var shownResults := {}
	var hideCount := 0

	func showEndScreen(results: Dictionary) -> void:
		shownResults = results.duplicate(true)

	func hideEndScreen() -> void:
		hideCount += 1

	func acknowledge() -> void:
		endScreenContinuePressed.emit()


func _ready() -> void:
	await _run()
	get_tree().quit(failures)


func _run() -> void:
	var party = get_node("/root/Party")
	party.inventory = []
	party.money = 0
	party._nextInstanceNumber = 1
	for index in 23:
		party.inventory.append({
			"instanceId": "full_%d" % index,
			"definitionId": "paregoric",
			"itemType": "consumable",
			"quantity": 5,
		})
	party.inventory.append({
		"instanceId": "full_last",
		"definitionId": "paregoric",
		"itemType": "consumable",
		"quantity": 4,
	})

	var shootout = ShootoutScript.new()
	var ui = FakeUI.new()
	shootout.ui = ui
	ui.endScreenContinuePressed.connect(shootout._on_end_screen_continue_pressed)

	var endSignals := []
	shootout.shootoutEnded.connect(func(winningSide, results): endSignals.append([winningSide, results]))

	shootout.presentFightResults({
		"winningSide": Shootout.TEAM_PLAYER,
		"fled": false,
		"outcome": "victory",
		"party": {},
		"rodeoLoot": {},
		"loot": {
			"money": 4,
			"items": [{ "definitionId": "paregoric", "itemType": "consumable", "quantity": 2 }],
		},
	})

	_check(endSignals.is_empty(), "shootoutEnded does not fire before acknowledgment")
	_check(ui.shownResults.has("lootResult"), "end screen receives the loot application result")
	var lootResult = ui.shownResults.lootResult
	_check(lootResult.accepted.size() == 1 and lootResult.accepted[0].quantity == 1, "one unit fits the partial stack")
	_check(lootResult.overflow.size() == 1 and lootResult.overflow[0].quantity == 1, "remaining unit is reported as overflow")
	_check(lootResult.overflow[0].name == "Paregoric", "overflow keeps a display name")
	_check(lootResult.money == 4 and party.money == 4, "money is applied once")
	_check(party.inventory.size() == 24, "inventory remains at capacity")

	ui.acknowledge()
	_check(endSignals.size() == 1, "acknowledgment emits the end signal once")
	_check(ui.hideCount == 1, "acknowledgment hides the result screen")
	var emittedResults = endSignals[0][1]
	_check(emittedResults.lootResult.overflow.size() == 1, "emitted result retains overflow details")
	ui.acknowledge()
	_check(endSignals.size() == 1, "repeated acknowledgment cannot emit again")

	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
	ui.free()
	shootout.free()

	if failures == 0:
		print("TestShootoutLoot: ALL CHECKS PASSED")
	else:
		printerr("TestShootoutLoot: %d CHECK(S) FAILED" % failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
