extends TileMap
class_name AStarGrid

@onready var astarGridNode = AStarGrid2D.new()


func initAStarGrid():
	astarGridNode.region = get_used_rect()
	astarGridNode.cell_size = Vector2i(12, 12)
	astarGridNode.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astarGridNode.update()
	
	for x in get_used_rect().size.x:
		for y in get_used_rect().size.y:
			var tile = Vector2i(x + get_used_rect().position.x, y + get_used_rect().position.y)
			var tileId = get_cell_source_id(0, tile)
			if tileId == -1 or tileId == 2:
				astarGridNode.set_point_solid(tile)
