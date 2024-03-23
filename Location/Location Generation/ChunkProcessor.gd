extends ChunkProcessorBase

var selectedOpenBorderTiles = {
	"left": [],
	"right": [],
	"top": [],
	"bottom": []
}
var nonSelectedOpenBorderTiles = {
	"left": [],
	"right": [],
	"top": [],
	"bottom": []
}


func generateFromNoiseMap(parameters):
	parameters.noiseMap.seed = randi()
	var tilePosition = $"..".local_to_map(Vector2i(0, 0))
	for x in range(24):
		for y in range(48):
			var noise = parameters.noiseMap.get_noise_2d(tilePosition.x + x, tilePosition.y + y)
			
			var tile = 1
			if noise > parameters.noiseCutoff:
				tile = 0
			
			if tile == 0:
				$"..".generatedChunk.tiles[Vector2i(x, y)] = tile

func getOpenBorderTiles():
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
			if $"..".generatedChunk.tiles[Vector2i(x, y)] == 1:
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
			if $"..".generatedChunk.tiles[Vector2i(x, 46 + y)] == 1:
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
	
	for y in range(4, WaveFunctionCollapse.gridSize.y - 4):
		if $"..".generatedChunk.tiles[Vector2i(0, y)] == 1:
			if !tilesOpen:
				firstOpenTile = y
				tilesOpen = true
		elif tilesOpen:
			openBorderTiles.left.append(
				{
					"firstOpenTile": firstOpenTile,
					"lastOpenTile": y - 1,
					"halfwayPoint": calculateHalfwayPoint("left", firstOpenTile + ((y - 1 - firstOpenTile) / 2))
				}
			)
			firstOpenTile = null
			tilesOpen = false
	
	for y in range(4, WaveFunctionCollapse.gridSize.y - 4):
		if $"..".generatedChunk.tiles[Vector2i(23, y)] == 1:
			if !tilesOpen:
				firstOpenTile = y
				tilesOpen = true
		elif tilesOpen:
			openBorderTiles.right.append(
				{
					"firstOpenTile": firstOpenTile,
					"lastOpenTile": y - 1,
					"halfwayPoint": calculateHalfwayPoint("right", firstOpenTile + ((y - 1 - firstOpenTile) / 2))
				}
			)
			firstOpenTile = null
			tilesOpen = false
	
	nonSelectedOpenBorderTiles = openBorderTiles.duplicate(true)
	
	for border in openBorderTiles:
		var newBorder = []
		for openBorder in openBorderTiles[border]:
			if openBorder.lastOpenTile - openBorder.firstOpenTile >= 2:
				newBorder.append(openBorder)
		openBorderTiles[border] = newBorder
	
	for border in openBorderTiles:
		if !$"../../LocationMapLayoutGeneration".tiles.has($"..".generatedChunkPosition + HelperVariables.cardinalDirections[border]):
			selectedOpenBorderTiles[border] = null
			continue
		if openBorderTiles[border].is_empty():
			openBorderTiles[border].append(generateOpenBorder(border))
		selectedOpenBorderTiles[border] = openBorderTiles[border][randi() % openBorderTiles[border].size()]
	
	if $"..".generatedChunkPosition == Vector2i(0, 0):
		selectedOpenBorderTiles.top = {
			"firstOpenTile": 22,
			"lastOpenTile": 25,
			"halfwayPoint": Vector2i(11, 1)
		}
		$"..".generatedChunk.tiles[Vector2i(11, 0)] = 1
		$"..".generatedChunk.tiles[Vector2i(11, 1)] = 1
		$"..".generatedChunk.tiles[Vector2i(12, 0)] = 1
		$"..".generatedChunk.tiles[Vector2i(12, 1)] = 1

