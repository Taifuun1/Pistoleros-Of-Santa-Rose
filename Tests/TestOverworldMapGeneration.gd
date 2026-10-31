extends SceneTree

## Headless validation for the shared chunk reader and the full-world bake
## (Docs/System Design/Journal/Overworld Map.md): reader identity with the
## live decode (the reference functions below are the original Overworld.gd
## math, kept as the oracle so no second decoder can silently drift),
## synthetic bake fixtures (empty/missing chunks, duplicates, out-of-grid
## cells, unknown styles, invalid Location anchors, determinism, stable
## bounds) and a real-data subset bake.
## Run with: godot --headless --script res://Tests/TestOverworldMapGeneration.gd

const HelperVariablesScript := preload("res://Globals/HelperVariables.gd")

var failures = 0
var coordinates: OverworldCoordinates
var reader: OverworldChunkReader
var chunkTiles: Vector2i


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var helperVars = HelperVariablesScript.new()
	chunkTiles = helperVars.overworldChunkSize
	helperVars.free()
	coordinates = OverworldCoordinates.makeHeadless()
	reader = OverworldChunkReader.new(coordinates)

	print("--- Shared reader matches the live decode ---")
	testReaderIdentity()
	print("\n--- Reader script data ---")
	testReaderScripts()
	print("\n--- Synthetic bake fixtures ---")
	testSyntheticBakes()
	print("\n--- Real-data subset bake ---")
	testRealDataBake()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func testReaderIdentity() -> void:
	# Plain chunks, script chunks, the spawn area, a chunk next to a coverage
	# hole and the far grid corner.
	for chunk in [Vector2i(8, 12), Vector2i(0, 5), Vector2i(11, 23), Vector2i(8, 16), Vector2i(8, 17), Vector2i(1, 22)]:
		var packedScene: PackedScene = load(WorldData.getChunkPath(chunk))
		var readCells := reader.readCells(chunk, packedScene)
		var referenceCells := _referenceCells(chunk, packedScene)
		_check(readCells == referenceCells, "reader cells match the live decode for chunk {chunk} ({count} cells)".format({ "chunk": chunk, "count": readCells.size() / 6 }))
		var read := reader.readChunk(chunk, packedScene)
		_check(read["errors"].is_empty(), "chunk {chunk} reads without errors".format({ "chunk": chunk }))


func testReaderScripts() -> void:
	var lazysprings: Dictionary = reader.readChunk(Vector2i(8, 17), load(WorldData.getChunkPath(Vector2i(8, 17))))["locations"]
	_check(lazysprings.has("Lazysprings"), "chunk (8,17) carries Lazysprings")
	if lazysprings.has("Lazysprings"):
		_check(lazysprings["Lazysprings"]["tiles"][0] == Vector2(20, 36) and lazysprings["Lazysprings"]["pregenerated"] == true, "Lazysprings anchor tile (20,36) is passed through unchanged")
	var spawnChunk: Dictionary = reader.readChunk(Vector2i(8, 16), load(WorldData.getChunkPath(Vector2i(8, 16))))
	_check(spawnChunk["spawnPoints"].has("Fluffy Rabbit") and spawnChunk["locations"].is_empty(), "chunk (8,16) carries spawnPoints but no locations")
	var plainChunk: Dictionary = reader.readChunk(Vector2i(8, 12), load(WorldData.getChunkPath(Vector2i(8, 12))))
	_check(plainChunk["locations"].is_empty() and plainChunk["spawnPoints"].is_empty(), "a chunk without a data script reads empty script data")
	var missingScene := reader.readChunk(Vector2i(0, 0), null)
	_check(!missingScene["errors"].is_empty() and missingScene["cells"].is_empty(), "a missing scene is an error, never invented terrain")


## Reference: the original Overworld.gd decode, preserved here as the oracle.
func _referenceBaseCell(chunk: Vector2i) -> Vector2i:
	var chunkMap := TileMap.new()
	var chunkTileSet := TileSet.new()
	chunkTileSet.tile_size = WorldData.CHUNK_MAP_TILE_SIZE
	chunkMap.tile_set = chunkTileSet
	var templateMap := TileMap.new()
	templateMap.tile_set = load(WorldData.TEMPLATE_TILESET_PATH)
	var origin = Vector2i(chunkMap.map_to_local(chunk).x - (32 * 24), chunkMap.map_to_local(chunk).y - (32 * 6))
	return templateMap.local_to_map(origin)


func _referenceCells(chunk: Vector2i, packedScene: PackedScene) -> PackedInt32Array:
	var cellData = PackedInt32Array()
	var baseCell = _referenceBaseCell(chunk)
	var state = packedScene.get_state()
	for n in range(state.get_node_count()):
		for p in range(state.get_node_property_count(n)):
			if state.get_node_property_name(n, p) != "layer_0/tile_data":
				continue
			var data: PackedInt32Array = state.get_node_property_value(n, p)
			for i in range(0, data.size() - 2, 3):
				var cell = baseCell + Vector2i(
					_referenceS16(data[i] & 0xFFFF),
					_referenceS16((data[i] >> 16) & 0xFFFF)
					) - Vector2i(1, 1)
				cellData.append(cell.x)
				cellData.append(cell.y)
				cellData.append(_referenceS16(data[i + 1] & 0xFFFF))
				cellData.append(_referenceS16((data[i + 1] >> 16) & 0xFFFF))
				cellData.append(_referenceS16(data[i + 2] & 0xFFFF))
				cellData.append(_referenceS16((data[i + 2] >> 16) & 0xFFFF))
	return cellData


