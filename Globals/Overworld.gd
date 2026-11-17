extends Node

## Overworld autoload: player entry and exact last-known state shared by the
## Overworld scene and the Journal map (Docs/System Design/Journal/Overworld
## Map.md, player position provider). spawnChunk/spawnTile remain the re-entry
## contract but are reseeded from the exact marker position whenever it is
## stored, so re-entry and the map marker share one position.

var spawnChunk = Vector2i(8, 12)
var spawnTile = Vector2i(40, 38)

const DEFAULT_SPAWN_CHUNK := Vector2i(8, 12)
const DEFAULT_SPAWN_TILE := Vector2i(40, 38)
## Save snapshot format for exportState()/importState().
const STATE_FORMAT_VERSION := 1

var overworldActorIdCount = 0
var overworldSpawnpointIdCount = 0

var _livePlayerActor: Node2D = null
var _lastKnownPosition := Vector2.ZERO
var _hasLastKnownPosition := false
var _coordinates: OverworldCoordinates = null


## Return-to-town/checkpoint placement: set the Overworld entry anchor and drop
## the exact prior position so re-entry lands on the destination entrance.
func setSpawn(chunk: Vector2i, tile: Vector2i) -> void:
	spawnChunk = chunk
	spawnTile = tile
	_lastKnownPosition = Vector2.ZERO
	_hasLastKnownPosition = false


## Versioned save snapshot: the exact position this provider would report (live
## player, last-known, or the entry anchor). Live actor nodes are transient and
## are never part of the payload.
func exportState() -> Dictionary:
	var positionInfo: Dictionary = getOverworldMapPosition()
	var position: Vector2 = positionInfo.get("world_position", Vector2.ZERO)
	return {
		"formatVersion": STATE_FORMAT_VERSION,
		"position": { "x": position.x, "y": position.y },
	}


## Validates the payload before committing. A null position means "no exact
## position recorded" (legacy saves): the entry anchor is kept as the best known
## position. Malformed payloads leave the current position untouched.
func importState(state) -> Dictionary:
	if !(state is Dictionary) or int(state.get("formatVersion", -1)) != STATE_FORMAT_VERSION:
		return _failure("invalid_state")
	var positionValue = state.get("position", null)
	if positionValue == null:
		_lastKnownPosition = Vector2.ZERO
		_hasLastKnownPosition = false
		return { "success": true, "reason": "" }
	if !(positionValue is Dictionary):
		return _failure("invalid_state")
	var x = positionValue.get("x", null)
	var y = positionValue.get("y", null)
	if !_isNumber(x) or !_isNumber(y):
		return _failure("invalid_state")
	var position := Vector2(float(x), float(y))
	if !is_finite(position.x) or !is_finite(position.y):
		return _failure("invalid_state")
	storeLastKnownPlayerPosition(position)
	return { "success": true, "reason": "" }


## New Game: return to the default Overworld entry anchor and forget the
## previous run's last-known position.
func resetForNewGame() -> void:
	spawnChunk = DEFAULT_SPAWN_CHUNK
	spawnTile = DEFAULT_SPAWN_TILE
	overworldActorIdCount = 0
	overworldSpawnpointIdCount = 0
	_livePlayerActor = null
	_lastKnownPosition = Vector2.ZERO
	_hasLastKnownPosition = false


## The Overworld scene registers its live player on entry; the placement
## position becomes the initial last-known state.
func registerLivePlayer(actor: Node2D) -> void:
	_livePlayerActor = actor
	if actor != null:
		storeLastKnownPlayerPosition(actor.global_position)


## Called when the Overworld scene leaves the tree (enterLocation or any
## other transition): retains the exact position for the map and re-entry.
func clearLivePlayer() -> void:
	if _livePlayerActor != null and is_instance_valid(_livePlayerActor):
		storeLastKnownPlayerPosition(_livePlayerActor.global_position)
	_livePlayerActor = null


## Retains the exact marker position and unifies re-entry with it: the spawn
## anchor is reseeded to the tile containing that position (tile-centered —
## sub-tile offsets are not part of the re-entry contract).
func storeLastKnownPlayerPosition(worldPosition: Vector2) -> void:
	_lastKnownPosition = worldPosition
	_hasLastKnownPosition = true
	var coordinates := _getCoordinates()
	var chunkTile := coordinates.cellToChunkTile(coordinates.worldToCell(worldPosition))
	spawnChunk = chunkTile["chunk"]
	spawnTile = chunkTile["tile"]


## Journal map player position provider: live while the Overworld scene runs,
## exact last-known after it is destroyed, spawn anchor before the first
## entry. Never invalid defaults like (0,0).
func getOverworldMapPosition() -> Dictionary:
	if _livePlayerActor != null and is_instance_valid(_livePlayerActor):
		return { "valid": true, "world_position": _livePlayerActor.global_position, "is_live": true }
	if _hasLastKnownPosition:
		return { "valid": true, "world_position": _lastKnownPosition, "is_live": false }
	var worldPosition: Vector2 = _getCoordinates().chunkTileToWorld(spawnChunk, spawnTile)
	return { "valid": true, "world_position": worldPosition, "is_live": false }


func _getCoordinates() -> OverworldCoordinates:
	if _coordinates == null:
		_coordinates = OverworldCoordinates.makeHeadless()
	return _coordinates


func _isNumber(value) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason }


func _exit_tree() -> void:
	if _coordinates != null:
		_coordinates.dispose()
