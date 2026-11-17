extends Node

## Real application-restart proof for the disk save service (Docs/System Design/
## First Steps Implementation Plan.md, save-service commit): this process plays a
## session, saves through the production checkpoint, then spawns a second Godot
## process that loads the file and verifies every restored domain
## (Tests/SaveRestartVerify.gd). It then exercises the production Continue route
## and proves New Game stays independent of the stored save.
## Run as TestSaveRestart.tscn.

const SceneManagerScene = preload("res://Nodes/Scene Manager/SceneManager.tscn")
const OverworldCoordinatesScript = preload("res://Overworld/OverworldCoordinates.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")

const VERIFY_SCENE := "res://Tests/SaveRestartVerify.tscn"
const QUEST_ID := "pistoleros_regroup"
const GENERAL_STORE := "lazysprings_general"
const TEST_VENDOR_SEED := 5123
const EXPECTED_MONEY := 640
const EXPECTED_REVEAL := "Gold Run"
const VERIFY_TIMEOUT_SECONDS := 240.0

var failures := 0
var sceneManager: Node
var expectedObjective := ""
var expectedPosition := Vector2.ZERO


func _ready() -> void:
	# A deterministic vendor seed makes the verified payload reproducible.
	Vendors.baseSeed = TEST_VENDOR_SEED
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	get_tree().root.add_child.call_deferred(sceneManager)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	await _cleanup()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _run() -> void:
	print("--- No save yet: Continue stays unavailable ---")
	SaveGame.deleteSave()
	sceneManager.change_scene("main_menu")
	_check(await _awaitSceneKey("main_menu"), "the Main Menu loads")
	var menu = sceneManager.get_current_scene()
	_check(menu != null and menu.has_method("hasValidSave"), "the Main Menu is the production instance")
	_check(_continueButton(menu).disabled, "Continue is disabled without a save")

	print("\n--- Play a session and save it ---")
	_playSession()
	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads")
	_check(SaveGame.hasValidSave(), "entering the Overworld writes a checkpoint save")
	var player = sceneManager.get_current_scene().get_node_or_null("Actors/PlayerOverworldActor")
	_check(player != null, "the Overworld player exists")
	var anchor: Vector2 = Overworld.getOverworldMapPosition().world_position
	expectedPosition = anchor + Vector2(0.5, 0.25)
	player.global_position = expectedPosition
	_check(Overworld.getOverworldMapPosition().world_position == expectedPosition, "the live provider reports the walked position")
	_check(SaveGame.save().success, "the walked position saves")
	var stored: Dictionary = SaveGame.readPayload()
	_check(stored.success, "the written file reads back as valid")
	_check(_payloadPosition(stored.payload) == expectedPosition, "the stored payload holds the exact position")
	_check(int(stored.payload.party.money) == EXPECTED_MONEY, "the stored payload holds the session money")

	print("\n--- A fresh process restores the file ---")
	var exitCode: int = await _runVerifyProcess()
	_check(exitCode == 0, "the verifying process restored every domain (exit code %d)" % exitCode)

	print("\n--- Continue restores the stored session ---")
	# Exactness is checked at the provider before any scene consumes the payload.
	_check(SaveGame.loadSave().success, "the live session can restore the save directly")
	_check(Overworld.getOverworldMapPosition().world_position == expectedPosition, "the restored provider position is exact")
	_check(int(SaveGame.readPayload().payload.party.money) == EXPECTED_MONEY, "the stored save is still the played session")

	# Leaving the Overworld records the played session through the production
	# checkpoint; only then is the in-memory session dirtied, so Continue proves
	# the restore rather than re-reading live state.
	sceneManager.change_scene("main_menu")
	_check(await _awaitSceneKey("main_menu"), "the Main Menu reloads")
	_check(int(SaveGame.readPayload().payload.party.money) == EXPECTED_MONEY, "the checkpoint keeps the played session")
	Party.money = 1
	Quests.resetForNewGame()
	Locations.resetForNewGame()
	Cutscene.resetForNewGame()
	Discovery.resetForNewGame()
	Overworld.resetForNewGame()
	menu = sceneManager.get_current_scene()
	_check(!_continueButton(menu).disabled, "Continue is enabled by a valid save")
	menu._on_continue_pressed()
	_check(await _awaitSceneKey("overworld"), "Continue resumes on the Overworld")
	_check(Party.money == EXPECTED_MONEY, "Continue restores the played money")
	_check(Quests.getCurrentObjectiveId(QUEST_ID) == expectedObjective, "Continue restores the quest objective")
	_check(Locations.isOnTrail() and Locations.trailDepartureId == 1, "Continue restores the active Trail")
	_check(Locations.getLastTownId() == "Lazysprings", "Continue restores the last resupply Town")
	_check(Discovery.isRevealed(EXPECTED_REVEAL), "Continue restores the map reveal")
	var restoredPlayer = sceneManager.get_current_scene().get_node_or_null("Actors/PlayerOverworldActor")
	var coordinates := OverworldCoordinatesScript.makeHeadless()
	var expectedCell: Dictionary = coordinates.cellToChunkTile(coordinates.worldToCell(expectedPosition))
	_check(restoredPlayer != null, "the resumed Overworld has a player")
	if restoredPlayer != null:
		# Scene re-entry is cell-accurate by the shared coordinate contract; the
		# exact position lives in the provider above.
		_check(coordinates.cellToChunkTile(coordinates.worldToCell(restoredPlayer.global_position)) == expectedCell, "the resumed player stands on the restored position's cell")
	coordinates.dispose()

	print("\n--- A slot selection survives a restart (commit 14) ---")
	# The played session is live after Continue: store it in slot A, then a
	# different session in slot B, and prove both that a fresh process restores
	# through the slot index and that the untouched sibling keeps its own session.
	# The resumed Overworld re-anchors the provider position, so the child args
	# describe the session as slot A actually stores it.
	expectedPosition = Overworld.getOverworldMapPosition().world_position
	_check(bool(SaveGame.createSlot("run a").get("success", false)), "slot A is created for the played session")
	_check(bool(SaveGame.save().get("success", false)), "slot A stores the played session")
	Party.money = 111
	_check(bool(SaveGame.createSlot("run b").get("success", false)), "slot B is created")
	_check(bool(SaveGame.save().get("success", false)), "slot B stores the dirtied session")
	_check(bool(SaveGame.selectSlot("run a").get("success", false)), "slot A is selected again")
	var slotExitCode: int = await _runVerifyProcess()
	_check(slotExitCode == 0, "a fresh process restored slot A through the slot index (exit code %d)" % slotExitCode)
	_check(bool(SaveGame.selectSlot("run b").get("success", false)), "slot B is selected in this process")
	_check(bool(SaveGame.loadSave().get("success", false)), "slot B restores its own session")
	_check(Party.money == 111, "slot B was untouched by the slot A restore")
	SaveGame.deleteSlot("run a")
	SaveGame.deleteSlot("run b")
	SaveGame.deleteSlot("slot1")

	print("\n--- New Game stays independent of the stored save ---")
	sceneManager.startNewGame(TEST_VENDOR_SEED)
	_check(await _awaitSceneKey("overworld"), "New Game loads the Overworld")
	_check(Party.money != EXPECTED_MONEY, "New Game starts from the canonical Party state")
	_check(!Quests.hasActiveQuest(), "New Game starts with no quest progress")
	_check(!Locations.isOnTrail(), "New Game starts Off Trail")
	_check(Overworld.spawnChunk == Overworld.DEFAULT_SPAWN_CHUNK and Overworld.spawnTile == Overworld.DEFAULT_SPAWN_TILE, "New Game restores the default Overworld anchor")
	_check(SaveGame.readPayload().success, "New Game leaves a valid save behind for the new session")
	SaveGame.deleteSlot("slot1")


