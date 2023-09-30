extends TileMap

var gridSize = Vector2i(0,0)


func create():
	var usedCells = get_used_cells(0)
	for cellPosition in usedCells:
		if cellPosition.x + 1 > gridSize.x:
			gridSize.x = int(cellPosition.x + 1)
		if cellPosition.y + 1 > gridSize.y:
			gridSize.y = int(cellPosition.y + 1)
