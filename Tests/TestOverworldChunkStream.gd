extends SceneTree

## Headless validation for the Overworld streaming caches and placement anchors
## (Docs/System Design/Journal/Overworld Map.md, step 6): per-chunk queue
## replacement, budgeted writes, the queued erase of an unloaded chunk, the
## object unload rule, cache bounds over a long traversal and the shared-anchor
## placement of location collisions.
## Run with: godot --headless --script res://Tests/TestOverworldChunkStream.gd

const HelperVariablesScript := preload("res://Globals/HelperVariables.gd")

var failures = 0
var checks = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var mergedTiles := TileMapLayer.new()
	mergedTiles.tile_set = load(WorldData.TEMPLATE_TILESET_PATH)

	_queue_replacement(mergedTiles)
	_budgeted_writes(mergedTiles)
	_queued_erase(mergedTiles)
	_unload_rule()
	_cache_bounds()
	_placement_anchors()

	mergedTiles.free()
	print("\nTestOverworldChunkStream: %d passed, %d failed" % [checks - failures, failures])
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _queue_replacement(mergedTiles: TileMapLayer) -> void:
	print("--- Queued cell ops replace per chunk ---")
	var cache := OverworldChunkStreamCache.new()
	var chunkA := Vector2i(3, 4)
	var chunkB := Vector2i(4, 4)
	var cellsA := _makeCells(Vector2i(0, 0), 3)
	cache.queueCellOp(chunkA, cellsA, true)
	cache.queueCellOp(chunkB, _makeCells(Vector2i(10, 10), 2), true)
	_check(cache.cellOpQueue.size() == 2, "each chunk queues its own op")
	cache.queueCellOp(chunkA, cellsA, false)
	_check(cache.cellOpQueue.size() == 2, "a second op for the same chunk replaces the queued one instead of stacking")
	_check(cache.cellOpQueue[0]["chunk"] == chunkB and cache.cellOpQueue[1]["chunk"] == chunkA, "the replacement op moves to the back of the queue")
	_check(cache.cellOpQueue[1]["write"] == false, "the replacement keeps the later op's write flag")
	_check(!cache.presentChunkCells.has(chunkA) and cache.presentChunkCells.has(chunkB), "the present flags follow the queued ops")
	cache.processCellOps(mergedTiles)
	_check(cache.cellOpQueue.is_empty(), "the queue drains once every op is processed")
	_check(mergedTiles.get_used_cells().size() == 2, "only the surviving write reaches the merged layer")
	mergedTiles.clear()


func _budgeted_writes(mergedTiles: TileMapLayer) -> void:
	print("\n--- Cell ops are budgeted across frames ---")
	var cache := OverworldChunkStreamCache.new()
	cache.queueCellOp(Vector2i(0, 0), _makeCells(Vector2i(100, 100), 10), true)
	cache.processCellOps(mergedTiles, 4)
	_check(mergedTiles.get_used_cells().size() == 4, "one call writes at most the given budget")
	_check(cache.cellOpQueue.size() == 1 and cache.cellOpQueue[0]["offset"] == 24, "a partial op resumes from its stored offset")
	cache.processCellOps(mergedTiles)
	_check(mergedTiles.get_used_cells().size() == 10, "the rest of the op finishes on later frames")
	_check(cache.cellOpQueue.is_empty(), "the drained queue is empty again")
	mergedTiles.clear()


func _queued_erase(mergedTiles: TileMapLayer) -> void:
	print("\n--- Unloading a chunk queues the erase of its cells ---")
	var cache := OverworldChunkStreamCache.new()
	var chunk := Vector2i(8, 12)
	var cells := _makeCells(Vector2i(500, 500), 5)
	cache.chunkCellDataCache[chunk] = cells
	cache.loadedChunkCells[chunk] = true
	cache.queueCellOp(chunk, cells, true)
	cache.processCellOps(mergedTiles)
	_check(mergedTiles.get_used_cells().size() == 5, "the loaded chunk's cells are in the merged layer")
	cache.unload(chunk)
	_check(!cache.loadedChunkCells.has(chunk), "unloading drops the chunk from the handled set")
	_check(cache.cellOpQueue.size() == 1 and !cache.cellOpQueue[0]["write"], "unloading queues an erase built from the cached cells")
	_check(cache.cellOpQueue[0]["data"] == cells, "the erase uses the chunk's own cached cells")
	cache.processCellOps(mergedTiles)
	_check(mergedTiles.get_used_cells().is_empty(), "processing the queued erase clears the chunk's cells")
	cache.unload(chunk)
	_check(cache.cellOpQueue.is_empty(), "unloading an already unloaded chunk queues nothing")


func _unload_rule() -> void:
	print("\n--- Objects outside the loaded neighbourhood unload ---")
	var center := Vector2i(8, 12)
	var loaded := [Vector2i(9, 12), Vector2i(7, 12), Vector2i(8, 13)]
	_check(OverworldChunkStreamCache.isKept(center, center, loaded), "the player's chunk keeps its cells and objects")
	_check(OverworldChunkStreamCache.isKept(Vector2i(8, 13), center, loaded), "a loaded neighbour keeps its cells and objects")
	_check(!OverworldChunkStreamCache.isKept(Vector2i(5, 5), center, loaded), "a chunk outside the loaded neighbourhood unloads")
	_check(!OverworldChunkStreamCache.isKept(Vector2i(9, 14), center, loaded), "a chunk that was never loaded unloads")


