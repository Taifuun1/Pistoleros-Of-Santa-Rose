extends CharacterBody2D

@export var speed = 125


func get_input():
	var input_direction = Input.get_vector("MOVE_LEFT", "MOVE_RIGHT", "MOVE_UP", "MOVE_DOWN")
	velocity = Vector2(input_direction.x * speed, input_direction.y * speed / 2)
	if velocity == Vector2(0, 0):
		$AnimationPlayer.play("Idle")
	else:
		$AnimationPlayer.play("Run")
		if velocity.x == 0:
			pass
		elif velocity.x < 0:
			$Sprite2D.set_flip_h(true)
		else:
			$Sprite2D.set_flip_h(false)

func _physics_process(_delta):
	get_input()
	move_and_slide()
