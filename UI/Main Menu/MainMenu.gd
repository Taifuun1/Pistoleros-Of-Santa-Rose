extends Control


func _ready() -> void:
	# Continue is only available for a readable, schema-valid save; nothing is
	# restored by merely opening the menu.
	$CenterContainer/VBoxContainer/Continue.disabled = !hasValidSave()


func hasValidSave() -> bool:
	var saveGame = get_node_or_null("/root/SaveGame")
	return saveGame != null and saveGame.has_method("hasValidSave") and saveGame.hasValidSave()


func _on_new_game_pressed() -> void:
	# One reset path: the Scene Manager resets every domain and clears transient
	# state before the Overworld loads. A stored save is left alone - New Game is
	# independent of any loaded session. Direct-scene runs fall back to a plain
	# Overworld change so the menu still works without the manager.
	var sceneManager = HelperFunctions.sceneManagerNode()
	if sceneManager != null and sceneManager.has_method("startNewGame"):
		sceneManager.startNewGame()
		return
	HelperFunctions.changeScene("overworld")


func _on_continue_pressed() -> void:
	# The Scene Manager owns the restore + resume route; without it the menu
	# cannot guarantee the rest of the session is coherent with the payload.
	var sceneManager = HelperFunctions.sceneManagerNode()
	if sceneManager != null and sceneManager.has_method("continueGame"):
		if sceneManager.continueGame():
			return
	push_warning("MainMenu: Continue requires the Scene Manager and a valid save; nothing was restored.")


func _on_settings_pressed() -> void:
	pass # Settings not implemented yet.


func _on_quit_pressed() -> void:
	get_tree().quit()
