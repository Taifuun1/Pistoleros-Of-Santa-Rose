extends Node

## Scene-run validation of the Journal shell (Docs/System Design/Journal/
## Journal.md): lifecycle, idempotent open/close, pause coordination, lazy
## tabs, refresh-on-activation, selection memory, the tab close guard, input
## consumption and the SceneManager open/close policy. Runs as a scene
## (TestJournal.tscn) because SceneManager.gd uses project autoloads; the
## tabs are fakes, matching the shell/fake-provider split of the design.

const SceneManagerScene := preload("res://Nodes/Scene Manager/SceneManager.tscn")
const ModalPauseCoordinatorScript := preload("res://Globals/ModalPauseCoordinator.gd")

var testsPassed := 0
var testsFailed := 0

var sceneManager: Node
var journal: Journal
var openedCount := 0
var closedCount := 0
var tabOne: FakeTab
var tabTwo: FakeTab
var tabGuard: FakeTab


class FakeTab:
	extends Control
	var refreshCount := 0
	var activateCount := 0
	var deactivateCount := 0
	var canClose := true

	func refreshTab() -> void:
		refreshCount += 1

	func setTabActive(active: bool) -> void:
		if active:
			activateCount += 1
		else:
			deactivateCount += 1

	func canCloseTab() -> bool:
		return canClose


class FakeOwner:
	extends RefCounted


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	add_child(sceneManager)
	journal = sceneManager.get_node("JournalLayer/Journal")
	journal.opened.connect(func(): openedCount += 1)
	journal.closed.connect(func(): closedCount += 1)

	await testLifecycle()
	await testTabNavigation()
	await testCloseGuard()
	await testInput()
	await testPauseCoordinator()
	await testSceneChangePolicy()
	await testRealTabs()
	await testSceneTreeSetup()

	print("TestJournal: %d passed, %d failed" % [testsPassed, testsFailed])
	get_tree().quit(testsFailed)


func check(condition: bool, testName: String) -> void:
	if condition:
		testsPassed += 1
		print("PASS: ", testName)
	else:
		testsFailed += 1
		print("FAIL: ", testName)


func installFakeTabs() -> void:
	tabOne = FakeTab.new()
	tabTwo = FakeTab.new()
	tabGuard = FakeTab.new()
	journal.setTabDefinitions([
		{ "id": "one", "title": "One", "instance": tabOne },
		{ "id": "two", "title": "Two", "instance": tabTwo },
		{ "id": "guard", "title": "Guard", "instance": tabGuard },
	])


func toggleEvent() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "TOGGLE_JOURNAL"
	event.pressed = true
	return event


func cancelEvent() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func testLifecycle() -> void:
	installFakeTabs()
	check(journal.pauseCoordinator != null, "journal uses the shared pause coordinator")
	check(!journal.isOpen, "journal starts closed")
	journal.open()
	check(journal.isOpen and journal.visible, "open shows the journal")
	check(get_tree().paused, "opening pauses the game")
	check(tabOne.activateCount == 1 and tabOne.refreshCount == 1, "first open activates and refreshes the selected tab")
	check(openedCount == 1, "opened is emitted once")
	check(get_viewport().gui_get_focus_owner() == journal.tabBar, "the tab bar takes focus on open")
	journal.open()
	check(openedCount == 1 and tabOne.refreshCount == 1, "opening while open is idempotent")
	journal.close()
	check(!journal.isOpen and !journal.visible, "close hides the journal")
	check(!get_tree().paused, "closing restores the unpaused state")
	check(tabOne.deactivateCount == 1, "closing deactivates the active tab")
	check(closedCount == 1, "closed is emitted once")
	journal.close()
	check(closedCount == 1 and tabOne.deactivateCount == 1, "closing while closed is idempotent")
	journal.toggle()
	check(journal.isOpen, "toggle opens a closed journal")
	journal.toggle()
	check(!journal.isOpen, "toggle closes an open journal")


func testTabNavigation() -> void:
	installFakeTabs()
	journal.open()
	check(tabOne.activateCount == 1 and tabOne.refreshCount == 1, "open refreshes only the active tab")
	journal.selectTab("two")
	check(journal.selectedTabId == "two", "selectTab changes the selection")
	check(tabTwo.get_parent() != null, "a tab instantiates lazily on first selection")
	check(tabTwo.activateCount == 1 and tabTwo.refreshCount == 1, "the newly visible tab activates and refreshes")
	check(tabOne.deactivateCount == 1 and tabOne.refreshCount == 1, "the previous tab deactivates without refreshing")
	journal.selectTab("one")
	check(tabOne.activateCount == 2 and tabOne.refreshCount == 2, "re-selecting a cached tab refreshes without re-instantiating")
	var host: Control = journal.tabContentHost
	check(host.get_child_count() == 2, "tabs stay cached in the content host")
	journal.close()
	journal.open()
	check(journal.selectedTabId == "one", "the selected tab is remembered for the session")
	check(tabOne.activateCount == 3 and tabOne.refreshCount == 3, "reopening re-activates and refreshes the remembered tab")
	check(host.get_child_count() == 2, "reopening does not duplicate tab instances")
	check(tabTwo.refreshCount == 1, "hidden tabs are not refreshed")
	journal.close()


func testCloseGuard() -> void:
	installFakeTabs()
	journal.open()
	journal.selectTab("guard")
	tabGuard.canClose = false
	journal.close()
	check(journal.isOpen, "a tab's close guard blocks closing")
	check(tabGuard.deactivateCount == 0, "a blocked close does not deactivate the tab")
	tabGuard.canClose = true
	journal.close()
	check(!journal.isOpen, "closing works once the tab allows it")


