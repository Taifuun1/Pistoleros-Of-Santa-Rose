extends SceneTree

## Headless validation for the persisted user settings (Docs/System Design/Next
## Steps Implementation Plan.md, commit 15): defaults, clamped writes, malformed
## payload rejection, atomic persistence, the Master-bus audio application and
## the real Settings tab wiring. Run with: godot --headless --script
## res://Tests/TestUserSettings.gd

const UserSettingsScript = preload("res://Globals/UserSettings.gd")
const SettingsTabScene = preload("res://UI/Journal/Tabs/SettingsTab.tscn")

const SETTINGS_PATH := "user://settings_service_test.json"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	_wipeFile()
	testDefaultsAndPersistence()
	testClampingAndRejection()
	testMalformedPayloads()
	testAudioApplication()
	testSettingsTab()
	_wipeFile()

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures)
	quit(failures)


func _makeSettings() -> Node:
	var settings = UserSettingsScript.new()
	settings.configure({ "settingsPath": SETTINGS_PATH })
	return settings


func _wipeFile() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func testDefaultsAndPersistence() -> void:
	print("--- Defaults and round trip ---")
	_wipeFile()
	var settings = _makeSettings()
	_check(is_equal_approx(float(settings.musicVolume), 1.0) and bool(settings.fullscreen), "a missing settings file yields the defaults")
	_check(bool(settings.loadSettings().get("defaults", false)), "loading a missing file reports defaults")
	_check(bool(settings.saveSettings().get("success", false)), "the first write succeeds")
	_check(FileAccess.file_exists(SETTINGS_PATH) and !FileAccess.file_exists(SETTINGS_PATH + ".tmp"), "the write is atomic with no temp leftover")

	settings.musicVolume = 0.3
	settings.fullscreen = false
	_check(bool(settings.saveSettings().get("success", false)), "the direct mutation persists through an explicit save")
	var read = UserSettingsScript.new()
	read.configure({ "settingsPath": SETTINGS_PATH })
	_check(bool(read.loadSettings().get("success", false)), "a written file loads cleanly")
	_check(is_equal_approx(float(read.musicVolume), 0.3) and !bool(read.fullscreen), "the round trip keeps volume and fullscreen")
	_check(!bool(read.loadSettings().get("defaults", true)), "a written file no longer reports defaults")
	read.free()
	settings.free()


func testClampingAndRejection() -> void:
	print("\n--- Clamped writes and invalid input ---")
	_wipeFile()
	var settings = _makeSettings()
	var high: Dictionary = settings.setMusicVolume(5.0)
	_check(bool(high.get("success", false)) and is_equal_approx(float(settings.musicVolume), 1.0), "volume clamps at 1.0")
	var low: Dictionary = settings.setMusicVolume(-3.0)
	_check(bool(low.get("success", false)) and is_equal_approx(float(settings.musicVolume), 0.0), "volume clamps at 0.0")
	var bad: Dictionary = settings.setMusicVolume("loud")
	_check(!bool(bad.get("success", false)) and str(bad.reason) == "invalid_volume", "a non-numeric volume is rejected")
	var badFullscreen: Dictionary = settings.setFullscreen("yes")
	_check(!bool(badFullscreen.get("success", false)), "a non-boolean fullscreen is rejected")
	_check(bool(settings.setFullscreen(false).get("success", false)), "a boolean fullscreen toggle persists")
	settings.free()
	var read = UserSettingsScript.new()
	read.configure({ "settingsPath": SETTINGS_PATH })
	read.loadSettings()
	_check(is_equal_approx(float(read.musicVolume), 0.0) and !bool(read.fullscreen), "the clamped values persist")
	read.free()

	var reset = _makeSettings()
	reset.loadSettings()
	reset.resetToDefaults()
	_check(is_equal_approx(float(reset.musicVolume), 1.0) and bool(reset.fullscreen), "resetToDefaults restores the defaults")
	_wipeFile()
	var afterReset = _makeSettings()
	afterReset.loadSettings()
	_check(is_equal_approx(float(afterReset.musicVolume), 1.0), "the reset persists")
	reset.free()
	afterReset.free()


func testMalformedPayloads() -> void:
	print("\n--- Malformed payloads fall back to defaults ---")
	var cases := {
		"not_json": "{ this is not json",
		"not_a_dict": "[1, 2, 3]",
		"unknown_key": "{\"formatVersion\": 1, \"musicVolume\": 0.5, \"theme\": \"dark\"}",
		"bad_volume_type": "{\"formatVersion\": 1, \"musicVolume\": \"loud\", \"fullscreen\": true}",
		"bad_fullscreen_type": "{\"formatVersion\": 1, \"musicVolume\": 0.5, \"fullscreen\": 1}",
	}
	for caseName in cases:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(cases[caseName])
		file.close()
		var settings = _makeSettings()
		var result: Dictionary = settings.loadSettings()
		_check(!bool(result.get("success", false)) and str(result.reason) == "malformed_settings", "%s is rejected as malformed" % caseName)
		_check(is_equal_approx(float(settings.musicVolume), 1.0) and bool(settings.fullscreen), "%s leaves the defaults untouched" % caseName)
		settings.free()


func testAudioApplication() -> void:
	print("\n--- Master bus audio application ---")
	_wipeFile()
	var settings = _makeSettings()
	settings.setMusicVolume(0.5)
	var expectedDb := linear_to_db(0.5)
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) - expectedDb) < 0.01, "the volume lands on the Master bus in decibels")
	_check(!AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "a nonzero volume unmutes the bus")
	settings.setMusicVolume(0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "volume zero mutes the bus instead of writing -inf")
	settings.setMusicVolume(1.0)
	settings.free()


## The real Settings tab wires its slider and toggle to the settings service
## with immediate effect and persistence.
func testSettingsTab() -> void:
	print("\n--- Settings tab wiring ---")
	_wipeFile()
	var settings = _makeSettings()
	settings.name = "UserSettings"
	root.add_child(settings)
	var tab = SettingsTabScene.instantiate()
	root.add_child(tab)
	await process_frame
	tab.refreshTab()
	await process_frame

	var slider: HSlider = tab.find_child("MusicVolumeSlider", true, false)
	var toggle: CheckButton = tab.find_child("FullscreenToggle", true, false)
	var quitButton: Button = tab.find_child("QuitToMenuButton", true, false)
	_check(slider != null and toggle != null and quitButton != null, "the tab exposes volume, fullscreen and quit controls")
	_check(is_equal_approx(slider.value, 1.0), "the slider starts from the persisted volume")
	_check(tab.getFocusTarget() == slider, "controller focus enters on the volume slider")

	slider.value = 0.4
	await process_frame
	_check(is_equal_approx(float(settings.musicVolume), 0.4), "moving the slider applies the volume immediately")
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) - linear_to_db(0.4)) < 0.01, "the slider drives the Master bus")
	var persisted = UserSettingsScript.new()
	persisted.configure({ "settingsPath": SETTINGS_PATH })
	persisted.loadSettings()
	_check(is_equal_approx(float(persisted.musicVolume), 0.4), "the slider change persists to disk")
	persisted.free()

	toggle.button_pressed = false
	await process_frame
	_check(!bool(settings.fullscreen), "the fullscreen toggle applies immediately")

	_check(quitButton != null and tab.find_child("QuitConfirmation", true, false) != null, "the quit-to-menu confirmation flow is unchanged")

	tab.free()
	settings.free()