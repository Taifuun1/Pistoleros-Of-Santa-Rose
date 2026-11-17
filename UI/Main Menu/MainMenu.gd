extends Control


## Two-step delete confirmation state: slot id -> armed.
var _deleteArmed := {}


func _ready() -> void:
	# Continue is only available for a readable, schema-valid save; nothing is
	# restored by merely opening the menu.
	$CenterContainer/VBoxContainer/Continue.disabled = !hasValidSave()
	$SavesPanel.visible = false


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


func _on_saves_pressed() -> void:
	_deleteArmed.clear()
	$SavesPanel.visible = true
	$CenterContainer.visible = false
	_refreshSlots()


func _on_saves_back_pressed() -> void:
	$SavesPanel.visible = false
	$CenterContainer.visible = true
	$CenterContainer/VBoxContainer/Continue.disabled = !hasValidSave()


func _on_new_save_pressed() -> void:
	var saveGame = get_node_or_null("/root/SaveGame")
	if saveGame == null or !saveGame.has_method("createSlot"):
		_setSlotsStatus("Saving is unavailable.")
		return
	var created: Dictionary = saveGame.createSlot()
	if !bool(created.get("success", false)):
		_setSlotsStatus("Could not create a new save slot.")
		return
	_refreshSlots()
	_setSlotsStatus("Save slot '%s' selected. It appears here after the first checkpoint save." % str(created.get("activeSlot", "")))


## One row per slot: summary text, Play (select + Continue) and Delete.
func _refreshSlots() -> void:
	var saveGame = get_node_or_null("/root/SaveGame")
	var slotList = $SavesPanel/MarginContainer/VBoxContainer/SlotList
	for child in slotList.get_children():
		child.queue_free()
	if saveGame == null or !saveGame.has_method("listSlots"):
		_setSlotsStatus("Saving is unavailable.")
		return
	var slots: Array = saveGame.listSlots()
	if slots.is_empty():
		_setSlotsStatus("No saves yet. Start a game and reach an Overworld boundary to save.")
		return
	_setSlotsStatus("")
	for entry in slots:
		slotList.add_child(_makeSlotRow(saveGame, entry))


func _makeSlotRow(saveGame, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slotId := str(entry.get("id", ""))
	var summary := "%s" % slotId
	if int(entry.get("savedAt", 0)) > 0:
		summary += " — %s" % _formatSavedAt(int(entry.savedAt))
	var activeSlot := str(saveGame.activeSlot)
	if activeSlot == slotId:
		summary += " (active)"
	var label := Label.new()
	label.text = summary
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if !bool(entry.get("valid", false)):
		label.text += "\n" + str(entry.get("notice", "This save is damaged and cannot be loaded."))
	row.add_child(label)
	var play := Button.new()
	play.text = "Play"
	play.disabled = !bool(entry.get("valid", false))
	play.pressed.connect(func(): _on_slot_play_pressed(saveGame, slotId))
	row.add_child(play)
	var delete := Button.new()
	delete.text = "Delete"
	delete.pressed.connect(func(): _on_slot_delete_pressed(saveGame, slotId, delete))
	row.add_child(delete)
	return row


func _on_slot_play_pressed(saveGame, slotId: String) -> void:
	var selected: Dictionary = saveGame.selectSlot(slotId) if saveGame.has_method("selectSlot") else {}
	if !bool(selected.get("success", false)):
		_setSlotsStatus("That save could not be selected.")
		_refreshSlots()
		return
	_on_continue_pressed()


func _on_slot_delete_pressed(saveGame, slotId: String, button: Button) -> void:
	if !_deleteArmed.get(slotId, false):
		_deleteArmed[slotId] = true
		button.text = "Really delete?"
		return
	_deleteArmed.erase(slotId)
	var deleted: Dictionary = saveGame.deleteSlot(slotId) if saveGame.has_method("deleteSlot") else {}
	if !bool(deleted.get("success", false)):
		_setSlotsStatus("That save could not be deleted.")
		return
	_refreshSlots()
	_setSlotsStatus("Deleted save '%s'." % slotId)


func _setSlotsStatus(text: String) -> void:
	$SavesPanel/MarginContainer/VBoxContainer/Status.text = text


func _formatSavedAt(unixTime: int) -> String:
	var parts := Time.get_datetime_dict_from_unix_time(unixTime)
	return "%04d-%02d-%02d %02d:%02d" % [parts.year, parts.month, parts.day, parts.hour, parts.minute]


func _on_quit_pressed() -> void:
	get_tree().quit()
