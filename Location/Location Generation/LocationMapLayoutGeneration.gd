extends Node2D

var tileCount
var tiles = [Vector2i(0, 0)]
var borderTiles = [Vector2i(0, 0)]


func generateMapLayout(type: String = "Clearwater Grove") -> Array:
	match type:
		"Clearwater Grove":
			createClearwaterGroveMapLayout()
	
	for index in 10:
		var randomTile = tiles[randi() % tiles.size()]
		if randomTile != Vector2i(0, 0):
			tiles.erase(randomTile)
	
	for tile in tiles:
		$TileMap.set_cell(0, tile, 0, Vector2i(0, 0))
	
	$TileMap.initAStarGrid()
	var newTiles = []
	for tile in tiles:
		if !$TileMap.astarGridNode.get_id_path(Vector2i(0, 0), tile).is_empty():
			newTiles.append(tile)
	tiles = newTiles
	
	tiles.erase(Vector2i(0, 0))
	$TileMap.clear()
	
	return tiles

func createClearwaterGroveMapLayout():
	tileCount = 75
	while tileCount > 0:
		var expandedTile = borderTiles[randi() % borderTiles.size()]
		var expandedTileHorizontal = expandedTile.x
		if expandedTile.x == 0:
			expandedTileHorizontal = 1
		if randi() % abs(expandedTileHorizontal) == 0:
			var newTiles = [
				expandedTile + Vector2i(1, 0),
				expandedTile + Vector2i(-1, 0),
				expandedTile + Vector2i(0, 1)
			]
			for newTile in newTiles:
				if !tiles.has(newTile):
					tiles.append(newTile)
					borderTiles.append(newTile)
					tileCount -= 1
				borderTiles.erase(expandedTile)
		else:
			var newTile = expandedTile + Vector2i(0, 1)
			if !tiles.has(newTile):
				tiles.append(newTile)
				borderTiles.append(newTile)
				tileCount -= 1
			borderTiles.erase(expandedTile)
