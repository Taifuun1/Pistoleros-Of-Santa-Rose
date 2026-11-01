extends TileMap

@onready var spawnPointInstance = preload("res://Overworld/OverworldSpawnpoint.tscn")

var currentChunk = null
var currentlyLoadedChunks = []
var loadingChunk = true

# Chunk scene / cell cache, background-parse bookkeeping and the budgeted
# merged-layer write queue (see OverworldChunkStreamCache.gd; extracted so the
# streaming logic is testable without a scene tree).
var streamCache := OverworldChunkStreamCache.new()

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
		# thread, then drop the caches for the chunks far behind the player.
		preloadChunkScenes()
		pruneChunkCaches()
		loadingChunk = false

func init() -> void:
	currentChunk = Overworld.spawnChunk
	if !setChunk() and !streamCache.pendingChunkLoads.has(currentChunk):
		streamCache.pendingChunkLoads.append(currentChunk)
	var newCurrentlyLoadedChunks = getAdjacentChunks()
	setAdjacentChunks(newCurrentlyLoadedChunks)
	currentlyLoadedChunks = newCurrentlyLoadedChunks
	# Canonical shared-coordinate placement (the map's chunkTileToWorld); the
	# old inline offset formula sat one tile off this pipeline.
	$Actors/PlayerOverworldActor.position = _getCoordinates().chunkTileToWorld(Overworld.spawnChunk, Overworld.spawnTile)
	# Live player state for the Journal map; the placement also initializes
	# the autoload's last-known position (see Globals/Overworld.gd).
	Overworld.registerLivePlayer($Actors/PlayerOverworldActor)
	loadingChunk = false
	# Zone music for the chunk the player spawns in (MusicPlayer decides by
	# the zone bands in Data/Music/MusicData.gd; only zone changes restart).
	MusicPlayer.on_overworld_chunk(currentChunk)
	# Parse nearby chunk scenes ahead of time on a background thread.
	preloadChunkScenes()
	pruneChunkCaches()


func _exit_tree() -> void:
	# Any transition that destroys the Overworld (enterLocation included)
	# snapshots the exact player position first: Journal map last-known state
	# and re-entry seeding stay in sync (see Globals/Overworld.gd).
	Overworld.clearLivePlayer()
	# Drain background chunk parses and release the streaming caches so the
	# scene does not leave loaders/resources behind.
	streamCache.dispose()
	streamCache = null
	if _coordinates != null:
		_coordinates.dispose()
		_coordinates = null
	_chunkReader = null


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
		streamCache.loadedChunkCells[chunkLocation] = true
		return true
	var chunkRead = _getChunkReader().readChunk(chunkLocation, chunkScene)
	if !chunkRead["errors"].is_empty():
		for error in chunkRead["errors"]:
			push_error(str(error))
		# Do not render a partial chunk or retry malformed data every frame.
		streamCache.loadedChunkCells[chunkLocation] = true
		return true
	var cellData: PackedInt32Array = chunkRead["cells"]
	streamCache.chunkCellDataCache[chunkLocation] = cellData
	streamCache.loadedChunkCells[chunkLocation] = true
	if !streamCache.presentChunkCells.has(chunkLocation):
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
				# Canonical shared-coordinate placement (the old inline offset
				# formula sat one tile off this pipeline).
				_getCoordinates().chunkTileToWorld(chunkLocation, spawnPoints[actorName].tiles[0]),
				spawnPoints[actorName].chance,
				spawnPoints[actorName].maximum
			)
	return true

func setAdjacentChunks(newAdjacentChunks: Array) -> void:
	# Erase every merged chunk that is neither the player's chunk nor one of
	# its neighbours (also covers chunks left over from earlier positions,
	# e.g. the spawn chunk).
	for loadedChunkLocation in streamCache.loadedChunkCells.keys():
		if !OverworldChunkStreamCache.isKept(loadedChunkLocation, currentChunk, newAdjacentChunks):
			unloadChunk(loadedChunkLocation)
	for currentAdjacentChunk in newAdjacentChunks:
		if streamCache.loadedChunkCells.has(currentAdjacentChunk):
			continue
		# Chunks whose scene is still parsing load on a later frame instead
		# of blocking this one.
		if !setChunk(currentAdjacentChunk) and !streamCache.pendingChunkLoads.has(currentAdjacentChunk):
			streamCache.pendingChunkLoads.append(currentAdjacentChunk)

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
	if streamCache.chunkCellDataCache.has(chunkLocation):
		return streamCache.chunkCellDataCache[chunkLocation]
	var cellData = PackedInt32Array()
	var chunkScene = streamCache.chunkScenes.get(chunkLocation, null)
	if chunkScene != null:
		cellData = _getChunkReader().readCells(chunkLocation, chunkScene)
	streamCache.chunkCellDataCache[chunkLocation] = cellData
	return cellData

# Queues a write/erase of the chunk's cells, processed a slice per frame by
# processCellOps(). Any already queued op for the same chunk is replaced (a
# fully rewritten chunk is harmless; erasing absent cells is a no-op).
func queueCellOp(chunkLocation: Vector2i, cellData: PackedInt32Array, write: bool) -> void:
	streamCache.queueCellOp(chunkLocation, cellData, write)

