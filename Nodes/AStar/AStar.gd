extends Node2D
class_name AStar

@onready var pathfindingAstarNode = AStar2D.new()
@onready var weightedAstarNode = AStar2D.new()



func calculatePath(astarNode, pathStartPosition, pathEndPosition, tile1, tile2):
	if !hasPoint(pathStartPosition):
		print("No point a", pathStartPosition)
		print(tile1, " ", tile2)
	if !hasPoint(pathEndPosition):
		print("No point e", pathEndPosition)
		print(tile1, " ", tile2)
	return astarNode.get_point_path(id(pathStartPosition), id(pathEndPosition))

func initPathfindingAstarNode(tiles: Dictionary):
	pathfindingAstarNode.clear()
	var walkableTiles = addWalkableTiles(pathfindingAstarNode, tiles, [0, 2])
	connectWalkableCells(pathfindingAstarNode, walkableTiles)

func initWeightedAstarNode(tiles: Dictionary):
	weightedAstarNode.clear()
	var walkableTiles = addWalkableTiles(weightedAstarNode, tiles, [])
	for tile in walkableTiles:
		if tiles[tile] == 0:
			weightedAstarNode.set_point_weight_scale(id(tile), 5)
		else:
			weightedAstarNode.set_point_weight_scale(id(tile), 1)
	connectWalkableCells(weightedAstarNode, walkableTiles)

func addWalkableTiles(astarNode, tiles, illegibleIds = null):
	var points = []
	for x in WaveFunctionCollapse.gridSize.x:
		for y in WaveFunctionCollapse.gridSize.y:
			var point = Vector2i(x, y)
			if isTileIllegible(tiles[point], illegibleIds):
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
				Vector2i(point.x, point.y - 1),
				Vector2i(point.x, point.y + 1),
				Vector2i(point.x - 1, point.y + 1),
				Vector2i(point.x - 1, point.y - 1)
			])
		else:
			pointsRelative = PackedVector2Array([
				Vector2i(point.x, point.y - 1),
				Vector2i(point.x, point.y + 1),
				Vector2i(point.x + 1, point.y + 1),
				Vector2i(point.x + 1, point.y - 1)
			])
		for pointRelative in pointsRelative:
			var pointRelativeIndex = id(pointRelative)
			if HelperFunctions.isOutSideTileMap(pointRelative):
				continue
			if not astarNode.has_point(pointRelativeIndex):
				continue
			astarNode.connect_points(pointIndex, pointRelativeIndex, false)

func isTileIllegible(tile, illegibleIds):
	for illegibleId in illegibleIds:
		if tile == illegibleId:
			return true
	return false

func hasPoint(point):
	return pathfindingAstarNode.has_point(id(point))

func id(point):
	var a = point.x
	var b = point.y
	return (a + b) * (a + b + 1) / 2 + b