func connectBorderEntrances():
	$"..".initPathfindingAstarNode($"..".generatedChunk.tiles)
	$"..".initWeightedAstarNode($"..".generatedChunk.tiles)
	for openBorder in selectedOpenBorderTiles:
		for otherOpenBorder in selectedOpenBorderTiles:
			if (
				openBorder != otherOpenBorder and
				(
					(
						$"..".generatedChunkPosition == Vector2i(0, 0) and
						openBorder == "top"
					) or
					$"../../LocationMapLayoutGeneration".tiles.has($"..".generatedChunkPosition + HelperVariables.cardinalDirections[openBorder])
				) and
				$"../../LocationMapLayoutGeneration".tiles.has($"..".generatedChunkPosition + HelperVariables.cardinalDirections[otherOpenBorder]) and
				$"..".calculatePath($"..".pathfindingAstarNode, selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint, $"..".generatedChunk.tiles[selectedOpenBorderTiles[openBorder].halfwayPoint], $"..".generatedChunk.tiles[selectedOpenBorderTiles[otherOpenBorder].halfwayPoint]).is_empty()
			):
				connectBorderEntrance(selectedOpenBorderTiles[openBorder].halfwayPoint, selectedOpenBorderTiles[otherOpenBorder].halfwayPoint)

func connectBorderEntrance(openBorder, otherOpenBorder):
	var path = $"..".calculatePath($"..".weightedAstarNode, openBorder, otherOpenBorder, $"..".generatedChunk.tiles[openBorder], $"..".generatedChunk.tiles[otherOpenBorder])
	print("connecting ", path)
	for tile in path:
		var tileI = Vector2i(tile.x, tile.y)
		$"..".generatedChunk.tiles[tileI] = 1
	$"..".initPathfindingAstarNode($"..".generatedChunk.tiles)
	$"..".initWeightedAstarNode($"..".generatedChunk.tiles)

func fillVisibleEmptyTiles():
	for border in $"..".generatedChunk.openBorders:
		if $"..".generatedChunk.openBorders[border] != null:
			for tile in $"..".generatedChunk.openBorders[border].tiles:
				if border == "top" or border == "bottom":
					for index in range(1, 5):
						$"..".generatedChunk.tiles[tile + (HelperVariables.cardinalDirections[border] * index)] = 1
				else:
					for index in range(1, 3):
						$"..".generatedChunk.tiles[tile + (HelperVariables.cardinalDirections[border] * index)] = 1
	
	for x in range(-2, WaveFunctionCollapse.gridSize.x + 2):
		for y in range(-4, WaveFunctionCollapse.gridSize.y + 4):
			if (
				!$"..".generatedChunk.tiles.has(Vector2i(x, y)) and
				!isTileInOpenBorder(Vector2i(x, y))
			):
				$"..".generatedChunk.tiles[Vector2i(x, y)] = 2

func transformOpenBordersToTiles():
	var borderTiles = {
		"left": [],
		"right": [],
		"top": [],
		"bottom": []
	}
	for openBorder in selectedOpenBorderTiles:
		if selectedOpenBorderTiles[openBorder] == null:
			borderTiles[openBorder] = null
			continue
		borderTiles[openBorder] = transformOpenBorderToTiles(openBorder, selectedOpenBorderTiles[openBorder])
	
	$"..".generatedChunk.openBorders = borderTiles

func generateOpenBorder(border):
	var openBorder = {}
	var tiles = []
	
	if border == "left" or border == "right":
		var firstOpenTile = Vector2i(0, (randi() % (WaveFunctionCollapse.gridSize.y - 8)) + 4)
		if border == "right":
			firstOpenTile.x = 23
		openBorder = {
			"firstOpenTile": firstOpenTile.y,
			"lastOpenTile": firstOpenTile.y + 4,
			"halfwayPoint": firstOpenTile + Vector2i(0, 2)
		}
		for index in 4:
			tiles.append(Vector2i(firstOpenTile.x, firstOpenTile.y + index))
	else:
		var firstOpenTile = Vector2i((randi() % (WaveFunctionCollapse.gridSize.x - 4)) + 2, 0)
		if border == "bottom":
			firstOpenTile.y = 46
		if firstOpenTile.x % 2 == 1:
			firstOpenTile.y += 1
			tiles.append(Vector2i(firstOpenTile.x / 2, firstOpenTile.y))
			tiles.append(Vector2i(firstOpenTile.x / 2 + 1, firstOpenTile.y - 1))
			tiles.append(Vector2i(firstOpenTile.x / 2 + 1, firstOpenTile.y))
			tiles.append(Vector2i(firstOpenTile.x / 2 + 2, firstOpenTile.y - 1))
		else:
			for x in 2:
				for y in 2:
					tiles.append(Vector2i(firstOpenTile.x / 2 + x, firstOpenTile.y + y))
		openBorder = {
			"firstOpenTile": firstOpenTile.x,
			"lastOpenTile": firstOpenTile.x + 4,
			"halfwayPoint": Vector2i(firstOpenTile.x / 2, firstOpenTile.y)
		}
	
	for tile in tiles:
		$"..".generatedChunk.tiles[tile] = 1
	
	print("border ", border)
	print(openBorder)
	
	return openBorder

