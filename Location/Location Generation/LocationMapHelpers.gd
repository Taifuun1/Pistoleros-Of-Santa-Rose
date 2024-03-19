extends Node2D
class_name LocationMapHelpers

var dynamicSprite = load("res://Nodes/Dynamic Sprite/DynamicSprite.tscn")

var currentGeneration = "Clearwater Grove"

var emptyChunks = []
var currentlyGeneratingChunks = []
var idleGenerators = ["Gen1", "Gen2", "Gen3"]
var chunkPriority = null

var generatedChunks = {}

var currentChunk = Vector2i(0, 0)


func resetChunk():
	$Map.clear()
	for node in $Entities/OutdoorObjects.get_children():
		node.queue_free()
	for node in $Entities/Exits.get_children():
		node.queue_free()

func checkIfChangeChunk(body, direction, directionRelative):
	print("direction: ", directionRelative)
	if body.name == "PlayerActor":
		changeChunk(direction, directionRelative)

func changeChunk(direction, directionRelative = Vector2i(0, 0)):
	resetChunk()
	currentChunk += directionRelative
	print("changed to ", currentChunk)
	var tileTypes = transformWFCTilesToMapTiles(generatedChunks[currentChunk].tiles)
	for tileType in tileTypes:
		match tileType:
			"water":
				$Map.setTerrainTiles(tileTypes[tileType], 0, 1)
			"ground":
				$Map.setTerrainTiles(tileTypes[tileType], 0, 0)
			"trees":
				$Map.setTerrainTiles(tileTypes[tileType], 0, 2)
	addTrees(tileTypes.trees, "Birch", 4)
	addExits()
	
	var newDirection = "left"
	if direction == "left":
		newDirection = "right"
	elif direction == "top":
		newDirection = "bottom"
	elif direction == "bottom":
		newDirection = "top"
	$Entities/Actors/PlayerActor.position = $Map.map_to_local(generatedChunks[currentChunk].openBorders[newDirection].halfwayTile)

func transformWFCTilesToMapTiles(tiles: Dictionary):
	var mapTiles = {
		"water": [],
		"ground": [],
		"trees": []
	}
	for tile in tiles:
		match currentGeneration:
			"Clearwater Grove":
				if tiles[tile] == 0:
					mapTiles.water.append(tile)
				elif tiles[tile] == 1:
					mapTiles.ground.append(tile)
				elif tiles[tile] == 2:
					mapTiles.trees.append(tile)
	return mapTiles

func addExits():
	for openBorder in generatedChunks[currentChunk].openBorders:
		if generatedChunks[currentChunk].openBorders[openBorder] == null:
			continue
		var directions = {
			"left": Vector2i(-2, 0),
			"right": Vector2i(2, 0),
			"top": Vector2i(0, -5),
			"bottom": Vector2i(0, 3)
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
		tree.init(treeSprites)
		tree.position = $Map.map_to_local(cell)
		tree.name = str(currentChunk) + str(cell)
		$"Entities/OutdoorObjects".add_child(tree)
		
		get_node("Entities/OutdoorObjects/{tree}".format({ "tree": str(currentChunk) + str(cell) })).call_deferred("add_child",
			createCollision(
				cell,
				PackedVector2Array([
					Vector2i(-1, -1),
					Vector2i(-1, 0),
					Vector2i(0, 0),
					Vector2i(-1, 1)
				])
			)
		)

func createCollision(collisionPosition: Vector2i, shape: Array):
	var areaShape = CollisionShape2D.new()
	var areaShapeCollision = ConvexPolygonShape2D.new()
	var chunkMappedTiles = PackedVector2Array()
	
	for point in shape:
		chunkMappedTiles.append(Vector2i($Map.map_to_local(point)))
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
