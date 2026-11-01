extends Node

## Overworld autoload: player entry and exact last-known state shared by the
## Overworld scene and the Journal map (Docs/System Design/Journal/Overworld
## Map.md, player position provider). spawnChunk/spawnTile remain the re-entry
## contract but are reseeded from the exact marker position whenever it is
## stored, so re-entry and the map marker share one position.

var spawnChunk = Vector2i(8, 12)
var spawnTile = Vector2i(40, 38)

var overworldActorIdCount = 0
var overworldSpawnpointIdCount = 0

var _livePlayerActor: Node2D = null
var _lastKnownPosition := Vector2.ZERO
var _hasLastKnownPosition := false
var _coordinates: OverworldCoordinates = null


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
	var fraction := coordinates.worldToCellFraction(worldPosition)
	var cell := Vector2i(floori(fraction.x), floori(fraction.y))
	var chunkTile := coordinates.cellToChunkTile(cell)
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


func _exit_tree() -> void:
	if _coordinates != null:
		_coordinates.dispose()
