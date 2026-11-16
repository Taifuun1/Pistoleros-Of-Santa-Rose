class_name EncounterRequest
extends RefCounted

## Validated Shootout launch request (Docs/System Design/First Steps
## Implementation Plan.md, commit 2). SceneManager creates/validates one of
## these and owns the return context; the Shootout scene consumes the pending
## request exactly once and never falls back to the debug encounter in
## production.

const FORMAT_VERSION := 1
const SOURCES := ["overworld_event", "location_ambush", "quest", "debug"]
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")

var encounterPath := ""
var zoneId := ""
var source := ""
var sourceId := ""
var origin: Dictionary = {}
var progression: Dictionary = {}
## Snapshot of Locations.exportState() captured before the transition.
var trailState: Dictionary = {}
## >= 0 makes the encounter/pool/loot RNG deterministic; -1 uses production RNG.
var seedValue := -1

var _valid := false
var _reason := ""


## Production callers may omit trailState; it is captured from the Locations
## autoload. Tests inject both providers for headless determinism.
static func make(options: Dictionary, zoneCatalog = null, locationsSource = null) -> EncounterRequest:
	var request = new()
	request._configure(options, zoneCatalog, locationsSource)
	return request


func _configure(options: Dictionary, zoneCatalog, locationsSource) -> void:
	encounterPath = str(options.get("encounterPath", options.get("encounter", ""))).strip_edges()
	zoneId = str(options.get("zoneId", options.get("zone", ""))).strip_edges()
	source = str(options.get("source", "")).strip_edges()
	sourceId = str(options.get("sourceId", options.get("result", ""))).strip_edges()
	origin = _dictionaryValue(options.get("origin", {}))
	progression = _dictionaryValue(options.get("progression", {}))
	seedValue = int(options.get("seed", -1))
	var providedTrailState = options.get("trailState", null)
	if providedTrailState is Dictionary and !providedTrailState.is_empty():
		trailState = providedTrailState.duplicate(true)
	else:
		var locations = locationsSource if locationsSource != null else _resolveLocations()
		if locations != null and locations.has_method("exportState"):
			trailState = locations.exportState()

	if zoneCatalog == null:
		zoneCatalog = ZoneCatalogScript.new()
	_valid = _validate(zoneCatalog)
	if _valid:
		_reason = ""
	else:
		_reason = _reason if _reason != "" else "invalid_request"


func _validate(zoneCatalog) -> bool:
	if encounterPath == "" or !encounterPath.begins_with("res://") or !ResourceLoader.exists(encounterPath):
		_reason = "invalid_encounter"
		return false
	var script = load(encounterPath)
	if script == null:
		_reason = "invalid_encounter"
		return false
	var holder = script.new()
	if holder == null or !("data" in holder):
		if holder != null:
			holder.free()
		_reason = "missing_encounter_data"
		return false
	holder.free()
	if zoneId == "" or !zoneCatalog.hasZone(zoneId):
		_reason = "invalid_zone"
		return false
	if !SOURCES.has(source):
		_reason = "invalid_source"
		return false
	if !(trailState.get("onTrail", null) is bool):
		_reason = "invalid_trail_state"
		return false
	if typeof(trailState.get("trailDepartureId", null)) != TYPE_INT or int(trailState.trailDepartureId) < 0:
		_reason = "invalid_trail_state"
		return false
	if typeof(trailState.get("lastTownId", null)) != TYPE_STRING:
		_reason = "invalid_trail_state"
		return false
	if seedValue < -1:
		_reason = "invalid_seed"
		return false
	return true


func isValid() -> bool:
	return _valid


func reason() -> String:
	return _reason


func toDictionary() -> Dictionary:
	return {
		"formatVersion": FORMAT_VERSION,
		"encounterPath": encounterPath,
		"zoneId": zoneId,
		"source": source,
		"sourceId": sourceId,
		"origin": origin.duplicate(true),
		"progression": progression.duplicate(true),
		"trailState": trailState.duplicate(true),
		"seed": seedValue,
	}


func _dictionaryValue(value) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _resolveLocations():
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var root = (loop as SceneTree).root
		if root != null:
			return root.get_node_or_null("Locations")
	return null