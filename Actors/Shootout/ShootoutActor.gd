extends ActorBase

const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")

var outlineShader = load("res://Shaders/Outline.tres")

signal actorSelected
signal actorTurn
signal actorHovered
signal actorUnhovered

var characterUIHidden = false



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
	animations.name = actorNameInit
	if actorSide == "enemy team":
		animations.flipAnimation()
	animations.playAnimation(idleAnimation)
	add_child(animations)
	# Drop shadow under the fighter (see Nodes/Actor Shadow/ActorShadow.gd).
	ShadowScript.attachTo(animations)
	# Input/hover collision follows the animation sprite: the default feet-only
	# 16x12 rectangle made clicks and hover miss the character's body. The box
	# is centered on the sprite's drawn rect — AnimatedSprite2D offsets put the
	# drawn body above the actor origin (Walker Langley's sprite center sits
	# 15px up), so a shape centered at the origin missed the head. The width is
	# capped at the column spacing so side-by-side actors' boxes never overlap
	# (columns sit 30px apart while sprites are 40px wide).
	var frameSize = Vector2(16, 12)
	var frameCenter = Vector2.ZERO
	var animationSprite = animations.get_node_or_null("AnimationSprite")
	if animationSprite != null and animationSprite.sprite_frames != null:
		var frameTexture = animationSprite.sprite_frames.get_frame_texture(idleAnimation, 0)
		if frameTexture != null:
			frameSize = frameTexture.get_size()
			frameCenter = animations.position + animationSprite.position + animationSprite.offset
			if !animationSprite.centered:
				frameCenter += frameSize / 2.0
	var spriteShape = RectangleShape2D.new()
	spriteShape.size = Vector2(minf(frameSize.x, _minColumnSpacing(actorSide)), frameSize.y)
	$Area2D/CollisionShape2D.position = frameCenter
	$Area2D/CollisionShape2D.shape = spriteShape
	name = actorNameInit
	position = Shootout.shootoutPositions[actorSide][actorPosition]
	actorTurn.connect(showActorTurn)

## Smallest horizontal gap between the side's columns: actors stand in the
## same row, so the gap is also the closest two actors' bodies can get.
func _minColumnSpacing(actorSide: String) -> float:
	var columns = Shootout.shootoutPositions.get(actorSide, {})
	var xs = []
	for column in columns:
		xs.append(float(columns[column].x))
	var spacing = INF
	for i in xs.size():
		for j in range(i + 1, xs.size()):
			spacing = minf(spacing, abs(xs[i] - xs[j]))
	return spacing

## The turn highlight shows only (Shootout hides every other actor's marker
## before the current actor's turn starts; the old toggle left previous actors
## highlighted and hid the marker on an actor's second turn).
func showActorTurn() -> void:
	if characterUIHidden:
		return
	$Highlight2.show()

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
	if !characterUIHidden:
		var sprite = get_node_or_null("{actorName}/AnimationSprite".format({ "actorName": name }))
		if sprite != null:
			sprite.material = outlineShader
	actorHovered.emit()

func _on_area_2d_mouse_exited() -> void:
	var sprite = get_node_or_null("{actorName}/AnimationSprite".format({ "actorName": name }))
	if sprite != null:
		sprite.material = null
	actorUnhovered.emit()
