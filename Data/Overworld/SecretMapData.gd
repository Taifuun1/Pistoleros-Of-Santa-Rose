extends RefCounted
class_name SecretMapData

## Authored map reveals (Docs/System Design/Location Vendors Implementation.md,
## Secrets). A map reveals stable target ids; Location targets resolve through
## the generated Overworld map manifest by id and must be authored as secret
## there, while secret-item targets carry an authored chunk+tile for projection.
## Nothing here grants loot or reveals ordinary always-visible Locations.

const HelperVariablesScript = preload("res://Globals/HelperVariables.gd")

const SUPPORTED_TARGET_KINDS = ["location", "secret_item"]

var maps = {
	"canyon_cache_map": {
		"mapId": "canyon_cache_map",
		"targetIds": ["Gold Run"],
	},
}

var targets = {
	"Gold Run": {
		"targetId": "Gold Run",
		"kind": "location",
		"displayName": "Gold Run",
		"icon": "secret_location",
	},
}


func hasMap(mapId: String) -> bool:
	return maps.has(mapId)


func getMap(mapId: String) -> Dictionary:
	if !maps.has(mapId):
		return {}
	return maps[mapId].duplicate(true)


func getTarget(targetId: String) -> Dictionary:
	if !targets.has(targetId):
		return {}
	return targets[targetId].duplicate(true)


## Resolves every target in authored order; unknown ids are omitted so callers
## must validate first or treat a shorter list as invalid data.
func getMapTargets(mapId: String) -> Array:
	var resolved = []
	for targetId in maps.get(mapId, {}).get("targetIds", []):
		var target = getTarget(str(targetId))
		if !target.is_empty():
			resolved.append(target)
	return resolved


## Cross-data lint. itemCatalog ensures every reveal_map effect resolves a map
## definition; mapData ensures Location targets exist in the generated
## manifest. Both are optional for schema-only fixtures.
func validate(itemCatalog = null, mapData = null) -> Array:
	var errors = []
	for mapId in maps:
		var map = maps[mapId]
		if !(map is Dictionary):
			errors.append("map '%s' must be a Dictionary" % mapId)
			continue
		if str(map.get("mapId", "")) != mapId:
			errors.append("map '%s': mapId must match its key" % mapId)
		var targetIds = map.get("targetIds", null)
		if !(targetIds is Array) or targetIds.is_empty():
			errors.append("map '%s': targetIds must be a non-empty Array" % mapId)
			continue
		var seenTargets = {}
		for targetIdValue in targetIds:
			var targetId = str(targetIdValue)
			if targetId == "" or !targets.has(targetId):
				errors.append("map '%s': unknown target '%s'" % [mapId, targetId])
				continue
			if seenTargets.has(targetId):
				errors.append("map '%s': duplicate target '%s'" % [mapId, targetId])
			seenTargets[targetId] = true

	for targetId in targets:
		var target = targets[targetId]
		if !(target is Dictionary):
			errors.append("target '%s' must be a Dictionary" % targetId)
			continue
		if str(target.get("targetId", "")) != targetId:
			errors.append("target '%s': targetId must match its key" % targetId)
		var kind = str(target.get("kind", ""))
		if !SUPPORTED_TARGET_KINDS.has(kind):
			errors.append("target '%s': unsupported kind '%s'" % [targetId, kind])
		if str(target.get("displayName", "")) == "":
			errors.append("target '%s': missing displayName" % targetId)
		if str(target.get("icon", "")) == "":
			errors.append("target '%s': missing icon" % targetId)
		if kind == "location":
			if mapData != null:
				var entry: Dictionary = mapData.resolveSecretLocation(targetId)
				if entry.is_empty():
					errors.append("target '%s': no Overworld map manifest Location is authored as secret '%s'" % [targetId, targetId])
				elif str(entry.get("secret_id", "")) != targetId:
					errors.append("target '%s': manifest secret_id does not match the target id" % targetId)
			if target.has("chunk") or target.has("tile"):
				errors.append("target '%s': Location targets resolve coordinates from the manifest" % targetId)
		elif kind == "secret_item":
			errors.append_array(_validateSecretItem(targetId, target))

	if itemCatalog != null:
		for definitionId in itemCatalog.definitions:
			var definition = itemCatalog.definitions[definitionId]
			if !(definition is Dictionary) or definition.get("itemType", "") != "map":
				continue
			var effect = definition.get("effect", {})
			var mapId = str(effect.get("mapId", ""))
			if !maps.has(mapId):
				errors.append("item '%s': reveal_map references unknown map '%s'" % [definitionId, mapId])
	return errors


func _validateSecretItem(targetId: String, target: Dictionary) -> Array:
	var errors = []
	if !(target.get("chunk", null) is Vector2i):
		errors.append("target '%s': secret_item requires Vector2i chunk" % targetId)
	if !(target.get("tile", null) is Vector2i):
		errors.append("target '%s': secret_item requires Vector2i tile" % targetId)
	if errors.is_empty():
		var helperVars = HelperVariablesScript.new()
		var chunkGrid = WorldData.CHUNK_GRID
		var chunkTiles = helperVars.overworldChunkSize
		helperVars.free()
		if !chunkGrid.has_point(target["chunk"]):
			errors.append("target '%s': chunk %s is outside the world grid" % [targetId, target["chunk"]])
		if target["tile"].x < 0 or target["tile"].y < 0 or target["tile"].x >= chunkTiles.x or target["tile"].y >= chunkTiles.y:
			errors.append("target '%s': tile %s is outside its chunk" % [targetId, target["tile"]])
	return errors
