extends TileMap

var adjacentChunkDirections = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]

var currentChunk = null
var currentlyLoadedChunks = []
var loadingChunk = true


func _process(_delta):
	if currentChunk == null:
		init()
	if !loadingChunk and local_to_map($Actors/PlayerOverworldActor.position) != currentChunk:
		loadingChunk = true
		currentChunk = local_to_map($Actors/PlayerOverworldActor.position)
		var newCurrentlyLoadedChunks = getAdjacentChunks()
		setAdjacentChunks(newCurrentlyLoadedChunks)
		currentlyLoadedChunks = newCurrentlyLoadedChunks
		removeFarawayLocations()
		removeNodes()
		loadingChunk = false

func init() -> void:
	currentChunk = Overworld.spawnChunk
	setChunk()
	var newCurrentlyLoadedChunks = getAdjacentChunks()
	setAdjacentChunks(newCurrentlyLoadedChunks)
	currentlyLoadedChunks = newCurrentlyLoadedChunks
	removeNodes()
	$Actors/PlayerOverworldActor.position = Vector2i(map_to_local(Overworld.spawnChunk)) + Overworld.spawnTile
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
			if !isLocationLoaded(location):
				createLocation(location, chunkLocation, locations[location].tiles, locations[location].pregenerated)

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
	for adjacentChunkDirection in adjacentChunkDirections:
		var adjacentChunkLocation = currentChunk + adjacentChunkDirection
		adjacentChunks.append(adjacentChunkLocation)
	return adjacentChunks

func getChunkTiles(node: Node2D) -> Dictionary:
	var tiles = {}
	for x in range(HelperVariables.overworldChunkSize.x):
		for y in range(HelperVariables.overworldChunkSize.y):
			tiles[Vector2i(x, y)] = {
				"id": node.get_node("OverworldTileChunkTemplate").get_cell_source_id(0, Vector2i(x,y)),
				"coords": node.get_node("OverworldTileChunkTemplate").get_cell_atlas_coords(0, Vector2i(x,y))
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
		) + key - Vector2i(1, 1), tiles[key].id, tiles[key].coords)

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

func createLocation(locationName: String, chunkPosition: Vector2i, tiles: Array, pregenerated: bool = false):
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

func isLocationLoaded(locationName):
	for location in $Locations.get_children():
		print(location.name)
		if location.name == locationName:
			return true
	return false

func removeFarawayLocations():
	for location in $Locations.get_children():
		var locationArea = location.get_child(0)
		if local_to_map(locationArea.position) != currentChunk and !currentlyLoadedChunks.has(local_to_map(locationArea.position)):
			location.queue_free()

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
	
	return areaShape

func removeNodes() -> void:
	for _node in $Chunks.get_children():
		_node.queue_free()