func transformOpenBorderToTiles(border, tiles):
	var openBorder = {}
	
	var firstOpenTile = Vector2i(0, 0)
	var lastOpenTile = Vector2i(0, 0)
	
	var topLeft = Vector2i(0, 0)
	var bottomLeft = Vector2i(0, 0)
	var bottomRight = Vector2i(0, 0)
	var topRight = Vector2i(0, 0)
	
	var borderTiles = []
	
	if border == "left" or border == "right":
		firstOpenTile = Vector2i(0, tiles.firstOpenTile)
		lastOpenTile = Vector2i(0, tiles.lastOpenTile)
		
		if border == "right":
			firstOpenTile.x = 23
		
		for y in range(tiles.firstOpenTile, tiles.firstOpenTile + tiles.lastOpenTile - tiles.firstOpenTile + 1):
			borderTiles.append(Vector2i(firstOpenTile.x, y))
		
		if border == "left":
			if tiles.firstOpenTile % 2 == 1:
				topLeft.x += -0.5
				topRight.x += -0.5
			if tiles.lastOpenTile % 2 == 1:
				bottomLeft.x += -0.5
				bottomRight.x += -0.5
			
			topLeft.x += -3
			
			bottomLeft.x += -3
			bottomLeft.y = lastOpenTile.y - firstOpenTile.y
			
			bottomRight.x += -2
			bottomRight.y = lastOpenTile.y - firstOpenTile.y
			
			topRight.x += -2
		elif border == "right":
			if tiles.firstOpenTile % 2 == 1:
				topLeft.x = 0.5
				bottomLeft.x = 0.5
			if tiles.lastOpenTile % 2 == 1:
				topRight.x = 0.5
				bottomRight.x = 0.5
			
			topLeft.x += 2
			
			bottomLeft.x += 2
			bottomLeft.y = lastOpenTile.y - firstOpenTile.y
			
			bottomRight.x += 1
			bottomRight.y = lastOpenTile.y - firstOpenTile.y
			
			topRight.x += 1
	else:
		firstOpenTile.x = tiles.firstOpenTile / 2
		lastOpenTile.x = tiles.lastOpenTile / 2
		
		if border == "bottom":
			firstOpenTile.y = 46
		if firstOpenTile.x % 2 == 1:
			firstOpenTile.y += 1
		if lastOpenTile.x % 2 == 1:
			lastOpenTile.y += 1
		
		if border == "top":
			if firstOpenTile.x % 2 == 1:
				topLeft.x += -0.5
				topLeft.y += -1
				bottomLeft.x = -0.5
				bottomLeft.y += -1
			if lastOpenTile.x % 2 == 1:
				topRight.x = -0.5
				topRight.y += -1
				bottomRight.x = -0.5
				bottomRight.y += -1
			
			topLeft.y += 2 * -1
			
			bottomLeft.y += -1
			
			bottomRight.x += lastOpenTile.x - firstOpenTile.x
			bottomRight.y = -1
			
			topRight.x += lastOpenTile.x - firstOpenTile.x
			topRight.y += 2 * -1
			
			for x in range(firstOpenTile.x, firstOpenTile.x + lastOpenTile.x - firstOpenTile.x + 1):
				for y in 2:
					borderTiles.append(Vector2i(x, y))
		
		if border == "bottom":
			if firstOpenTile.x % 2 == 1:
				topLeft.x += -0.5
				topRight.x += -0.5
				bottomLeft.x += -0.5
			else:
				bottomLeft.x += 0.5
			if lastOpenTile.x % 2 == 1:
				bottomLeft.x += -0.5
				bottomRight.x += -0.5
			
			topLeft.y += 3 * 1
			
			bottomLeft.y += 4 * 1
			
			topRight.x += lastOpenTile.x - firstOpenTile.x
			topRight.y += 3 * 1
			
			bottomRight.x += lastOpenTile.x - firstOpenTile.x
			bottomRight.y += 4 * 1
			
			for x in range(firstOpenTile.x, firstOpenTile.x + lastOpenTile.x - firstOpenTile.x + 1):
				for y in 2:
					borderTiles.append(Vector2i(x, 46 + y))
	
	openBorder = {
		"firstOpenTile": firstOpenTile,
		"lastOpenTile": lastOpenTile,
		"tiles": borderTiles,
		"halfwayTile": tiles.halfwayPoint
	}
	
	return openBorder