# Runs queued cell writes/erases, at most OverworldChunkStreamCache.CELL_OP_BUDGET
# cells per frame, so a chunk transition's work spreads over a few frames.
func processCellOps() -> void:
	streamCache.processCellOps($MergedTiles)

# Keeps the scene/cell caches bounded around the player: the current chunk plus
# the preload ring. Chunks still present in the merged layer always keep their
# cells, because unloading needs them to erase.
func pruneChunkCaches() -> void:
	streamCache.prune(OverworldChunkStreamCache.keptChunks(currentChunk))

###################################
### Chunk scene loading (async) ###
###################################

func getChunkPath(chunkLocation: Vector2i) -> String:
	return WorldData.getChunkPath(chunkLocation)

# Parses a chunk scene on a background thread before it is needed, so
# first-time chunk loads don't stall a frame on disk I/O and scene parsing.
func requestChunkScene(chunkLocation: Vector2i) -> void:
	streamCache.requestScene(chunkLocation, getChunkPath(chunkLocation))

# Moves finished background parses into the chunk scene cache.
func pollChunkScenes() -> void:
	streamCache.pollScenes()

# True when getChunkScene() can return the chunk's scene right away: cached
# (loaded or missing), not requested, or its background parse is finished.
func isChunkSceneReady(chunkLocation: Vector2i) -> bool:
	return streamCache.isSceneReady(chunkLocation, getChunkPath(chunkLocation))

# Returns the PackedScene for a chunk (from the cache, a finished background
# parse, or a direct load), or null when there is no chunk scene file. Call
# isChunkSceneReady() first: a still-parsing path would wait for the whole
# loader queue here.
func getChunkScene(chunkLocation: Vector2i) -> PackedScene:
	return streamCache.getScene(chunkLocation, getChunkPath(chunkLocation))

# Loads chunks whose background parse finished after they were needed.
func processPendingChunkLoads() -> void:
	if streamCache.pendingChunkLoads.is_empty():
		return
	# Drop chunks the player has moved away from.
	var adjacentChunks = getAdjacentChunks()
	var stillWanted = []
	for chunkLocation in streamCache.pendingChunkLoads:
		if OverworldChunkStreamCache.isKept(chunkLocation, currentChunk, adjacentChunks):
			stillWanted.append(chunkLocation)
	streamCache.pendingChunkLoads = stillWanted
	for chunkLocation in streamCache.pendingChunkLoads.duplicate():
		if streamCache.loadedChunkCells.has(chunkLocation):
			streamCache.pendingChunkLoads.erase(chunkLocation)
			continue
		if setChunk(chunkLocation):
			streamCache.pendingChunkLoads.erase(chunkLocation)

# Preloads every chunk scene within two chunks of the player, nearest first,
# so the chunks needed on the next boundary crossing are already parsed.
func preloadChunkScenes() -> void:
	# Headless test runs quit without joining ResourceLoader's background
	# tasks, which leaves loader objects behind at exit. Preloading is a
	# runtime-only optimization, so skip it in headless mode.
	if DisplayServer.get_name() == "headless":
		return
	for radius in range(1, OverworldChunkStreamCache.PRELOAD_RADIUS + 1):
		for x in range(currentChunk.x - radius, currentChunk.x + radius + 1):
			for y in range(currentChunk.y - radius, currentChunk.y + radius + 1):
				requestChunkScene(Vector2i(x, y))

func unloadChunk(chunk: Vector2i) -> void:
	# Unload by erasing the chunk's cached cells from the merged layer
	# (queued; processed a slice per frame).
	streamCache.unload(chunk)
	

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
		area.add_child(createCollisionWithPosition(tile, chunkPosition))
	
	area.body_entered.connect(enterLocation.bind(locationName, pregenerated))

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
		if !OverworldChunkStreamCache.isKept(local_to_map(locationArea.position), currentChunk, currentlyLoadedChunks):
			location.queue_free()
	for spawnpoint in $Spawnpoints.get_children():
		if !OverworldChunkStreamCache.isKept(local_to_map(spawnpoint.spawnPoint), currentChunk, currentlyLoadedChunks):
			spawnpoint.queue_free()

########################
### Helper functions ###
########################

# The collision diamond for one location tile: centred on the tile's shared
# world anchor (chunkTileToWorld) with the tile's own half-extents, so the area
# covers exactly the tile it was authored for.
func createCollisionWithPosition(collisionPosition: Vector2i, chunkPosition: Vector2i):
	var coordinates = _getCoordinates()
	var tileCenter = coordinates.chunkTileToWorld(chunkPosition, collisionPosition)
	var u = coordinates.cellToWorld(coordinates.chunkTileToCell(chunkPosition, collisionPosition) + Vector2i.RIGHT) - tileCenter
	var v = coordinates.cellToWorld(coordinates.chunkTileToCell(chunkPosition, collisionPosition) + Vector2i.DOWN) - tileCenter
	var areaShape = CollisionShape2D.new()
	var areaShapeCollision = ConvexPolygonShape2D.new()
	areaShapeCollision.set_point_cloud(PackedVector2Array([
		-u * 0.5 - v * 0.5,
		u * 0.5 - v * 0.5,
		u * 0.5 + v * 0.5,
		-u * 0.5 + v * 0.5
	]))
	areaShape.name = str(chunkPosition) + str(collisionPosition)
	areaShape.position = tileCenter
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
