extends StaticBody2D

func init(sprites: Dictionary, collisionSize: int = 0, collisionPosition: Vector2i = Vector2i()):
	var selectedSprite
	selectedSprite = sprites.sprites[randi() % sprites.sprites.size()]
	var sprite = load("res://Assets/{type}/{sprite}.png".format({ "type": sprites.type, "sprite": selectedSprite }))
	$Sprite2D.texture = sprite
	if collisionSize != 0:
		$CollisionShape2D.shape.radius = collisionSize
		$CollisionShape2D.position = collisionPosition
	#var swayTween = get_tree().create_tween().set_loops()
	#swayTween.tween_property(self, "skew", skew + -.02, 3)
	#swayTween.tween_interval(.75)
	#swayTween.tween_property(self, "skew", skew + .02, 3)
	#swayTween.tween_interval(.75)
