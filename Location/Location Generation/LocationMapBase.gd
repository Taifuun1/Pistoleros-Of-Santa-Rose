extends Node2D
class_name LocationMapBase

var dynamicSprite = load("res://Nodes/Dynamic Sprite/DynamicSprite.tscn")

var emptyChunks = []
var currentlyGeneratingChunks = []
var idleGenerators = ["Gen1", "Gen2", "Gen3"]
var chunkPriority = null

var generatedChunks = {}

var currentChunk = Vector2i(0, 0)
var movedDirection = "bottom"


func _ready():
	set_process(false)

func _process(_delta):
	if generatedChunks.has(currentChunk):
		changeChunk()
		set_process(false)

func setChunkPriority(chunk: Vector2i):
	chunkPriority = chunk

func changeChunk(direction = movedDirection, directionRelative = Vector2i(0, 0)):
	resetChunk()
	currentChunk += directionRelative
	movedDirection = direction
	if !generatedChunks.has(currentChunk):
		chunkPriority = currentChunk
		set_process(true)
		return
	var generationVariables = load("res://Data/Location Generation/{generatedLocation}.gd".format({ "generatedLocation": Locations.currentLocation.replace(" ", "") })).new().generationVariables
	var tileTypes = transformWFCTilesToMapTiles(generatedChunks[currentChunk].tiles)
	for tileType in tileTypes:
		match tileType:
			"ground":
				$Map.setTerrainTiles(tileTypes[tileType], generationVariables.tileset, 0)
			"water":
				$Map.setTerrainTiles(tileTypes[tileType], generationVariables.tileset, 1)
			"trees":
				$Map.setTerrainTiles(tileTypes[tileType], generationVariables.tileset, 2)
			"walls":
				$Map.setTerrainTiles(tileTypes[tileType], generationVariables.tileset, 3)
	addTrees(tileTypes.trees, generationVariables.trees, 4)
	addExits()
	if typeof(generatedChunks[currentChunk].interactables) == TYPE_ARRAY:
		generatedChunks[currentChunk].interactables = getInteractablePositions(generatedChunks[currentChunk].interactables, tileTypes.ground)
	addInteractables(generatedChunks[currentChunk].interactables, tileTypes.ground)
	
	# get_tree().current_scene.get_node("AI/NavigationRegion2D").bake_navigation_polygon()
	
	$AI/Pathfinding.initPathfindingAstarNode(generatedChunks[currentChunk].tiles)
	
	var newDirection = "left"
	if movedDirection == "left":
		newDirection = "right"
	elif movedDirection == "top":
		newDirection = "bottom"
	elif movedDirection == "bottom":
		newDirection = "top"
	$Entities/Actors/PlayerActor.position = $Map.map_to_local(generatedChunks[currentChunk].openBorders[newDirection].halfwayTile)

func transformWFCTilesToMapTiles(tiles: Dictionary):
	var mapTiles = {
		"water": [],
		"ground": [],
		"trees": [],
		"walls": []
	}
	for tile in tiles:
		match Locations.currentLocation:
			"Clearwater Grove", "Donnafolk Cave":
				if tiles[tile] == 0:
					mapTiles.water.append(tile)
				elif tiles[tile] == 1:
					mapTiles.ground.append(tile)
				elif tiles[tile] == 2:
					mapTiles.trees.append(tile)
				elif tiles[tile] == 3:
					mapTiles.walls.append(tile)
	return mapTiles

func addExits():
	for openBorder in generatedChunks[currentChunk].openBorders:
		if generatedChunks[currentChunk].openBorders[openBorder] == null:
			continue
		var directions = {
			"left": Vector2i(-2, 0),
			"right": Vector2i(2, 0),
			"top": Vector2i(0, -5),
			"bottom": Vector2i(0, 5)
		}
		var direction = directions[openBorder]
		addExit(generatedChunks[currentChunk].openBorders[openBorder], openBorder, direction)