## The played session the second process verifies: a Town resupply purchase, a
## belt reservation, an explicit Trail start, quest progress, a reveal and a
## played cutscene flag.
func _playSession() -> void:
	Party.setInventoryManagementAllowed(true)
	Party.money = EXPECTED_MONEY
	Locations.enterTown("Lazysprings")
	_check(bool(Locations.startTrail().get("success", false)), "a Trail starts from the Town")
	var purchase: Dictionary = Vendors.buy(GENERAL_STORE, "paregoric", 1)
	_check(bool(purchase.get("success", false)), "the General Store sells the Paregoric: %s" % str(purchase))
	if bool(purchase.get("success", false)):
		var stackId := str(Party.inventory[0].instanceId)
		var reservation: Dictionary = Party.reserveBeltItem("Walker Langley", stackId, 1)
		_check(bool(reservation.get("success", false)), "the carried stack is reserved on Walker's belt: %s" % str(reservation))
	Party.money = EXPECTED_MONEY
	# One activated class grant plus an equipped equipment grant: the Fight
	# loadout and its grant sources must survive the restart.
	_check(bool(Party.activateMove("Walker Langley", "Duck Down").get("success", false)), "Walker activates the class-granted Duck Down")
	var generator = ItemGenerationScript.new()
	var revolver: Dictionary = generator.generateWeapon({ "definitionId": "cattleman", "family": "revolver", "rarity": "common" })
	generator.free()
	var added: Dictionary = Party.addItem(revolver)
	var acceptedIds: Array = added.get("acceptedInstanceIds", [])
	_check(acceptedIds.size() == 1, "the rolled Cattleman is carried: %s" % str(added))
	if acceptedIds.size() == 1:
		_check(bool(Party.equipItem("Walker Langley", str(acceptedIds[0])).get("success", false)), "the granting Cattleman is equipped")
	_check(Quests.startQuest(QUEST_ID), "the quest starts")
	Quests.completeCurrentObjective(QUEST_ID, Quests.getCurrentObjectiveId(QUEST_ID))
	expectedObjective = Quests.getCurrentObjectiveId(QUEST_ID)
	_check(!expectedObjective.is_empty(), "the quest advances to its next objective")
	_check(bool(Discovery.importState({ "formatVersion": 1, "revealedIds": [EXPECTED_REVEAL] }).get("success", false)), "a map reveal is stored")
	Cutscene.playedCutscenes["Finch Pond"] = true


