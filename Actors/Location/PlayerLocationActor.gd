extends CharacterBody2D

@export var speed = 125

var transparentShader = load("res://Shaders/Transparent.tres")


func get_input():
	var input_direction = Input.get_vector("MOVE_LEFT", "MOVE_RIGHT", "MOVE_UP", "MOVE_DOWN")
	velocity = Vector2(input_direction.x * speed, input_direction.y * speed / 2)
	
	if velocity == Vector2(0, 0):
		$AnimationPlayer.play("Idle")
		$AnimatedSprite2D.animation = "Idle"
	else:
		$AnimationPlayer.play("Run")
		$AnimatedSprite2D.animation = "Run"
		if velocity.x == 0:
			pass
		elif velocity.x < 0:
			$AnimatedSprite2D.set_flip_h(true)
		else:
			$AnimatedSprite2D.set_flip_h(false)


func _physics_process(_delta):
	get_input()
	move_and_slide()


func _on_area_2d_body_entered(body):
	if body.has_node("Sprite2D"):
		body.get_node("Sprite2D").material = transparentShader

func _on_area_2d_body_exited(body):
	if body.has_node("Sprite2D"):
		body.get_node("Sprite2D").material = null
