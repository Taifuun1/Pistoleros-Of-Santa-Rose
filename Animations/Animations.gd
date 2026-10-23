extends Node2D

var idleAnimation = ""
var oneshotAnimation = false
var animationFrameHit = -1
var frameHit = false
var nextAnimation = null

signal onAnimationFrameHit
signal onNextAnimation


func initAnimations(initIdleAnimation, initAnimationFrameHit = -1):
	idleAnimation = initIdleAnimation
	animationFrameHit = initAnimationFrameHit

func playAnimation(animation, isOneshotAnimation = false, lookForFrameHit = false, assignNextAnimation = null):
	oneshotAnimation = isOneshotAnimation
	frameHit = lookForFrameHit
	nextAnimation = assignNextAnimation
	$AnimationSprite.animation = animation
	# AnimationPlayer.play() silently continues an already-playing animation,
	# so an actor acting on back-to-back turns (closing one round and opening
	# the next) never reached the frame hit again and the turn hung forever.
	# Stop + play forces a restart; the explicit frame reset mirrors what
	# changing the animation property does for a different animation.
	$AnimationSprite.frame = 0
	$AnimationPlayer.stop()
	$AnimationPlayer.play(animation)

func flipAnimation():
	$AnimationSprite.set_flip_h(!$AnimationSprite.flip_h)


func _on_animation_sprite_frame_changed() -> void:
	if frameHit and $AnimationSprite.frame == animationFrameHit:
		onAnimationFrameHit.emit()

func _on_animation_player_animation_finished(animation) -> void:
	if oneshotAnimation:
		if nextAnimation == null:
			$AnimationSprite.animation = idleAnimation
			$AnimationPlayer.play(idleAnimation)
			oneshotAnimation = false
			frameHit = false
			return
		onNextAnimation.emit(nextAnimation)
		nextAnimation = null
	else:
		$AnimationSprite.animation = animation
		$AnimationPlayer.play(animation)
