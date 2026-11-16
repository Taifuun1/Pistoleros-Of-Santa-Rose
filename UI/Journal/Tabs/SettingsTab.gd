extends JournalTab

## Settings tab. Audio and save management remain unavailable, but the tab owns
## the production route back to the main menu. Confirmation prevents an
## accidental loss of the unsaved session.

const RETURN_PROMPT := "Return to the main menu? Unsaved progress will be lost."

var _quitButton: Button = null
var _confirmation: ConfirmationDialog = null
var _confirmationVisible := false
## Optional routing seam used by the real-shell test; production resolves it
## through the SceneManager root.
var menuRouteProvider := Callable()


func refreshTab() -> void:
	_buildControls()


func setTabActive(tabActive: bool) -> void:
	super(tabActive)
	if tabActive:
		_buildControls()
	elif _confirmation != null and _confirmation.visible:
		_confirmation.hide()
		_confirmationVisible = false


func canCloseTab() -> bool:
	return !_confirmationVisible


func getFocusTarget() -> Control:
	_buildControls()
	return _quitButton


func _buildControls() -> void:
	if _quitButton != null and is_instance_valid(_quitButton):
		return
	showStateMessage()

	var layout := VBoxContainer.new()
	layout.name = "SettingsLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	for child in get_children():
		if child != layout:
			remove_child(child)
			layout.add_child(child)

	var status := Label.new()
	status.name = "UnavailableMessage"
	status.text = "Options and save management are not available yet."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.custom_minimum_size = Vector2(240, 0)
	layout.add_child(status)

	_quitButton = Button.new()
	_quitButton.name = "QuitToMenuButton"
	_quitButton.text = "Quit to Main Menu"
	_quitButton.custom_minimum_size = Vector2(180, 28)
	_quitButton.pressed.connect(_showConfirmation)
	layout.add_child(_quitButton)

	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "QuitConfirmation"
	_confirmation.title = "Return to the Main Menu"
	_confirmation.dialog_text = RETURN_PROMPT
	_confirmation.ok_button_text = "Quit"
	_confirmation.cancel_button_text = "Stay"
	_confirmation.about_to_popup.connect(func() -> void: _confirmationVisible = true)
	_confirmation.confirmed.connect(_returnToMainMenu)
	_confirmation.canceled.connect(_hideConfirmation)
	add_child(_confirmation)


func _showConfirmation() -> void:
	if _confirmation == null:
		return
	_confirmationVisible = true
	_confirmation.popup_centered()


func _hideConfirmation() -> void:
	_confirmationVisible = false


func _returnToMainMenu() -> void:
	_confirmationVisible = false
	if menuRouteProvider.is_valid():
		menuRouteProvider.call()
		return
	var sceneManager := HelperFunctions.sceneManagerNode()
	if sceneManager == null or !sceneManager.has_method("change_scene"):
		push_warning("SettingsTab: SceneManager is unavailable; cannot return to the main menu.")
		return
	sceneManager.call("change_scene", "main_menu")
