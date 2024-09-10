extends TextureRect





func _on_area_2d_mouse_entered() -> void:
	print("here")
	$Highlight.show()

func _on_area_2d_mouse_exited() -> void:
	$Highlight.hide()