func _referenceS16(value: int) -> int:
	if value >= 0x8000:
		return value - 0x10000
	return value


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)


func testSyntheticBakes() -> void:
	# Small declared grid with tiny synthetic chunks; the projection bounds
	# come from the grid, not from the fixture data.
	var grid := Rect2i(0, 0, 3, 2)
	var tiles := Vector2i(4, 4)
	var mapProjection := OverworldMapProjection.cellForGrid(coordinates, grid, tiles)
	var baker := OverworldMapBaker.new(coordinates, mapProjection, grid, tiles)
	var styles := MapTileStyles.new({
		Vector3i(5, 0, 0): { "color": Color("#556b2f"), "feature": MapTileStyles.FEATURE_GROUND, "priority": 10 },
		Vector3i(5, 1, 0): { "color": Color("#4a7023"), "feature": MapTileStyles.FEATURE_GROUND, "priority": 10 },
	})

	var chunkCells := {}
	for chunk in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		chunkCells[chunk] = _syntheticChunkCells(chunk, tiles, 0)
	var emptyChunk := Vector2i(2, 1)
	chunkCells[emptyChunk] = PackedInt32Array()
	var scripts := {
		Vector2i(0, 0): { "locations": { "Alpha": { "tiles": PackedVector2Array([Vector2i(1, 1)]), "pregenerated": true } }, "spawnPoints": {} },
		Vector2i(1, 1): { "locations": {}, "spawnPoints": {} },
	}

	var baked := baker.bake(chunkCells, scripts, styles)
	var report: Dictionary = baked["report"]
	_check(report["errors"].is_empty(), "a clean bake reports no errors")
	_check(report["presentChunks"].size() == 6 and report["missingChunks"].is_empty(), "all declared chunks are reported present")
	_check(report["cells"] == 5 * tiles.x * tiles.y, "cell count matches the fixture (the empty chunk contributes none)")
	_check(baked["image"].get_size() == mapProjection.imageSize, "the image covers the full declared bounds")
	_check(baked["locations"].size() == 1, "the valid location is collected")
	if baked["locations"].size() == 1:
		var alpha: Dictionary = baked["locations"][0]
		var expectedCell := coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(1, 1))
		_check(alpha["cell"] == expectedCell, "the location anchor normalizes to its shared cell")
		_check(alpha["image_position"] == mapProjection.cellToImage(expectedCell), "the location anchor uses the same projection as the bake")
	var pngBytes: PackedByteArray = baked["image"].save_png_to_buffer()
	var bakedAgain := baker.bake(chunkCells, scripts, styles)
	_check(bakedAgain["image"].save_png_to_buffer() == pngBytes, "two identical bakes produce byte-identical PNGs")

	# A missing chunk stays transparent and is only reported; adding it never
	# shifts the image or the projection.
	chunkCells.erase(emptyChunk)
	var withoutEdge := baker.bake(chunkCells, scripts, styles)
	_check(withoutEdge["report"]["missingChunks"] == [emptyChunk] and withoutEdge["report"]["errors"].is_empty(), "a missing chunk is a coverage hole, not a failure")
	_check(withoutEdge["image"].get_size() == mapProjection.imageSize, "output bounds stay stable when an edge chunk is missing")
	chunkCells[emptyChunk] = _syntheticChunkCells(emptyChunk, tiles, 0)
	var withEdge := baker.bake(chunkCells, scripts, styles)
	_check(withEdge["image"].get_size() == mapProjection.imageSize and withEdge["report"]["missingChunks"].is_empty(), "output bounds stay stable when the edge chunk appears")

	# Overlapping seam cell: chunk (1,0) rewrites a cell owned by chunk (0,0).
	# Authoring overlaps are reported and resolved deterministically (the
	# later chunk in sorted order wins), never invented or hidden.
	var duplicateCells := _syntheticChunkCells(Vector2i(1, 0), tiles, 1)
	var stolenCell := coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(3, 3))
	for value in [stolenCell.x, stolenCell.y, 5, 0, 0, 0]:
		duplicateCells.append(value)
	var overlapInput := { Vector2i(0, 0): chunkCells[Vector2i(0, 0)], Vector2i(1, 0): duplicateCells }
	var overlapBake := baker.bake(overlapInput, {}, styles)
	_check(overlapBake["report"]["errors"].is_empty(), "an overlapping seam cell is not a bake failure")
	_check(overlapBake["report"]["overlappingCells"].size() == 1, "an overlapping seam cell is reported")
	var overlapPng: PackedByteArray = overlapBake["image"].save_png_to_buffer()
	_check(baker.bake(overlapInput, {}, styles)["image"].save_png_to_buffer() == overlapPng, "overlap resolution is deterministic")

	# Out-of-grid cell.
	var outOfGridBake := baker.bake({ Vector2i(0, 0): PackedInt32Array([10000, 10000, 5, 0, 0, 0]) }, {}, styles)
	_check(!outOfGridBake["report"]["errors"].is_empty() and outOfGridBake["report"]["outOfGridCells"].size() == 1, "an out-of-grid cell fails the bake")

	# Unknown style key: conspicuous fallback, reported once per key.
	var unknownCells := _syntheticChunkCells(Vector2i(0, 0), tiles, 9)
	var unknownBake := baker.bake({ Vector2i(0, 0): unknownCells }, {}, styles)
	_check(unknownBake["report"]["errors"].is_empty(), "unknown styles are reported, not bake failures")
	_check(unknownBake["report"]["unknownStyles"].size() == 1 and int(unknownBake["report"]["unknownStyles"][Vector3i(5, 9, 0)]) == tiles.x * tiles.y, "unknown keys are counted once per key")
	var unknownWorking := mapProjection.cellToWorkingPixel(coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(0, 0)))
	var unknownPixel: Color = unknownBake["image"].get_pixelv(Vector2i(unknownWorking.x, int(unknownWorking.y / 2)))
	_check(unknownPixel.r > 0.4 and unknownPixel.b > 0.4 and unknownPixel.g < 0.1 and unknownPixel.a > 0.4, "unknown styles render the magenta development fallback (blended with empty rows by the downsample)")

	# Invalid location anchors are errors; multi-chunk locations dedupe to the
	# first anchor in sorted chunk order and are reported.
	var badScripts := {
		Vector2i(0, 0): { "locations": { "Alpha": { "tiles": PackedVector2Array([Vector2i(1, 1)]), "pregenerated": true }, "Beta": { "tiles": PackedVector2Array([]), "pregenerated": true } }, "spawnPoints": {} },
		Vector2i(1, 0): { "locations": { "Alpha": { "tiles": PackedVector2Array([Vector2i(1, 1)]), "pregenerated": true } }, "spawnPoints": {} },
	}
	var badInput := { Vector2i(0, 0): chunkCells[Vector2i(0, 0)], Vector2i(1, 0): chunkCells[Vector2i(1, 0)] }
	var badBake := baker.bake(badInput, badScripts, styles)
	_check(badBake["report"]["errors"].size() == 1, "an empty anchor tile list is an error")
	_check(badBake["locations"].size() == 1, "the multi-chunk location dedupes to one anchor")
	var sharedAlpha: Array = badBake["report"]["sharedLocationIds"].get("Alpha", [])
	_check(sharedAlpha.size() == 2 and sharedAlpha[0] == Vector2i(0, 0) and sharedAlpha[1] == Vector2i(1, 0), "all declaring chunks are reported under the shared id")


