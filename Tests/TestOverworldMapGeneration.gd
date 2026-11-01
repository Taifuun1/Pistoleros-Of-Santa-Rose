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
	print("\n--- Malformed chunk data ---")
	testMalformedData()
	print("\n--- Authored palette ---")
	testAuthoredPalette()
	print("\n--- Overview aggregation ---")
	testOverviewAggregation()
	print("\n--- Synthetic bake fixtures ---")
	testSyntheticBakes()
	print("\n--- Real-data subset bake ---")
	testRealDataBake()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	coordinates.dispose()
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


func testMalformedData() -> void:
	var fixturePath := "user://malformed_overworld_chunk.tscn"
	var fixture := FileAccess.open(fixturePath, FileAccess.WRITE)
	_check(fixture != null, "the malformed tile_data fixture opens")
	if fixture == null:
		return
	# Scene-state loading preserves the malformed records without TileMap.set()
	# validating or normalizing them first.
	fixture.store_string("[gd_scene format=3]\n\n[node name=\"Chunk\" type=\"TileMap\"]\nlayer_0/tile_data = PackedInt32Array(0, 0, 0, 1, 0)\n")
	fixture.close()
	var packedScene: PackedScene = load(fixturePath)
	var read := reader.readChunk(Vector2i(8, 12), packedScene)
	_check(!read["errors"].is_empty(), "incomplete tile_data records are reported")
	_check(read["cells"].is_empty(), "malformed tile_data returns no partial cells")
	_check(read["locations"].is_empty() and read["spawnPoints"].is_empty(), "a malformed chunk does not instantiate its data script")
	DirAccess.remove_absolute(fixturePath)


