extends TileMap


func setTiles(tiles):
	for tile in tiles:
		set_cell(0, Vector2i(tile.x, tile.y), tiles[tile], Vector2i(0, 0))

func setTerrainTiles(tiles, terrainSet, terrain):
	set_cells_terrain_connect(0, tiles, terrainSet, terrain, false)
