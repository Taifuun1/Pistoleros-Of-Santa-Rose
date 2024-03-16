extends TileMap


func setTiles(_tiles, _generatedChunk = { x = 1, y = 1 }):
	for _tile in _tiles:
		set_cell(0, Vector2i(_tile.x + _generatedChunk.x, _tile.y + _generatedChunk.y), _tiles[_tile], Vector2i(0, 0))

func resetChunkTiles(_chunk):
	for _x in WaveFunctionCollapse.gridSize.x:
		for _y in WaveFunctionCollapse.gridSize.y:
			erase_cell(0, Vector2i(_x + _chunk.x, _y + _chunk.y))
