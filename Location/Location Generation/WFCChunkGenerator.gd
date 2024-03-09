extends Node2D

@onready var waveFunctionCollapse = preload("res://Location/Location Generation/WaveFunctionCollapse.tscn")
var dynamicSprite = load("res://Nodes/DynamicSprite/DynamicSprite.tscn")


func generateChunk(input: String):
	$WFCInputCreation.addInputs(input)
	WaveFunctionCollapse.inputs[input] = $WFCInputCreation.assignInputsForInputSet()
	$WFCInputCreation.removeInputs()
	
	var waveFunctionCollapseInstance = waveFunctionCollapse.instantiate()
	waveFunctionCollapseInstance.name = "WFC"
	waveFunctionCollapseInstance.selectInputSet(input)
	add_child(waveFunctionCollapseInstance)
	$WFC.generateChunk(Vector2i(0,0))

func processTiles(tile: int, toTile: int, areaSize: int):
	cleanUpTile(tile, toTile, areaSize)
	addTrees("Birch", 4)

func addTrees(treeType: String, treeTypeAmount: int):
	var treeSprites = { "type": "Outdoor Objects", "sprites": []}
	for index in range(1, treeTypeAmount + 1):
		treeSprites.sprites.append("{treeType}{index}".format({ "treeType": treeType, "index": index }))
	for cell in $"..".get_used_cells_by_id(0, 3, Vector2i(0, 0)):
		var tree = dynamicSprite.instantiate()
		tree.init(treeSprites)
		#tree.init({ "type": "Outdoor Objects", "sprites": ["CactusBall"]})
		tree.position = $"../".map_to_local(cell)# + Vector2i(12, 6)
		tree.name = str(cell)
		#var tree = load("res://Assets/Outdoor Objects/{treeType}{treeTypeAmount}.png".format({ "treeType": treeType, treeTypeAmount: randi() % 4 + 1 }))
		#tree.add_child(
			#createCollision(
				#cell,
				#PackedVector2Array([
					#Vector2i(-1, -1),
					#Vector2i(-1, 0),
					#Vector2i(0, 0),
					#Vector2i(-1, 1)
				#])
			#)
		#)
		$"../../Entities/OutdoorObjects".add_child(tree)
		
		get_node("../../Entities/OutdoorObjects/{tree}".format({ "tree": str(cell) })).add_child(
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
		chunkMappedTiles.append($"..".map_to_local(point))
	areaShapeCollision.set_point_cloud(chunkMappedTiles)
	
	areaShape.name = str(collisionPosition)
	#areaShape.position = Vector2(
		#$"..".map_to_local(collisionPosition).x,
		#$"..".map_to_local(collisionPosition).y
	#)
	areaShape.shape = areaShapeCollision
	
	return areaShape

func cleanUpTile(tile: int, toTile: int, areaSize: int):
	var areas = []
	for x in range(24):
		for y in range(48):
			if $"../".get_cell_source_id(0, Vector2i(x, y)) == tile and !isTileAlreadyInAnArea(Vector2i(x, y), areas):
				areas.append(getArea(Vector2i(x, y), tile))
	
	for area in areas:
		if area.size() < areaSize:
			for tilePosition in area:
				$"../".set_cell(0, tilePosition, toTile, Vector2i(0, 0))

func checkAdjacentTilesForTile(_tile, _tileTypes, _checkForTile = true):
	var _tiles = []
	var _directions = [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		#Vector2i(1, -1),
		#Vector2i(1, 0),
		#Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1)
		#Vector2i(-1, 0)
	]
	for _direction in _directions:
		var _checkedTilePosition = Vector2i(_tile.x + _direction.x, _tile.y + _direction.y)
		if !isOutSideTileMap(_checkedTilePosition):
			if isTileOneOfTypes(_checkedTilePosition, _tileTypes) and _checkForTile:
				_tiles.append(_checkedTilePosition)
			elif !isTileOneOfTypes(_checkedTilePosition, _tileTypes) and !_checkForTile:
				_tiles.append(_checkedTilePosition)
	return _tiles

func getArea(tile, tileType):
	var areaTiles = [tile]
	var adjacentTiles = checkAdjacentTilesForTile(tile, [tileType])
	areaTiles.append_array(adjacentTiles)
	while !adjacentTiles.is_empty():
		for adjacentTile in checkAdjacentTilesForTile(adjacentTiles.pop_back(), [tileType]):
			if !areaTiles.has(adjacentTile):
				adjacentTiles.append(adjacentTile)
				areaTiles.append(adjacentTile)
	return areaTiles

func isTileAlreadyInAnArea(tile, areas):
	for area in areas:
		for cell in area:
			if cell == tile:
				return true
	return false

func isOutSideTileMap(point):
	return point.x < 0 or point.y < 0 or point.x >= WaveFunctionCollapse.gridSize.x or point.y >= WaveFunctionCollapse.gridSize.y

func isTileOneOfTypes(tilePosition: Vector2i, tileTypes):
	for tileType in tileTypes:
		if $"../".get_cell_source_id(0, tilePosition) == tileType:
			return true
	return false
