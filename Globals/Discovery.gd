extends Node

## Secret discovery service (Docs/System Design/Location Vendors
## Implementation.md, patch 5 / Map discovery). It owns the revealed target ids
## and map use. Validation completes before any mutation, so a rejected map is
## never consumed, and using a map never grants loot or moves the player.

signal discoveryChanged

const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const HelperVariablesScript = preload("res://Globals/HelperVariables.gd")

const MAP_DATA_PATH := "res://Data/Overworld/OverworldMapData.tres"
const STATE_FORMAT_VERSION := 1
const SUPPORTED_EFFECT_KIND := "reveal_map"
const MAP_ITEM_TYPE := "map"

## Collaborators. Production resolves them in _ready(); tests inject via
## configure().
var party = null
var secretMaps = null
var itemCatalog = null
var mapData: OverworldMapData = null
var coordinates = null

var _revealedIds := {}
var _commandInProgress := false
var _initialized := false


func _ready() -> void:
	secretMaps = SecretMapDataScript.new()
	itemCatalog = ItemCatalogScript.new()
	party = get_node_or_null("/root/Party")
	mapData = _loadMapData()
	coordinates = OverworldCoordinates.makeHeadless()
	_initialized = true


## Test/headless initialization seam. `coordinateService` may be shared with a
## caller that already owns one.
func configure(partyNode = null, secretMapData = null, itemCatalogData = null, mapDataResource = null, coordinateService = null) -> void:
	party = partyNode
	secretMaps = secretMapData if secretMapData != null else SecretMapDataScript.new()
	itemCatalog = itemCatalogData if itemCatalogData != null else ItemCatalogScript.new()
	mapData = mapDataResource
	coordinates = coordinateService if coordinateService != null else OverworldCoordinates.makeHeadless()
	_revealedIds = {}
	_commandInProgress = false
	_initialized = true


func isDiscoveryDataAvailable() -> bool:
	return _initialized and secretMaps != null and party != null


func _exit_tree() -> void:
	if coordinates != null:
		coordinates.dispose()
		coordinates = null


func _loadMapData() -> OverworldMapData:
	if !ResourceLoader.exists(MAP_DATA_PATH):
		return null
	var data = load(MAP_DATA_PATH)
	if data == null or !(data is OverworldMapData):
		return null
	return data


## Read-only preview for the Journal confirmation: the map's target display
## names in authored order, or a stable reason when the map cannot be used now.
## Validation here is advisory; useMap() revalidates before consuming.
func getMapUsePreview(instanceId: String) -> Dictionary:
	if !isDiscoveryDataAvailable():
		return _failure("data_unavailable")
	var item = _carriedItem(instanceId)
	if item.is_empty():
		return _failure("unknown_item")
	if str(item.get("itemType", "")) != MAP_ITEM_TYPE:
		return _failure("wrong_item_type")
	var effect = item.get("effect", null)
	if !(effect is Dictionary) or str(effect.get("kind", "")) != SUPPORTED_EFFECT_KIND:
		return _failure("invalid_map")
	var mapId := str(effect.get("mapId", ""))
	var map = secretMaps.getMap(mapId)
	if map.is_empty():
		return _failure("invalid_map")
	var targets = secretMaps.getMapTargets(mapId)
	if targets.is_empty() or targets.size() != (map.get("targetIds", []) as Array).size():
		return _failure("invalid_target")
	var names := []
	var unrevealed := false
	for target in targets:
		var targetError := _targetError(target)
		if targetError != "":
			return _failure(targetError)
		names.append(str(target.get("displayName", "")))
		if !isRevealed(str(target.get("targetId", ""))):
			unrevealed = true
	if !unrevealed:
		return _failure("already_revealed")
	return { "success": true, "reason": "", "mapId": mapId, "targetNames": names }


## Validates and consumes one carried map. Returns
## { success, reason, mapId, revealedIds, consumed }.
func useMap(instanceId: String) -> Dictionary:
	if !isDiscoveryDataAvailable():
		return _failure("data_unavailable")
	if _commandInProgress:
		return _failure("command_in_progress")
	var item = _carriedItem(instanceId)
	if item.is_empty():
		return _failure("unknown_item")
	if str(item.get("itemType", "")) != MAP_ITEM_TYPE:
		return _failure("wrong_item_type")
	var effect = item.get("effect", null)
	if !(effect is Dictionary) or str(effect.get("kind", "")) != SUPPORTED_EFFECT_KIND:
		return _failure("invalid_map")
	var mapId := str(effect.get("mapId", ""))
	var map = secretMaps.getMap(mapId)
	if map.is_empty():
		return _failure("invalid_map")
	var targets = secretMaps.getMapTargets(mapId)
	var authoredIds: Array = map.get("targetIds", [])
	if targets.is_empty() or targets.size() != authoredIds.size():
		return _failure("invalid_target")

	# Every target resolves before anything mutates; one bad target rejects the
	# whole reveal.
	var unrevealed := []
	for target in targets:
		var targetError := _targetError(target)
		if targetError != "":
			return _failure(targetError)
		var targetId := str(target.get("targetId", ""))
		if !isRevealed(targetId):
			unrevealed.append(targetId)
	if unrevealed.is_empty():
		return _failure("already_revealed")

	_commandInProgress = true
	var consumeResult = party.consumeItem(instanceId, MAP_ITEM_TYPE)
	if !(consumeResult is Dictionary) or !bool(consumeResult.get("success", false)):
		_commandInProgress = false
		return _failure(str(consumeResult.get("reason", "data_unavailable")) if consumeResult is Dictionary else "data_unavailable")
	for targetId in unrevealed:
		_revealedIds[targetId] = true
	_commandInProgress = false
	discoveryChanged.emit()
	return {
		"success": true,
		"reason": "",
		"mapId": mapId,
		"revealedIds": unrevealed,
		"consumed": true,
	}


