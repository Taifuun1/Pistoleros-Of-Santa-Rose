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


## Continuous cell coordinates for a world position (sub-cell motion). The
## integer cell comes from the real map transform and the fraction is solved
## on that cell's actual u/v basis, so cell centers round-trip exactly. The
## staggered v axis alternates per row, so fractions are exact within a cell
## and may wobble a fraction of a cell on row crossings.
func worldToCellFraction(worldPosition: Vector2) -> Vector2:
	var local := _templateMap.to_local(worldPosition)
	var cell := _templateMap.local_to_map(local)
	var axes := _cellAxes(cell)
	var center: Vector2 = axes[0]
	var uAxis: Vector2 = axes[1]
	var vAxis: Vector2 = axes[2]
	var delta: Vector2 = local - center
	var determinant := uAxis.x * vAxis.y - uAxis.y * vAxis.x
	var fractionU: float = (delta.x * vAxis.y - delta.y * vAxis.x) / determinant
	var fractionV: float = (uAxis.x * delta.y - uAxis.y * delta.x) / determinant
	return Vector2(cell) + Vector2(fractionU, fractionV)


func cellFractionToWorld(cellFraction: Vector2) -> Vector2:
	var cell := Vector2i(floori(cellFraction.x), floori(cellFraction.y))
	var axes := _cellAxes(cell)
	var uAxis: Vector2 = axes[1]
	var vAxis: Vector2 = axes[2]
	var offset := uAxis * (cellFraction.x - cell.x) + vAxis * (cellFraction.y - cell.y)
	return _templateMap.to_global(axes[0] + offset)


func _cellAxes(cell: Vector2i) -> Array:
	var center := _templateMap.map_to_local(cell)
	return [
		center,
		_templateMap.map_to_local(cell + Vector2i(1, 0)) - center,
		_templateMap.map_to_local(cell + Vector2i(0, 1)) - center,
	]