extends Node2D


func playAnimation(animation):
	$AnimationPlayer.play(animation)
	$AnimatedSprite.animation = animation