func testInput() -> void:
	installFakeTabs()
	sceneManager.currentSceneKey = "overworld"
	sceneManager._unhandled_input(toggleEvent())
	check(journal.isOpen, "TOGGLE_JOURNAL opens the journal through SceneManager")
	journal._unhandled_input(toggleEvent())
	check(!journal.isOpen, "the journal consumes TOGGLE_JOURNAL to close itself")
	sceneManager._unhandled_input(toggleEvent())
	check(journal.isOpen, "the journal reopens through the toggle")
	journal._unhandled_input(cancelEvent())
	check(!journal.isOpen, "ui_cancel closes the journal")
	sceneManager.currentSceneKey = "shootout"
	sceneManager._unhandled_input(toggleEvent())
	check(!journal.isOpen, "the journal cannot open in blocked scenes")
	sceneManager.currentSceneKey = "main_menu"
	sceneManager._unhandled_input(toggleEvent())
	check(!journal.isOpen, "the journal cannot open in the main menu")
	sceneManager.currentSceneKey = "overworld"
	sceneManager.transitioning = true
	sceneManager._unhandled_input(toggleEvent())
	check(!journal.isOpen, "the journal cannot open during transitions")
	check(!sceneManager.canOpenJournal(), "canOpenJournal is false during transitions")
	sceneManager.transitioning = false
	check(sceneManager.canOpenJournal(), "canOpenJournal is true in allowed scenes")
	sceneManager.currentSceneKey = "shootout"
	check(!sceneManager.canOpenJournal(), "canOpenJournal is false in blocked scenes")


func testPauseCoordinator() -> void:
	var coordinator = ModalPauseCoordinatorScript.new(get_tree())
	var ownerA := FakeOwner.new()
	var ownerB := FakeOwner.new()
	coordinator.acquirePause(ownerA)
	check(get_tree().paused, "the first modal acquires the pause")
	coordinator.acquirePause(ownerB)
	coordinator.releasePause(ownerA)
	check(get_tree().paused, "a stacked modal keeps the pause")
	coordinator.releasePause(ownerB)
	check(!get_tree().paused, "the last modal releases the pause")

	get_tree().paused = true
	coordinator.acquirePause(ownerA)
	coordinator.releasePause(ownerA)
	check(get_tree().paused, "an externally paused game stays paused")
	get_tree().paused = false

	get_tree().paused = true
	installFakeTabs()
	journal.open()
	journal.close()
	check(get_tree().paused, "closing the journal does not unpause an externally paused game")
	get_tree().paused = false


func testSceneChangePolicy() -> void:
	installFakeTabs()
	journal.open()
	check(get_tree().paused, "the journal pauses for the modal")
	sceneManager.change_scene("main_menu")
	await sceneManager.scene_changed
	check(!journal.isOpen, "a scene change closes the journal")
	check(!get_tree().paused, "the scene change does not leave the game paused")
	check(sceneManager.currentSceneKey == "main_menu" and !sceneManager.canOpenJournal(), "the journal stays blocked in the main menu")


func testRealTabs() -> void:
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	check(journal.tabBar.tab_count == 5, "the default registry has five tabs")
	var expectedIcons := [
		preload("res://Assets/Journal/MapIcon.png"),
		preload("res://Assets/Journal/InventoryIcon.png"),
		preload("res://Assets/Journal/QuestsIcon.png"),
		preload("res://Assets/Journal/EquipmentIcon.png"),
		preload("res://Assets/Journal/SettingsIcon.png"),
	]
	var icons := []
	for index in expectedIcons.size():
		check(journal.tabBar.get_tab_title(index) == "", "tab %d shows only its icon, no text" % index)
		icons.append(journal.tabBar.get_tab_icon(index))
	check(str(icons) == str(expectedIcons), "the default tab order is Map, Inventory, Quests, Character, Settings (by icon)")
	journal.open()
	for tabId in ["map", "inventory", "quests", "character", "settings"]:
		journal.selectTab(tabId)
		var tab = journal._tabInstances[tabId]
		check(tab is JournalTab, "the %s tab scene instantiates from the registry" % tabId)
		if tab is JournalTab:
			check(tab.canCloseTab(), "the %s tab allows closing" % tabId)
		check(tab.tabIcon != null, "the %s tab receives its icon from the registry" % tabId)
		if tabId == "map":
			check(tab.find_child("BaseMap", true, false) != null, "the map tab builds its view from the generated manifest")
		else:
			check(tab.find_child("TabSprite", true, false) != null, "the %s tab identifies its empty state with its tab sprite" % tabId)
			check(tab.get_child_count() > 0, "the %s tab shows its empty/unavailable state" % tabId)
	journal.close()
	check(!journal.isOpen, "the real tabs close cleanly")


func testSceneTreeSetup() -> void:
	var journalLayer: CanvasLayer = sceneManager.get_node("JournalLayer")
	var transitionLayer: CanvasLayer = sceneManager.get_node("TransitionLayer")
	check(journalLayer.layer < transitionLayer.layer, "the journal layer stays below the transition layer")
	check(journal.get_parent() == journalLayer, "the journal is a persistent child of its layer")
	check(sceneManager.process_mode == Node.PROCESS_MODE_ALWAYS, "SceneManager keeps processing while paused")
	check(sceneManager.get_node("CurrentScene").process_mode == Node.PROCESS_MODE_PAUSABLE, "CurrentScene is explicitly pausable")
	check(journal.process_mode == Node.PROCESS_MODE_ALWAYS, "the journal processes while the game is paused")