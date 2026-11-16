extends Control


func _ready() -> void:
	# No save support yet.
	$CenterContainer/VBoxContainer/Continue.disabled = true


func _on_new_game_pressed() -> void:
	# One reset path: the Scene Manager resets every domain and clears transient
	# state before the Overworld loads. Direct-scene runs fall back to a plain
	# Overworld change so the menu still works without the manager.
	var sceneManager = HelperFunctions.sceneManagerNode()
	if sceneManager != null and sceneManager.has_method("startNewGame"):
		sceneManager.startNewGame()
		return
	HelperFunctions.changeScene("overworld")


func _on_continue_pressed() -> void:
	pass # Save/load not implemented yet.


func _on_settings_pressed() -> void:
	pass # Settings not implemented yet.


func _on_quit_pressed() -> void:
	get_tree().quit()
