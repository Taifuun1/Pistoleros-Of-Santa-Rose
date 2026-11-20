extends CharacterBody2D

const AnimationServiceScript = preload("res://Globals/ActorAnimationService.gd")
const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")

@export var speed = 125

var paused = false
# Commit 19: the Idle/Run set resolves through the shared registry instead
# of the scene-embedded AnimatedSprite2D/AnimationPlayer pair.
var animations: Node = null


func _ready():
	animations = AnimationServiceScript.new().forActor("Player", "Player Location")
	if animations != null:
		animations.name = "Animations"
		add_child(animations)
		_playAnimation("Idle")
	# Drop shadow under the player (see Nodes/Actor Shadow/ActorShadow.gd).
	ShadowScript.attachTo(self)
	add_to_group("location_player")


func get_input():
	var input_direction = Input.get_vector("MOVE_LEFT", "MOVE_RIGHT", "MOVE_UP", "MOVE_DOWN")
	velocity = Vector2(input_direction.x * speed, input_direction.y * speed / 2)
	
	if velocity == Vector2(0, 0):
		_playAnimation("Idle")
	else:
		_playAnimation("Run")
		if velocity.x != 0 and animations != null:
			animations.get_node("AnimationSprite").set_flip_h(velocity.x < 0)


## Plays a registry state without restarting it every physics frame (the
## legacy AnimationPlayer.play() kept playing; a forced restart would pin
## the walk cycle on its first frame).
func _playAnimation(animationName: String) -> void:
	if animations == null:
		return
	var player: AnimationPlayer = animations.get_node("AnimationPlayer")
	if player.current_animation == animationName and player.is_playing():
		return
	animations.playAnimation(animationName)


func _physics_process(_delta):
	if !paused:
		get_input()
		move_and_slide()
