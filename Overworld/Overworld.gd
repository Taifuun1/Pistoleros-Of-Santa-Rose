extends TileMap

@onready var spawnPointInstance = preload("res://Overworld/OverworldSpawnpoint.tscn")

var currentChunk = null
var currentlyLoadedChunks = []
var loadingChunk = true

# Parsed chunk scenes cached by chunk location (see getChunkScene(); null
# entries are chunks that have no scene file).
var chunkScenes = {}
# Chunk scene paths currently parsing on a background thread (path -> chunk).
var pendingChunkPaths = {}
# Chunk tile cells in shared template-grid coordinates (the same cells the
# old per-cell copy wrote), decoded once from each chunk scene's baked
# tile_data and cached flat as [cellX, cellY, sourceId, atlasX, atlasY,
# alternative] per cell. Writing them straight into the one merged
# TileMapLayer keeps the old rendering exactly; the writes/erases are
# spread across frames (see processCellOps()) so chunk crossings don't
# stall a single frame.
var chunkCellDataCache = {}
# Chunk locations handled: cells in $MergedTiles or no scene file.
var loadedChunkCells = {}
# Chunk locations whose cells are present in $MergedTiles once the queued
# cell operations have run.
var presentChunkCells = {}
# Chunks that became needed while their scene was still parsing on the
# background thread; retried every frame until the parse finishes.
var pendingChunkLoads = []
# Queued cell operations: { "chunk": location, "data": PackedInt32Array,
# "offset": int, "write": bool }, processed up to cellOpBudget cells a frame.
var cellOpQueue = []
const cellOpBudget = 8192

# Shared chunk/cell decoding (extracted; see OverworldChunkReader.gd and
# OverworldCoordinates.gd). Built lazily because _process's init() is the
# live entry point.
var _coordinates: OverworldCoordinates = null
var _chunkReader: OverworldChunkReader = null


func _getCoordinates() -> OverworldCoordinates:
	if _coordinates == null:
		_coordinates = OverworldCoordinates.new(self, $OverworldTileChunkTemplate)
	return _coordinates


func _getChunkReader() -> OverworldChunkReader:
	if _chunkReader == null:
		_chunkReader = OverworldChunkReader.new(_getCoordinates())
	return _chunkReader


func _process(_delta):
	if currentChunk == null:
		init()
	pollChunkScenes()
	processPendingChunkLoads()
	processCellOps()
	if !loadingChunk and local_to_map(to_local($Actors/PlayerOverworldActor.position)) != currentChunk:
		loadingChunk = true
		currentChunk = local_to_map($Actors/PlayerOverworldActor.position)
		var newCurrentlyLoadedChunks = getAdjacentChunks()
		setAdjacentChunks(newCurrentlyLoadedChunks)
		currentlyLoadedChunks = newCurrentlyLoadedChunks
		removeFarawayObjects()
		# Zone change check after entering the new chunk.
		MusicPlayer.on_overworld_chunk(currentChunk)
		# Parse the chunk scenes the next crossing will need on a background
		# thread.
		preloadChunkScenes()
		loadingChunk = false

func init() -> void:
	currentChunk = Overworld.spawnChunk
	if !setChunk() and !pendingChunkLoads.has(currentChunk):
		pendingChunkLoads.append(currentChunk)
	var newCurrentlyLoadedChunks = getAdjacentChunks()
	setAdjacentChunks(newCurrentlyLoadedChunks)
	currentlyLoadedChunks = newCurrentlyLoadedChunks
	$Actors/PlayerOverworldActor.position = Vector2i(map_to_local(Overworld.spawnChunk) - $OverworldTileChunkTemplate.map_to_local(HelperVariables.overworldChunkSize / 2) + $OverworldTileChunkTemplate.map_to_local(Overworld.spawnTile))
	loadingChunk = false
	# Zone music for the chunk the player spawns in (MusicPlayer decides by
	# the zone bands in Data/Music/MusicData.gd; only zone changes restart).
	MusicPlayer.on_overworld_chunk(currentChunk)
	# Parse nearby chunk scenes ahead of time on a background thread.
	preloadChunkScenes()


#######################
### Chunk functions ###
#######################