func testRealDataBake() -> void:
	var mapProjection := OverworldMapProjection.cellForGrid(coordinates, WorldData.CHUNK_GRID, chunkTiles)
	var baker := OverworldMapBaker.new(coordinates, mapProjection, WorldData.CHUNK_GRID, chunkTiles)
	var chunkCells := {}
	var chunkScripts := {}
	for chunk in [Vector2i(8, 12), Vector2i(8, 13), Vector2i(9, 12), Vector2i(9, 13)]:
		var read := reader.readChunk(chunk, load(WorldData.getChunkPath(chunk)))
		_check(read["errors"].is_empty(), "real chunk {chunk} decodes cleanly".format({ "chunk": chunk }))
		chunkCells[chunk] = read["cells"]
		chunkScripts[chunk] = { "locations": read["locations"], "spawnPoints": read["spawnPoints"] }
	var baked := baker.bake(chunkCells, chunkScripts, MapTileStyles.new())
	var report: Dictionary = baked["report"]
	_check(report["errors"].is_empty() and report["overlappingCells"].is_empty(), "real neighbouring chunks seam without overlapping cells")
	_check(report["presentChunks"].size() == 4 and report["missingChunks"].size() == 284, "the full declared grid is reported around the real subset")
	_check(report["cells"] == 4 * chunkTiles.x * chunkTiles.y, "the real subset contributes 16384 cells")
	_check(baked["image"].get_size() == Vector2i(2304, 1152), "the real-data image matches the derived full-grid bounds")
	_check(report["unknownStyles"].is_empty(), "the authored palette covers the real subset's tile keys")
	var pngBytes: PackedByteArray = baked["image"].save_png_to_buffer()
	_check(baker.bake(chunkCells, chunkScripts, MapTileStyles.new())["image"].save_png_to_buffer() == pngBytes, "the real-data bake is deterministic")


func _syntheticChunkCells(chunk: Vector2i, tiles: Vector2i, atlasX: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for localX in tiles.x:
		for localY in tiles.y:
			var cell := coordinates.chunkTileToCell(chunk, Vector2i(localX, localY))
			cells.append(cell.x)
			cells.append(cell.y)
			cells.append(5)
			cells.append(atlasX)
			cells.append(0)
			cells.append(0)
	return cells