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
	if !loadingChunk and local_to_map($PlayerActor.position) != currentChunk:
		loadingChunk = true
		var previousChunk = currentChunk
		currentChunk = local_to_map($PlayerActor.position)
		var newCurrentlyLoadedChunks = getAdjacentChunks()
		setAdjacentChunks(newCurrentlyLoadedChunks)
		currentlyLoadedChunks = newCurrentlyLoadedChunks
		removeNodes()
		loadingChunk = false

func init(spawnChunk: Vector2i = Vector2i(8, 11), spawnLocation: Vector2i = Vector2i(0, 0)) -> void:
	currentChunk = spawnChunk
	setChunk()
	var newCurrentlyLoadedChunks = getAdjacentChunks()
	setAdjacentChunks(newCurrentlyLoadedChunks)
	currentlyLoadedChunks = newCurrentlyLoadedChunks
	removeNodes()
	$PlayerActor.position = Vector2i(map_to_local(spawnChunk)) + spawnLocation
	loadingChunk = false

func setChunk(chunkLocation: Vector2i = currentChunk) -> void:
	var chunk = load("res://Overworld/Overworld Chunks/#{x}#{y}.tscn".format({ "x": chunkLocation.x, "y": chunkLocation.y }))
	if chunk == null:
		push_warning("No chunk for x: {x}, y: {y}".format({ "x": chunkLocation.x, "y": chunkLocation.y }))
		return
	$Chunks.add_child(chunk.instantiate())
	setTiles(chunkLocation, getChunkTiles($Chunks.get_children()[$Chunks.get_child_count() - 1]))

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
	for x in range(64):
		for y in range(64):
			tiles[Vector2i(x, y)] = {
				"id": node.get_node("OverworldTileChunkTemplate").get_cell_source_id(0, Vector2i(x,y)),
				"coords": node.get_node("OverworldTileChunkTemplate").get_cell_atlas_coords(0, Vector2i(x,y))
			}
	return tiles

func setTiles(chunk: Vector2i, tiles: Dictionary) -> void:
	for key in tiles:
		$OverworldTileChunkTemplate.set_cell(0, Vector2i(
			$OverworldTileChunkTemplate.local_to_map(
				Vector2(
					map_to_local(chunk).x - 32 * 24,
					map_to_local(chunk).y - 32 * 6
				)
			)
		) + key, tiles[key].id, tiles[key].coords)

func unloadChunk(chunk: Vector2i) -> void:
	for x in range(64):
		for y in range(64):
			$OverworldTileChunkTemplate.erase_cell(0, Vector2i(
				$OverworldTileChunkTemplate.local_to_map(
					Vector2(
						map_to_local(chunk).x - (32 * 24),
						map_to_local(chunk).y - (32 * 6)
					)
				)
			) + Vector2i(x ,y))

func removeNodes() -> void:
	for _node in $Chunks.get_children():
		_node.queue_free()
