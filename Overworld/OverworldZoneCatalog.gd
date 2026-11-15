extends RefCounted
class_name OverworldZoneCatalog

## Shared Overworld Zone lookup (Docs/System Design/Overworld Spawns.md). The
## production catalog loads Data/Overworld/ZoneData.gd; tests inject a
## replacement dataset. Consumers store canonical Zone ids, never band geometry.

const ZONE_DATA_SCRIPT := "res://Data/Overworld/ZoneData.gd"

# zoneData: same shape as ZoneData.data. Empty loads the production dataset.
var data: Dictionary = {}
var loadError := ""


func _init(zoneData: Dictionary = {}) -> void:
	if zoneData.is_empty():
		_loadProductionData()
	else:
		data = zoneData.duplicate(true)


func _loadProductionData() -> void:
	if !ResourceLoader.exists(ZONE_DATA_SCRIPT):
		loadError = "missing %s" % ZONE_DATA_SCRIPT
		return
	var zoneData = load(ZONE_DATA_SCRIPT).new()
	data = zoneData.data.duplicate(true)


## The Zone of an Overworld chunk: first inclusive min/max band wins, otherwise
## the shared default Zone. Returns "" only for malformed/missing catalog data.
func zoneForChunk(chunk: Vector2i) -> String:
	for band in data.get("zones", []):
		if !(band is Dictionary):
			continue
		var bandMin = band.get("min", null)
		var bandMax = band.get("max", null)
		if !(bandMin is Vector2i) or !(bandMax is Vector2i):
			continue
		if chunk.x >= bandMin.x and chunk.x <= bandMax.x and chunk.y >= bandMin.y and chunk.y <= bandMax.y:
			return str(band.get("zone", ""))
	return str(data.get("default_zone", ""))


## Unique canonical Zone ids in authored order.
func zoneIds() -> Array:
	var ids = []
	var seen = {}
	for band in data.get("zones", []):
		if !(band is Dictionary):
			continue
		var zoneId = str(band.get("zone", ""))
		if zoneId == "" or seen.has(zoneId):
			continue
		seen[zoneId] = true
		ids.append(zoneId)
	return ids


func hasZone(zoneId: String) -> bool:
	return zoneId != "" and zoneIds().has(zoneId)


func displayName(zoneId: String) -> String:
	for band in data.get("zones", []):
		if band is Dictionary and str(band.get("zone", "")) == zoneId:
			return str(band.get("displayName", zoneId))
	return zoneId


## Data-lint checks for an injected or production dataset. Bands may overlap
## because first-match ordering is intentional.
func validate() -> Array:
	var errors = []
	if loadError != "":
		errors.append(loadError)
	var zonesValue = data.get("zones", null)
	if !(zonesValue is Array) or zonesValue.is_empty():
		errors.append("zones must be a non-empty Array")
		return errors
	var seen = {}
	for index in zonesValue.size():
		var band = zonesValue[index]
		if !(band is Dictionary):
			errors.append("zone band %d must be a Dictionary" % index)
			continue
		var zoneId = str(band.get("zone", ""))
		if zoneId == "":
			errors.append("zone band %d missing zone id" % index)
		elif !seen.has(zoneId):
			seen[zoneId] = true
		if str(band.get("displayName", "")) == "":
			errors.append("zone '%s' missing displayName" % zoneId)
		var bandMin = band.get("min", null)
		var bandMax = band.get("max", null)
		if !(bandMin is Vector2i) or !(bandMax is Vector2i):
			errors.append("zone '%s' min/max must be Vector2i" % zoneId)
			continue
		if bandMin.x > bandMax.x or bandMin.y > bandMax.y:
			errors.append("zone '%s' min is above max" % zoneId)
	var defaultZone = str(data.get("default_zone", ""))
	if defaultZone == "":
		errors.append("default_zone is required")
	elif !seen.has(defaultZone):
		errors.append("default_zone '%s' is not a declared zone" % defaultZone)
	return errors
