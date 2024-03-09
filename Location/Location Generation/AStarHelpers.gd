extends TileMap

@onready var astarNode = AStarGrid2D.new()


func init():
	astarNode.region = get_used_rect()
	astarNode.cell_size = Vector2i(12, 12)
	astarNode.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astarNode.update()
	
	for x in get_used_rect().size.x:
		for y in get_used_rect().size.y:
			var tile = Vector2i(x + get_used_rect().position.x, y + get_used_rect().position.y)
			var tileData = get_cell_tile_data(0, tile)
			if tileData == null:
				astarNode.set_point_solid(tile)
