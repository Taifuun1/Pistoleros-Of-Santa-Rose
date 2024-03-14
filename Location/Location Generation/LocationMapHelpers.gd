extends Node2D
class_name LocationMapHelpers

var dynamicSprite = load("res://Nodes/DynamicSprite/DynamicSprite.tscn")


func addTrees(treeType: String, treeTypeAmount: int):
	var treeSprites = { "type": "Outdoor Objects", "sprites": []}
	for index in range(1, treeTypeAmount + 1):
		treeSprites.sprites.append("{treeType}{index}".format({ "treeType": treeType, "index": index }))
	for cell in $Map.get_used_cells_by_id(0, 2, Vector2i(0, 0)):
		var tree = dynamicSprite.instantiate()
		tree.init(treeSprites)
		tree.position = $Map.map_to_local(cell)
		tree.name = str(cell)
		$"Entities/OutdoorObjects".add_child(tree)
	
		get_node("Entities/OutdoorObjects/{tree}".format({ "tree": str(cell) })).add_child(
			createCollision(
				cell,
				PackedVector2Array([
					Vector2i(-1, -1),
					Vector2i(-1, 0),
					Vector2i(0, 0),
					Vector2i(-1, 1)
				])
			)
		)

func createCollision(collisionPosition: Vector2i, shape: Array):
	var areaShape = CollisionShape2D.new()
	var areaShapeCollision = ConvexPolygonShape2D.new()
	var chunkMappedTiles = PackedVector2Array()
	
	for point in shape:
		chunkMappedTiles.append($Map.map_to_local(point))
	areaShapeCollision.set_point_cloud(chunkMappedTiles)
	
	areaShape.name = str(collisionPosition)
	areaShape.shape = areaShapeCollision
	
	return areaShape
