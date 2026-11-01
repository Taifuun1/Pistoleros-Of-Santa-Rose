extends Node2D

## Tests for the scene manager: scene switching, the transition guard,
## unknown keys, and fade/loading screen state.

var sceneManager: Node

var testsPassed := 0
var testsFailed := 0


func _ready() -> void:
	sceneManager = load("res://Nodes/Scene Manager/SceneManager.tscn").instantiate()
	sceneManager.initialScene = ""
	add_child(sceneManager)
	await runTests()

	# Release the music autoload's playbacks before quitting so the process
	# exits without audio leaks (the same shutdown the autoload runs on exit).
	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
		music.free()
	# The Overworld autoload keeps headless coordinates for the map provider;
	# release them before quitting so the test process exits cleanly.
	if Overworld._coordinates != null:
		Overworld._coordinates.dispose()
		Overworld._coordinates = null
	await get_tree().create_timer(0.8).timeout
	print("SceneManagerTest: {passed} passed, {failed} failed".format({ "passed": testsPassed, "failed": testsFailed }))
	get_tree().quit()


func runTests() -> void:
	await testChangeScene()
	await testUnknownSceneKey()
	await testTransitionGuard()
	await testFadeStateAfterTransition()
	await testOverworldPlayerProvider()


func check(condition: bool, testName: String) -> void:
	if condition:
		testsPassed += 1
		print("PASS: ", testName)
	else:
		testsFailed += 1
		print("FAIL: ", testName)


func testChangeScene() -> void:
	sceneManager.change_scene("main_menu")
	await sceneManager.scene_changed
	var currentScene = sceneManager.get_current_scene()

	check(currentScene != null and currentScene.name == "MainMenu", "change_scene loads the main menu")
	check(sceneManager.currentSceneKey == "main_menu", "current scene key is set")
	check(currentScene.get_parent() == sceneManager.currentSceneContainer, "loaded scene is a child of CurrentScene")



func testUnknownSceneKey() -> void:
	sceneManager.change_scene("does_not_exist")
	await get_tree().process_frame
	var currentScene = sceneManager.get_current_scene()

	check(currentScene != null and currentScene.name == "MainMenu", "unknown scene key keeps the current scene")
	check(!sceneManager.transitioning, "unknown scene key does not start a transition")


func testTransitionGuard() -> void:
	sceneManager.change_scene("overworld")
	# The transition starts synchronously, so this call must be ignored.
	sceneManager.change_scene("main_menu")
	await sceneManager.scene_changed
	check(sceneManager.currentSceneKey == "overworld", "change_scene during a transition is ignored")
	sceneManager.change_scene("main_menu")
	await sceneManager.scene_changed
	check(sceneManager.currentSceneKey == "main_menu", "change_scene works again after the transition")


func testFadeStateAfterTransition() -> void:
	var fadeRect: ColorRect = sceneManager.get_node("TransitionLayer/FadeRect")
	check(fadeRect.modulate.a == 0.0, "fade rect is transparent after a transition")
	check(fadeRect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fade rect ignores mouse after a transition")
	check(!sceneManager.get_node("TransitionLayer/LoadingScreen").visible, "loading screen stays hidden for a fast load")


## Live/last-known player state (Docs/System Design/Journal/Overworld Map.md,
## player position provider): the running Overworld registers the exact live
## position, and destroying it retains that exact position for the Journal map
## and re-entry seeding instead of resetting to a default spawn.
func testOverworldPlayerProvider() -> void:
	sceneManager.change_scene("overworld")
	await sceneManager.scene_changed
	# The Overworld scene initializes from its first _process frame.
	await get_tree().process_frame
	await get_tree().process_frame
	var livePosition: Dictionary = Overworld.getOverworldMapPosition()
	check(livePosition["valid"] and livePosition["is_live"], "the running Overworld provides a live player position")
	var playerActor = sceneManager.get_current_scene().get_node_or_null("Actors/PlayerOverworldActor")
	check(playerActor != null and (livePosition["world_position"] as Vector2) == playerActor.global_position, "the live position is the player actor's exact position")
	var coordinates := OverworldCoordinates.makeHeadless()
	var expectedPlacement: Vector2 = coordinates.chunkTileToWorld(Overworld.spawnChunk, Overworld.spawnTile)
	check(playerActor != null and playerActor.global_position.distance_to(expectedPlacement) < 0.001, "the player is placed through the shared chunkTileToWorld pipeline")
	coordinates.dispose()

	sceneManager.change_scene("main_menu")
	await sceneManager.scene_changed
	var lastKnownPosition: Dictionary = Overworld.getOverworldMapPosition()
	check(lastKnownPosition["valid"] and !lastKnownPosition["is_live"], "destroying the Overworld switches the provider to last-known")
	check((lastKnownPosition["world_position"] as Vector2) == (livePosition["world_position"] as Vector2), "the last-known position is the exact pre-exit position, not a default spawn")
