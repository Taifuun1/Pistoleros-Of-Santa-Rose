extends Node

## Automated test for the Robbing minigame.
## Simulates clicks on robbers and collectibles and verifies scoring,
## despawning and minigame end behavior. Quits with exit code 0 on success.

var robbing: TextureRect
var testsPassed = 0
var testsFailed = 0
var logLines: Array = []

func _ready() -> void:
	print("--- RobbingTest started ---")
	robbing = load("res://Minigames/Gold Rush/Robbing.tscn").instantiate()
	add_child(robbing)
	runTests()

func runTests() -> void:
	var pointsBefore: int = Locations.minigamePoints["Robbing"]

	# Wait for the first pack to spawn
	await get_tree().create_timer(robbing.spawnInterval + 0.3).timeout
	assert_true(robbing.activeRobbers.size() > 0, "Robbers spawn")
	if robbing.activeRobbers.is_empty():
		finish()
		return

	# Clicking a robber awards points, frees it and spawns collectibles
	var robber: AnimatedSprite2D = robbing.activeRobbers[0]
	var scoreBefore: int = robbing.score
	robbing._gui_input(makeClickEvent(robber.position))
	assert_true(robbing.score == scoreBefore + robbing.POINTS_PER_ROBBER, "Clicking a robber awards 10 points")
	assert_true(robber.is_queued_for_deletion(), "Caught robber is freed")
	assert_true(not robbing.activeRobbers.has(robber), "Caught robber is removed from activeRobbers")

	# Collectibles become clickable once their pop-in animation finishes
	await get_tree().create_timer(0.3).timeout
	var collectible = findCollectible()
	assert_true(collectible != null, "Catching a robber spawns collectibles")
	if collectible != null:
		assert_true(collectible.mouse_filter == Control.MOUSE_FILTER_PASS, "Collectible is clickable after pop-in animation")
		assert_true(collectible.value > 0, "Robbing collectible has a point value")

		var collectibleScoreBefore: int = robbing.score
		var collectibleValue: int = collectible.value
		collectible.collect()
		assert_true(robbing.score == collectibleScoreBefore + collectibleValue, "Collecting awards the collectible's value")
		collectible.collect()
		assert_true(robbing.score == collectibleScoreBefore + collectibleValue, "Double collect does not score twice")

	# Remaining robbers despawn on their own after their lifetime
	robbing.spawnTimer.stop()
	await get_tree().create_timer(robbing.objectLifetime + 0.3).timeout
	assert_true(robbing.activeRobbers.is_empty(), "Uncaught robbers despawn after their lifetime")

	# End the minigame and verify points are stored globally
	var finalScore: int = robbing.score
	robbing.time_remaining = 0.05
	await get_tree().create_timer(0.3).timeout
	assert_true(robbing.game_over, "Minigame ends when time runs out")
	await get_tree().create_timer(2.3).timeout
	assert_true(Locations.minigamePoints["Robbing"] == pointsBefore + finalScore, "Points are stored in Locations.minigamePoints")
	assert_true(not is_instance_valid(robbing), "Minigame scene is freed after ending")

	finish()

func findCollectible() -> TextureRect:
	for child in robbing.get_children():
		if child is TextureRect and child.has_method("collect"):
			return child
	return null

func makeClickEvent(pos: Vector2) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	return event

func assert_true(condition: bool, testName: String) -> void:
	if condition:
		testsPassed += 1
		print("PASS: ", testName)
		logLines.append("PASS: " + testName)
	else:
		testsFailed += 1
		printerr("FAIL: ", testName)
		logLines.append("FAIL: " + testName)

func finish() -> void:
	var summary = "--- RobbingTest finished: %d passed, %d failed ---" % [testsPassed, testsFailed]
	print(summary)
	logLines.append(summary)
	var file = FileAccess.open("res://Minigames/Gold Rush/Test/robbing_test_result.txt", FileAccess.WRITE)
	if file != null:
		for line in logLines:
			file.store_line(line)
		file.close()
	get_tree().quit(1 if testsFailed > 0 else 0)
