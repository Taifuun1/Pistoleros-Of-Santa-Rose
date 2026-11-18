extends JournalTab

## Settings tab (Docs/System Design/Next Steps Implementation Plan.md, commit
## 15): music volume and fullscreen with immediate effect, persisted through
## the UserSettings service — never through a save slot — plus the production
## route back to the main menu. Confirmation prevents an accidental loss of the
## unsaved session.

const RETURN_PROMPT := "Return to the main menu? Unsaved progress will be lost."

var _quitButton: Button = null
var _volumeSlider: HSlider = null
var _volumeValue: Label = null
var _fullscreenToggle: CheckButton = null
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
	return _volumeSlider if _volumeSlider != null else _quitButton


func _settings() -> Node:
	return get_node_or_null("/root/UserSettings")


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

	var settings := _settings()
	if settings == null or !settings.has_method("setMusicVolume"):
		var status := Label.new()
		status.name = "UnavailableMessage"
		status.text = "Options and save management are not available yet."
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD
		status.custom_minimum_size = Vector2(240, 0)
		layout.add_child(status)
		_buildQuitControls(layout)
		return

	var volumeRow := HBoxContainer.new()
	volumeRow.name = "MusicVolumeRow"
	volumeRow.add_theme_constant_override("separation", 8)
	layout.add_child(volumeRow)
	var volumeLabel := Label.new()
	volumeLabel.name = "MusicVolumeLabel"
	volumeLabel.text = "Music volume"
	volumeRow.add_child(volumeLabel)
	_volumeSlider = HSlider.new()
	_volumeSlider.name = "MusicVolumeSlider"
	_volumeSlider.min_value = 0.0
	_volumeSlider.max_value = 1.0
	_volumeSlider.step = 0.05
	_volumeSlider.value = float(settings.musicVolume)
	_volumeSlider.custom_minimum_size = Vector2(180, 16)
	_volumeSlider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volumeSlider.value_changed.connect(_onVolumeChanged)
	volumeRow.add_child(_volumeSlider)
	_volumeValue = Label.new()
	_volumeValue.name = "MusicVolumeValue"
	_volumeValue.text = "%d%%" % roundi(float(settings.musicVolume) * 100.0)
	_volumeValue.custom_minimum_size = Vector2(48, 0)
	volumeRow.add_child(_volumeValue)

	_fullscreenToggle = CheckButton.new()
	_fullscreenToggle.name = "FullscreenToggle"
	_fullscreenToggle.text = "Fullscreen"
	_fullscreenToggle.button_pressed = bool(settings.fullscreen)
	_fullscreenToggle.toggled.connect(_onFullscreenToggled)
	layout.add_child(_fullscreenToggle)

	_buildQuitControls(layout)


## The quit-to-menu action keeps its confirmation flow regardless of whether
## the settings service is available.
func _buildQuitControls(layout: VBoxContainer) -> void:
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


func _onVolumeChanged(value: float) -> void:
	var settings := _settings()
	if settings == null or !settings.has_method("setMusicVolume"):
		return
	var result: Dictionary = settings.setMusicVolume(value)
	if bool(result.get("success", false)):
		_volumeValue.text = "%d%%" % roundi(float(settings.musicVolume) * 100.0)


func _onFullscreenToggled(on: bool) -> void:
	var settings := _settings()
	if settings == null or !settings.has_method("setFullscreen"):
		return
	settings.setFullscreen(on)


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
	var sceneManager := get_node_or_null("/root/SceneManager")
	if sceneManager == null or !sceneManager.has_method("change_scene"):
		push_warning("SettingsTab: SceneManager is unavailable; cannot return to the main menu.")
		return
	sceneManager.call("change_scene", "main_menu")