func _continueButton(menu: Node) -> Button:
	return menu.get_node("CenterContainer/VBoxContainer/Continue") as Button


## The stored position as the provider reports it after the int/float file
## normalization: integral coordinates come back as ints.
func _payloadPosition(payload: Dictionary) -> Vector2:
	var position: Dictionary = payload.overworld.position
	return Vector2(float(position.x), float(position.y))


func _awaitSceneKey(sceneKey: String, maxFrames := 900) -> bool:
	for _index in maxFrames:
		if sceneManager.currentSceneKey == sceneKey and !sceneManager.transitioning:
			return true
		await get_tree().process_frame
	return false


## Runs the second Godot process and returns its exit code. The child's output is
## routed into a log file the parent echoes, the same way Tests/RunAll.gd does it
## (a `cmd /C` one-liner breaks the quoted Godot path on Windows).
func _runVerifyProcess() -> int:
	var arguments := [
		"money=%d" % EXPECTED_MONEY,
		"departure=1",
		"objective=%s" % expectedObjective,
		"reveal=%s" % EXPECTED_REVEAL,
		"seed=%d" % int(Vendors.baseSeed),
		"belt=%d" % int(Party.getBeltSnapshot("Walker Langley").get("used", 0)),
		"moves=%s" % "|".join(Party.party["Walker Langley"]["moves"]),
		"weapon=%s" % str(Party.party["Walker Langley"]["equipment"]["weapon"].get("definitionId", "")),
		"pos_x=%s" % String.num(expectedPosition.x, 6),
		"pos_y=%s" % String.num(expectedPosition.y, 6),
	]
	var logDir := OS.get_user_data_dir() + "/runall"
	DirAccess.make_dir_recursive_absolute(logDir)
	var logPath := logDir + "/save_restart_verify.log"
	var launcherPath := logDir + "/save_restart_verify.cmd"
	var quoted := [
		"\"%s\"" % OS.get_executable_path(),
		"\"--headless\"",
		"\"--path\"",
		"\"%s\"" % ProjectSettings.globalize_path("res://"),
		"\"%s\"" % VERIFY_SCENE,
		"\"--\"",
	]
	for argument in arguments:
		quoted.append("\"%s\"" % argument)
	var pid := 0
	if OS.get_name() == "Windows":
		var batch := FileAccess.open(launcherPath, FileAccess.WRITE)
		batch.store_line("@echo off")
		batch.store_line(" ".join(quoted) + " > \"%s\" 2>&1" % logPath)
		batch.store_line("exit /B %ERRORLEVEL%")
		batch.close()
		pid = OS.create_process("cmd", ["/C", launcherPath])
	else:
		pid = OS.create_process("sh", ["-c", " ".join(quoted) + " > \"%s\" 2>&1" % logPath])
	if pid <= 0:
		printerr("TestSaveRestart: could not spawn the verifying process.")
		return -1
	var deadline := Time.get_ticks_msec() + int(VERIFY_TIMEOUT_SECONDS * 1000.0)
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() >= deadline:
			OS.kill(pid)
			print(FileAccess.get_file_as_string(logPath))
			return -999
		await get_tree().create_timer(0.2).timeout
	var exitCode := OS.get_process_exit_code(pid)
	print(FileAccess.get_file_as_string(logPath))
	DirAccess.remove_absolute(logPath)
	DirAccess.remove_absolute(launcherPath)
	return exitCode


func _cleanup() -> void:
	SaveGame.deleteSave()
	Quests.resetForNewGame()
	Locations.resetForNewGame()
	Cutscene.resetForNewGame()
	Discovery.resetForNewGame()
	Party.resetForNewGame()
	Overworld.resetForNewGame()
	OverworldEvents.resetEventState()
	if is_instance_valid(sceneManager):
		var manager = sceneManager
		manager.queue_free()
		if manager.is_inside_tree():
			await manager.tree_exited
	await get_tree().process_frame
	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
	if Overworld._coordinates != null:
		Overworld._coordinates.dispose()
		Overworld._coordinates = null
	var childLog := OS.get_user_data_dir() + "/save_restart_verify_child.log"
	if FileAccess.file_exists(childLog):
		DirAccess.remove_absolute(childLog)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

