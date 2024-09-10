extends AStar
class_name ChunkProcessorBase

var waterNoise = load("res://Location/Location Generation/Noise Maps/ClearwaterGroveLakes.tres")


func calculateHalfwayPoint(openBorder, halfwayPoint) -> Vector2i:
	var halfwayPointTile = Vector2i(0, 0)
	if openBorder == "left" or openBorder == "right":
		halfwayPointTile.y = halfwayPoint
		if openBorder == "left":
			halfwayPointTile.x = 0
		if openBorder == "right":
			halfwayPointTile.x = 23
	elif openBorder == "top" or openBorder == "bottom":
		halfwayPointTile.x = halfwayPoint / 2
		if halfwayPoint % 2 == 0:
			if openBorder == "top":
				halfwayPointTile.y = 0
			if openBorder == "bottom":
				halfwayPointTile.y = 46
		else:
			if openBorder == "top":
				halfwayPointTile.y = 1
			if openBorder == "bottom":
				halfwayPointTile.y = 47
	return halfwayPointTile

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
		if !HelperFunctions.isOutSideTileMap(_checkedTilePosition):
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

func isTileInOpenBorder(tile):
	for border in $"..".generatedChunk.openBorders:
		if (
			$"..".generatedChunk.openBorders[border] != null and
			$"..".generatedChunk.openBorders[border].tiles.has(tile)
		):
			return true
	return false

func isTileAlreadyInAnArea(tile, areas):
	for area in areas:
		for cell in area:
			if cell == tile:
				return true
	return false

func isTileOneOfTypes(tilePosition: Vector2i, tileTypes):
	for tileType in tileTypes:
		if $"..".generatedChunk.tiles[tilePosition] == tileType:
			return true
	return false
