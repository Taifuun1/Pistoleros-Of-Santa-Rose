extends Node
class_name SceneManager

## Base scene of the game. Loads and swaps all gameplay scenes, with a
## built-in fade transition and a loading screen for scenes that take time
## to load.

signal scene_change_started(sceneKey)
signal scene_changed(sceneKey)

const EncounterRequestScript = preload("res://Shootout/EncounterRequest.gd")

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
	# Generic vendor room shell; loads the interior from VendorCatalog.
	"vendor_room": "res://Location/Vendors/VendorRoom.tscn",
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
@onready var journal: Journal = $JournalLayer/Journal
@onready var vendorMenu: Control = $VendorLayer/VendorMenu

## Per-scene Journal availability policy (Journal.md): the Overworld and
## normal Locations initially. Cutscenes, Shootouts, minigames and the main
## menu stay blocked until an explicit decision extends this list. Vendor rooms
## allow the Journal while the VendorMenu itself is closed.
@export var journalAllowedScenes: Array[String] = ["overworld", "location", "pregenerated_location", "wfc_location", "vendor_room"]

var _pauseCoordinator: ModalPauseCoordinator
## Parent Location + safe door position captured when entering a vendor room.
var _vendorReturnContext := {}
## Launch request, captured origin and one-shot result state for a Shootout.
var _shootoutContext := {}


func _ready() -> void:
	# Start from a black screen so the initial scene fades in.
	fadeRect.modulate.a = 1.0
	# The Journal is a persistent modal owned by the layer below the
	# transitions; its open/close and pause policy live here. The VendorMenu
	# shares the same pause coordinator and its own layer.
	_pauseCoordinator = ModalPauseCoordinator.new(get_tree())
	journal.pauseCoordinator = _pauseCoordinator
	vendorMenu.pauseCoordinator = _pauseCoordinator
	vendorMenu.musicProvider = get_node_or_null("/root/MusicPlayer")
	scene_change_started.connect(_on_scene_change_started)
	_syncInventoryPolicy()
	if initialScene != "":
		change_scene(initialScene)


## Returns the currently active gameplay scene.
func get_current_scene() -> Node:
	if currentSceneContainer.get_child_count() == 0:
		return null
	return currentSceneContainer.get_child(0)


## Launches one validated encounter and owns its return context. Accepts an
## EncounterRequest or the options Dictionary that builds one; invalid requests
## never transition and production never falls back to the debug encounter.
func launchShootout(requestOptions) -> bool:
	if transitioning or currentSceneKey == "shootout" or !_shootoutContext.is_empty():
		return false
	var request = requestOptions
	if !_isEncounterRequest(request):
		request = EncounterRequestScript.make(requestOptions if requestOptions is Dictionary else {}, null, Locations)
	if !request.isValid():
		push_warning("SceneManager: Shootout launch rejected (%s)." % request.reason())
		return false
	var origin := _captureShootoutOrigin()
	if !request.origin.is_empty():
		for key in request.origin:
			origin[key] = request.origin[key]
	request.origin = origin
	if !request.isValid():
		push_warning("SceneManager: Shootout origin rejected (%s)." % request.reason())
		return false
	var shootoutGlobals = get_node_or_null("/root/Shootout")
	if shootoutGlobals == null or !shootoutGlobals.has_method("setPendingRequest"):
		push_warning("SceneManager: the Shootout launcher is unavailable.")
		return false
	if !shootoutGlobals.setPendingRequest(request):
		push_warning("SceneManager: another Shootout request is already pending.")
		return false
	_shootoutContext = {
		"request": request,
		"origin": origin.duplicate(true),
		"handled": false,
		"scene": null,
	}
	change_scene("shootout")
	return true


func hasPendingShootout() -> bool:
	return !_shootoutContext.is_empty()


func _isEncounterRequest(value) -> bool:
	return value is Object and value.has_method("isValid") and value.has_method("reason") and value.has_method("toDictionary")


## Exact enough to restore the launching context. The Overworld autoload already
## reseeds spawnChunk/spawnTile from the destroyed scene's exact player position;
## Location origins keep their location value and player position.
func _captureShootoutOrigin() -> Dictionary:
	var origin := {
		"sceneKey": currentSceneKey,
		"location": _duplicateLocationValue(Locations.currentLocation),
		"trailState": Locations.exportState(),
	}
	if currentSceneKey == "overworld":
		var provider = get_node_or_null("/root/Overworld")
		if provider != null and provider.has_method("getOverworldMapPosition"):
			var positionInfo: Dictionary = provider.getOverworldMapPosition()
			if bool(positionInfo.get("valid", false)):
				origin["worldPosition"] = positionInfo.get("world_position", Vector2.ZERO)
	else:
		var player := _findScenePlayer()
		if player is Node2D:
			origin["playerPosition"] = (player as Node2D).global_position
	return origin


