extends Sprite2D


func playAnimation(animation):
	$AnimationPlayer.play(animation)


func _on_animation_player_animation_finished(_animation):
	queue_free()
