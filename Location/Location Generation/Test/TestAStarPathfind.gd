extends TileMap

@onready var astarNode = AStar2D.new()


func _ready():
	init()

func calculatePathFindingPath(pathStartPosition, pathEndPosition):
	return astarNode.get_point_path(id(pathStartPosition), id(pathEndPosition))

func init():
	astarNode.clear()
	var walkableTiles = addWalkableTiles()
	connectWalkableCells(walkableTiles)

func addWalkableTiles():
	var points = []
	for x in 5:
		for y in 11:
			var point = Vector2(x, y)
			points.append(point)
			astarNode.add_point(id(point), point, 1.0)
	return points

func connectWalkableCells(points):
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
				if HelperFunctions.isOutSideTileMap(pointRelative):
					continue
				if not astarNode.has_point(pointRelativeIndex):
					continue
				astarNode.connect_points(pointIndex, pointRelativeIndex, false)

func hasPoint(point):
	return astarNode.has_point(id(point))

func id(point):
	var a = point.x
	var b = point.y
	return (a + b) * (a + b + 1) / 2 + b