func _findScenePlayer() -> Node:
	var scene := get_current_scene()
	if scene == null:
		return null
	for path in ["Entities/Actors/PlayerActor", "Actors/PlayerOverworldActor"]:
		var player = scene.get_node_or_null(path)
		if player != null:
			return player
	return null


func _connectShootoutResult(scene: Node) -> void:
	if _shootoutContext.is_empty() or bool(_shootoutContext.get("handled", false)):
		return
	if !scene.has_signal("shootoutEnded"):
		return
	var resultCallable := Callable(self, "_on_shootout_ended")
	if !scene.is_connected("shootoutEnded", resultCallable):
		scene.connect("shootoutEnded", resultCallable)
	_shootoutContext["scene"] = scene


func _disconnectShootoutResult() -> void:
	var scene = _shootoutContext.get("scene", null)
	if is_instance_valid(scene) and scene.is_connected("shootoutEnded", Callable(self, "_on_shootout_ended")):
		scene.disconnect("shootoutEnded", Callable(self, "_on_shootout_ended"))


## One-shot result handoff. Party/loot results are already committed by the
## Shootout; this only clears the request and restores the launch origin.
func _on_shootout_ended(_winningSide: String, _results: Dictionary) -> void:
	if _shootoutContext.is_empty() or bool(_shootoutContext.get("handled", false)):
		return
	_shootoutContext["handled"] = true
	_disconnectShootoutResult()
	var shootoutGlobals = get_node_or_null("/root/Shootout")
	if shootoutGlobals != null and shootoutGlobals.has_method("clearPendingRequest"):
		shootoutGlobals.clearPendingRequest()
	var origin: Dictionary = _shootoutContext.get("origin", {})
	if !_restoreShootoutOrigin(origin):
		push_warning("SceneManager: could not restore the Shootout origin; staying in the current scene.")
		_shootoutContext = {}


func _restoreShootoutOrigin(origin: Dictionary) -> bool:
	if transitioning:
		return false
	var sceneKey := str(origin.get("sceneKey", ""))
	if sceneKey == "" or sceneKey == "shootout" or !SCENES.has(sceneKey):
		return false
	var context := {}
	if sceneKey == "location" or sceneKey == "pregenerated_location" or sceneKey == "wfc_location":
		var returnLocation = _duplicateLocationValue(origin.get("location", Locations.currentLocation))
		if returnLocation is Dictionary and origin.has("playerPosition"):
			returnLocation["playerPosition"] = origin["playerPosition"]
		context["location"] = returnLocation
		if origin.has("playerPosition"):
			context["playerPosition"] = origin["playerPosition"]
	# The Overworld restores from Overworld.spawnChunk/spawnTile, which its
	# _exit_tree reseeds from the exact live position before leaving.
	change_scene(sceneKey, context)
	return true



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
	_syncInventoryPolicy()
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
	# Headless test runs quit before ResourceLoader's background tasks join, so
	# they load synchronously; the game keeps the threaded path.
	var headless := DisplayServer.get_name() == "headless"
	var requestError := OK
	if !headless:
		requestError = ResourceLoader.load_threaded_request(scenePath)
	await fadeOut.finished
	var scenePacked: PackedScene = null
	if headless:
		scenePacked = load(scenePath)
		if scenePacked == null:
			requestError = ERR_CANT_OPEN
	else:
		if requestError != OK:
			push_error("SceneManager: could not start loading '{path}' (error {error}).".format({ "path": scenePath, "error": requestError }))
			await _abortTransition(sceneKey)
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
			await _abortTransition(sceneKey)
			return
		scenePacked = ResourceLoader.load_threaded_get(scenePath)

	if scenePacked == null:
		push_error("SceneManager: failed to load '{path}'.".format({ "path": scenePath }))
		await _abortTransition(sceneKey)
		return

	var newScene: Node = scenePacked.instantiate()
	if sceneKey == "shootout":
		# Connect before the scene enters the tree so combat can never emit a
		# result before the return handler exists.
		_connectShootoutResult(newScene)
	var oldScene := get_current_scene()
	currentSceneContainer.add_child(newScene)
	if oldScene != null:
		oldScene.queue_free()
	_applyContext(newScene, context)
	# Scene music starts while the new scene fades in. The overworld, shootouts
	# and cutscenes drive their own music (see Globals/MusicPlayer.gd).
	MusicPlayer.on_scene_changed(sceneKey)
	currentSceneKey = sceneKey
	# A successful transition away from a vendor room completes the return.
	if sceneKey != "vendor_room" and !_vendorReturnContext.is_empty():
		_vendorReturnContext = {}
	# A successful return from a Shootout completes its one-shot context.
	if sceneKey != "shootout" and !_shootoutContext.is_empty() and bool(_shootoutContext.get("handled", false)):
		_shootoutContext = {}


	await _fadeIn()
	transitioning = false
	_syncInventoryPolicy()
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


