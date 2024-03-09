extends StaticBody2D

func init(sprites: Dictionary, collisionSize: int = 0, collisionPosition: Vector2i = Vector2i()):
	var selectedSprite
	selectedSprite = sprites.sprites[randi() % sprites.sprites.size()]
	var sprite = load("res://Assets/{type}/{sprite}.png".format({ "type": sprites.type, "sprite": selectedSprite }))
	$Sprite2D.texture = sprite
	if collisionSize != 0:
		$CollisionShape2D.shape.radius = collisionSize
		$CollisionShape2D.position = collisionPosition
