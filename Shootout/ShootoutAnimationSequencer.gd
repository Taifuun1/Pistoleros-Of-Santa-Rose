class_name ShootoutAnimationSequencer
extends Node


signal frameHit
signal sequenceDone

var steps = []
var actingActor = null
var targetActor = null
var running = false
# The acting step resolves its turn through the armed frame hit; the
# animation_finished hook below is the fallback for when that hit never fires.
var awaitingActingHit = false
var actingAnimationsNode = null


func play(stepsInit: Array, actingActorInit: Node, targetActorInit: Node = null) -> void:
	clearActingCompletion()
	steps = stepsInit.duplicate(true)
	actingActor = actingActorInit
	targetActor = targetActorInit
	running = true
	advance()

func advance() -> void:
	if steps.is_empty():
		running = false
		sequenceDone.emit()
		return
	var step = steps.pop_front()
	match step.get("target", ""):
		"selectedActor":
			playTargetEffect(step)
		"actingActor":
			playActingAnimation(step)
		_:
			advance()

func clearActingCompletion() -> void:
	awaitingActingHit = false
	if actingAnimationsNode != null:
		var animationPlayer = actingAnimationsNode.get_node_or_null("AnimationPlayer")
		if animationPlayer != null and animationPlayer.animation_finished.is_connected(_on_acting_animation_finished):
			animationPlayer.animation_finished.disconnect(_on_acting_animation_finished)
		actingAnimationsNode = null

func playTargetEffect(step: Dictionary) -> void:
	var effectPath = step.get("path", "")
	if targetActor == null or effectPath == "" or !ResourceLoader.exists(effectPath):
		advance()
		return
	var effect = load(effectPath).instantiate()
	targetActor.add_child(effect)
	effect.tree_exited.connect(advance)
	effect.playAnimation("Effect")

func playActingAnimation(step: Dictionary) -> void:
	var animationName = attackAnimationName(actingActor)
	var animationsNode = actingActor.getAnimations()
	if animationsNode == null:
		# No animations to play: advancing ends the sequence (sequenceDone
		# resolves the turn) instead of arming a frame hit that can never fire.
		advance()
		return
	if step.has("animation") and animationsNode.get_node("AnimationSprite").sprite_frames.has_animation(step.animation):
		animationName = step.animation
	var animationPlayer = animationsNode.get_node_or_null("AnimationPlayer")
	if animationPlayer == null or !animationPlayer.has_animation(animationName):
		# Missing animation: same as above, never wait on a dead sequence.
		advance()
		return
	awaitingActingHit = true
	actingAnimationsNode = animationsNode
	animationPlayer.animation_finished.connect(_on_acting_animation_finished)
	animationsNode.playAnimation(animationName, true, true)

static func attackAnimationName(actor) -> String:
	match actor.weapon.weapon:
		"revolver":
			return "Shoot Revolver"
		"rifle":
			return "Shoot Rifle"
	return "Melee"

func _on_acting_frame_hit() -> void:
	if running:
		awaitingActingHit = false
		frameHit.emit()

## Fallback for the acting step: if the armed frame hit never fired (missing
## hit-frame data, missing or restarted animation), completing the animation
## closes the sequence so sequenceDone resolves the pending turn instead of
## hanging the fight forever.
func _on_acting_animation_finished(_animation) -> void:
	if !awaitingActingHit:
		return
	clearActingCompletion()
	advance()
