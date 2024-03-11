extends TileMap
class_name AStarHelper

@onready var pathfindingAstarNode = AStar2D.new()
@onready var weightedAstarNode = AStar2D.new()



func calculatePath(astarNode, pathStartPosition, pathEndPosition):
	return astarNode.get_point_path(id(pathStartPosition), id(pathEndPosition))

func initPathfindingAstarNode():
	pathfindingAstarNode.clear()
	var walkableTiles = addWalkableTiles(pathfindingAstarNode, 3)
	connectWalkableCells(pathfindingAstarNode, walkableTiles)

func initWeightedAstarNode():
	weightedAstarNode.clear()
	var walkableTiles = addWalkableTiles(weightedAstarNode)
	for tile in walkableTiles:
		if get_cell_source_id(0, tile) == 1 or get_cell_source_id(0, tile) == 3:
			weightedAstarNode.set_point_weight_scale(id(tile), randi() % 10)
	connectWalkableCells(weightedAstarNode, walkableTiles)

func addWalkableTiles(astarNode, illegibleId = null):
	var points = []
	for x in WaveFunctionCollapse.gridSize.x:
		for y in WaveFunctionCollapse.gridSize.y:
			var point = Vector2(x, y)
			#for illegibleId in illegibleIds:
			if get_cell_source_id(0, point) == illegibleId:
					#set_cell(0, point, 1, Vector2i(0, 0))
				continue
			points.append(point)
			astarNode.add_point(id(point), point, 1.0)
	return points

func connectWalkableCells(astarNode, points):
	for point in points:
		var pointIndex = id(point)
		var pointsRelative
		if int(point.y) % 2 == 0:
			pointsRelative = PackedVector2Array([
				Vector2(point.x, point.y - 1),
				Vector2(point.x, point.y + 1),
				Vector2(point.x - 1, point.y + 1),
				Vector2(point.x - 1, point.y - 1)
			])
		else:
			pointsRelative = PackedVector2Array([
				Vector2(point.x, point.y - 1),
				Vector2(point.x, point.y + 1),
				Vector2(point.x + 1, point.y + 1),
				Vector2(point.x + 1, point.y - 1)
			])
		for pointRelative in pointsRelative:
				var pointRelativeIndex = id(pointRelative)
				if isOutSideTileMap(pointRelative):
					continue
				if not astarNode.has_point(pointRelativeIndex):
					continue
				astarNode.connect_points(pointIndex, pointRelativeIndex, false)

func isOutSideTileMap(point):
	return point.x < 0 or point.y < 0 or point.x >= WaveFunctionCollapse.gridSize.x or point.y >= WaveFunctionCollapse.gridSize.y

func hasPoint(point):
	return pathfindingAstarNode.has_point(id(point))

func id(point):
	var a = point.x
	var b = point.y
	return (a + b) * (a + b + 1) / 2 + b

#func initAStar():
	#astarNode.region = get_used_rect()
	#astarNode.cell_size = Vector2i(12, 12)
	#astarNode.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	#astarNode.update()
	#
	#for x in get_used_rect().size.x:
		#for y in get_used_rect().size.y:
			#var tile = Vector2i(x + get_used_rect().position.x, y + get_used_rect().position.y)
			#var tileId = get_cell_source_id(0, tile)
			#if tileId == -1 or tileId == 3:
				#astarNode.set_point_solid(tile)
#
#func initWeightedAStar():
	#weightedAstarNode.region = get_used_rect()
	#weightedAstarNode.cell_size = Vector2i(12, 12)
	#weightedAstarNode.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	#weightedAstarNode.update()
	#
	#for x in get_used_rect().size.x:
		#for y in get_used_rect().size.y:
			#var tile = Vector2i(x + get_used_rect().position.x, y + get_used_rect().position.y)
			#var tileData = get_cell_tile_data(0, tile)
			#var tileId = get_cell_source_id(0, tile)
			#if tileData == null:
				#weightedAstarNode.set_point_solid(tile)
			#if tileId == 1 or tileId == 3:
				#weightedAstarNode.set_point_weight_scale(tile, randi() % 10)
