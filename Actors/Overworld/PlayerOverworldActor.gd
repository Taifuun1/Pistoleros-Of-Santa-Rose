extends OverworldActorBase

const AnimationServiceScript = preload("res://Globals/ActorAnimationService.gd")
const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")

var _previous_position: Vector2 = Vector2.ZERO
# Commit 19: the wagon's directional animation set resolves through the
# shared registry; the per-view shadow coverage below is unchanged.
var animations: Node = null

## Each wagon view has its own ground footprint: diagonal moves use DIAGONAL
## coverage, straight vertical moves use VERTICAL, and horizontal moves keep
## the default HORIZONTAL feet ellipse. Stopping keeps the last animation's
## frame, so the coverage only changes when a new animation starts.
const BODY_SHADOW_ANIMATIONS_DIAGONAL = ["Move Up Side", "Move Down Side"]
const BODY_SHADOW_ANIMATIONS_VERTICAL = ["Move Up", "Move Down"]


func _ready():
	speed = 350
	_previous_position = position
	animations = AnimationServiceScript.new().forActor("Player", "Player Overworld")
	if animations != null:
		animations.name = "Animations"
		add_child(animations)
		_playAnimation("Move Down Side")
	# Drop shadow under the player (see Nodes/Actor Shadow/ActorShadow.gd).
	ShadowScript.attachTo(self)


func get_input():
	var input_direction = Input.get_vector("MOVE_LEFT", "MOVE_RIGHT", "MOVE_UP", "MOVE_DOWN")
	velocity = Vector2(input_direction.x * speed, input_direction.y * speed / 1.4)
	
	if velocity == Vector2(0, 0):
		# Stopping keeps the last animation's frame (the legacy pause).
		if animations != null:
			animations.get_node("AnimationPlayer").pause()
	elif (
		(
			velocity.x < 0 and
			velocity.y < 0
		) or
		(
			velocity.x > 0 and
			velocity.y < 0
		)
	):
		_playAnimation("Move Up Side")
		_setFlip(velocity.x < 0)
	elif (
		(
			velocity.x < 0 and
			velocity.y > 0
		) or
		(
			velocity.x > 0 and
			velocity.y > 0
		)
	):
		_playAnimation("Move Down Side")
		_setFlip(velocity.x < 0)
	elif velocity.y < 0:
		_playAnimation("Move Up")
	elif velocity.y > 0:
		_playAnimation("Move Down")
	elif velocity.x < 0 or velocity.x > 0:
		_playAnimation("Move Side")
		_setFlip(velocity.x < 0)

## Plays a registry state without restarting it every physics frame (the
## legacy AnimationPlayer.play() kept playing; a forced restart would pin
## the wagon on its first frame).
func _playAnimation(animationName: String) -> void:
	if animations == null:
		return
	var player: AnimationPlayer = animations.get_node("AnimationPlayer")
	if player.current_animation == animationName and player.is_playing():
		_updateShadowCoverage(animationName)
		return
	animations.playAnimation(animationName)
	_updateShadowCoverage(animationName)

func _setFlip(flip: bool) -> void:
	if animations == null:
		return
	animations.get_node("AnimationSprite").set_flip_h(flip)

## Select the shadow geometry that matches the wagon's current view.
func _updateShadowCoverage(animationName: String) -> void:
	var shadow = ShadowScript.findShadow(self)
	if shadow == null:
		return
	if animationName in BODY_SHADOW_ANIMATIONS_DIAGONAL:
		shadow.coverage = ShadowScript.Coverage.DIAGONAL
	elif animationName in BODY_SHADOW_ANIMATIONS_VERTICAL:
		shadow.coverage = ShadowScript.Coverage.VERTICAL
	else:
		shadow.coverage = ShadowScript.Coverage.HORIZONTAL

func _physics_process(_delta):
	get_input()
	move_and_slide()
	# Track distance travelled and report to the event system.
	var delta_distance: float = position.distance_to(_previous_position)
	if delta_distance > 0.0:
		OverworldEvents.add_distance(delta_distance)
	_previous_position = position


# Called by OverworldEventPopup when the player selects a choice.
# result is the result string defined in the event data.
func process_event_result(result: String) -> void:
	pass
