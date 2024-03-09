extends Node2D

var tileCount
var tiles = [Vector2i(0, 0)]
var borderTiles = [Vector2i(0, 0)]


func _ready():
	randomize()
	generateMap()

func generateMap(type: String = "Clearwater Grove"):
	match type:
		"Clearwater Grove":
			createClearwaterGroveMapLayout()
	
	for index in 10:
		var randomTile = tiles[randi() % tiles.size()]
		if randomTile != Vector2i(0, 0):
			tiles.erase(randomTile)
	
	for tile in tiles:
		$TileMap.set_cell(0, tile, 0, Vector2i(0, 0))
	
	$TileMap.init()
	var newTiles = []
	for tile in tiles:
		print(tile)
		print($TileMap.astarNode.get_id_path(Vector2i(0, 0), tile))
		print()
		if !$TileMap.astarNode.get_id_path(Vector2i(0, 0), tile).is_empty():
			newTiles.append(tile)
	tiles = newTiles
	
	
	drawTiles()
	
	var box = ColorRect.new()
	box.position = Vector2i(6,6)
	box.set_size(Vector2i(10, 10))
	box.color = Color(0, 0, 1)
	add_child(box)
	
	$TileMap.clear()

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

func drawTiles():
	for tile in tiles:
		drawBox($TileMap.map_to_local(tile))

func drawBox(boxPosition):
	var box = ColorRect.new()
	box.position = boxPosition
	box.set_size(Vector2i(10, 10))
	box.color = Color(0, 1, 0)
	add_child(box)
