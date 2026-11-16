extends RefCounted
class_name EncounterPoolData

## Shared regular-encounter pool schema per Overworld Zone (Docs/System Design/
## Shootout/Encounters.md and Location Vendors Implementation.md). The future
## encounter launcher and NewspaperReportBuilder read the same pools. An empty
## production pools map means no Zone has published local intelligence yet;
## unavailable must be shown explicitly, never substituted with RatAmbush.

const FORMAT_VERSION := 1
## Authored per-Zone pool files. Each file exposes a `data` Dictionary with the
## pool `entries`; the folder is optional so headless fixtures keep working.
const PRODUCTION_POOL_DIR := "res://Data/Shootout/EncounterPools"

# zoneId -> {
#   "zoneId": String,
#   "entries": [
#     {
#       "encounter": "res://Data/Shootout/Encounters/RatAmbush.gd",
#       "weight": int,
#       "newspaperPublic": bool  # optional, default true
#     },
#   ],
# }
var pools = {}


## Merges every authored `Data/Shootout/EncounterPools/*.gd` file into `pools`,
## keyed by the file's basename (the canonical Zone id). A file without `data`
## is an error, never a silent skip, so malformed content fails the lint.
func loadProductionPools(directory := PRODUCTION_POOL_DIR) -> Array:
	var errors = []
	if !DirAccess.dir_exists_absolute(directory):
		return errors
	for fileName in DirAccess.get_files_at(directory):
		if !fileName.ends_with(".gd"):
			continue
		var script = load(directory + "/" + fileName)
		if script == null:
			errors.append("pool file '%s' could not be loaded" % fileName)
			continue
		var holder = script.new()
		if !("data" in holder) or !(holder.data is Dictionary):
			errors.append("pool file '%s' must expose a `data` Dictionary" % fileName)
			holder.free()
			continue
		var zoneId := fileName.get_basename()
		pools[zoneId] = {
			"zoneId": zoneId,
			"entries": holder.data.get("entries", []),
		}
		holder.free()
	return errors


func hasZone(zoneId: String) -> bool:
	return pools.has(zoneId)


func getEntries(zoneId: String) -> Array:
	if !pools.has(zoneId):
		return []
	return pools[zoneId].get("entries", []).duplicate(true)


## Entries allowed in the newspaper projection.
func getPublicEntries(zoneId: String) -> Array:
	var publicEntries = []
	for entry in getEntries(zoneId):
		if bool(entry.get("newspaperPublic", true)):
			publicEntries.append(entry)
	return publicEntries


## Deterministic weighted selection for gameplay launchers. The same authored
## entries drive the newspaper; an injected RNG keeps selection testable and the
## global RNG untouched. Entries are read in authored order.
func selectEncounter(zoneId: String, rng: RandomNumberGenerator, zoneCatalog = null) -> Dictionary:
	if zoneCatalog != null and !zoneCatalog.hasZone(zoneId):
		return _selectionFailure("invalid_zone", zoneId)
	if !pools.has(zoneId):
		return _selectionFailure("no_pool", zoneId)
	if rng == null:
		return _selectionFailure("invalid_rng", zoneId)
	var entries = getEntries(zoneId)
	var total := 0
	for entryValue in entries:
		if !(entryValue is Dictionary):
			return _selectionFailure("invalid_entries", zoneId)
		var weight = int(entryValue.get("weight", 0))
		if weight <= 0:
			return _selectionFailure("invalid_entries", zoneId)
		total += weight
	if total <= 0:
		return _selectionFailure("no_pool", zoneId)
	var pick := rng.randi_range(0, total - 1)
	for entryValue in entries:
		var entry: Dictionary = entryValue
		pick -= int(entry.get("weight", 0))
		if pick < 0:
			return {
				"success": true,
				"reason": "",
				"zoneId": zoneId,
				"encounterPath": str(entry.get("encounter", "")),
				"weight": int(entry.get("weight", 0)),
				"entry": entry.duplicate(true),
			}
	return _selectionFailure("no_pool", zoneId)


func _selectionFailure(reason: String, zoneId: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"zoneId": zoneId,
		"encounterPath": "",
		"weight": 0,
		"entry": {},
	}


## Validates every authored pool. zoneCatalog enforces canonical Zone ids;
## encounterNames, when provided, resolves encounter file basenames so unknown
## references are rejected before runtime.
func validate(zoneCatalog = null, encounterNames: Array = []) -> Array:
	var errors = []
	for zoneId in pools:
		if zoneCatalog != null and !zoneCatalog.hasZone(zoneId):
			errors.append("pool '%s': unknown Overworld Zone id" % zoneId)
		var pool = pools[zoneId]
		if !(pool is Dictionary):
			errors.append("pool '%s' must be a Dictionary" % zoneId)
			continue
		if str(pool.get("zoneId", "")) != zoneId:
			errors.append("pool '%s': zoneId must match its key" % zoneId)
		var entries = pool.get("entries", null)
		if !(entries is Array):
			errors.append("pool '%s': entries must be an Array" % zoneId)
			continue
		for index in entries.size():
			var entry = entries[index]
			if !(entry is Dictionary):
				errors.append("pool '%s' entry %d must be a Dictionary" % [zoneId, index])
				continue
			var encounterPath = str(entry.get("encounter", ""))
			if !encounterPath.begins_with("res://") or !ResourceLoader.exists(encounterPath):
				errors.append("pool '%s' entry %d: encounter does not exist" % [zoneId, index])
			elif !encounterNames.is_empty() and !encounterNames.has(encounterPath.get_file().get_basename()):
				errors.append("pool '%s' entry %d: unknown encounter '%s'" % [zoneId, index, encounterPath.get_file()])
			var weight = entry.get("weight", null)
			if typeof(weight) != TYPE_INT or int(weight) <= 0:
				errors.append("pool '%s' entry %d: weight must be a positive integer" % [zoneId, index])
			if entry.has("newspaperPublic") and typeof(entry["newspaperPublic"]) != TYPE_BOOL:
				errors.append("pool '%s' entry %d: newspaperPublic must be a Boolean" % [zoneId, index])
	return errors


## Production lint includes zones but no encounter-name catalog; the encounter
## path existence check still runs.
func validateProduction(zoneCatalog) -> Array:
	return validate(zoneCatalog)


## Loads the authored pool files, then validates them. Returns every error from
## both steps so a broken pool file is reported like a broken pool entry.
func validateAuthoredPools(zoneCatalog, encounterNames: Array = [], directory := PRODUCTION_POOL_DIR) -> Array:
	var errors := loadProductionPools(directory)
	errors.append_array(validate(zoneCatalog, encounterNames))
	return errors
