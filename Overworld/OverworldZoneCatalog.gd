extends RefCounted
class_name OverworldZoneCatalog

## Shared Overworld Zone lookup (Docs/System Design/Overworld Spawns.md). The
## production catalog loads Data/Overworld/ZoneData.gd; tests inject a
## replacement dataset. Consumers store canonical Zone ids, never band geometry.

const ZONE_DATA_SCRIPT := "res://Data/Overworld/ZoneData.gd"

# zoneData: same shape as ZoneData.data. Empty loads the production dataset.
var data: Dictionary = {}
var loadError := ""
# Vector2i chunk -> canonical Zone id, parsed once from the ASCII zone map.
var chunkZones: Dictionary = {}


func _init(zoneData: Dictionary = {}) -> void:
	if zoneData.is_empty():
		_loadProductionData()
	else:
		data = zoneData.duplicate(true)
	_buildLookup()


func _loadProductionData() -> void:
	if !ResourceLoader.exists(ZONE_DATA_SCRIPT):
		loadError = "missing %s" % ZONE_DATA_SCRIPT
		return
	var zoneData = load(ZONE_DATA_SCRIPT).new()
	data = zoneData.data.duplicate(true)


func _buildLookup() -> void:
	chunkZones.clear()
	var rows: Array = data.get("zone_map", [])
	var legend: Dictionary = data.get("legend", {})
	for y in rows.size():
		var row = rows[y]
		if !(row is String):
			continue
		for x in row.length():
			var zoneId = legend.get(row[x], "")
			if zoneId != "":
				chunkZones[Vector2i(x, y)] = str(zoneId)


## The Zone of an Overworld chunk: the explicitly drawn map character wins,
## otherwise the shared default Zone covers chunks outside the map. Returns ""
## only for malformed/missing catalog data.
func zoneForChunk(chunk: Vector2i) -> String:
	var zoneId = str(chunkZones.get(chunk, ""))
	if zoneId != "":
		return zoneId
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


## Data-lint checks for an injected or production dataset. The zone map is the
## only geography: every drawn chunk is explicitly zoned and default_zone must
## stay off the map.
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
		var zone = zonesValue[index]
		if !(zone is Dictionary):
			errors.append("zone entry %d must be a Dictionary" % index)
			continue
		var zoneId = str(zone.get("zone", ""))
		if zoneId == "":
			errors.append("zone entry %d missing zone id" % index)
		elif seen.has(zoneId):
			errors.append("zone '%s' is declared more than once" % zoneId)
		else:
			seen[zoneId] = true
		if str(zone.get("displayName", "")) == "":
			errors.append("zone '%s' missing displayName" % zoneId)
	var defaultZone = str(data.get("default_zone", ""))
	if defaultZone == "":
		errors.append("default_zone is required")
	elif !seen.has(defaultZone):
		errors.append("default_zone '%s' is not a declared zone" % defaultZone)

	var legend = data.get("legend", null)
	if !(legend is Dictionary) or legend.is_empty():
		errors.append("legend must be a non-empty Dictionary")
		legend = {}
	var mappedZones = {}
	for mapChar in legend:
		if str(mapChar).length() != 1:
			errors.append("legend key '%s' must be a single character" % str(mapChar))
		var zoneId = str(legend[mapChar])
		if !seen.has(zoneId):
			errors.append("legend maps '%s' to undeclared zone '%s'" % [str(mapChar), zoneId])
		else:
			mappedZones[zoneId] = true

	var mapWidth = data.get("map_width", null)
	var mapHeight = data.get("map_height", null)
	if !(mapWidth is int) or !(mapHeight is int) or mapWidth < 1 or mapHeight < 1:
		errors.append("map_width/map_height must be positive ints")
		return errors
	var rows = data.get("zone_map", null)
	if !(rows is Array) or rows.size() != mapHeight:
		errors.append("zone_map must hold exactly map_height rows")
		return errors
	for y in rows.size():
		var row = rows[y]
		if !(row is String) or row.length() != mapWidth:
			errors.append("zone_map row %d must be a String of map_width characters" % y)
			continue
		for x in row.length():
			var mapChar = row[x]
			if !legend.has(mapChar):
				errors.append("zone_map (%d,%d) uses character '%s' outside the legend" % [x, y, mapChar])
	for zoneId in seen:
		if !mappedZones.has(zoneId):
			errors.append("zone '%s' is declared but never drawn on the map" % zoneId)
	return errors
