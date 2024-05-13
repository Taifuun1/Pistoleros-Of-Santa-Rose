extends ActorBase

signal actorSelected


func initFightActor(actorType, actorNameInit, actorPosition, actorSide):
	var animations = load("res://Animations/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.capitalize().replace(" ", "") })).instantiate()
	animations.init("Idle")
	name = actorNameInit
	animations.name = actorNameInit
	if actorSide == "enemy team":
		animations.flipAnimation()
	animations.playAnimation("Idle")
	add_child(animations)
	
	position = Fight.fightPositions[actorSide][actorPosition.column][actorPosition.row]


func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if(
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		not event.is_pressed()
	):
		actorSelected.emit()