func testAuthoredPalette() -> void:
	var styles := MapTileStyles.new()
	var groundColors := []
	for sourceId in [1, 2, 3, 4, 5, 6]:
		groundColors.append(MapTileStyles.SOURCE_GROUND[sourceId])
	var distinctGrounds := {}
	for color in groundColors:
		distinctGrounds[color] = true
	_check(distinctGrounds.size() == groundColors.size(), "every biome has a distinct authored ground color")

	# The sampled palette gave Grasslands the canyon's orange (it averaged each
	# tile's dirt front face); these are the two keys that used to collide.
	var grasslandGround := styles.styleForId(styles.styleIdFor(3, 0, 0))
	var canyonGround := styles.styleForId(styles.styleIdFor(1, 4, 0))
	_check(grasslandGround["color"] != canyonGround["color"], "grasslands no longer share the canyon's sampled color")

	var canyonRock := styles.styleForId(styles.styleIdFor(1, 8, 1))
	_check(styles.styleIdFor(1, 4, 0) != styles.styleIdFor(1, 8, 1), "distinct Grande Cañón keys get distinct styles")
	_check(canyonGround["feature"] == MapTileStyles.FEATURE_GROUND and canyonRock["feature"] == MapTileStyles.FEATURE_MOUNTAIN, "the Grande Cañón rock band classifies as mountain")
	_check(canyonGround["color"] != canyonRock["color"], "Grande Cañón ground and rock read differently")

	# Forest cover follows the classification doc: Grasslands rows 1-3, Wild West
	# row 3 (tiles 5-9), Snowy Mountains row 3 (tiles 5-9) and Prairie row 3.
	# Rocky Hills' green rows are grass, not forest.
	var grassForest := styles.styleForId(styles.styleIdFor(3, 5, 0))
	var grassGround := styles.styleForId(styles.styleIdFor(3, 1, 0))
	var grassCliff := styles.styleForId(styles.styleIdFor(3, 11, 0))
	_check(grassForest["feature"] == MapTileStyles.FEATURE_FOREST, "the Grasslands forest tiles classify as forest")
	_check(grassGround["feature"] == MapTileStyles.FEATURE_GROUND, "the first three Grasslands tiles stay grass")
	_check(grassCliff["feature"] == MapTileStyles.FEATURE_CLIFF, "the tall Grasslands cliff tile classifies as cliff")
	_check(grassForest["color"] != grassGround["color"] and grassCliff["color"] != grassForest["color"], "Grasslands grass, forest and cliff read differently")
	_check(grassCliff["color"] != MapTileStyles.FEATURE_COLORS[MapTileStyles.FEATURE_MOUNTAIN], "cliffs read darker than rocks")

	var plainsForest := styles.styleForId(styles.styleIdFor(5, 4, 2))
	var plainsGrass := styles.styleForId(styles.styleIdFor(5, 1, 2))
	var plainsRock := styles.styleForId(styles.styleIdFor(5, 0, 1))
	_check(plainsForest["feature"] == MapTileStyles.FEATURE_FOREST and plainsGrass["feature"] == MapTileStyles.FEATURE_GROUND, "Wild West row 3 splits grass and forest")
	_check(plainsRock["feature"] == MapTileStyles.FEATURE_MOUNTAIN, "the Wild West rock row classifies as mountain")

	var rockyGrass := styles.styleForId(styles.styleIdFor(2, 0, 0))
	var rockyRock := styles.styleForId(styles.styleIdFor(2, 0, 2))
	var rockyCliff := styles.styleForId(styles.styleIdFor(2, 3, 2))
	_check(rockyGrass["feature"] == MapTileStyles.FEATURE_GROUND and rockyRock["feature"] == MapTileStyles.FEATURE_MOUNTAIN, "Rocky Hills grass and rock rows classify differently")
	_check(rockyCliff["feature"] == MapTileStyles.FEATURE_CLIFF, "the Rocky Hills solid tiles classify as cliffs")
	_check(styles.styleIdFor(2, 0, 0) != styles.styleIdFor(2, 0, 2) and rockyGrass["color"] != rockyRock["color"], "Rocky Hills grass and rock read differently")

	var canyonCliff := styles.styleForId(styles.styleIdFor(1, 6, 2))
	_check(canyonCliff["feature"] == MapTileStyles.FEATURE_CLIFF and canyonCliff["color"] != canyonGround["color"], "the Grande Cañón cliff row classifies as cliff")

	var prairieForest := styles.styleForId(styles.styleIdFor(4, 1, 2))
	var prairieCliff := styles.styleForId(styles.styleIdFor(4, 7, 2))
	var prairieTileTen := styles.styleForId(styles.styleIdFor(4, 9, 2))
	_check(prairieForest["feature"] == MapTileStyles.FEATURE_FOREST and prairieCliff["feature"] == MapTileStyles.FEATURE_CLIFF, "the Prairie forest and cliff tiles split correctly")
	_check(prairieTileTen["feature"] == MapTileStyles.FEATURE_GROUND, "Prairie tile 10 is grass, not forest")

	# Snowy Mountains: rock row, tents/forest row, cliff/water row, water row.
	var snowyRock := styles.styleForId(styles.styleIdFor(6, 0, 1))
	var snowyGround := styles.styleForId(styles.styleIdFor(6, 3, 0))
	var snowyTent := styles.styleForId(styles.styleIdFor(6, 0, 2))
	var snowyForest := styles.styleForId(styles.styleIdFor(6, 4, 2))
	var snowyCliff := styles.styleForId(styles.styleIdFor(6, 0, 3))
	var snowyWater := styles.styleForId(styles.styleIdFor(6, 0, 4))
	_check(snowyRock["feature"] == MapTileStyles.FEATURE_MOUNTAIN and snowyRock["color"] != snowyGround["color"], "Snowy Mountains rock reads differently from the ice ground")
	_check(snowyGround["feature"] == MapTileStyles.FEATURE_GROUND, "the Snowy Mountains ground row stays ground")
	_check(snowyTent["feature"] == MapTileStyles.FEATURE_STRUCTURE, "the Snowy Mountains tent tiles classify as structure")
	_check(snowyForest["feature"] == MapTileStyles.FEATURE_FOREST, "the Snowy Mountains forest tiles classify as forest")
	_check(snowyCliff["feature"] == MapTileStyles.FEATURE_CLIFF, "the Snowy Mountains cliff tiles classify as cliff")
	_check(snowyWater["feature"] == MapTileStyles.FEATURE_WATER, "the Snowy Mountains water row classifies as water")

	# Tileset terrain authoring outranks the atlas tables.
	_check(styles.styleForId(styles.styleIdFor(2, 0, 5))["feature"] == MapTileStyles.FEATURE_WATER, "the Rocky Hills water row classifies as water")
	_check(styles.styleForId(styles.styleIdFor(3, 0, 8))["feature"] == MapTileStyles.FEATURE_WATER, "the Grasslands water row classifies as water")
	var swamp := styles.styleForId(styles.styleIdFor(3, 0, 9))
	_check(swamp["feature"] == MapTileStyles.FEATURE_SWAMP, "the Grasslands swamp row classifies as swamp")
	_check(swamp["color"] != MapTileStyles.FEATURE_COLORS[MapTileStyles.FEATURE_WATER] and swamp["color"] != MapTileStyles.FEATURE_COLORS[MapTileStyles.FEATURE_FOREST], "swamp reads differently from water and forest")
	_check(styles.styleForId(styles.styleIdFor(3, 0, 4))["feature"] == MapTileStyles.FEATURE_STRUCTURE, "fence terrain classifies as structure")
	_check(styles.styleForId(styles.styleIdFor(5, 5, 3))["feature"] == MapTileStyles.FEATURE_TRACK, "train-track terrain classifies as track")
	_check(styles.styleForId(styles.styleIdFor(3, 0, 6))["feature"] == MapTileStyles.FEATURE_POWERLINE, "powerline terrain classifies as powerline")

	var tileSet: TileSet = load(WorldData.TEMPLATE_TILESET_PATH)
	var tileCount := 0
	for sourceIndex in tileSet.get_source_count():
		var source: TileSetAtlasSource = tileSet.get_source(tileSet.get_source_id(sourceIndex))
		var grid := source.get_atlas_grid_size()
		for atlasY in grid.y:
			for atlasX in grid.x:
				if source.has_tile(Vector2i(atlasX, atlasY)):
					tileCount += 1
	_check(styles.styleCount() == tileCount, "the authored palette covers every tile in the tileset ({count})".format({ "count": tileCount }))

	# The distinction must survive rasterization, not only classification.
	var grid := Rect2i(0, 0, 1, 1)
	var tiles := Vector2i(4, 4)
	var mapProjection := OverworldMapProjection.cellForGrid(coordinates, grid, tiles)
	var baker := OverworldMapBaker.new(coordinates, mapProjection, grid, tiles)
	var groundCell := coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(0, 0))
	var rockCell := coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(1, 0))
	var cells := PackedInt32Array()
	for value in [groundCell.x, groundCell.y, 1, 4, 0, 0, rockCell.x, rockCell.y, 1, 8, 1, 0]:
		cells.append(value)
	var baked := baker.bake({ Vector2i(0, 0): cells }, {}, styles)
	var image: Image = baked["image"]
	var groundPixel: Color = image.get_pixelv(Vector2i(mapProjection.cellToImage(groundCell)))
	var rockPixel: Color = image.get_pixelv(Vector2i(mapProjection.cellToImage(rockCell)))
	_check(groundPixel != rockPixel and groundPixel.a > 0.9 and rockPixel.a > 0.9, "Grande Cañón ground and rock bake as different opaque pixels")


