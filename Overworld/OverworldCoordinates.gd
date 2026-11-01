extends RefCounted
class_name OverworldCoordinates

## Shared Overworld coordinate conversions (Docs/System Design/Journal/
## Overworld Map.md), built from the actual chunk/template tile map
## transforms: the template grid is a staggered isometric layout (map_to_local
## basis u = (24, 0), v = (+/-12, 6) by row parity), so these helpers never
## re-derive the math by hand. Live streaming/spawning and the map generator
## both go through this class instead of copying the constants.

var _chunkMap: TileMap
var _templateMap: TileMap
var _ownsMaps := false


func _init(chunkMap: TileMap, templateMap: TileMap) -> void:
	_chunkMap = chunkMap
	_templateMap = templateMap


## Headless construction for the generator and tests (no autoloads, no scene
## tree): same tileset and chunk frame as the live Overworld.
static func makeHeadless() -> OverworldCoordinates:
	var chunkTileSet := TileSet.new()
	chunkTileSet.tile_size = WorldData.CHUNK_MAP_TILE_SIZE
	var chunkMap := TileMap.new()
	chunkMap.tile_set = chunkTileSet
	var templateMap := TileMap.new()
	templateMap.tile_set = load(WorldData.TEMPLATE_TILESET_PATH)
	var coordinates := OverworldCoordinates.new(chunkMap, templateMap)
	coordinates._ownsMaps = true
	return coordinates


## Frees maps created by makeHeadless(). Live coordinates borrow scene nodes
## and never take ownership of them.
func dispose() -> void:
	if !_ownsMaps:
		return
	if is_instance_valid(_chunkMap):
		_chunkMap.free()
	if is_instance_valid(_templateMap):
		_templateMap.free()
	_chunkMap = null
	_templateMap = null
	_ownsMaps = false


## The chunk's first cell on the shared template grid (the live
## getChunkBaseCell() formula). The decoder's -Vector2i.ONE tile correction
## is applied in chunkTileToCell(), not here.
func chunkToBaseCell(chunk: Vector2i) -> Vector2i:
	var origin := Vector2i(
		int(_chunkMap.map_to_local(chunk).x) - (32 * 24),
		int(_chunkMap.map_to_local(chunk).y) - (32 * 6)
	)
	return _templateMap.local_to_map(origin)


func chunkTileToCell(chunk: Vector2i, tile: Vector2i) -> Vector2i:
	return chunkToBaseCell(chunk) + tile - Vector2i.ONE


## Inverse of chunkTileToCell: the chunk and 1-based local tile a shared cell
## belongs to, derived from the real chunk-frame transforms (never hand math).
func cellToChunkTile(cell: Vector2i) -> Dictionary:
	var baseZero := chunkToBaseCell(Vector2i.ZERO)
	var stepX := chunkToBaseCell(Vector2i(1, 0)) - baseZero
	var stepY := chunkToBaseCell(Vector2i(0, 1)) - baseZero
	var chunk := Vector2i(
		floori(float(cell.x - baseZero.x + 1) / float(stepX.x)),
		floori(float(cell.y - baseZero.y + 1) / float(stepY.y))
	)
	var tile := cell - chunkToBaseCell(chunk) + Vector2i.ONE
	return { "chunk": chunk, "tile": tile }


## The chunk/tile anchor in world space, defined through the shared cell so
## it always agrees with cellToWorld(chunkTileToCell()). The player spawn, the
## location collision areas and the spawn points all place through this.
func chunkTileToWorld(chunk: Vector2i, tile: Vector2i) -> Vector2:
	return cellToWorld(chunkTileToCell(chunk, tile))


func cellToWorld(cell: Vector2i) -> Vector2:
	return _templateMap.map_to_local(cell)


## The shared cell containing a world position through the tile map's real
## transform. Re-entry reseeds from this cell; never floor a continuous
## fraction to recover it.
func worldToCell(worldPosition: Vector2) -> Vector2i:
	return _templateMap.local_to_map(_templateMap.to_local(worldPosition))


## Exact world position as its containing cell plus the offset on that cell's
## own u/v basis: { "cell": Vector2i, "fraction": Vector2 }. The staggered grid's
## per-cell parallelograms overlap, so this pair (not a packed Vector2) is the
## invertible contract.
func worldToCellAndFraction(worldPosition: Vector2) -> Dictionary:
	var local := _templateMap.to_local(worldPosition)
	var cell := _templateMap.local_to_map(local)
	return { "cell": cell, "fraction": _localToFraction(cell, local) }


## Inverse of worldToCellAndFraction, on the given cell's own axes.
func cellAndFractionToWorld(cell: Vector2i, fraction: Vector2) -> Vector2:
	var axes := _cellAxes(cell)
	var uAxis: Vector2 = axes[1]
	var vAxis: Vector2 = axes[2]
	return _templateMap.to_global(axes[0] + uAxis * fraction.x + vAxis * fraction.y)


## Continuous projection coordinate for a world position (sub-cell marker
## motion): the containing cell plus its local offset. Projection is affine, so
## this value is safe to hand to OverworldMapProjection, but it is not
## invertible on its own — use worldToCellAndFraction() for exact conversion.
func worldToCellFraction(worldPosition: Vector2) -> Vector2:
	var local := _templateMap.to_local(worldPosition)
	var cell := _templateMap.local_to_map(local)
	return Vector2(cell) + _localToFraction(cell, local)


## Position within its containing cell expressed on that cell's u/v basis.
func _localToFraction(cell: Vector2i, localPosition: Vector2) -> Vector2:
	var axes := _cellAxes(cell)
	var center: Vector2 = axes[0]
	var uAxis: Vector2 = axes[1]
	var vAxis: Vector2 = axes[2]
	var delta: Vector2 = localPosition - center
	var determinant := uAxis.x * vAxis.y - uAxis.y * vAxis.x
	return Vector2(
		(delta.x * vAxis.y - delta.y * vAxis.x) / determinant,
		(uAxis.x * delta.y - uAxis.y * delta.x) / determinant
	)


func _cellAxes(cell: Vector2i) -> Array:
	var center := _templateMap.map_to_local(cell)
	return [
		center,
		_templateMap.map_to_local(cell + Vector2i(1, 0)) - center,
		_templateMap.map_to_local(cell + Vector2i(0, 1)) - center,
	]