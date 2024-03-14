extends Node2D
class_name ChunkProcessorHelperFunctions


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

func isTileAlreadyInAnArea(tile, areas):
	for area in areas:
		for cell in area:
			if cell == tile:
				return true
	return false

func isTileOneOfTypes(tilePosition: Vector2i, tileTypes):
	for tileType in tileTypes:
		if $"..".generatedChunkTiles[tilePosition] == tileType:
			return true
	return false
