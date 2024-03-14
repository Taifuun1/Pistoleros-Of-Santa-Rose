extends TileMap


func setTiles(tiles):
	for tile in tiles:
		set_cell(0, Vector2i(tile.x, tile.y), tiles[tile], Vector2(0, 0))