func _abortTransition(failedSceneKey := "") -> void:
	loadingScreen.hide()
	# A failed vendor-room entry must not leave a stale return context behind;
	# a failed return keeps the vendor room and its context intact.
	if failedSceneKey == "vendor_room":
		_vendorReturnContext = {}
	# A failed Shootout load consumes no results and leaves no stale request.
	if failedSceneKey == "shootout":
		var shootoutGlobals = get_node_or_null("/root/Shootout")
		if shootoutGlobals != null and shootoutGlobals.has_method("clearPendingRequest"):
			shootoutGlobals.clearPendingRequest()
		_shootoutContext = {}
	await _fadeIn()
	transitioning = false
	_syncInventoryPolicy()


## Domain mutation policy is separate from Journal visibility: only scenes that
## permit the Journal may equip/drop, and transitions always fail closed.
func _syncInventoryPolicy() -> void:
	var party = get_node_or_null("/root/Party")
	if party != null and party.has_method("setInventoryManagementAllowed"):
		party.setInventoryManagementAllowed(!transitioning and journalAllowedScenes.has(currentSceneKey))


func canOpenJournal() -> bool:
	return !transitioning and journalAllowedScenes.has(currentSceneKey) and !vendorMenu.isOpen


func toggleJournal() -> void:
	if vendorMenu.isOpen:
		return
	if journal.isOpen:
		journal.close()
	elif canOpenJournal():
		journal.open()


## Captures the parent Location + safe exterior position and enters a vendor
## room. Returns false without transitioning for invalid vendors, nested rooms,
## modals or blocked scenes.
func enterVendorRoom(vendorId: String, returnPosition := Vector2.ZERO) -> bool:
	if transitioning or currentSceneKey == "vendor_room":
		return false
	if !journalAllowedScenes.has(currentSceneKey) or currentSceneKey == "overworld":
		return false
	if journal.isOpen or vendorMenu.isOpen:
		return false
	var vendor = _vendorDefinition(vendorId)
	if vendor.is_empty():
		return false
	var roomScene = str(vendor.get("roomScene", ""))
	if roomScene == "" or !ResourceLoader.exists(roomScene):
		return false
	_vendorReturnContext = {
		"sceneKey": currentSceneKey,
		"location": _duplicateLocationValue(Locations.currentLocation),
		"playerPosition": returnPosition,
	}
	change_scene("vendor_room", { "vendorId": vendorId })
	return true


## Restores the captured parent Location and safe door position. The context is
## cleared only after the parent scene loads successfully.
func exitVendorRoom() -> bool:
	if transitioning or currentSceneKey != "vendor_room" or _vendorReturnContext.is_empty():
		return false
	var returnSceneKey = str(_vendorReturnContext.get("sceneKey", ""))
	if returnSceneKey == "":
		return false
	var returnPosition = _vendorReturnContext.get("playerPosition", Vector2.ZERO)
	var returnLocation = _vendorReturnContext.get("location", "")
	if returnLocation is Dictionary:
		returnLocation = returnLocation.duplicate(true)
		returnLocation["playerPosition"] = returnPosition
		Locations.currentLocation = returnLocation
		change_scene(returnSceneKey, { "location": Locations.currentLocation })
		return true
	if str(returnLocation) == "":
		return false
	Locations.currentLocation = str(returnLocation)
	change_scene(returnSceneKey, { "location": Locations.currentLocation, "playerPosition": returnPosition })
	return true


func openVendor(vendorId: String) -> bool:
	if transitioning or currentSceneKey != "vendor_room" or journal.isOpen or vendorMenu.isOpen:
		return false
	return vendorMenu.open(vendorId)


func closeVendor() -> void:
	vendorMenu.close()


func canOpenVendor() -> bool:
	return !transitioning and currentSceneKey == "vendor_room" and !journal.isOpen and !vendorMenu.isOpen


func _vendorDefinition(vendorId: String) -> Dictionary:
	var vendors = get_node_or_null("/root/Vendors")
	if vendors == null or !vendors.has_method("getVendorDefinition"):
		return {}
	return vendors.getVendorDefinition(vendorId)


func _duplicateLocationValue(value):
	return value.duplicate(true) if value is Dictionary else value


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("TOGGLE_JOURNAL"):
		if vendorMenu.isOpen:
			get_viewport().set_input_as_handled()
			return
		toggleJournal()
		get_viewport().set_input_as_handled()


func _on_scene_change_started(_sceneKey) -> void:
	# Modals are not allowed to survive a scene change.
	if vendorMenu.isOpen:
		vendorMenu.close()
	if journal.isOpen:
		journal.close()
