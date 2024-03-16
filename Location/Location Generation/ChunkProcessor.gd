extends ChunkProcessorHelperFunctions

var selectedOpenBorderTiles = {
	"left": [],
	"right": [],
	"top": [],
	"bottom": [],
}


func connectBorderEntrances():
	$"..".initPathfindingAstarNode()
	$"..".initWeightedAstarNode()
	for openBorder in selectedOpenBorderTiles:
		for otherOpenBorder in selectedOpenBorderTiles:
			if openBorder != otherOpenBorder and $"..".calculatePath($"..".pathfindingAstarNode, selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint).is_empty():
				connectBorderEntrance(selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint)

func connectBorderEntrance(openBorder, otherOpenBorder):
	var path = $"..".calculatePath($"..".weightedAstarNode, openBorder, otherOpenBorder)
	for tile in path:
		if $"..".get_cell_source_id(0, tile) == 2:
			$"..".generatedChunkTiles[tile] = 1

func getChunkOpenBorderTiles():
	var openBorderTiles = {
		"left": [],
		"right": [],
		"top": [],
		"bottom": []
	}
	var tilesOpen = false
	var firstOpenTile = null
	
	for x in range(2, WaveFunctionCollapse.gridSize.x - 2):
		for y in range(2):
			if $"..".get_cell_source_id(0, Vector2i(x, y)) == 1:
				if !tilesOpen:
					firstOpenTile = 2 * x + y
					tilesOpen = true
			elif tilesOpen:
				openBorderTiles.top.append(
					{
						"firstOpenTile": firstOpenTile,
						"lastOpenTile": 2 * x + y - 1,
						"halfwayPoint": calculateHalfwayPoint("top", firstOpenTile + (((2 * x + y - 1) - firstOpenTile) / 2))
					}
				)
				firstOpenTile = null
				tilesOpen = false
	
	for x in range(2, WaveFunctionCollapse.gridSize.x - 2):
		for y in range(2):
			if $"..".get_cell_source_id(0, Vector2i(x, 46 + y)) == 1:
				if !tilesOpen:
					firstOpenTile = 2 * x + y
					tilesOpen = true
			elif tilesOpen:
				openBorderTiles.bottom.append(
					{
						"firstOpenTile": firstOpenTile,
						"lastOpenTile": 2 * x + y - 1,
						"halfwayPoint": calculateHalfwayPoint("bottom", firstOpenTile + (((2 * x + y - 1) - firstOpenTile) / 2))
					}
				)
				firstOpenTile = null
				tilesOpen = false
	
	for y in range(4, WaveFunctionCollapse.gridSize.y - 3):
		if $"..".get_cell_source_id(0, Vector2i(0, y)) == 1:
			if !tilesOpen:
				firstOpenTile = y
				tilesOpen = true
		elif tilesOpen:
			openBorderTiles.left.append(
				{
					"firstOpenTile": firstOpenTile,
					"lastOpenTile": y - 1,
					"halfwayPoint": calculateHalfwayPoint("left", firstOpenTile + (((y - 1) - firstOpenTile) / 2))
				}
			)
			firstOpenTile = null
			tilesOpen = false
	
	for y in range(4, WaveFunctionCollapse.gridSize.y - 3):
		if $"..".get_cell_source_id(0, Vector2i(23, y)) == 1:
			if !tilesOpen:
				firstOpenTile = y
				tilesOpen = true
		elif tilesOpen:
			openBorderTiles.right.append(
				{
					"firstOpenTile": firstOpenTile,
					"lastOpenTile": y - 1,
					"halfwayPoint": calculateHalfwayPoint("right", firstOpenTile + (((y - 1) - firstOpenTile) / 2))
				}
			)
			firstOpenTile = null
			tilesOpen = false
	
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

func calculateHalfwayPoint(openBorder, halfwayPoint) -> Vector2i:
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

func randomizeTrees(treeChance: int):
	for cell in $"..".generatedChunkTiles:
		if randi() % 100 < treeChance:
			$"..".generatedChunkTiles[cell] = 2

func cleanUpTile(tile: int, toTile: int, areaSize: int):
	var areas = []
	for x in range(24):
		for y in range(48):
			if $"..".generatedChunkTiles[Vector2i(x, y)] == tile and !isTileAlreadyInAnArea(Vector2i(x, y), areas):
				areas.append(getArea(Vector2i(x, y), tile))
	
	for area in areas:
		if area.size() < areaSize:
			for tilePosition in area:
				$"..".generatedChunkTiles[tilePosition] = toTile
