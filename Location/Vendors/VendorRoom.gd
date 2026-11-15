extends Node2D

## Generic vendor room shell (Docs/System Design/Location Vendors
## Implementation.md, patch 3). It owns the persistent player/director/exit and
## loads the authored interior from VendorCatalog for the requested vendorId.
## A failed interior load leaves a readable fallback and the exit usable.

var vendorId := ""
var roomReady := false
var loadError := ""

var _initSceneCalled := false

@onready var roomRoot: Node2D = $Room
@onready var playerActor: Node2D = $Entities/Actors/PlayerActor
@onready var fallbackLabel: Label = get_node_or_null("Fallback")


func _ready() -> void:
	if fallbackLabel != null:
		fallbackLabel.visible = false
	# SceneManager calls initScene() in this same frame; a direct scene run (F6)
	# never does, so the deferred check reports that instead of showing a room
	# with no way back.
	_verifyInitialized.call_deferred()


func _verifyInitialized() -> void:
	if !_initSceneCalled:
		_showUnavailable("Enter this vendor from a Location; a direct scene run cannot return.")


func initScene(context: Dictionary) -> void:
	_initSceneCalled = true
	vendorId = str(context.get("vendorId", ""))
	var vendor = _vendorDefinition(vendorId)
	if vendor.is_empty():
		_showUnavailable("Vendor room unavailable.")
		return
	var roomScenePath = str(vendor.get("roomScene", ""))
	if roomScenePath == "" or !ResourceLoader.exists(roomScenePath):
		_showUnavailable("Vendor room unavailable.")
		return
	var roomScene := load(roomScenePath) as PackedScene
	if roomScene == null:
		_showUnavailable("Vendor room unavailable.")
		return
	var interior = roomScene.instantiate()
	roomRoot.add_child(interior)
	var spawn = interior.get_node_or_null("PlayerSpawn")
	if spawn != null and playerActor != null:
		playerActor.global_position = spawn.global_position
	roomReady = true


func _vendorDefinition(id: String) -> Dictionary:
	if id == "" or !is_inside_tree():
		return {}
	var vendors = get_tree().root.get_node_or_null("Vendors")
	if vendors == null or !vendors.has_method("getVendorDefinition"):
		return {}
	return vendors.getVendorDefinition(id)


func _showUnavailable(message: String) -> void:
	roomReady = false
	loadError = message
	if fallbackLabel != null:
		fallbackLabel.visible = true
		fallbackLabel.text = message
