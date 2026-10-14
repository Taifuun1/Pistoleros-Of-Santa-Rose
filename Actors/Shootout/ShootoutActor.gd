extends ActorBase

var outlineShader = load("res://Shaders/Outline.tres")

signal actorSelected
signal actorTurn
signal actorHovered
signal actorUnhovered



func initShootoutActor(actorType, actorNameInit, actorPosition, actorSide) -> void:
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
	
	position = Shootout.shootoutPositions[actorSide][actorPosition]
	actorTurn.connect(toggleActorTurn)

func toggleActorTurn() -> void:
	if !$Highlight2.visible:
		$Highlight2.show()
		return
	$Highlight2.hide()

func getAnimations() -> Node:
	var node = get_node_or_null(str(name))
	return node


func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if(
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		not event.is_pressed()
	):
		actorSelected.emit()

func _on_area_2d_mouse_entered() -> void:
	# Null-safe: a misnamed animations child must not crash the hover (the
	# outline is cosmetic; the hover payload still updates the stat panel).
	var sprite = get_node_or_null("{actorName}/AnimationSprite".format({ "actorName": name }))
	if sprite != null:
		sprite.material = outlineShader
	actorHovered.emit()

func _on_area_2d_mouse_exited() -> void:
	var sprite = get_node_or_null("{actorName}/AnimationSprite".format({ "actorName": name }))
	if sprite != null:
		sprite.material = null
	actorUnhovered.emit()
