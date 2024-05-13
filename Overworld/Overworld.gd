extends TileMap

@onready var spawnPointInstance = preload("res://Overworld/OverworldSpawnpoint.tscn")

var currentChunk = null
var currentlyLoadedChunks = []
var loadingChunk = true


func _process(_delta):
	if currentChunk == null:
		init()
	if !loadingChunk and local_to_map(to_local($Actors/PlayerOverworldActor.position)) != currentChunk:
		loadingChunk = true
		currentChunk = local_to_map($Actors/PlayerOverworldActor.position)
		var newCurrentlyLoadedChunks = getAdjacentChunks()
		setAdjacentChunks(newCurrentlyLoadedChunks)
		currentlyLoadedChunks = newCurrentlyLoadedChunks
		removeFarawayObjects()
		removeNodes()
		loadingChunk = false

func init() -> void:
	currentChunk = Overworld.spawnChunk
	setChunk()
	var newCurrentlyLoadedChunks = getAdjacentChunks()
	setAdjacentChunks(newCurrentlyLoadedChunks)
	currentlyLoadedChunks = newCurrentlyLoadedChunks
	removeNodes()
	$Actors/PlayerOverworldActor.position = Vector2i(map_to_local(Overworld.spawnChunk) - $OverworldTileChunkTemplate.map_to_local(HelperVariables.overworldChunkSize / 2) + $OverworldTileChunkTemplate.map_to_local(Overworld.spawnTile))
	loadingChunk = false


#######################
### Chunk functions ###
#######################

func setChunk(chunkLocation: Vector2i = currentChunk) -> void:
	var chunk = load("res://Overworld/Overworld Chunks/#{x}#{y}.tscn".format({ "x": chunkLocation.x, "y": chunkLocation.y }))
	if chunk == null:
		push_warning("No chunk for x: {x}, y: {y}".format({ "x": chunkLocation.x, "y": chunkLocation.y }))
		return
	$Chunks.add_child(chunk.instantiate())
	setTiles(chunkLocation, getChunkTiles($Chunks.get_children()[$Chunks.get_child_count() - 1]))
	if "locations" in $Chunks.get_children()[$Chunks.get_child_count() - 1]:
		var locations = $Chunks.get_children()[$Chunks.get_child_count() - 1].locations
		for location in locations:
			if !isOverworldObjectLoaded(location, "Locations"):
				createLocation(location, chunkLocation, locations[location].tiles, locations[location].pregenerated)
	if "spawnPoints" in $Chunks.get_children()[$Chunks.get_child_count() - 1]:
		var spawnPoints = $Chunks.get_children()[$Chunks.get_child_count() - 1].spawnPoints
		for actorName in spawnPoints:
			if !isOverworldObjectLoaded(actorName, "Spawnpoints"):
				createSpawnPoint(
					actorName,
					spawnPoints[actorName].type,
					Vector2i(map_to_local(chunkLocation) - Vector2(32 * 24, 32 * 6) + $OverworldTileChunkTemplate.map_to_local(spawnPoints[actorName].tiles[0])),
					spawnPoints[actorName].chance,
					spawnPoints[actorName].maximum
				)

func setAdjacentChunks(newAdjacentChunks: Array) -> void:
	for previousAdjacentChunk in currentlyLoadedChunks:
		if !newAdjacentChunks.has(previousAdjacentChunk) and previousAdjacentChunk != currentChunk:
			unloadChunk(previousAdjacentChunk)
	for currentAdjacentChunk in newAdjacentChunks:
		if currentlyLoadedChunks.has(currentAdjacentChunk):
			continue
		else:
			setChunk(currentAdjacentChunk)

func getAdjacentChunks() -> Array:
	var adjacentChunks = []
	for adjacentChunkDirection in HelperVariables.adjacentDirections:
		var adjacentChunkLocation = currentChunk + adjacentChunkDirection
		adjacentChunks.append(adjacentChunkLocation)
	return adjacentChunks

func getChunkTiles(node: Node2D) -> Dictionary:
	var tiles = {}
	for x in range(HelperVariables.overworldChunkSize.x):
		for y in range(HelperVariables.overworldChunkSize.y):
			tiles[Vector2i(x, y)] = {
				"id": node.get_node("OverworldTileChunkTemplate").get_cell_source_id(0, Vector2i(x,y)),
				"coords": node.get_node("OverworldTileChunkTemplate").get_cell_atlas_coords(0, Vector2i(x,y)),
				"alternative": node.get_node("OverworldTileChunkTemplate").get_cell_alternative_tile(0, Vector2i(x,y))
			}
	return tiles

func setTiles(chunk: Vector2i, tiles: Dictionary) -> void:
	for key in tiles:
		$OverworldTileChunkTemplate.set_cell(0, Vector2i(
			$OverworldTileChunkTemplate.local_to_map(
				Vector2i(
					map_to_local(chunk).x - (32 * 24),
					map_to_local(chunk).y - (32 * 6)
				)
			)
		) + key - Vector2i(1, 1), tiles[key].id, tiles[key].coords, tiles[key].alternative)

func unloadChunk(chunk: Vector2i) -> void:
	for x in range(64):
		for y in range(64):
			$OverworldTileChunkTemplate.erase_cell(0, Vector2i(
				$OverworldTileChunkTemplate.local_to_map(
					Vector2i(
						map_to_local(chunk).x - (32 * 24),
						map_to_local(chunk).y - (32 * 6)
					)
				)
			) + Vector2i(x ,y) - Vector2i(1, 1))
	

##########################
### Location functions ###
##########################

func enterLocation(body: Node2D, locationName: String, pregenerated: bool):
	if body.name == "PlayerOverworldActor":
		if pregenerated:
			get_tree().call_deferred("change_scene_to_file", "res://Location/Locations/{locationName}/{locationName}.tscn".format({ "locationName": locationName }))
		else:
			var noWhitespacelocationName = locationName.replace(" ", "")
			get_tree().call_deferred("change_scene_to_file", "res://Location/Location Generation/{locationName}/{noWhitespacelocationName}.tscn".format({ "locationName": locationName, "noWhitespacelocationName": noWhitespacelocationName }))

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

func removeNodes() -> void:
	for _node in $Chunks.get_children():
		_node.queue_free()


#######################
### Timer functions ###
#######################

func _on_animal_spawn_point_timer_timeout():
	checkActorSpawns()

func checkActorSpawns():
	for spawnPoint in get_node("Spawnpoints").get_children():
		spawnPoint.checkForSpawn()
	$Timers/SpawnPointTimer.start()
