extends Node2D

var idleAnimation = ""
var oneshotAnimation = false
var animationFrameHit = -1
var frameHit = false

signal onAnimationFrameHit


func init(initIdleAnimation, initAnimationFrameHit = -1):
	idleAnimation = initIdleAnimation
	animationFrameHit = initAnimationFrameHit

func playAnimation(animation, isOneshotAnimation = false, lookForFrameHit = false):
	oneshotAnimation = isOneshotAnimation
	frameHit = lookForFrameHit
	$AnimationSprite.animation = animation
	$AnimationPlayer.play(animation)

func flipAnimation():
	$AnimationSprite.set_flip_h(!$AnimationSprite.flip_h)


func _on_animation_sprite_frame_changed() -> void:
	if frameHit and $AnimationSprite.frame == animationFrameHit:
		onAnimationFrameHit.emit()

func _on_animation_player_animation_finished(animation) -> void:
	if oneshotAnimation:
		$AnimationSprite.animation = idleAnimation
		$AnimationPlayer.play(idleAnimation)
		oneshotAnimation = false
		frameHit = false
	else:
		$AnimationSprite.animation = animation
		$AnimationPlayer.play(animation)
