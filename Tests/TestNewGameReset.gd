extends Node

## Scene-run validation for the New Game reset coordinator (Docs/System Design/
## First Steps Implementation Plan.md, commit 5): after a dirty run (purchases,
## reveals, quest progress, a started Trail, minigame/poker session state and an
## open modal) startNewGame() returns every domain to its canonical initial
## state and loads the Overworld. Run as TestNewGameReset.tscn.

const SceneManagerScene = preload("res://Nodes/Scene Manager/SceneManager.tscn")

var failures := 0
var sceneManager: Node


func _ready() -> void:
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
	print("--- Dirty every domain ---")
	var canonicalParty = load("res://Globals/Party.gd").new()
	var canonicalMoney := int(canonicalParty.money)
	canonicalParty.free()
	Party.money = 999
	Party.inventory = [
		{ "instanceId": "starter_paregoric", "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 },
		{ "instanceId": "dirty_paregoric", "definitionId": "paregoric", "itemType": "consumable", "quantity": 2 },
	]
	Party.setInventoryManagementAllowed(true)
	Party.party["Walker Langley"]["injuryDamage"] = 12
	# Dirty belt: the starter reservation is replaced by one on a dirty stack.
	Party.party["Walker Langley"]["beltReservations"] = [{ "instanceId": "dirty_paregoric", "combatId": "Paregoric", "quantity": 1 }]
	var questStarted: bool = Quests.startQuest("pistoleros_regroup")
	Locations.enterTown("Lazysprings")
	Locations.startTrail()
	Locations.minigamePoints["Mining"] = 42
	Locations.collectedPanningMaterials["rock"] = 0
	Overworld.setSpawn(Vector2i(3, 3), Vector2i(1, 1))
	Overworld.overworldSpawnpointIdCount = 5
	Cutscene.playedCutscenes["Finch Pond"] = true
	Cutscene.cutsceneName = "Changed"
	Discovery.importState({ "formatVersion": 1, "revealedIds": ["Gold Run"] })
	PokerMoney.money = 7
	Poker.players["player2"].money = 1
	OverworldEvents.distance_since_last_event = 5.0
	OverworldEvents.event_active = true

	_check(Party.money == 999, "money is dirty before New Game")
	_check(Party.inventory.size() == 2 and Party.getBeltSnapshot("Walker Langley").entries[0].instanceId == "dirty_paregoric", "inventory and belts are dirty before New Game")
	_check(questStarted and Quests.hasActiveQuest(), "a quest is active before New Game")
	_check(Locations.isOnTrail() and Locations.trailDepartureId == 1, "a Trail is active before New Game")
	_check(Discovery.exportState().revealedIds == ["Gold Run"], "a reveal exists before New Game")

	# Enter the Overworld so the Journal can open, then open the modal.
	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads before New Game")
	await get_tree().process_frame
	sceneManager.journal.open()
	_check(sceneManager.journal.isOpen, "the Journal is open before New Game")

	print("\n--- startNewGame resets every domain ---")
	sceneManager.startNewGame(777)
	# The event lifecycle is an ambient system that resumes with the Overworld,
	# so it is verified at the reset boundary before the scene runs frames.
	_check(OverworldEvents.distance_since_last_event == 0.0 and !OverworldEvents.event_active, "New Game clears the event lifecycle")
	_check(await _awaitSceneKey("overworld"), "New Game loads the Overworld")
	_check(!sceneManager.journal.isOpen, "New Game closes modals")
	_check(!sceneManager.hasPendingShootout() and Shootout.pendingRequest == null, "New Game clears encounter context")

	_check(Party.money == canonicalMoney, "New Game resets money to the canonical starter amount")
	_check(Party.inventory.size() == 1 and Party.inventory[0].instanceId == "starter_paregoric", "New Game restores the starter carried stack")
	_check(int(Party.party["Walker Langley"]["injuryDamage"]) == 0, "New Game clears injuries")
	var belt: Dictionary = Party.getBeltSnapshot("Walker Langley")
	_check(belt.used == 1 and belt.entries[0].instanceId == "starter_paregoric", "New Game restores the starter belt reservation")

	_check(!Quests.hasActiveQuest(), "New Game clears quest progress")
	_check(!Locations.isOnTrail() and Locations.trailDepartureId == 0 and Locations.getLastTownId() == "", "New Game resets the Trail state")
	_check(Locations.minigamePoints["Mining"] == 0 and Locations.collectedPanningMaterials["rock"] == 20, "New Game resets minigame session state")

	_check(Overworld.spawnChunk == Vector2i(8, 12) and Overworld.spawnTile == Vector2i(40, 38), "New Game resets the Overworld entry anchor")
	_check(Overworld.overworldSpawnpointIdCount == 0, "New Game resets Overworld id counters")
	_check(!Cutscene.playedCutscenes["Finch Pond"] and Cutscene.cutsceneName == "Finch Pond", "New Game clears cutscene flags")
	_check(Discovery.exportState().revealedIds.is_empty(), "New Game clears discovery reveals")
	_check(PokerMoney.money == PokerMoney.DEFAULT_MONEY, "New Game resets the poker bankroll")
	_check(Poker.players["player2"].money == 100, "New Game restores the poker roster")
	_check(Vendors.baseSeed == 777, "New Game applies the requested vendor seed")

	# The Main Menu is the production entry point for the same reset path.
	print("\n--- MainMenu New Game routes through the coordinator ---")
	Party.money = 321
	var mainMenu = load("res://UI/Main Menu/MainMenu.tscn").instantiate()
	add_child(mainMenu)
	_check(mainMenu.get_node("CenterContainer/VBoxContainer/Continue").disabled, "Continue stays disabled (no save service yet)")
	mainMenu._on_new_game_pressed()
	_check(await _awaitSceneKey("overworld"), "MainMenu New Game loads the Overworld")
	_check(Party.money == canonicalMoney, "MainMenu New Game restores Party state to the canonical starter amount")
	mainMenu.queue_free()


func _awaitSceneKey(sceneKey: String, maxFrames := 900) -> bool:
	for _index in maxFrames:
		if sceneManager.currentSceneKey == sceneKey and !sceneManager.transitioning:
			return true
		await get_tree().process_frame
	return false


func _cleanup() -> void:
	Quests.resetForNewGame()
	Locations.resetForNewGame()
	Overworld.resetForNewGame()
	Party.resetForNewGame()
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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
