extends Node

## Scene-run validation for Overworld event cadence, canonical Zone pools and
## explicit outcome dispatch (Docs/System Design/First Steps Implementation
## Plan.md, commit 6). Requires the project autoloads (Overworld, Locations,
## OverworldEvents). Run as TestOverworldEvents.tscn.

const ResolverScript = preload("res://Overworld/OverworldEventOutcomeResolver.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const EventsScriptPath := "res://Globals/OverworldEvents.gd"
const GENERIC_EVENT_FILE := "res://Data/Events/GenericEvents.gd"
## Hard bound for the cadence search: ~0.15% per tick means a real trigger lands
## long before this, so reaching the bound is a failure rather than a bad seed.
const CADENCE_TICK_BOUND := 50000
## Representative chunk per canonical Zone (matches the ZoneData bands).
const ZONE_CHUNKS := {
	"grassy_plains": Vector2i(0, 0),
	"whispering_pines_reach": Vector2i(2, 0),
	"hilly_mining": Vector2i(4, 0),
	"snowy_mountain": Vector2i(6, 0),
	"canyon": Vector2i(8, 0),
	"ghost_town": Vector2i(10, 1),
	"desert_prairie": Vector2i(10, 4),
	"swamp": Vector2i(10, 12),
}


## Minimal Overworld stand-in so cadence and Zone resolution never depend on a
## live Overworld scene.
class FakeOverworld:
	extends Node

	var chunk := Vector2i(8, 12)

	func _init() -> void:
		var actors := Node.new()
		actors.name = "Actors"
		add_child(actors)
		var player := Node2D.new()
		player.name = "PlayerOverworldActor"
		actors.add_child(player)

	func local_to_map(_position: Vector2) -> Vector2i:
		return chunk


var failures := 0
var _fake = null


func _ready() -> void:
	_fake = FakeOverworld.new()
	add_child(_fake)
	OverworldEvents.overworldProvider = _fake
	await _run()
	_cleanup()
	await get_tree().process_frame
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _run() -> void:
	_testCadenceWithInjectedRng()
	_testZonePoolMapping()
	_testEnabledOutcomes()
	_testUnavailableOutcomes()


func _testCadenceWithInjectedRng() -> void:
	print("--- Event cadence with an injected RNG ---")
	var triggered := []
	var handle := func(eventId: String, _data: Dictionary): triggered.append(eventId)
	OverworldEvents.event_triggered.connect(handle)

	var firstTick := _firstTriggerTick(4242)
	_check(firstTick > 0, "a reachable event fires within the cadence bound (tick %d)" % firstTick)
	_check(triggered.size() == 1, "exactly one event fires before the popup closes (%s)" % [triggered])
	_check(OverworldEvents.event_active, "a triggered event marks itself active")
	_check(OverworldEvents.distance_since_last_event == 0.0, "the trigger resets the distance counter")

	# An active event blocks every new roll until the popup closes.
	OverworldEvents.add_distance(500.0)
	_check(OverworldEvents.distance_since_last_event == 0.0 and OverworldEvents.event_active, "an active event blocks new triggers")
	OverworldEvents.on_event_closed()
	_check(!OverworldEvents.event_active, "closing the event releases the cadence lock")

	var secondTick := _firstTriggerTick(4242)
	_check(firstTick == secondTick, "the same injected seed fires on the same tick (%d vs %d)" % [firstTick, secondTick])
	_check(triggered.size() == 2, "each fresh cadence run fires exactly once")

	# Sub-minimum steps accumulate without consuming RNG.
	OverworldEvents.resetEventState()
	OverworldEvents.rng = _seededRng(7)
	OverworldEvents.add_distance(0.4)
	_check(OverworldEvents.distance_since_last_event == 0.4 and !OverworldEvents.event_active, "a sub-minimum step accumulates without rolling")
	OverworldEvents.event_triggered.disconnect(handle)


func _firstTriggerTick(value: int) -> int:
	OverworldEvents.resetEventState()
	OverworldEvents.rng = _seededRng(value)
	for tick in range(1, CADENCE_TICK_BOUND + 1):
		OverworldEvents.add_distance(1.0)
		if OverworldEvents.event_active:
			return tick
	return -1


func _seededRng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _testZonePoolMapping() -> void:
	print("\n--- Canonical Zone pools map exactly ---")
	var catalog = ZoneCatalogScript.new()
	var zoneFiles: Dictionary = _zoneEventFiles()
	var generic := _loadEvents(GENERIC_EVENT_FILE)
	var authoredByZone := {}
	for zoneId in zoneFiles:
		authoredByZone[zoneId] = _loadEvents(zoneFiles[zoneId]).keys()
	_check(catalog.zoneIds().size() == 8, "the catalog still declares eight Zones")
	for zoneId in catalog.zoneIds():
		var pool: Dictionary = OverworldEvents.get_event_pool_for_zone(zoneId)
		for genericId in generic:
			_check(pool.has(genericId), "Zone '%s' merges generic event '%s'" % [zoneId, genericId])
		if zoneFiles.has(zoneId):
			for eventId in authoredByZone[zoneId]:
				_check(pool.has(eventId), "Zone '%s' includes its authored event '%s'" % [zoneId, eventId])
	for zoneId in catalog.zoneIds():
		var pool: Dictionary = OverworldEvents.get_event_pool_for_zone(zoneId)
		for otherZone in authoredByZone:
			if otherZone == zoneId:
				continue
			for eventId in authoredByZone[otherZone]:
				_check(!pool.has(eventId), "Zone '%s' never receives '%s' from '%s'" % [zoneId, eventId, otherZone])


func _testEnabledOutcomes() -> void:
	print("\n--- Every enabled outcome executes once ---")
	var catalog = ZoneCatalogScript.new()
	var resolver = ResolverScript.new()
	var launches := []
	OverworldEvents.rng = _seededRng(99)
	OverworldEvents.resetEventState()
	OverworldEvents.encounterLauncher = func(request): launches.append(request); return true
	var enabled := 0
	for zoneId in _zoneEventFiles():
		var events := _loadEvents(_zoneEventFiles()[zoneId])
		_fake.chunk = ZONE_CHUNKS.get(zoneId, Vector2i(8, 12))
		for eventId in events:
			var eventData: Dictionary = events[eventId]
			for choice in eventData.get("choices", []):
				if !(choice is Dictionary) or !choice.has("outcome"):
					continue
				enabled += 1
				var validation: Dictionary = resolver.canResolve(choice, catalog)
				_check(validation.success, "choice '%s' in '%s' validates (%s)" % [choice.get("label", ""), eventId, validation.get("reason", "")])
				launches.clear()
				var resolution: Dictionary = OverworldEvents.resolve_event_choice(eventId, eventData, choice)
				_check(resolution.success, "choice '%s' in '%s' resolves (%s)" % [choice.get("label", ""), eventId, resolution.get("reason", "")])
				if str(validation.get("kind", "")) == "encounter":
					_check(launches.size() == 1, "one launch per enabled encounter choice")
					if launches.size() == 1:
						_check(launches[0].isValid() and launches[0].zoneId == zoneId, "the launched request keeps its canonical Zone")
						_check(launches[0].source == "overworld_event", "the launched request keeps its source")
				else:
					_check(launches.is_empty(), "a flavor-only choice launches nothing")
	_check(enabled > 0, "at least one production outcome is enabled (%d)" % enabled)
	OverworldEvents.encounterLauncher = Callable()


func _testUnavailableOutcomes() -> void:
	print("\n--- Unimplemented outcomes stay explicitly unavailable ---")
	var catalog = ZoneCatalogScript.new()
	var resolver = ResolverScript.new()
	var files := [GENERIC_EVENT_FILE]
	for zoneId in _zoneEventFiles():
		files.append(_zoneEventFiles()[zoneId])
	var legacy := 0
	for filePath in files:
		var events := _loadEvents(filePath)
		for eventId in events:
			for choice in events[eventId].get("choices", []):
				if !(choice is Dictionary) or choice.has("outcome"):
					continue
				legacy += 1
				var validation: Dictionary = resolver.canResolve(choice, catalog)
				_check(!validation.success and str(validation.get("reason", "")) == "missing_outcome", "legacy result-only choice '%s' stays unavailable" % choice.get("label", ""))
	_check(legacy > 0, "the legacy result-only choices are still authored and disabled (%d)" % legacy)
	for kind in ["loot", "injury", "recover", "quest", "scene", "text"]:
		_check(!resolver.canResolve({ "outcome": { "kind": kind } }, catalog).success, "unimplemented outcome kind '%s' is unavailable" % kind)
	_check(!resolver.canResolve({}, catalog).success, "a choice without an outcome is unavailable")
	_check(resolver.canResolve({ "outcome": { "kind": "none" } }, catalog).success, "the explicit flavor outcome stays available")

	# The popup must route through the shared dispatcher, never an actor no-op.
	var popupSource := FileAccess.get_file_as_string("res://UI/OverworldEvent/OverworldEventPopup.gd")
	_check(popupSource.contains("can_resolve_choice") and popupSource.contains("resolve_event_choice"), "the popup routes choices through the shared dispatcher")
	_check(popupSource.contains("on_event_closed"), "the popup releases the cadence lock when it closes")


func _zoneEventFiles() -> Dictionary:
	return load(EventsScriptPath).ZONE_EVENT_FILES


func _loadEvents(path: String) -> Dictionary:
	var script = load(path)
	if script == null:
		return {}
	var holder = script.new()
	if holder == null:
		return {}
	var events = holder.get("events") if ("events" in holder) else null
	if holder is Node:
		holder.free()
	return events.duplicate(true) if events is Dictionary else {}


func _cleanup() -> void:
	OverworldEvents.encounterLauncher = Callable()
	OverworldEvents.overworldProvider = null
	OverworldEvents.resetEventState()
	if _fake != null and is_instance_valid(_fake):
		_fake.queue_free()
	_fake = null
	if Overworld._coordinates != null:
		Overworld._coordinates.dispose()
		Overworld._coordinates = null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