func randomizeTileToTile(parameters):
	for cell in $"..".generatedChunk.tiles:
		if $"..".generatedChunk.tiles[cell] == parameters.fromTileType and randi() % 100 < parameters.tileChance:
			$"..".generatedChunk.tiles[cell] = parameters.toTileType

func cleanUpBorders():
	for y in range(0, WaveFunctionCollapse.gridSize.y):
		if (
			$"..".generatedChunk.tiles[Vector2i(0, y)] != 2 and
			(
				(
					$"..".generatedChunk.openBorders.left == null
				) or
				(
					$"..".generatedChunk.openBorders.left != null and
					!$"..".generatedChunk.openBorders.left.tiles.has(Vector2i(0, y))
				)
			)
		):
			$"..".generatedChunk.tiles[Vector2i(0, y)] = 2
	
	for y in range(0, WaveFunctionCollapse.gridSize.y):
		if (
			$"..".generatedChunk.tiles[Vector2i(23, y)] != 2 and
			(
				(
					$"..".generatedChunk.openBorders.right == null
				) or
				(
					$"..".generatedChunk.openBorders.right != null and
					!$"..".generatedChunk.openBorders.right.tiles.has(Vector2i(23, y))
				)
			)
		):
			$"..".generatedChunk.tiles[Vector2i(23, y)] = 2
	
	for x in range(0, WaveFunctionCollapse.gridSize.x):
		for y in range(2):
			if (
				$"..".generatedChunk.tiles[Vector2i(x, y)] != 2 and
				(
					(
						$"..".generatedChunk.openBorders.top == null
					) or
					(
						$"..".generatedChunk.openBorders.top != null and
						!$"..".generatedChunk.openBorders.top.tiles.has(Vector2i(x, y))
					)
				)
			):
				$"..".generatedChunk.tiles[Vector2i(x, y)] = 2
	
	for x in range(0, WaveFunctionCollapse.gridSize.x):
		for y in range(46, 48):
			if (
				$"..".generatedChunk.tiles[Vector2i(x, y)] != 2 and
				(
					(
						$"..".generatedChunk.openBorders.bottom == null
					) or
					(
						$"..".generatedChunk.openBorders.bottom != null and
						!$"..".generatedChunk.openBorders.bottom.tiles.has(Vector2i(x, y))
					)
				)
			):
				$"..".generatedChunk.tiles[Vector2i(x, y)] = 2

func cleanUpTile(parameters):
	var areas = []
	for x in range(24):
		for y in range(48):
			if $"..".generatedChunk.tiles[Vector2i(x, y)] == parameters.fromTile and !isTileAlreadyInAnArea(Vector2i(x, y), areas):
				areas.append(getArea(Vector2i(x, y), parameters.fromTile))
	
	for area in areas:
		if area.size() < parameters.areaSize:
			for tilePosition in area:
				$"..".generatedChunk.tiles[tilePosition] = parameters.toTile
