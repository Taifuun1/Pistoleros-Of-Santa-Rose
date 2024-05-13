extends Node2D

var idleAnimation = ""
var oneshotAnimation = false


func init(initIdleAnimation):
	idleAnimation = initIdleAnimation

func playAnimation(animation, isOneshotAnimation = false):
	oneshotAnimation = isOneshotAnimation
	$AnimationSprite.animation = animation
	$AnimationPlayer.play(animation)

func flipAnimation():
	$AnimationSprite.set_flip_h(!$AnimationSprite.flip_h)


func _on_animation_player_animation_finished(animation):
	if oneshotAnimation:
		$AnimationSprite.animation = idleAnimation
		$AnimationPlayer.play(idleAnimation)
		oneshotAnimation = false
	else:
		$AnimationSprite.animation = animation
		$AnimationPlayer.play(animation)
