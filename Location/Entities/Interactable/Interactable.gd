extends Area2D

var playerClose = false


func init(interactableType, interactableName, interactablePosition):
	var animations = load("res://Animations/Locations/{interactableType}/{interactableName}Animations.tscn".format({ "interactableType": interactableType, "interactableName": interactableName.capitalize().replace(" ", "") })).instantiate()
	animations.initAnimations("Sway")
	name = interactableName + str(Locations.actorId)
	animations.name = interactableName + str(Locations.actorId)
	Locations.actorId += 1
	animations.playAnimation("Sway")
	add_child(animations)
	
	position = interactablePosition + Vector2i(0, 3)

func _physics_process(_delta):
	if Input.is_action_just_pressed("INTERACT") and playerClose:
		queue_free()


func _on_body_entered(body):
	if body.name == "PlayerActor":
		playerClose = true
	if body.name == "PlayerActor":
		get_node("{name}".format({ "name": name })).playAnimation("Shake", true)

func _on_body_exited(body):
	if body.name == "PlayerActor":
		playerClose = false
