extends Control


func _ready() -> void:
	# No save support yet.
	$CenterContainer/VBoxContainer/Continue.disabled = true


func _on_new_game_pressed() -> void:
	HelperFunctions.changeScene("overworld")


func _on_continue_pressed() -> void:
	pass # Save/load not implemented yet.


func _on_quit_pressed() -> void:
	get_tree().quit()
