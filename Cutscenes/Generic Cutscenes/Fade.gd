extends AnimationPlayer


func playAnimation(fade = "Fade In"):
	print("fade: ", fade)
	current_animation = fade
	stop()
	$Waiter.start()

func _on_waiter_timeout() -> void:
	print(current_animation)
	play()