func setChunk(chunkLocation: Vector2i = currentChunk) -> bool:
	# Returns false when the chunk scene is still parsing on the background
	# loader; the caller retries later (see pendingChunkLoads).
	if !isChunkSceneReady(chunkLocation):
		return false
	var chunkScene = getChunkScene(chunkLocation)
	if chunkScene == null:
		push_warning("No chunk for x: {x}, y: {y}".format({ "x": chunkLocation.x, "y": chunkLocation.y }))
		# Mark missing chunks as handled so they are not retried every frame.
		loadedChunkCells[chunkLocation] = true
		return true
	var chunkRead = _getChunkReader().readChunk(chunkLocation, chunkScene)
	var cellData: PackedInt32Array = chunkRead["cells"]
	chunkCellDataCache[chunkLocation] = cellData
	loadedChunkCells[chunkLocation] = true
	if !presentChunkCells.has(chunkLocation):
		queueCellOp(chunkLocation, cellData, true)
	# Per-chunk data scripts (locations / spawnPoints) are read by the shared
	# chunk reader on a bare script instance; the scene never enters the tree.
	var locations = chunkRead["locations"]
	for location in locations:
		if !isOverworldObjectLoaded(location, "Locations"):
			createLocation(location, chunkLocation, locations[location].tiles, locations[location].pregenerated)
	var spawnPoints = chunkRead["spawnPoints"]
	for actorName in spawnPoints:
		if !isOverworldObjectLoaded(actorName, "Spawnpoints"):
			createSpawnPoint(
				actorName,
				spawnPoints[actorName].type,
				Vector2i(map_to_local(chunkLocation) - Vector2(32 * 24, 32 * 6) + $OverworldTileChunkTemplate.map_to_local(spawnPoints[actorName].tiles[0])),
				spawnPoints[actorName].chance,
				spawnPoints[actorName].maximum
			)
	return true

func setAdjacentChunks(newAdjacentChunks: Array) -> void:
	# Erase every merged chunk that is neither the player's chunk nor one of
	# its neighbours (also covers chunks left over from earlier positions,
	# e.g. the spawn chunk).
	for loadedChunkLocation in loadedChunkCells.keys():
		if loadedChunkLocation != currentChunk and !newAdjacentChunks.has(loadedChunkLocation):
			unloadChunk(loadedChunkLocation)
	for currentAdjacentChunk in newAdjacentChunks:
		if loadedChunkCells.has(currentAdjacentChunk):
			continue
		# Chunks whose scene is still parsing load on a later frame instead
		# of blocking this one.
		if !setChunk(currentAdjacentChunk) and !pendingChunkLoads.has(currentAdjacentChunk):
			pendingChunkLoads.append(currentAdjacentChunk)

func getAdjacentChunks() -> Array:
	var adjacentChunks = []
	for adjacentChunkDirection in HelperVariables.adjacentDirections:
		var adjacentChunkLocation = currentChunk + adjacentChunkDirection
		adjacentChunks.append(adjacentChunkLocation)
	return adjacentChunks

# The chunk's first cell on the shared template grid (the old setTiles()
# formula's base offset for the chunk's local keys).
func getChunkBaseCell(chunkLocation: Vector2i) -> Vector2i:
	return _getCoordinates().chunkToBaseCell(chunkLocation)

# The chunk's tiles as shared template-grid cells (exactly the cells the
# old setTiles() copy used to write), decoded once from the scene's baked
# tile_data and cached. Chunks without a scene decode to an empty array.
func getChunkCellData(chunkLocation: Vector2i) -> PackedInt32Array:
	if chunkCellDataCache.has(chunkLocation):
		return chunkCellDataCache[chunkLocation]
	var cellData = PackedInt32Array()
	if chunkScenes.has(chunkLocation) and chunkScenes[chunkLocation] != null:
		cellData = _getChunkReader().readCells(chunkLocation, chunkScenes[chunkLocation])
	chunkCellDataCache[chunkLocation] = cellData
	return cellData

# Queues a write/erase of the chunk's cells, processed a slice per frame by
# processCellOps(). Any already queued op for the same chunk is replaced (a
# fully rewritten chunk is harmless; erasing absent cells is a no-op).
func queueCellOp(chunkLocation: Vector2i, cellData: PackedInt32Array, write: bool) -> void:
	for i in range(cellOpQueue.size() - 1, -1, -1):
		if cellOpQueue[i]["chunk"] == chunkLocation:
			cellOpQueue.remove_at(i)
	if write:
		presentChunkCells[chunkLocation] = true
	else:
		presentChunkCells.erase(chunkLocation)
	cellOpQueue.append({ "chunk": chunkLocation, "data": cellData, "offset": 0, "write": write })

