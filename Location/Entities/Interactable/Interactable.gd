extends Area2D

var playerClose = false


func init(interactableType, interactableName, interactablePosition):
	var animations = load("res://Animations/Locations/{interactableType}/{interactableName}Animations.tscn".format({ "interactableType": interactableType, "interactableName": interactableName.capitalize().replace(" ", "") })).instantiate()
	name = interactableName
	animations.name = interactableName
	animations.playAnimation("Sway")
	add_child(animations)
	
	position = interactablePosition

func _physics_process(delta):
	if Input.is_action_just_pressed("INTERACT") and playerClose:
		queue_free()

func _on_body_entered(body):
	if body.name == "PlayerActor":
		playerClose = true


func _on_body_exited(body):
	if body.name == "PlayerActor":
		playerClose = false