## Overview/LOD aggregation: thin features survive generalization, area features
## need a share of the block, and missing chunks stay transparent.
func testOverviewAggregation() -> void:
	var grid := Rect2i(0, 0, 1, 1)
	var tiles := Vector2i(8, 8)
	var mapProjection := OverworldMapProjection.cellForGrid(coordinates, grid, tiles)
	var baker := OverworldMapBaker.new(coordinates, mapProjection, grid, tiles)
	var styles := MapTileStyles.new()
	var block := Vector2i(4, 4)
	var cellMin := mapProjection.cellMin
	var cells := _syntheticChunkCells(Vector2i(0, 0), tiles, 0)
	# Block 0: one water cell. Block 1: one forest cell. Block 2: five forest
	# cells. Block 3: untouched ground.
	cells.append_array(PackedInt32Array([cellMin.x, cellMin.y, 2, 0, 5, 0]))
	cells.append_array(PackedInt32Array([cellMin.x + 4, cellMin.y, 3, 5, 0, 0]))
	for offset in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(0, 5), Vector2i(1, 5)]:
		cells.append_array(PackedInt32Array([cellMin.x + offset.x, cellMin.y + offset.y, 3, 5, 0, 0]))

	var baked := baker.bake({ Vector2i(0, 0): cells }, {}, styles, block)
	var overview: Image = baked["overview"]
	_check(overview.get_size() == Vector2i(2, 2), "the overview aggregates the grid into 4x4-cell blocks")
	var waterColor: Color = MapTileStyles.FEATURE_COLORS[MapTileStyles.FEATURE_WATER]
	var forestColor: Color = MapTileStyles.FEATURE_COLORS[MapTileStyles.FEATURE_FOREST]
	var groundColor: Color = styles.styleForId(styles.styleIdFor(5, 0, 0))["color"]
	_check(overview.get_pixel(0, 0) == waterColor, "a single water cell wins its overview block")
	_check(overview.get_pixel(1, 0) == groundColor, "forest below the area share keeps the block as ground")
	_check(overview.get_pixel(0, 1) == forestColor, "forest covering enough of a block wins it")
	_check(overview.get_pixel(1, 1) == groundColor, "a fully ground block stays ground")
	_check(baker.bake({ Vector2i(0, 0): cells }, {}, styles, block)["overview"].save_png_to_buffer() == overview.save_png_to_buffer(), "the overview bake is deterministic")

	var wideGrid := Rect2i(0, 0, 2, 1)
	var wideProjection := OverworldMapProjection.cellForGrid(coordinates, wideGrid, tiles)
	var wideBaker := OverworldMapBaker.new(coordinates, wideProjection, wideGrid, tiles)
	var wide: Image = wideBaker.bake({ Vector2i(0, 0): cells }, {}, styles, block)["overview"]
	var transparent := 0
	for y in wide.get_height():
		for x in wide.get_width():
			if wide.get_pixel(x, y).a < 0.5:
				transparent += 1
	_check(transparent > 0, "missing chunks stay transparent in the overview")


