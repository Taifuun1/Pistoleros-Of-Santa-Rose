extends Node2D

@onready var waveFunctionCollapse = preload("res://Location/Location Generation/WaveFunctionCollapse.tscn")
var dynamicSprite = load("res://Nodes/DynamicSprite/DynamicSprite.tscn")

var selectedOpenBorderTiles = {
	"left": [],
	"right": [],
	"top": [],
	"bottom": [],
}


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
	#cleanUpTile(tile, toTile, areaSize)
	getChunkOpenBorderTiles()
	connectBorderEntrances()
	addTrees("Birch", 4)

func connectBorderEntrances():
	$"..".initPathfindingAstarNode()
	for openBorder in selectedOpenBorderTiles:
		for otherOpenBorder in selectedOpenBorderTiles:
			if openBorder != otherOpenBorder and $"..".calculatePath($"..".pathfindingAstarNode, selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint).is_empty():
				print("no path ", openBorder, otherOpenBorder, selectedOpenBorderTiles[openBorder], selectedOpenBorderTiles[otherOpenBorder])
				connectBorderEntrance(selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint)
			else:
				print("path ", openBorder, otherOpenBorder, selectedOpenBorderTiles[openBorder], selectedOpenBorderTiles[otherOpenBorder])
	print()
	$"..".initPathfindingAstarNode()
	for openBorder in selectedOpenBorderTiles:
		for otherOpenBorder in selectedOpenBorderTiles:
			if openBorder != otherOpenBorder and $"..".calculatePath($"..".pathfindingAstarNode, selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint).is_empty():
				print("no path ", openBorder, otherOpenBorder, selectedOpenBorderTiles[openBorder], selectedOpenBorderTiles[otherOpenBorder])
			else:
				print("path ", openBorder, otherOpenBorder, selectedOpenBorderTiles[openBorder], selectedOpenBorderTiles[otherOpenBorder])

func connectBorderEntrance(openBorder, otherOpenBorder):
	$"..".initWeightedAstarNode()
	var path = $"..".calculatePath($"..".weightedAstarNode, openBorder, otherOpenBorder)
	for tile in path:
		if $"..".get_cell_source_id(0, tile) == 3:
			$"..".set_cell(0, tile, 1, Vector2i(0, 0))

func getChunkOpenBorderTiles():
	var openBorderTiles = {
		"left": [],
		"right": [],
		"top": [],
		"bottom": []
	}
	var tilesOpen = false
	var firstOpenTile = null
	
	#for x in range(2, WaveFunctionCollapse.gridSize.x - 2):
		#for y in range(2):
			#if $"..".get_cell_source_id(0, Vector2i(x, y)) == 1:
				#if !tilesOpen:
					#firstOpenTile = 2 * x + y
					#tilesOpen = true
			#elif tilesOpen:
				#openBorderTiles.top.append(
					#{
						#"firstOpenTile": firstOpenTile,
						#"lastOpenTile": 2 * x + y - 1,
						#"halfwayPoint": calculateHalfwayPoint("top", firstOpenTile + (((2 * x + y - 1) - firstOpenTile) / 2), openBorderTiles)
					#}
				#)
				#firstOpenTile = null
				#tilesOpen = false
	#
	#for x in range(2, WaveFunctionCollapse.gridSize.x - 2):
		#for y in range(2):
			#if $"..".get_cell_source_id(0, Vector2i(x, 46 + y)) == 1:
				#if !tilesOpen:
					#firstOpenTile = 2 * x + y
					#tilesOpen = true
			#elif tilesOpen:
				#openBorderTiles.bottom.append(
					#{
						#"firstOpenTile": firstOpenTile,
						#"lastOpenTile": 2 * x + y - 1,
						#"halfwayPoint": calculateHalfwayPoint("bottom", firstOpenTile + (((2 * x + y - 1) - firstOpenTile) / 2), openBorderTiles)
					#}
				#)
				#firstOpenTile = null
				#tilesOpen = false
	#
	#for y in range(4, WaveFunctionCollapse.gridSize.y - 3):
		#if $"..".get_cell_source_id(0, Vector2i(0, y)) == 1:
			#if !tilesOpen:
				#firstOpenTile = y
				#tilesOpen = true
		#elif tilesOpen:
			#openBorderTiles.left.append(
				#{
					#"firstOpenTile": firstOpenTile,
					#"lastOpenTile": y - 1,
					#"halfwayPoint": calculateHalfwayPoint("left", firstOpenTile + (((y - 1) - firstOpenTile) / 2), openBorderTiles)
				#}
			#)
			#firstOpenTile = null
			#tilesOpen = false
	#
	#for y in range(4, WaveFunctionCollapse.gridSize.y - 3):
		#if $"..".get_cell_source_id(0, Vector2i(23, y)) == 1:
			#if !tilesOpen:
				#firstOpenTile = y
				#tilesOpen = true
		#elif tilesOpen:
			#openBorderTiles.right.append(
				#{
					#"firstOpenTile": firstOpenTile,
					#"lastOpenTile": y - 1,
					#"halfwayPoint": calculateHalfwayPoint("right", firstOpenTile + (((y - 1) - firstOpenTile) / 2), openBorderTiles)
				#}
			#)
			#firstOpenTile = null
			#tilesOpen = false
	
	for border in openBorderTiles:
		if openBorderTiles[border].is_empty():
			openBorderTiles[border].append(generateOpenBorder(border))
	
	for border in openBorderTiles:
		var newBorder = []
		for openBorder in openBorderTiles[border]:
			if openBorder.lastOpenTile - openBorder.firstOpenTile >= 2:
				newBorder.append(openBorder)
		openBorderTiles[border] = newBorder
	
	selectedOpenBorderTiles = {
		"left": openBorderTiles.left[randi() % openBorderTiles.left.size()],
		"right": openBorderTiles.right[randi() % openBorderTiles.right.size()],
		"top": openBorderTiles.top[randi() % openBorderTiles.top.size()],
		"bottom": openBorderTiles.bottom[randi() % openBorderTiles.bottom.size()]
	}

