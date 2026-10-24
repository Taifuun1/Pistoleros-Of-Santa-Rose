extends Node

# Emitted when an event is ready to be shown. Carries the event name and data dict.
signal event_triggered(event_name: String, event_data: Dictionary)

# Minimum distance (in pixels) the player must travel before an event can fire.
const MINIMUM_EVENT_DISTANCE: float = 1.0

# After the minimum distance is met, chance per physics tick (0–100) that an event fires.
const EVENT_CHANCE_PER_TICK: float = 0.15

# Distance accumulated since the last event fired.
var distance_since_last_event: float = 0.0

# Whether an event popup is currently open (prevents stacking events).
var event_active: bool = false

# Biome regions defined as chunk coordinate rectangles: { "biome_name": Rect2i }
# These should be updated to match the actual map layout.
var biome_regions: Dictionary = {
	"grassland": Rect2i(0, 8, 8, 8),
	"desert":    Rect2i(8, 0, 8, 8),
	"forest":    Rect2i(0, 0, 8, 8),
	"swamp":     Rect2i(8, 8, 8, 8),
}

# Loaded event pools — populated on first use.
var _generic_events: Dictionary = {}
var _biome_events: Dictionary = {}

# Maps biome names to their data file paths.
const BIOME_EVENT_FILES: Dictionary = {
	"grassland": "res://Data/Events/GrasslandEvents.gd",
	"desert":    "res://Data/Events/DesertEvents.gd",
	"forest":    "res://Data/Events/ForestEvents.gd",
	"swamp":     "res://Data/Events/SwampEvents.gd",
}


func _ready() -> void:
	_load_generic_events()


# Called by PlayerOverworldActor every physics tick with the distance moved this frame.
func add_distance(delta_distance: float) -> void:
	if event_active:
		return

	distance_since_last_event += delta_distance

	if distance_since_last_event >= MINIMUM_EVENT_DISTANCE:
		if randf() * 100.0 < EVENT_CHANCE_PER_TICK:
			_trigger_random_event()


# Returns the biome name for the given chunk coordinate, or "" if none matches.
func get_biome_for_chunk(chunk: Vector2i) -> String:
	for biome_name in biome_regions:
		var region: Rect2i = biome_regions[biome_name]
		if region.has_point(chunk):
			return biome_name
	return ""


func _trigger_random_event() -> void:
	var current_chunk: Vector2i = Overworld.spawnChunk  # fallback
	var overworld_node = get_tree().current_scene
	if overworld_node and overworld_node.has_node("Actors/PlayerOverworldActor"):
		var player = overworld_node.get_node("Actors/PlayerOverworldActor")
		if overworld_node.has_method("local_to_map"):
			current_chunk = overworld_node.local_to_map(player.position)

	var biome = get_biome_for_chunk(current_chunk)

	# Build the combined event pool for this location.
	var pool: Dictionary = {}
	for key in _generic_events:
		pool[key] = _generic_events[key]

	if biome != "":
		var biome_pool = _get_biome_events(biome)
		for key in biome_pool:
			pool[key] = biome_pool[key]

	if pool.is_empty():
		return

	# Pick a random event from the pool.
	var keys = pool.keys()
	var chosen_key: String = keys[randi() % keys.size()]
	var chosen_event: Dictionary = pool[chosen_key]

	distance_since_last_event = 0.0
	event_active = true
	event_triggered.emit(chosen_key, chosen_event)


func _load_generic_events() -> void:
	var script = load("res://Data/Events/GenericEvents.gd")
	if script:
		var node = script.new()
		_generic_events = node.events
		node.free()


func _get_biome_events(biome: String) -> Dictionary:
	if _biome_events.has(biome):
		return _biome_events[biome]

	if not BIOME_EVENT_FILES.has(biome):
		return {}

	var script = load(BIOME_EVENT_FILES[biome])
	if script:
		var node = script.new()
		_biome_events[biome] = node.events
		node.free()
		return _biome_events[biome]

	return {}


# Called by the popup when the player has made a choice and the popup closes.
func on_event_closed() -> void:
	event_active = false