func _cache_bounds() -> void:
	print("\n--- A long traversal keeps the caches bounded ---")
	var cache := OverworldChunkStreamCache.new()
	var scene: PackedScene = load("res://Overworld/OverworldTileChunkTemplate.tscn")
	var helperVars = HelperVariablesScript.new()
	var adjacentDirections: Array = helperVars.adjacentDirections
	helperVars.free()
	var radius := OverworldChunkStreamCache.PRELOAD_RADIUS
	var keepSize := OverworldChunkStreamCache.keptChunks(Vector2i.ZERO).size()
	_check(radius >= 1, "the kept radius covers the loaded neighbourhood")
	_check(keepSize == (radius * 2 + 1) * (radius * 2 + 1), "the kept set is the preload square around the player")
	_check(OverworldChunkStreamCache.keptChunks(Vector2i(4, 4)).has(Vector2i(4 + radius, 4 + radius)), "the kept set reaches the preload ring")
	var worstScenes := 0
	var worstCells := 0
	var worstLoaded := 0
	for step in range(120):
		var center := Vector2i(step, 7)
		var loaded := []
		for direction in adjacentDirections:
			loaded.append(center + direction)
		# A crossing: load the new neighbourhood, then drop what is behind.
		cache.chunkScenes[center] = scene
		cache.chunkCellDataCache[center] = _makeCells(Vector2i(step * 4, 0), 2)
		cache.loadedChunkCells[center] = true
		cache.presentChunkCells[center] = true
		for loadedChunk in cache.loadedChunkCells.keys():
			if !OverworldChunkStreamCache.isKept(loadedChunk, center, loaded):
				cache.unload(loadedChunk)
		cache.prune(OverworldChunkStreamCache.keptChunks(center))
		worstScenes = maxi(worstScenes, cache.chunkScenes.size())
		worstCells = maxi(worstCells, cache.chunkCellDataCache.size())
		worstLoaded = maxi(worstLoaded, cache.loadedChunkCells.size())
	_check(worstScenes <= keepSize, "120 crossings keep at most the kept set of parsed scenes (worst %d)" % worstScenes)
	_check(worstCells <= keepSize, "120 crossings keep at most the kept set of cell caches (worst %d)" % worstCells)
	_check(worstLoaded <= 9, "120 crossings keep at most the loaded neighbourhood of handled chunks (worst %d)" % worstLoaded)
	_check(!cache.chunkCellDataCache.has(Vector2i(0, 7)), "chunks left far behind are evicted from the cell cache")
	_check(!cache.chunkScenes.has(Vector2i(0, 7)), "chunks left far behind are evicted from the scene cache")
	_check(cache.chunkCellDataCache.has(Vector2i(119, 7)), "the current chunk keeps its cached cells")
	_check(cache.presentChunkCells.has(Vector2i(119, 7)), "a present chunk is never evicted while it is still in the merged layer")


func _placement_anchors() -> void:
	print("\n--- Placement goes through the shared anchor ---")
	var overworld: TileMap = load("res://Overworld/Overworld.gd").new()
	overworld.name = "Overworld"
	var chunkTileSet := TileSet.new()
	chunkTileSet.tile_size = WorldData.CHUNK_MAP_TILE_SIZE
	overworld.tile_set = chunkTileSet
	overworld.add_child(load("res://Overworld/OverworldTileChunkTemplate.tscn").instantiate())
	var coordinates := OverworldCoordinates.makeHeadless()
	var anchors := [
		[Vector2i(8, 12), Vector2i(40, 38)],
		[Vector2i(8, 17), Vector2i(20, 36)],
		[Vector2i(0, 0), Vector2i(0, 0)],
		[Vector2i(11, 23), Vector2i(63, 63)],
	]
	for anchor in anchors:
		var chunk: Vector2i = anchor[0]
		var tile: Vector2i = anchor[1]
		var shape: CollisionShape2D = overworld.createCollisionWithPosition(tile, chunk)
		var expected := coordinates.chunkTileToWorld(chunk, tile)
		var cell := coordinates.chunkTileToCell(chunk, tile)
		var u := coordinates.cellToWorld(cell + Vector2i.RIGHT) - expected
		var v := coordinates.cellToWorld(cell + Vector2i.DOWN) - expected
		var points: PackedVector2Array = shape.shape.points
		# set_point_cloud() returns the closed hull, so the first corner repeats.
		var corners := []
		for point in points:
			if !corners.has(point):
				corners.append(point)
		var diagonals := [corners[0].distance_to(corners[2]), corners[1].distance_to(corners[3])]
		diagonals.sort()
		var expectedDiagonals := [(u + v).length(), (u - v).length()]
		expectedDiagonals.sort()
		_check(shape.position.is_equal_approx(expected), "the collision area sits on the shared anchor for chunk {chunk} tile {tile}".format({ "chunk": chunk, "tile": tile }))
		_check(corners.size() == 4, "the collision diamond has four distinct corners")
		_check(is_equal_approx(diagonals[0], expectedDiagonals[0]) and is_equal_approx(diagonals[1], expectedDiagonals[1]), "the diamond spans exactly the tile it was authored for")
		_check((corners[0] + corners[1] + corners[2] + corners[3]).length() < 0.001, "the diamond is centred on its own origin")
		shape.free()
	# The legacy inline offsets are gone: every placement goes through
	# OverworldCoordinates now.
	var overworldSource := FileAccess.get_file_as_string("res://Overworld/Overworld.gd")
	_check(!overworldSource.contains("32 * 24"), "Overworld.gd no longer hand-rolls the chunk offset")
	overworld.free()
	coordinates.dispose()


## Six-int cell records in the shared [cellX, cellY, sourceId, atlasX, atlasY,
## alternative] layout, one per cell from origin.x onward.
func _makeCells(origin: Vector2i, count: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for index in count:
		cells.append(origin.x + index)
		cells.append(origin.y)
		cells.append(0)
		cells.append(0)
		cells.append(0)
		cells.append(0)
	return cells


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)

