extends Node
class_name SceneManager

## Base scene of the game. Loads and swaps all gameplay scenes, with a
## built-in fade transition and a loading screen for scenes that take time
## to load.

signal scene_change_started(sceneKey)
signal scene_changed(sceneKey)

## Logical scene keys mapped to scene paths. Location paths are formatted
## with the "location" context value (see _resolveScenePath).
const SCENES := {
	"main_menu": "res://UI/Main Menu/MainMenu.tscn",
	"overworld": "res://Overworld/Overworld.tscn",
	"cutscene": "res://Cutscenes/Cutscene.tscn",
	"shootout": "res://Shootout/Shootout.tscn",
	# Generic location loader; reads Locations.currentLocation / currentQuest.
	"location": "res://Location/Locations/Location.tscn",
	# Pregenerated location loaded directly from its scene.
	"pregenerated_location": "res://Location/Locations/{location}/{location}.tscn",
	# WFC-generated location; the file name strips whitespace.
	"wfc_location": "res://Location/Location Generation/{location}/{file}.tscn",
}

## Scene loaded on game start.
@export var initialScene := "main_menu"
## Duration of the fade out / fade in, in seconds.
@export var fadeDuration := 0.3
## How long a load may take before the loading screen is shown, in seconds.
@export var loadingScreenDelay := 0.2

var currentSceneKey := ""
var transitioning := false

@onready var currentSceneContainer: Node = $CurrentScene
@onready var fadeRect: ColorRect = $TransitionLayer/FadeRect
@onready var loadingScreen: Control = $TransitionLayer/LoadingScreen


func _ready() -> void:
	# Start from a black screen so the initial scene fades in.
	fadeRect.modulate.a = 1.0
	if initialScene != "":
		change_scene(initialScene)


## Returns the currently active gameplay scene.
func get_current_scene() -> Node:
	if currentSceneContainer.get_child_count() == 0:
		return null
	return currentSceneContainer.get_child(0)


## Switches to a scene from the SCENES registry. Optional context values
## (e.g. { "location": "Clearwater Grove" }) are applied to globals and to
## the new scene's init() method, if it has one.
func change_scene(sceneKey: String, context := {}) -> void:
	if transitioning:
		push_warning("SceneManager: change to '{key}' ignored; a transition is already in progress.".format({ "key": sceneKey }))
		return
	if !SCENES.has(sceneKey):
		push_error("SceneManager: unknown scene key '{key}'.".format({ "key": sceneKey }))
		return
	change_scene_to_path(_resolveScenePath(sceneKey, context), context, sceneKey)


## Switches to a scene by resource path, for scenes not in the registry.
func change_scene_to_path(scenePath: String, context := {}, sceneKey := "") -> void:
	if transitioning:
		push_warning("SceneManager: change to '{path}' ignored; a transition is already in progress.".format({ "path": scenePath }))
		return
	transitioning = true
	scene_change_started.emit(sceneKey)
	_swapScene(scenePath, context, sceneKey)


func _resolveScenePath(sceneKey: String, context: Dictionary) -> String:
	var scenePath: String = SCENES[sceneKey]
	if sceneKey == "pregenerated_location":
		scenePath = scenePath.format({ "location": context.get("location", Locations.currentLocation) })
	elif sceneKey == "wfc_location":
		var locationName: String = context.get("location", Locations.currentLocation)
		scenePath = scenePath.format({ "location": locationName, "file": locationName.replace(" ", "") })
	return scenePath


func _swapScene(scenePath: String, context: Dictionary, sceneKey: String) -> void:
	# Block input and fade out while the load starts on a background thread.
	fadeRect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fadeOut := create_tween()
	fadeOut.tween_property(fadeRect, "modulate:a", 1.0, fadeDuration)
	var requestError := ResourceLoader.load_threaded_request(scenePath)
	await fadeOut.finished
	if requestError != OK:
		push_error("SceneManager: could not start loading '{path}' (error {error}).".format({ "path": scenePath, "error": requestError }))
		await _abortTransition()
		return

	# Poll the load; show the loading screen only if it takes a while.
	var previousMsec := Time.get_ticks_msec()
	var elapsed := 0.0
	var status := ResourceLoader.load_threaded_get_status(scenePath)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		elapsed += float(now - previousMsec) / 1000.0
		previousMsec = now
		if elapsed >= loadingScreenDelay:
			loadingScreen.show()
		status = ResourceLoader.load_threaded_get_status(scenePath)
	loadingScreen.hide()
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("SceneManager: failed to load '{path}'.".format({ "path": scenePath }))
		await _abortTransition()
		return

	var newScene: Node = ResourceLoader.load_threaded_get(scenePath).instantiate()
	var oldScene := get_current_scene()
	currentSceneContainer.add_child(newScene)
	if oldScene != null:
		oldScene.queue_free()
	_applyContext(newScene, context)
	# Scene music starts while the new scene fades in. The overworld, shootouts
	# and cutscenes drive their own music (see Globals/MusicPlayer.gd).
	MusicPlayer.on_scene_changed(sceneKey)
	currentSceneKey = sceneKey


	await _fadeIn()
	transitioning = false
	scene_changed.emit(sceneKey)


func _applyContext(newScene: Node, context: Dictionary) -> void:
	if context.has("location"):
		Locations.currentLocation = context["location"]
	# Scenes can implement initScene(context) to receive the context.
	if newScene.has_method("initScene"):
		newScene.initScene(context)



func _fadeIn() -> void:
	var fadeIn := create_tween()
	fadeIn.tween_property(fadeRect, "modulate:a", 0.0, fadeDuration)
	await fadeIn.finished
	fadeRect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _abortTransition() -> void:
	loadingScreen.hide()
	await _fadeIn()
	transitioning = false