# Runs queued cell writes/erases, at most cellOpBudget cells per frame, so a
# chunk transition's work spreads over a few frames instead of stalling one.
func processCellOps() -> void:
	if cellOpQueue.is_empty():
		return
	var mergedTiles = $MergedTiles
	var remaining = cellOpBudget
	while remaining > 0 and !cellOpQueue.is_empty():
		var op = cellOpQueue[0]
		var data: PackedInt32Array = op["data"]
		var offset: int = op["offset"]
		var end: int = min(offset + remaining * 6, data.size())
		if op["write"]:
			var i = offset
			while i < end:
				mergedTiles.set_cell(
					Vector2i(data[i], data[i + 1]),
					data[i + 2],
					Vector2i(data[i + 3], data[i + 4]),
					data[i + 5]
				)
				i += 6
		else:
			var i = offset
			while i < end:
				mergedTiles.erase_cell(Vector2i(data[i], data[i + 1]))
				i += 6
		remaining -= (end - offset) / 6
		if end >= data.size():
			cellOpQueue.pop_front()
		else:
			op["offset"] = end


###################################
### Chunk scene loading (async) ###
###################################

func getChunkPath(chunkLocation: Vector2i) -> String:
	return WorldData.getChunkPath(chunkLocation)

# Parses a chunk scene on a background thread before it is needed, so
# first-time chunk loads don't stall a frame on disk I/O and scene parsing.
func requestChunkScene(chunkLocation: Vector2i) -> void:
	if chunkScenes.has(chunkLocation):
		return
	var path = getChunkPath(chunkLocation)
	if pendingChunkPaths.has(path):
		return
	if !ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_request(path):
		pendingChunkPaths[path] = chunkLocation

# Moves finished background parses into the chunk scene cache.
func pollChunkScenes() -> void:
	for path in pendingChunkPaths.keys():
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			chunkScenes[pendingChunkPaths[path]] = ResourceLoader.load_threaded_get(path)
			pendingChunkPaths.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			chunkScenes[pendingChunkPaths[path]] = null
			pendingChunkPaths.erase(path)

# True when getChunkScene() can return the chunk's scene right away: cached
# (loaded or missing), not requested, or its background parse is finished.
func isChunkSceneReady(chunkLocation: Vector2i) -> bool:
	if chunkScenes.has(chunkLocation):
		return true
	var path = getChunkPath(chunkLocation)
	if !pendingChunkPaths.has(path):
		return true
	return ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED

# Returns the PackedScene for a chunk (from the cache, a finished background
# parse, or a direct load), or null when there is no chunk scene file. Call
# isChunkSceneReady() first: a still-parsing path would wait for the whole
# loader queue here.
func getChunkScene(chunkLocation: Vector2i):
	var path = getChunkPath(chunkLocation)
	if chunkScenes.has(chunkLocation):
		return chunkScenes[chunkLocation]
	if pendingChunkPaths.has(path):
		chunkScenes[chunkLocation] = ResourceLoader.load_threaded_get(path)
		pendingChunkPaths.erase(path)
		return chunkScenes[chunkLocation]
	if !ResourceLoader.exists(path):
		return null
	chunkScenes[chunkLocation] = load(path)
	return chunkScenes[chunkLocation]

# Loads chunks whose background parse finished after they were needed.
func processPendingChunkLoads() -> void:
	if pendingChunkLoads.is_empty():
		return
	# Drop chunks the player has moved away from.
	var adjacentChunks = getAdjacentChunks()
	var stillWanted = []
	for chunkLocation in pendingChunkLoads:
		if adjacentChunks.has(chunkLocation) or chunkLocation == currentChunk:
			stillWanted.append(chunkLocation)
	pendingChunkLoads = stillWanted
	for chunkLocation in pendingChunkLoads.duplicate():
		if loadedChunkCells.has(chunkLocation):
			pendingChunkLoads.erase(chunkLocation)
			continue
		if setChunk(chunkLocation):
			pendingChunkLoads.erase(chunkLocation)

