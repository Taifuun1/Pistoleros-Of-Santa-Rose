extends ActorBase

var outlineShader = load("res://Shaders/Outline.tres")

signal actorSelected
signal actorTurn

var items = ["Paregoric", "Paregoric"]
var abilities = ["Sharp Shot"]


func initFightActor(actorType, actorNameInit, actorPosition, actorSide) -> void:
	var animations = load("res://Animations/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.capitalize().replace(" ", "") })).instantiate()
	var frameHit = FrameData.frameData.animationHits[weapon.weapon]
	var idleAnimation
	if weapon.weapon == "revolver":
		idleAnimation = "Idle Revolver"
	elif weapon.weapon == "rifle":
		idleAnimation = "Idle Rifle"
	else:
		idleAnimation = "Idle"
	animations.initAnimations(idleAnimation, frameHit)
	name = actorNameInit
	animations.name = actorNameInit
	if actorSide == "enemy team":
		animations.flipAnimation()
	animations.playAnimation(idleAnimation)
	add_child(animations)
	
	position = Fight.fightPositions[actorSide][actorPosition.column][actorPosition.row]
	#position.y -= animations.get_node("AnimationSprite").sprite_frames.get_frame_texture(animations.get_node("AnimationSprite").animation, animations.get_node("AnimationSprite").frame).get_size().y / 2
	actorTurn.connect(toggleActorTurn)

func toggleActorTurn() -> void:
	if !$Highlight2.visible:
		$Highlight2.show()
		return
	$Highlight2.hide()


func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if(
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		not event.is_pressed()
	):
		actorSelected.emit()

func _on_area_2d_mouse_entered() -> void:
	get_node("{actorName}/AnimationSprite".format({ "actorName": name })).material = outlineShader

func _on_area_2d_mouse_exited() -> void:
	get_node("{actorName}/AnimationSprite".format({ "actorName": name })).material = null
