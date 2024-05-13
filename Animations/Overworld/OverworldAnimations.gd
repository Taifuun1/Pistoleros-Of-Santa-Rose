extends Node2D


func playAnimation(animation):
	$AnimationPlayer.play(animation)

#func flipAnimation():
	#$AnimationSprite.set_flip_h(!$AnimationSprite.flip_h)


func _on_animation_player_animation_finished(animation):
	$AnimationPlayer.play(animation)