func generateOpenBorder(border):
	var openBorder = {}
	
	if border == "left" or border == "right":
		var firstOpenTile = Vector2i(0, (randi() % (WaveFunctionCollapse.gridSize.y - 5)) + 4)
		if border == "right":
			firstOpenTile.x = 23
		openBorder = {
			"firstOpenTile": firstOpenTile.y,
			"lastOpenTile": firstOpenTile.y + 4,
			"halfwayPoint": firstOpenTile + Vector2i(0, 2)
		}
	else:
		var firstOpenTile = Vector2i((randi() % (WaveFunctionCollapse.gridSize.x - 3)) + 2, 0)
		if border == "bottom":
			firstOpenTile.y = 46
		if firstOpenTile.x % 2 == 1:
			firstOpenTile.y += 1
		openBorder = {
			"firstOpenTile": firstOpenTile.x,
			"lastOpenTile": firstOpenTile.x + 4,
			"halfwayPoint": (firstOpenTile + Vector2i(2, 0)) / 2
		}
	
	return openBorder
	#selectedOpenBorderTiles[border].append(openBorder)

func calculateHalfwayPoint(openBorder, halfwayPoint, openBorderTiles) -> Vector2i:
	var halfwayPointTile = Vector2i(0, 0)
	if openBorder == "left" or openBorder == "right":
		halfwayPointTile.y = halfwayPoint
		if openBorder == "left":
			halfwayPointTile.x = 0
		if openBorder == "right":
			halfwayPointTile.x = 23
	elif openBorder == "top" or openBorder == "bottom":
		if halfwayPoint % 2 == 0:
			halfwayPointTile.x = halfwayPoint / 2
			if openBorder == "top":
				halfwayPointTile.y = 0
			if openBorder == "bottom":
				halfwayPointTile.y = 46
		else:
			halfwayPointTile.x = halfwayPoint / 2
			if openBorder == "top":
				halfwayPointTile.y = 1
			if openBorder == "bottom":
				halfwayPointTile.y = 47
	return halfwayPointTile

func addTrees(treeType: String, treeTypeAmount: int):
	var treeSprites = { "type": "Outdoor Objects", "sprites": []}
	for index in range(1, treeTypeAmount + 1):
		treeSprites.sprites.append("{treeType}{index}".format({ "treeType": treeType, "index": index }))
	for cell in $"..".get_used_cells_by_id(0, 3, Vector2i(0, 0)):
		if randi() % 6 != 0:
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
		#else:
			#$"..".set_cell(0, cell, 1, Vector2i(0, 0))

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
