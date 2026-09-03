class_name ShootoutAnimationSequencer
extends Node


signal frameHit
signal sequenceDone

var steps = []
var actingActor = null
var targetActor = null
var running = false


func play(stepsInit: Array, actingActorInit: Node, targetActorInit: Node = null) -> void:
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
	if step.has("animation") and animationsNode.get_node("AnimationSprite").sprite_frames.has_animation(step.animation):
		animationName = step.animation
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
		frameHit.emit()
