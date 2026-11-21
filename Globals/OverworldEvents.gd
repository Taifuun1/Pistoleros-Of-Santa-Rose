extends Node

## Overworld event cadence, canonical Zone pools and choice dispatch (Docs/System
## Design/First Steps Implementation Plan.md, commit 2). Events resolve through
## the shared Zone catalog; no private biome rectangles exist.

signal event_triggered(event_name: String, event_data: Dictionary)
signal event_resolved(event_name: String, choice: Dictionary, resolution: Dictionary)

const ResolverScript = preload("res://Overworld/OverworldEventOutcomeResolver.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const GENERIC_EVENT_FILE := "res://Data/Events/GenericEvents.gd"
const MINIMUM_EVENT_DISTANCE: float = 1.0
const EVENT_CHANCE_PER_TICK: float = 0.15

## Explicit Zone -> event-file mapping. A Zone without an entry uses generic
## events only; it never falls back to another Zone's pool.
const ZONE_EVENT_FILES: Dictionary = {
	"kipley_wilds": "res://Data/Events/ForestEvents.gd",
	"urie_prairie": "res://Data/Events/DesertEvents.gd",
	"tillhill_marsh": "res://Data/Events/SwampEvents.gd",
	"wild_west": "res://Data/Events/WildWestEvents.gd",
}

var distance_since_last_event: float = 0.0
var event_active: bool = false

## Production RNG and injectable seams for deterministic tests.
var rng := RandomNumberGenerator.new()
var zoneCatalog = ZoneCatalogScript.new()
var encounterPools = null
## Optional test override for launching an encounter.
var encounterLauncher: Callable = Callable()
## Optional test override for resolving the running Overworld scene.
var overworldProvider: Node = null

var eventOutcomeResolver = ResolverScript.new()
var _generic_events: Dictionary = {}
var _zone_events: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	_load_generic_events()


func add_distance(delta_distance: float) -> void:
	if event_active:
		return
	distance_since_last_event += delta_distance
	if distance_since_last_event >= MINIMUM_EVENT_DISTANCE:
		if rng.randf() * 100.0 < EVENT_CHANCE_PER_TICK:
			_trigger_random_event()


func on_event_closed() -> void:
	event_active = false


func get_zone_for_chunk(chunk: Vector2i) -> String:
	return zoneCatalog.zoneForChunk(chunk)


## Generic + authored Zone events. Missing Zone files intentionally contribute
## nothing rather than another Zone's content.
func get_event_pool_for_zone(zoneId: String) -> Dictionary:
	var pool := _generic_events.duplicate(true)
	for key in _get_zone_events(zoneId):
		pool[key] = _zone_events[zoneId][key]
	return pool


func can_resolve_choice(choice: Dictionary) -> Dictionary:
	return eventOutcomeResolver.canResolve(choice, zoneCatalog)


## Resolves one popup choice through the pure outcome resolver. Production uses
## SceneManager for encounter launches; tests can inject `encounterLauncher`.
func resolve_event_choice(event_name: String, event_data: Dictionary, choice: Dictionary) -> Dictionary:
	var zoneId := get_zone_for_chunk(_current_chunk())
	var context := {
		"zoneId": zoneId,
		"zoneCatalog": zoneCatalog,
		"origin": { "sceneKey": "overworld" },
		"trailState": _locationsState(),
		"progression": {},
		"rng": rng,
		"encounterPools": _encounterPools(),
		"launchEncounter": Callable(self, "launch_encounter"),
	}
	var resolution: Dictionary = eventOutcomeResolver.resolve(event_name, event_data, choice, context)
	event_resolved.emit(event_name, choice, resolution)
	return resolution


func launch_encounter(request) -> bool:
	if encounterLauncher.is_valid():
		return bool(encounterLauncher.call(request))
	var manager := _sceneManagerNode()
	if manager == null or !manager.has_method("launchShootout"):
		push_warning("OverworldEvents: no Scene Manager to launch an encounter.")
		return false
	return bool(manager.launchShootout(request))


func resetEventState() -> void:
	distance_since_last_event = 0.0
	event_active = false


## New Game: same as resetEventState, named for the coordinator contract.
func resetForNewGame() -> void:
	resetEventState()


func _trigger_random_event() -> void:
	var current_chunk := _current_chunk()
	var zoneId := get_zone_for_chunk(current_chunk)
	var pool := get_event_pool_for_zone(zoneId)
	if pool.is_empty():
		return
	var keys := pool.keys()
	keys.sort()
	var chosen_key := str(keys[rng.randi_range(0, keys.size() - 1)])
	var chosen_event: Dictionary = pool[chosen_key]
	distance_since_last_event = 0.0
	event_active = true
	event_triggered.emit(chosen_key, chosen_event)


func _current_chunk() -> Vector2i:
	var overworld_node := _overworldNode()
	if overworld_node != null and overworld_node.has_node("Actors/PlayerOverworldActor") and overworld_node.has_method("local_to_map"):
		var player = overworld_node.get_node("Actors/PlayerOverworldActor")
		return overworld_node.local_to_map(player.position)
	return Overworld.spawnChunk


func _overworldNode() -> Node:
	if overworldProvider != null and is_instance_valid(overworldProvider):
		return overworldProvider
	var manager := _sceneManagerNode()
	if manager != null and manager.has_method("get_current_scene") and str(manager.get("currentSceneKey")) == "overworld":
		return manager.get_current_scene()
	var current := get_tree().current_scene
	if current != null and current.has_node("Actors/PlayerOverworldActor"):
		return current
	return null


func _sceneManagerNode() -> Node:
	var root := get_tree().root
	var manager = root.get_node_or_null("SceneManager")
	if manager != null:
		return manager
	var current := get_tree().current_scene
	if current != null and current.has_method("get_current_scene"):
		return current
	return null


func _locationsState() -> Dictionary:
	var locations = get_tree().root.get_node_or_null("Locations")
	if locations != null and locations.has_method("exportState"):
		return locations.exportState()
	return {}


func _encounterPools():
	if encounterPools == null:
		encounterPools = EncounterPoolDataScript.new()
		encounterPools.loadProductionPools()
	return encounterPools


func _load_generic_events() -> void:
	var script = load(GENERIC_EVENT_FILE)
	if script:
		var node = script.new()
		_generic_events = node.events
		node.free()


func _get_zone_events(zoneId: String) -> Dictionary:
	if _zone_events.has(zoneId):
		return _zone_events[zoneId]
	if !ZONE_EVENT_FILES.has(zoneId):
		_zone_events[zoneId] = {}
		return _zone_events[zoneId]
	var script = load(ZONE_EVENT_FILES[zoneId])
	if script:
		var node = script.new()
		_zone_events[zoneId] = node.events
		node.free()
	else:
		_zone_events[zoneId] = {}
	return _zone_events[zoneId]
