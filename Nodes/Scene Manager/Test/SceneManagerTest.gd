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
	print("SceneManagerTest: {passed} passed, {failed} failed".format({ "passed": testsPassed, "failed": testsFailed }))
	get_tree().quit()


func runTests() -> void:
	await testChangeScene()
	await testUnknownSceneKey()
	await testTransitionGuard()
	await testFadeStateAfterTransition()


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