func isRevealed(targetId: String) -> bool:
	return bool(_revealedIds.get(targetId, false))


## True when a map has targets and every one of them is already known. Vendors
## uses this to hide owned/exhausted map offers.
func isMapFullyRevealed(mapId: String) -> bool:
	var targets = secretMaps.getMapTargets(mapId) if secretMaps != null else []
	if targets.is_empty():
		return false
	for target in targets:
		if !isRevealed(str(target.get("targetId", ""))):
			return false
	return true


## Deep-copied marker input for revealed ids only: the resolved shared `cell`
## plus the authored `chunk`/`tile` for secret items. Location targets resolve
## their cell from the generated manifest.
func getRevealedSecretMarkers() -> Array:
	var markers := []
	if secretMaps == null:
		return markers
	var seen := {}
	for mapId in secretMaps.maps:
		for target in secretMaps.getMapTargets(mapId):
			var targetId := str(target.get("targetId", ""))
			if targetId == "" or seen.has(targetId) or !isRevealed(targetId):
				continue
			var cell = _targetCell(target)
			if cell == null:
				push_warning("Discovery: revealed target '%s' has no resolvable position." % targetId)
				continue
			seen[targetId] = true
			markers.append({
				"targetId": targetId,
				"kind": str(target.get("kind", "")),
				"displayName": str(target.get("displayName", targetId)),
				"icon": str(target.get("icon", "")),
				"cell": cell,
				"chunk": target.get("chunk", null),
				"tile": target.get("tile", null),
			})
	return markers


func exportState() -> Dictionary:
	var ids: Array = _revealedIds.keys()
	ids.sort()
	return { "formatVersion": STATE_FORMAT_VERSION, "revealedIds": ids }


## Validates the whole payload before committing; malformed imports leave the
## current reveals untouched.
func importState(state) -> Dictionary:
	if !isDiscoveryDataAvailable():
		return _failure("data_unavailable")
	if !(state is Dictionary):
		return _failure("invalid_state")
	if int(state.get("formatVersion", -1)) != STATE_FORMAT_VERSION:
		return _failure("invalid_state")
	var idsValue = state.get("revealedIds", null)
	if !(idsValue is Array):
		return _failure("invalid_state")
	var validated := {}
	for idValue in idsValue:
		if typeof(idValue) != TYPE_STRING:
			return _failure("invalid_state")
		var targetId := str(idValue)
		if targetId == "" or secretMaps.getTarget(targetId).is_empty() or validated.has(targetId):
			return _failure("invalid_state")
		validated[targetId] = true
	_revealedIds = validated
	discoveryChanged.emit()
	return { "success": true, "reason": "" }


## New Game: forget every reveal without touching Party, vendors or the world.
func resetForNewGame() -> void:
	_revealedIds = {}
	_commandInProgress = false
	discoveryChanged.emit()


func _carriedItem(instanceId: String) -> Dictionary:
	if party == null or instanceId == "" or !party.has_method("getInventorySnapshot"):
		return {}
	for itemValue in party.getInventorySnapshot().get("items", []):
		if itemValue is Dictionary and str(itemValue.get("instanceId", "")) == instanceId:
			return itemValue
	return {}


## Empty string when the target is usable, else a stable failure reason.
func _targetError(target: Dictionary) -> String:
	var kind := str(target.get("kind", ""))
	if kind == "location":
		if mapData == null:
			return "data_unavailable"
		var entry := mapData.resolveLocation(str(target.get("targetId", "")))
		if entry.is_empty():
			return "invalid_target"
		# Only manifest Locations carrying this exact secret id are revealable:
		# an always-visible Location is a content error, not a free reveal.
		if str(entry.get("secret_id", "")) != str(target.get("targetId", "")):
			return "invalid_target"
		return ""
	if kind == "secret_item":
		return "" if _targetCell(target) != null else "invalid_map"
	return "invalid_target"


## Shared-cell position of a target, or null when it cannot be resolved.
func _targetCell(target: Dictionary):
	var kind := str(target.get("kind", ""))
	if kind == "location":
		if mapData == null:
			return null
		var entry := mapData.resolveLocation(str(target.get("targetId", "")))
		if entry.is_empty():
			return null
		return entry.get("cell", null)
	if kind != "secret_item":
		return null
	if coordinates == null:
		return null
	var chunk = target.get("chunk", null)
	var tile = target.get("tile", null)
	if typeof(chunk) != TYPE_VECTOR2I or typeof(tile) != TYPE_VECTOR2I:
		return null
	var helperVars = HelperVariablesScript.new()
	var chunkTiles: Vector2i = helperVars.overworldChunkSize
	helperVars.free()
	if !WorldData.CHUNK_GRID.has_point(chunk):
		return null
	if tile.x < 0 or tile.y < 0 or tile.x >= chunkTiles.x or tile.y >= chunkTiles.y:
		return null
	var cell: Vector2i = coordinates.chunkTileToCell(chunk, tile)
	if mapData != null:
		if cell.x < mapData.cell_min.x or cell.x > mapData.cell_max.x or cell.y < mapData.cell_min.y or cell.y > mapData.cell_max.y:
			return null
	return cell


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason, "mapId": "", "revealedIds": [], "consumed": false }