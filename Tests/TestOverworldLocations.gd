extends SceneTree

## Headless lint for authored Location entrances (Docs/System Design/Journal/
## Overworld Map.md): every Location anchor must be inside its chunk, land on a
## walkable cell, sit on (or one cell from) the town entrance prop, and match the
## committed map manifest. Guards the drift that put Lazysprings' entrance two
## tiles up-left of the drawn town.
## Run with: godot --headless --script res://Tests/TestOverworldLocations.gd

const HelperVariablesScript := preload("res://Globals/HelperVariables.gd")
const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"
## Tileset source 0 is the "Overworld Locations" entrance-prop source.
const PROP_SOURCE := 0

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var helperVars = HelperVariablesScript.new()
	var chunkTiles: Vector2i = helperVars.overworldChunkSize
	helperVars.free()
	var coordinates := OverworldCoordinates.makeHeadless()
	var reader := OverworldChunkReader.new(coordinates)
	var tileSet: TileSet = load(WorldData.TEMPLATE_TILESET_PATH)
	var manifest = load(MAP_MANIFEST)
	var manifestById := {}
	if manifest != null:
		for entry in manifest.locations:
			manifestById[str(entry.get("id", ""))] = entry
	_check(manifest != null and !manifestById.is_empty(), "the committed map manifest lists its Locations")

	var checked := 0
	for fileName in DirAccess.get_files_at("res://Overworld/Overworld Chunks"):
		if !fileName.ends_with(".gd"):
			continue
		var script = load("res://Overworld/Overworld Chunks/" + fileName)
		if script == null:
			continue
		var data = script.new()
		if !("locations" in data):
			data.free()
			continue
		var chunkName := fileName.get_basename()
		var parts := chunkName.split("#")
		var chunk := Vector2i(int(parts[1]), int(parts[2]))
		var packed = load("res://Overworld/Overworld Chunks/" + chunkName + ".tscn")
		var byCell := _readCells(reader, chunk, packed)
		for locationName in data.locations:
			checked += 1
			_checkLocation(locationName, data.locations[locationName], chunk, chunkTiles, byCell, tileSet, coordinates, manifestById)
		data.free()

	_check(checked == 7, "all seven authored Locations are linted (found %d)" % checked)
	coordinates.dispose()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _checkLocation(locationName: String, entry: Dictionary, chunk: Vector2i, chunkTiles: Vector2i, byCell: Dictionary, tileSet: TileSet, coordinates, manifestById: Dictionary) -> void:
	var tiles: PackedVector2Array = entry.get("tiles", PackedVector2Array())
	if tiles.is_empty():
		_check(false, "%s authors an entrance tile" % locationName)
		return
	var tile := Vector2i(tiles[0])
	_check(tile.x >= 0 and tile.y >= 0 and tile.x < chunkTiles.x and tile.y < chunkTiles.y, "%s entrance tile %s is inside its chunk" % [locationName, tile])
	var anchorCell: Vector2i = coordinates.chunkTileToCell(chunk, tile)
	var tileRecord: Vector3i = byCell.get(anchorCell, Vector3i(-1, -1, -1))
	_check(tileRecord.x >= 0, "%s entrance %s has terrain in chunk %s" % [locationName, anchorCell, chunk])
	_check(_walkable(tileSet, tileRecord), "%s entrance %s is walkable" % [locationName, anchorCell])
	var propGap := _nearestPropGap(byCell, anchorCell)
	_check(propGap <= 1, "%s entrance sits on the town prop (gap %d)" % [locationName, propGap])

	var manifestEntry: Dictionary = manifestById.get(locationName, {})
	_check(!manifestEntry.is_empty(), "%s appears in the map manifest" % locationName)
	if manifestEntry.is_empty():
		return
	_check(Vector2i(manifestEntry.get("chunk", Vector2i(-1, -1))) == chunk, "%s manifest chunk matches its data script" % locationName)
	_check(Vector2i(manifestEntry.get("tile", Vector2i(-1, -1))) == tile, "%s manifest tile matches its authored entrance" % locationName)
	_check(Vector2i(manifestEntry.get("cell", Vector2i(-1, -1))) == anchorCell, "%s manifest cell matches the shared-cell conversion" % locationName)


func _readCells(reader: OverworldChunkReader, chunk: Vector2i, packed) -> Dictionary:
	var cells: PackedInt32Array = reader.readCells(chunk, packed)
	var byCell := {}
	var i := 0
	while i + 5 < cells.size():
		byCell[Vector2i(cells[i], cells[i + 1])] = Vector3i(cells[i + 2], cells[i + 3], cells[i + 4])
		i += 6
	return byCell


## Chebyshev distance from a cell to the nearest entrance prop of that chunk.
func _nearestPropGap(byCell: Dictionary, cell: Vector2i) -> int:
	var best := 9999
	for candidate in byCell:
		if byCell[candidate].x != PROP_SOURCE:
			continue
		best = mini(best, maxi(absi(candidate.x - cell.x), absi(candidate.y - cell.y)))
	return best


func _walkable(tileSet: TileSet, tile: Vector3i) -> bool:
	if tile.x < 0 or !tileSet.has_source(tile.x):
		return false
	var source := tileSet.get_source(tile.x) as TileSetAtlasSource
	if source == null:
		return false
	var coords := Vector2i(tile.y, tile.z)
	if !source.has_tile(coords):
		return false
	var data := source.get_tile_data(coords, 0)
	return data == null or data.get_collision_polygons_count(0) == 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)