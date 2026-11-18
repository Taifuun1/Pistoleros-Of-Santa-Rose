extends Node

## Persisted user settings (Docs/System Design/Next Steps Implementation
## Plan.md, commit 15): music volume and fullscreen, stored in
## user://settings.json separately from any save slot. Defaults, validation,
## clamped writes and an atomic replacement; a malformed payload falls back to
## the defaults instead of breaking the session. Settings never touch a save
## slot, and New Game/Continue never touch settings.

const SETTINGS_PATH := "user://settings.json"
const TEMP_SUFFIX := ".tmp"
const MASTER_BUS := 0
const DEFAULT_MUSIC_VOLUME := 1.0
const MIN_VOLUME := 0.0
const MAX_VOLUME := 1.0
## Payload keys allowed in the settings file.
const SETTINGS_KEYS := ["formatVersion", "musicVolume", "fullscreen"]
const FORMAT_VERSION := 1

var musicVolume := DEFAULT_MUSIC_VOLUME
var fullscreen := true
var settingsPath := SETTINGS_PATH


## Test/headless seam: an isolated settings file path.
func configure(options: Dictionary = {}) -> void:
	settingsPath = str(options.get("settingsPath", settingsPath))


func _ready() -> void:
	loadSettings()
	applySettings()


## Reads, validates and applies the settings file. Any malformed, unknown-keyed
## or out-of-range payload falls back to the defaults; nothing is mutated on
## failure.
func loadSettings() -> Dictionary:
	if !FileAccess.file_exists(settingsPath):
		return { "success": true, "reason": "no_settings", "defaults": true }
	var file := FileAccess.open(settingsPath, FileAccess.READ)
	if file == null:
		return { "success": false, "reason": "unreadable_settings" }
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if !(parsed is Dictionary):
		return { "success": false, "reason": "malformed_settings" }
	for keyValue in parsed:
		if !SETTINGS_KEYS.has(str(keyValue)):
			return { "success": false, "reason": "malformed_settings" }
	var volumeValue = (parsed as Dictionary).get("musicVolume", DEFAULT_MUSIC_VOLUME)
	var fullscreenValue = (parsed as Dictionary).get("fullscreen", true)
	if typeof(volumeValue) != TYPE_FLOAT and typeof(volumeValue) != TYPE_INT:
		return { "success": false, "reason": "malformed_settings" }
	if typeof(fullscreenValue) != TYPE_BOOL:
		return { "success": false, "reason": "malformed_settings" }
	musicVolume = clampf(float(volumeValue), MIN_VOLUME, MAX_VOLUME)
	fullscreen = bool(fullscreenValue)
	return { "success": true, "reason": "", "defaults": false }


## Clamped write with immediate audio application and an atomic file write.
func setMusicVolume(value) -> Dictionary:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return { "success": false, "reason": "invalid_volume" }
	musicVolume = clampf(float(value), MIN_VOLUME, MAX_VOLUME)
	_applyAudio()
	return saveSettings()


## Fullscreen toggle with immediate application and an atomic file write.
func setFullscreen(on) -> Dictionary:
	if typeof(on) != TYPE_BOOL:
		return { "success": false, "reason": "invalid_fullscreen" }
	fullscreen = bool(on)
	_applyDisplay()
	return saveSettings()


## Applies the current values to the audio bus and the window.
func applySettings() -> void:
	_applyAudio()
	_applyDisplay()


## Restores the defaults, applies them and persists the file.
func resetToDefaults() -> Dictionary:
	musicVolume = DEFAULT_MUSIC_VOLUME
	fullscreen = true
	applySettings()
	return saveSettings()


func _applyAudio() -> void:
	# Music is the only audio in the game and plays on the Master bus; volume
	# 0 mutes instead of relying on linear_to_db(0) being -inf.
	if musicVolume <= MIN_VOLUME:
		AudioServer.set_bus_mute(MASTER_BUS, true)
	else:
		AudioServer.set_bus_mute(MASTER_BUS, false)
		AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(musicVolume))


func _applyDisplay() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Atomic replacement (temp file + verified read-back + rename), the same
## contract as the save service's file writes.
func saveSettings() -> Dictionary:
	var payload := {
		"formatVersion": FORMAT_VERSION,
		"musicVolume": musicVolume,
		"fullscreen": fullscreen,
	}
	var json := JSON.stringify(payload, "  ", true)
	if json.is_empty():
		return { "success": false, "reason": "invalid_settings" }
	var directory := settingsPath.get_base_dir()
	if !directory.is_empty() and !DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var tempPath := settingsPath + TEMP_SUFFIX
	var file := FileAccess.open(tempPath, FileAccess.WRITE)
	if file == null:
		return { "success": false, "reason": "write_failed" }
	file.store_string(json)
	file.close()
	var verify := FileAccess.open(tempPath, FileAccess.READ)
	if verify == null or verify.get_as_text() != json:
		if verify != null:
			verify.close()
		DirAccess.remove_absolute(tempPath)
		return { "success": false, "reason": "write_verify_failed" }
	verify.close()
	if DirAccess.rename_absolute(tempPath, settingsPath) != OK:
		DirAccess.remove_absolute(tempPath)
		return { "success": false, "reason": "write_failed" }
	return { "success": true, "reason": "", "path": settingsPath }