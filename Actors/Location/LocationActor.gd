extends CharacterBody2D

var speed = 25


func _ready():
	await get_tree().physics_frame
	calculatePath()
	set_physics_process(false)
	call_deferred("set_physics_process", true)

func _physics_process(delta):
	#var direction = to_local($NavigationAgent2D.get_next_path_position()).normalized()
	#
	#velocity = direction * speed
	#
	#move_and_slide()
	
	var direction = Vector2.ZERO
	
	direction = $NavigationAgent2D.get_next_path_position() - global_position
	direction = direction.normalized()
	
	velocity = direction * speed
	
	move_and_slide()

func calculatePath():
	$NavigationAgent2D.target_position = get_tree().current_scene.get_node("Entities/Actors/PlayerActor").global_position
	
	#var direction = Vector2.ZERO
	#
	#direction = $NavigationAgent2D.get_next_path_position() - global_position
	#direction = direction.normalized()
	#
	#velocity = direction * speed
	#
	#move_and_slide()
	
	$Timer.start(0.1)