# Preloads every chunk scene within two chunks of the player, nearest first,
# so the chunks needed on the next boundary crossing are already parsed.
func preloadChunkScenes() -> void:
	for radius in [1, 2]:
		for x in range(currentChunk.x - radius, currentChunk.x + radius + 1):
			for y in range(currentChunk.y - radius, currentChunk.y + radius + 1):
				requestChunkScene(Vector2i(x, y))

func unloadChunk(chunk: Vector2i) -> void:
	# Unload by erasing the chunk's cached cells from the merged layer
	# (queued; processed a slice per frame).
	if loadedChunkCells.has(chunk):
		loadedChunkCells.erase(chunk)
		queueCellOp(chunk, chunkCellDataCache.get(chunk, PackedInt32Array()), false)
	

##########################
### Location functions ###
##########################

func enterLocation(body: Node2D, locationName: String, pregenerated: bool):
	Locations.currentLocation = locationName
	if body.name == "PlayerOverworldActor":
		if pregenerated:
			HelperFunctions.changeScene("pregenerated_location", { "location": locationName })
		else:
			HelperFunctions.changeScene("wfc_location", { "location": locationName })


func createLocation(locationName: String, chunkPosition: Vector2i, tiles: Array, pregenerated: bool):
	var area = Area2D.new()
	area.name = locationName
	$Locations.add_child(area)
	
	for tile in tiles:
		$Locations.get_node("{locationName}".format({ "locationName": locationName })).add_child(
			createCollisionWithPosition(
				tile,
				chunkPosition,
				PackedVector2Array([
					Vector2i(-1, -1),
					Vector2i(-1, 0),
					Vector2i(0, 0),
					Vector2i(-1, 1)
				])
			)
		)
	
	$Locations.get_node("{locationName}".format({ "locationName": locationName })).body_entered.connect(enterLocation.bind(locationName, pregenerated))

func createSpawnPoint(actorName, actorType, spawnPosition, spawnChance, spawnMaximum):
	var newSpawnPoint = spawnPointInstance.instantiate()
	newSpawnPoint.name = actorName + str(Overworld.overworldSpawnpointIdCount)
	Overworld.overworldSpawnpointIdCount += 1
	newSpawnPoint.init(actorName, actorType, spawnPosition, spawnChance, spawnMaximum)
	$Spawnpoints.add_child(newSpawnPoint)

func isOverworldObjectLoaded(objectName, objectType):
	for object in get_node("{objectType}".format({ "objectType": objectType })).get_children():
		if object.name.find(objectName) != -1:
			return true
	return false

func removeFarawayObjects():
	for location in $Locations.get_children():
		var locationArea = location.get_child(0)
		if local_to_map(locationArea.position) != currentChunk and !currentlyLoadedChunks.has(local_to_map(locationArea.position)):
			location.queue_free()
	for spawnpoint in $Spawnpoints.get_children():
		if local_to_map(spawnpoint.spawnPoint) != currentChunk and !currentlyLoadedChunks.has(local_to_map(spawnpoint.spawnPoint)):
			spawnpoint.queue_free()

########################
### Helper functions ###
########################

func createCollisionWithPosition(collisionPosition: Vector2i, chunkPosition: Vector2i, shape: Array):
	var areaShape = CollisionShape2D.new()
	var areaShapeCollision = ConvexPolygonShape2D.new()
	var chunkMappedTiles = PackedVector2Array()
	
	for point in shape:
		chunkMappedTiles.append(Vector2i($OverworldTileChunkTemplate.map_to_local(point)))
	areaShapeCollision.set_point_cloud(chunkMappedTiles)
	
	areaShape.name = str(currentChunk) + str(collisionPosition)
	areaShape.position = Vector2i(map_to_local(chunkPosition) - Vector2(32 * 24, 32 * 6) + $OverworldTileChunkTemplate.map_to_local(collisionPosition))
	areaShape.shape = areaShapeCollision
	areaShape.z_index = 1
	
	return areaShape

#######################
### Timer functions ###
#######################

func _on_animal_spawn_point_timer_timeout():
	checkActorSpawns()

func checkActorSpawns():
	for spawnPoint in get_node("Spawnpoints").get_children():
		spawnPoint.checkForSpawn()
	$Timers/SpawnPointTimer.start()