func addExit(tiles, direction, directionRelative):
	var area = Area2D.new()
	area.name = str(currentChunk) + direction
	area.body_entered.connect(checkIfChangeChunk.bind(direction, HelperVariables.cardinalDirections[direction]))
	$Entities/Exits.add_child(area)
	for tile in tiles.tiles:
		var collision = createCollisionWithPosition(
			tile + directionRelative,
			PackedVector2Array([
				Vector2i(-1, -1),
				Vector2i(-1, 0),
				Vector2i(0, 0),
				Vector2i(-1, 1)
			])
		)
		get_node("Entities/Exits/{direction}".format({ "direction": str(currentChunk) + direction })).call_deferred("add_child", collision)

func addTrees(tiles: Array, treeType: String, treeTypeAmount: int):
	var treeSprites = { "type": "Outdoor Objects", "sprites": []}
	for index in range(1, treeTypeAmount + 1):
		treeSprites.sprites.append("{treeType}{index}".format({ "treeType": treeType, "index": index }))
	#for cell in $Map.get_used_cells_by_id(0, 2, Vector2i(0, 0)):
	for cell in tiles:
		var tree = dynamicSprite.instantiate()
		$"Entities/OutdoorObjects".add_child(tree)
		tree.init(treeSprites)
		tree.position = $Map.map_to_local(cell)
		tree.name = str(currentChunk) + str(cell)
		
		get_node("Entities/OutdoorObjects/{tree}".format({ "tree": str(currentChunk) + str(cell) })).call_deferred("add_child",
			createCollision(
				cell,
				PackedVector2Array([
					Vector2i(0, 0),
					Vector2i(-1, -1),
					Vector2i(-1, 0),
					Vector2i(-1, 1)
				])
			)
		)

func addInteractables(interactables, tiles):
	var interactableNode = load("res://Location/Entities/Interactable/Interactable.tscn")
	var newInteractables = interactables
	for interactablePosition in newInteractables:
		var newInteractable = interactableNode.instantiate()
		newInteractable.init(newInteractables[interactablePosition].type, newInteractables[interactablePosition].name, Vector2i($Map.map_to_local(interactablePosition)))
		$Entities/Interactables.call_deferred("add_child", newInteractable)

func getInteractablePositions(interactables, tiles):
	var newInteractables = {}
	for interactable in interactables:
		for count in interactable.count:
			var interactablePosition = tiles[randi() % tiles.size()]
			newInteractables[interactablePosition] = {
				"name": interactable.name,
				"type": interactable.type,
				"tileType": interactable.tileType
			}
	return newInteractables

func createCollision(collisionPosition: Vector2i, shape: Array):
	var areaShape = CollisionShape2D.new()
	var areaShapeCollision = ConvexPolygonShape2D.new()
	var chunkMappedTiles = PackedVector2Array()
	
	for point in shape:
		chunkMappedTiles.append(Vector2i($Map.map_to_local(point)))
	#shape[2]
	areaShapeCollision.set_point_cloud(chunkMappedTiles)
	
	areaShape.name = str(currentChunk) + str(collisionPosition)
	areaShape.shape = areaShapeCollision
	
	return areaShape

func createCollisionWithPosition(collisionPosition: Vector2i, shape: Array):
	var areaShape = CollisionShape2D.new()
	var areaShapeCollision = ConvexPolygonShape2D.new()
	var chunkMappedTiles = PackedVector2Array()
	
	for point in shape:
		chunkMappedTiles.append(Vector2i($Map.map_to_local(point)))
	areaShapeCollision.set_point_cloud(chunkMappedTiles)
	
	areaShape.name = str(currentChunk) + str(collisionPosition)
	areaShape.position = Vector2i($Map.map_to_local(collisionPosition))
	areaShape.shape = areaShapeCollision
	
	return areaShape

func checkIfChangeChunk(body, direction, directionRelative):
	if body.name == "PlayerActor":
		if direction == "top" and directionRelative == Vector2i(0, -1) and currentChunk == Vector2i(0, 0):
			Overworld.spawnChunk = Vector2i(8, 18)
			Overworld.spawnTile = Vector2i(26, 62)
			get_tree().call_deferred("change_scene_to_file", "res://Overworld/Overworld.tscn")
			return
		changeChunk(direction, directionRelative)

func resetChunk():
	$Map.clear()
	for entityNode in $Entities.get_children():
		for node in entityNode.get_children():
			if node.name != "PlayerActor" and node.name != "LocationActor":
				node.queue_free()
