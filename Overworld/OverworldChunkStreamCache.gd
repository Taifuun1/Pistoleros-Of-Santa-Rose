extends RefCounted
class_name OverworldChunkStreamCache

## Chunk scene / cell cache, background-parse bookkeeping and the budgeted
## merged-layer write queue (Docs/System Design/Journal/Overworld Map.md, step
## 6). Extracted from Overworld.gd so the streaming bookkeeping is testable
## without a scene tree: Overworld.gd keeps the chunk-crossing decisions, this
## owns the caches and their bounds.

const CELL_OP_BUDGET := 8192
## Chunks kept cached beyond the loaded neighbourhood: the player's chunk plus
## this radius, matching Overworld.preloadChunkScenes().
const PRELOAD_RADIUS := 2

## chunk -> PackedScene (null = the chunk has no scene file).
var chunkScenes := {}
## path -> chunk, for scenes parsing on a background thread.
var pendingChunkPaths := {}
## chunk -> PackedInt32Array of six-int cell records in shared-cell coordinates.
var chunkCellDataCache := {}
## Chunks handled: cells in the merged layer or no scene file.
var loadedChunkCells := {}
## Chunks whose cells are in the merged layer once the queued ops have run.
var presentChunkCells := {}
## Chunks that became needed while their scene was still parsing.
var pendingChunkLoads := []
## Queued cell operations: { "chunk", "data", "offset", "write" }.
var cellOpQueue := []


## True when a chunk's cells and objects should stay loaded: the player's chunk
## or one of its loaded neighbours.
static func isKept(chunk: Vector2i, currentChunk: Vector2i, loadedChunks: Array) -> bool:
	return chunk == currentChunk or loadedChunks.has(chunk)


## The chunks that stay cached around a centre chunk: itself plus
## PRELOAD_RADIUS, which covers the loaded neighbourhood and the preload ring.
static func keptChunks(centerChunk: Vector2i) -> Array:
	var kept := []
	for x in range(centerChunk.x - PRELOAD_RADIUS, centerChunk.x + PRELOAD_RADIUS + 1):
		for y in range(centerChunk.y - PRELOAD_RADIUS, centerChunk.y + PRELOAD_RADIUS + 1):
			kept.append(Vector2i(x, y))
	return kept


## Starts a background parse for the chunk's scene; true when a request was
## issued.
func requestScene(chunk: Vector2i, path: String) -> bool:
	if chunkScenes.has(chunk) or pendingChunkPaths.has(path):
		return false
	if !ResourceLoader.exists(path):
		return false
	# Cache-ignore: the scene cache owns these scenes, so ResourceLoader must
	# not keep a second global reference after the Overworld is freed.
	if !ResourceLoader.load_threaded_request(path, "", false, ResourceLoader.CACHE_MODE_IGNORE):
		return false
	pendingChunkPaths[path] = chunk
	return true


## Moves finished background parses into the scene cache.
func pollScenes() -> void:
	for path in pendingChunkPaths.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			chunkScenes[pendingChunkPaths[path]] = ResourceLoader.load_threaded_get(path)
			pendingChunkPaths.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			chunkScenes[pendingChunkPaths[path]] = null
			pendingChunkPaths.erase(path)


## True when getScene() can return right away: cached (loaded or missing), not
## requested, or its background parse is finished.
func isSceneReady(chunk: Vector2i, path: String) -> bool:
	if chunkScenes.has(chunk):
		return true
	if !pendingChunkPaths.has(path):
		return true
	return ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED

## The chunk's PackedScene (cached, from a finished background parse, or loaded
## directly), or null when there is no chunk scene file. Call isSceneReady()
## first: a still-parsing path would wait for the whole loader queue here.
func getScene(chunk: Vector2i, path: String) -> PackedScene:
	if chunkScenes.has(chunk):
		return chunkScenes[chunk]
	if pendingChunkPaths.has(path):
		chunkScenes[chunk] = ResourceLoader.load_threaded_get(path)
		pendingChunkPaths.erase(path)
		return chunkScenes[chunk]
	if !ResourceLoader.exists(path):
		return null
	chunkScenes[chunk] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return chunkScenes[chunk]


## Queues a write/erase of the chunk's cells, replacing any queued op for the
## same chunk (a full rewrite is harmless; erasing absent cells is a no-op).
func queueCellOp(chunk: Vector2i, cellData: PackedInt32Array, write: bool) -> void:
	for index in range(cellOpQueue.size() - 1, -1, -1):
		if cellOpQueue[index]["chunk"] == chunk:
			cellOpQueue.remove_at(index)
	if write:
		presentChunkCells[chunk] = true
	else:
		presentChunkCells.erase(chunk)
	cellOpQueue.append({ "chunk": chunk, "data": cellData, "offset": 0, "write": write })


## Runs queued cell writes/erases against the merged layer, at most budget cells
## per call, so a chunk transition spreads over frames instead of stalling one.
func processCellOps(mergedTiles: TileMapLayer, budget := CELL_OP_BUDGET) -> void:
	var remaining := budget
	while remaining > 0 and !cellOpQueue.is_empty():
		var op = cellOpQueue[0]
		var data: PackedInt32Array = op["data"]
		var offset: int = op["offset"]
		var end: int = min(offset + remaining * 6, data.size())
		if op["write"]:
			var writeIndex := offset
			while writeIndex < end:
				mergedTiles.set_cell(
					Vector2i(data[writeIndex], data[writeIndex + 1]),
					data[writeIndex + 2],
					Vector2i(data[writeIndex + 3], data[writeIndex + 4]),
					data[writeIndex + 5]
				)
				writeIndex += 6
		else:
			var eraseIndex := offset
			while eraseIndex < end:
				mergedTiles.erase_cell(Vector2i(data[eraseIndex], data[eraseIndex + 1]))
				eraseIndex += 6
		remaining -= (end - offset) / 6
		if end >= data.size():
			cellOpQueue.pop_front()
		else:
			op["offset"] = end


## Unloads a chunk: drops it from the handled set and queues an erase of its
## cached cells.
func unload(chunk: Vector2i) -> void:
	if !loadedChunkCells.has(chunk):
		return
	loadedChunkCells.erase(chunk)
	queueCellOp(chunk, chunkCellDataCache.get(chunk, PackedInt32Array()), false)


## Releases every cache and forces any in-flight background parse to finish so
## its loader is not left pending when the owning scene is freed. Called from
## Overworld._exit_tree().
func dispose() -> void:
	for path in pendingChunkPaths.keys():
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_get(path)
	pendingChunkPaths.clear()
	pendingChunkLoads.clear()
	cellOpQueue.clear()
	chunkScenes.clear()
	chunkCellDataCache.clear()
	loadedChunkCells.clear()
	presentChunkCells.clear()


## Drops cached scenes and cell data outside the kept set, so a long traversal
## cannot grow the caches without bound. Cell data for a chunk still present in
## the merged layer is always kept: unloading needs it to erase.
func prune(kept: Array) -> void:
	for chunk in chunkScenes.keys():
		if !kept.has(chunk):
			chunkScenes.erase(chunk)
	for chunk in chunkCellDataCache.keys():
		if !kept.has(chunk) and !presentChunkCells.has(chunk):
			chunkCellDataCache.erase(chunk)

