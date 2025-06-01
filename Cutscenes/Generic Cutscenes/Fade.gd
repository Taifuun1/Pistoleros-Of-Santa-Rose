extends AnimationPlayer


func playAnimation(fade = "Fade In"):
	current_animation = fade
	stop()
	$Waiter.start()

func _on_waiter_timeout() -> void:
	play()
