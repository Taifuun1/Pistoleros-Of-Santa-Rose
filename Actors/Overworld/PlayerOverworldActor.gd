extends OverworldActorBase

const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")

var _previous_position: Vector2 = Vector2.ZERO


func _ready():
	speed = 350
	_previous_position = position
	# Drop shadow under the player (see Nodes/Actor Shadow/ActorShadow.gd).
	ShadowScript.attachTo(self)


func get_input():
	var input_direction = Input.get_vector("MOVE_LEFT", "MOVE_RIGHT", "MOVE_UP", "MOVE_DOWN")
	velocity = Vector2(input_direction.x * speed, input_direction.y * speed / 1.4)
	
	if velocity == Vector2(0, 0):
		pass
		#$AnimationPlayer.play("Idle Outline")
		$AnimationPlayer.pause()
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
		$AnimationPlayer.play("Move Up Side")
		$AnimatedSprite2D.animation = "Move Up Side"
		if velocity.x < 0:
			$AnimatedSprite2D.set_flip_h(true)
		else:
			$AnimatedSprite2D.set_flip_h(false)
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
		$AnimationPlayer.play("Move Down Side")
		$AnimatedSprite2D.animation = "Move Down Side"
		if velocity.x < 0:
			$AnimatedSprite2D.set_flip_h(true)
		else:
			$AnimatedSprite2D.set_flip_h(false)
	elif velocity.y < 0:
		$AnimationPlayer.play("Move Up")
		$AnimatedSprite2D.animation = "Move Up"
	elif velocity.y > 0:
		$AnimationPlayer.play("Move Down")
		$AnimatedSprite2D.animation = "Move Down"
	elif velocity.x < 0 or velocity.x > 0:
		$AnimationPlayer.play("Move Side")
		$AnimatedSprite2D.animation = "Move Side"
		if velocity.x < 0:
			$AnimatedSprite2D.set_flip_h(true)
		else:
			$AnimatedSprite2D.set_flip_h(false)

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
