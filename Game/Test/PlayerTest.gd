extends CharacterBody2D

@export var speed = 50


func get_input():
	var input_direction = Input.get_vector("MOVE_LEFT", "MOVE_RIGHT", "MOVE_UP", "MOVE_DOWN")
	velocity = Vector2(input_direction.x * speed, input_direction.y * speed / 2)

func _physics_process(_delta):
	get_input()
	move_and_slide()