## Reference: the original Overworld.gd decode, preserved here as the oracle.
func _referenceBaseCell(chunk: Vector2i) -> Vector2i:
	var chunkMap := TileMap.new()
	var chunkTileSet := TileSet.new()
	chunkTileSet.tile_size = WorldData.CHUNK_MAP_TILE_SIZE
	chunkMap.tile_set = chunkTileSet
	var templateMap := TileMap.new()
	templateMap.tile_set = load(WorldData.TEMPLATE_TILESET_PATH)
	var origin = Vector2i(chunkMap.map_to_local(chunk).x - (32 * 24), chunkMap.map_to_local(chunk).y - (32 * 6))
	var baseCell := templateMap.local_to_map(origin)
	chunkMap.free()
	templateMap.free()
	return baseCell


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
	var unknownCell := coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(0, 0))
	var unknownImagePosition := mapProjection.cellToImage(unknownCell)
	var unknownPixel: Color = unknownBake["image"].get_pixelv(Vector2i(roundi(unknownImagePosition.x), roundi(unknownImagePosition.y)))
	_check(unknownPixel.r > 0.4 and unknownPixel.b > 0.4 and unknownPixel.g < 0.1 and unknownPixel.a > 0.4, "unknown styles render the magenta development fallback in the final image")

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
	_check(baked["image"].get_size() == mapProjection.imageSize, "the real-data image matches the derived full-grid bounds")
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