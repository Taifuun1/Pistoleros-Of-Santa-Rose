extends Node

## Menu-flow validation for save slots (Docs/System Design/Next Steps
## Implementation Plan.md, commit 14). Drives the real Main Menu slots overlay
## against the real SaveGame autoload with an isolated save path. The Scene
## Manager is lifted out of the tree so "Play" proves the slot selection without
## triggering a real scene transition; the Continue restore route itself is
## proven by TestSaveRestart's slot section. Run as TestSaveSlots.tscn.

const MainMenuScene = preload("res://UI/Main Menu/MainMenu.tscn")
const TEST_SAVE_PATH := "user://savegame_slots_test.json"

var failures := 0


func _ready() -> void:
	await _run()
	_cleanup()
	get_tree().quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	_wipeSlots()
	SaveGame.activeSlot = ""
	SaveGame.savePath = TEST_SAVE_PATH
	SaveGame.deleteSave()

	var menu = MainMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame

	print("--- The menu starts without a save ---")
	_check(menu.get_node("CenterContainer/VBoxContainer/Continue").disabled, "Continue is disabled without a save")
	_check(!menu.get_node("SavesPanel").visible, "the slots overlay starts hidden")

	print("\n--- The slots overlay lists and creates slots ---")
	menu.get_node("CenterContainer/VBoxContainer/Saves").pressed.emit()
	await get_tree().process_frame
	_check(menu.get_node("SavesPanel").visible and !menu.get_node("CenterContainer").visible, "Saves opens the overlay over the menu")
	_check(str(menu.get_node("SavesPanel/MarginContainer/VBoxContainer/Status").text).contains("No saves yet"), "an empty store explains itself")

	menu.get_node("SavesPanel/MarginContainer/VBoxContainer/Buttons/NewSave").pressed.emit()
	_check(str(SaveGame.activeSlot) == "slot1", "New Save selects a fresh slot id")
	_check(str(menu.get_node("SavesPanel/MarginContainer/VBoxContainer/Status").text).contains("slot1"), "the status names the new slot")

	print("\n--- A checkpoint makes the slot playable ---")
	_check(SaveGame.save().success, "the checkpoint save writes into the selected slot")
	menu._refreshSlots()
	await get_tree().process_frame
	var slotList := menu.get_node("SavesPanel/MarginContainer/VBoxContainer/SlotList")
	_check(slotList.get_child_count() == 1, "the saved slot renders one row")
	var row := slotList.get_child(0)
	_check(row.get_child_count() == 3, "the row carries its summary and two actions")
	var play: Button = row.get_child(1)
	var delete: Button = row.get_child(2)
	_check(str(play.text) == "Play" and !play.disabled, "the row offers Play on a valid slot")

	print("\n--- Play selects the slot for the Continue route ---")
	play.pressed.emit()
	await get_tree().process_frame
	_check(str(SaveGame.activeSlot) == "slot1", "Play selects the slot as the Continue target")

	print("\n--- Delete needs a confirmation and then removes the slot ---")
	delete.pressed.emit()
	_check(FileAccess.file_exists("user://saves/slot1.json"), "the first press only arms the confirmation")
	_check(str(delete.text).contains("Really delete"), "the armed button asks for confirmation")
	delete.pressed.emit()
	_check(!FileAccess.file_exists("user://saves/slot1.json"), "the confirmed press removes the slot file")
	_check(str(SaveGame.activeSlot) == "", "deleting the active slot clears the selection")
	_check(str(menu.get_node("SavesPanel/MarginContainer/VBoxContainer/Status").text).contains("Deleted save"), "the deletion is reported")

	print("\n--- Back leaves a truthful menu ---")
	menu.get_node("SavesPanel/MarginContainer/VBoxContainer/Buttons/Back").pressed.emit()
	_check(!menu.get_node("SavesPanel").visible and menu.get_node("CenterContainer").visible, "Back returns to the menu")
	_check(menu.get_node("CenterContainer/VBoxContainer/Continue").disabled, "Continue stays disabled with no slot left")

	menu.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)


func _cleanup() -> void:
	SaveGame.activeSlot = ""
	SaveGame.savePath = SaveGame.DEFAULT_SAVE_PATH
	SaveGame.deleteSave()
	_wipeSlots()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _wipeSlots() -> void:
	if !DirAccess.dir_exists_absolute("user://saves"):
		return
	var directory := DirAccess.open("user://saves")
	if directory != null:
		directory.list_dir_begin()
		var fileName := directory.get_next()
		while fileName != "":
			if !directory.current_is_dir():
				DirAccess.remove_absolute("user://saves/" + fileName)
			fileName = directory.get_next()
		directory.list_dir_end()
	DirAccess.remove_absolute("user://saves")