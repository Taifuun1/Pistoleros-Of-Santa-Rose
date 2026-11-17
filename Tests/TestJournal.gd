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
## Every fake tab instance created by installFakeTabs(); inactive injected tabs
## are not children of the Journal, so the test owns and frees them.
var fakeTabs: Array = []


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


class FakeQuestProvider:
	extends Node

	signal questStateChanged(questId: String)

	var entries: Array = []

	func isQuestDataAvailable() -> bool:
		return true

	func getQuestJournalEntries() -> Array:
		return entries


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	sceneManager.autosaveEnabled = false
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
	await testQuestShowOnMap()
	await testMapControllerFocusHandoff()
	await testInventoryControllerFocusHandoff()
	await testInventoryNoSideEffects()
	await testCharacterControllerFocusHandoff()
	await testCharacterProductionRefresh()
	await testSceneTreeSetup()
	await testSettingsReturnToMenu()

	# Free the real/fake tabs the test owns and release the music autoload's
	# playbacks before quitting, so the process exits without node/RID/audio
	# leaks.
	journal.setTabDefinitions([])
	for tab in fakeTabs:
		if is_instance_valid(tab):
			tab.free()
	fakeTabs.clear()
	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
	await get_tree().create_timer(0.3).timeout

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
	fakeTabs.append_array([tabOne, tabTwo, tabGuard])
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


## Routes a real input action through the viewport so focus traversal, gui_input
## and unhandled-input paths all run as they do in game.
func pressAction(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


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
	var party = get_node("/root/Party")
	check(!party.inventoryManagementAllowed, "inventory management is blocked in the main menu")
	sceneManager.currentSceneKey = "overworld"
	sceneManager._syncInventoryPolicy()
	check(party.inventoryManagementAllowed, "inventory management is allowed in the Overworld")
	sceneManager.transitioning = true
	sceneManager._syncInventoryPolicy()
	check(!party.inventoryManagementAllowed, "inventory management fails closed during transitions")
	sceneManager.transitioning = false
	sceneManager.currentSceneKey = "shootout"
	sceneManager._syncInventoryPolicy()
	check(!party.inventoryManagementAllowed, "inventory management is blocked in Shootouts")
	sceneManager.currentSceneKey = "main_menu"
	sceneManager._syncInventoryPolicy()


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
		elif tabId == "inventory":
			check(tab.find_child("ContentView", true, false) != null, "the inventory tab has its member/item content view")
			check(tab.find_child("StateView", true, false) != null, "the inventory tab has its unavailable state view")
			check(tab._selectedMemberKey == "Walker Langley", "the inventory tab selects the real party member")
			check(tab._inventoryButtons.has("starter_paregoric"), "the inventory tab reads the real starter stack")
			check(tab.equipmentGrid.get_child_count() == 7, "the inventory tab renders the real seven equipment slots")
		elif tabId == "quests":
			check(tab.find_child("ContentView", true, false) != null, "the quests tab has its master/detail content view")
			check(tab.find_child("StateView", true, false) != null, "the quests tab has its empty/unavailable state view")
			check(tab.find_child("StateTabSprite", true, false) != null, "the quests tab identifies its empty state with its tab sprite")
			check(tab.get_child_count() > 0, "the quests tab shows its empty/unavailable state")
		elif tabId == "character":
			check(tab.find_child("ContentView", true, false) != null, "the character tab has its read-only content view")
			check(tab.find_child("StateView", true, false) != null, "the character tab has its unavailable state view")
			check(tab.find_child("StateTabSprite", true, false) != null, "the character tab identifies its empty state with its tab sprite")
			check(tab.get_child_count() > 0, "the character tab shows its content or empty/unavailable state")
		else:
			check(tab.find_child("TabSprite", true, false) != null, "the %s tab identifies its empty state with its tab sprite" % tabId)
			check(tab.get_child_count() > 0, "the %s tab shows its empty/unavailable state" % tabId)
	journal.close()
	check(!journal.isOpen, "the real tabs close cleanly")


func _journalQuestMarkerProvider() -> Array:
	return [{ "quest_id": "journal_quest", "objective_id": "journal_objective", "target_id": "Lazysprings", "icon": "quest_current" }]


## Real-shell Quests -> Journal -> Map navigation (Quests stage 3): the tab
## emits ids, the shell selects Map, and Map focuses the exact quest badge.
func testQuestShowOnMap() -> void:
	print("--- Quests to map navigation ---")
	var questProvider := FakeQuestProvider.new()
	add_child(questProvider)
	questProvider.entries.append({
		"quest_id": "journal_quest",
		"title": "Journal Quest",
		"summary": "Navigate to the map.",
		"status": "active",
		"history": [],
		"current_objective": {
			"objective_id": "journal_objective",
			"text": "Go to Lazysprings",
			"target_id": "Lazysprings",
		},
	})

	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	journal.open()
	journal.selectTab("quests")
	await get_tree().process_frame
	await get_tree().process_frame
	var questsTab = journal._tabInstances.get("quests")
	check(questsTab != null, "the real Quests tab is active for navigation")
	if questsTab == null:
		journal.close()
		questProvider.queue_free()
		return
	check(questsTab.is_connected("showOnMapRequested", Callable(journal, "showOnMap")), "the shell wires the Quests navigation signal once")
	questsTab.questProvider = questProvider
	questsTab.setTabActive(true)
	questsTab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame
	check(questsTab.showOnMapButton.visible, "the injected current objective offers Show on map")

	var mapTab = journal._tabInstances.get("map")
	check(mapTab != null, "the real Map tab is available")
	if mapTab == null:
		journal.close()
		questProvider.queue_free()
		return
	mapTab.questMarkerProvider = Callable(self, "_journalQuestMarkerProvider")
	mapTab._refreshQuestMarkers()
	await get_tree().process_frame
	await get_tree().process_frame
	var stateBefore := questProvider.entries.duplicate(true)

	questsTab.showOnMapButton.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(journal.selectedTabId == "map", "Show on map selects the Map tab")
	check(mapTab._questMarkers.has(mapTab._questMarkerKey("journal_quest", "journal_objective")), "Map built the exact quest/objective marker")
	check(mapTab._selectionPanel.visible and mapTab._selectionLabel.text == "Quest target: Lazysprings", "Map focused the exact quest marker")
	check(questProvider.entries == stateBefore, "navigation did not mutate quest state")
	check(questsTab._selectedQuestId == "journal_quest", "navigation did not change the Quests selection")
	check(!journal.showOnMap({ "quest_id": "missing", "objective_id": "journal_objective", "target_id": "Lazysprings" }), "an unknown quest identity returns false")
	check(!journal.showOnMap({ "quest_id": "", "objective_id": "journal_objective", "target_id": "Lazysprings" }), "an incomplete navigation request is rejected")
	journal.close()
	check(!journal.showOnMap({ "quest_id": "journal_quest", "objective_id": "journal_objective", "target_id": "Lazysprings" }), "a closed Journal rejects navigation")

	mapTab.questMarkerProvider = Callable()
	questsTab.questProvider = null
	questProvider.queue_free()
	await get_tree().process_frame


## Controller/keyboard focus handoff through the real shell (Docs/System Design/
## Journal/Overworld Map.md, iteration step 2): the tab bar hands focus down to
## the map, D-pad pans the map instead of switching tabs, and ui_cancel backs
## out to the tab bar before it closes the Journal.
func testMapControllerFocusHandoff() -> void:
	print("--- Controller focus handoff ---")
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	journal.selectTab("map")
	journal.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var mapTab = journal._tabInstances.get("map")
	check(mapTab != null, "the real map tab is active for the handoff test")
	if mapTab == null:
		journal.close()
		return
	check(get_viewport().gui_get_focus_owner() == journal.tabBar, "the shell starts with tab focus")
	check(mapTab.getFocusTarget() != null, "the map tab exposes a content focus target")
	await pressAction("ui_down")
	check(get_viewport().gui_get_focus_owner() == mapTab.getFocusTarget(), "D-pad down hands focus from the tab bar to the map")
	await pressAction("MAP_ZOOM_IN")
	var panBefore: Vector2 = mapTab._mapContent.position
	var tabBefore: int = journal.tabBar.current_tab
	await pressAction("ui_left")
	check(mapTab._mapContent.position.x > panBefore.x, "D-pad pans the focused map instead of switching tabs")
	check(journal.tabBar.current_tab == tabBefore, "panning the map does not change the selected tab")
	await pressAction("ui_cancel")
	check(journal.isOpen, "back from the map keeps the journal open")
	check(get_viewport().gui_get_focus_owner() == journal.tabBar, "back returns focus to the tab bar")
	await pressAction("ui_right")
	check(journal.tabBar.current_tab == tabBefore + 1, "D-pad switches tabs again after focus returns")
	await pressAction("ui_cancel")
	check(!journal.isOpen, "closing from the tab bar still closes the journal")


func testInventoryControllerFocusHandoff() -> void:
	print("--- Inventory controller focus handoff ---")
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	journal.selectTab("inventory")
	journal.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var inventoryTab = journal._tabInstances.get("inventory")
	check(inventoryTab != null, "the real inventory tab is active for the handoff test")
	if inventoryTab == null:
		journal.close()
		return
	check(get_viewport().gui_get_focus_owner() == journal.tabBar, "the inventory handoff starts on the tab bar")
	check(inventoryTab.getFocusTarget() == inventoryTab._memberButtons["Walker Langley"], "the inventory tab exposes its selected member")
	await pressAction("ui_down")
	check(get_viewport().gui_get_focus_owner() == inventoryTab._memberButtons["Walker Langley"], "D-pad down enters the member selector")
	await pressAction("ui_cancel")
	check(journal.isOpen and get_viewport().gui_get_focus_owner() == journal.tabBar, "back returns inventory focus to the tab bar")
	await pressAction("ui_cancel")
	check(!journal.isOpen, "closing from shell chrome still closes the journal")


func testInventoryNoSideEffects() -> void:
	print("--- Inventory: opening the Journal has no side effects ---")
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	var party = get_node("/root/Party")
	# Allow management so the tab exposes the same controls a player would see;
	# the test only inspects, never commands.
	party.setInventoryManagementAllowed(true)
	var inventoryBefore: Array = party.inventory.duplicate(true)
	var partyBefore: Dictionary = party.party.duplicate(true)
	var moneyBefore: int = int(party.money)
	var nextIdBefore: int = int(party._nextInstanceNumber)

	# The global RNG is what ItemGeneration draws from, so a fixed seed replays
	# exactly if nothing consumed randomness.
	seed(4242)
	var expectedRolls := [randi(), randi(), randf()]
	seed(4242)

	journal.open()
	for cycle in 3:
		journal.selectTab("inventory")
		var tab = journal._tabInstances.get("inventory")
		if tab == null:
			check(false, "the inventory tab is available on cycle %d" % cycle)
			break
		tab.refreshTab()
		# Inspection only: selecting a member, an equipment slot, and an item must
		# not issue a command or write state.
		tab._onEquipmentSlotPressed("headwear")
		if !tab._itemOrder.is_empty():
			tab._onInventoryItemPressed(str(tab._itemOrder[0]))
		tab.setTabActive(false)
		tab.setTabActive(true)
		journal.selectTab("quests")
		journal.close()
		journal.open()
	var actualRolls := [randi(), randi(), randf()]
	check(actualRolls == expectedRolls, "opening/closing the Journal consumes no RNG (%s vs %s)" % [actualRolls, expectedRolls])
	check(party.inventory == inventoryBefore, "opening/closing the Journal writes no inventory state")
	check(party.party == partyBefore, "opening/closing the Journal writes no member state")
	check(int(party.money) == moneyBefore, "opening/closing the Journal writes no money")
	check(int(party._nextInstanceNumber) == nextIdBefore, "opening/closing the Journal allocates no item ids")
	check(party.inventory.size() == inventoryBefore.size(), "opening/closing the Journal generates no items")

	# Repeated activations must not duplicate provider connections: one deferred
	# refresh per change signal is the contract. The tab must be active first —
	# closing the Journal deactivates tabs, which disconnects them by design.
	journal.selectTab("inventory")
	var tab = journal._tabInstances.get("inventory")
	if tab != null:
		var connections = party.inventoryChanged.get_connections().filter(
			func(connection): return connection.callable.get_object() == tab)
		check(connections.size() == 1, "the active inventory tab holds exactly one provider connection, got %d" % connections.size())
		tab.setTabActive(false)
		var afterDeactivate = party.inventoryChanged.get_connections().filter(
			func(connection): return connection.callable.get_object() == tab)
		check(afterDeactivate.is_empty(), "a deactivated inventory tab disconnects from the provider")
	journal.close()
	party.setInventoryManagementAllowed(false)


## Real-shell Character controller handoff (Docs/System Design/Journal/
## Character.md, patch 3): the tab bar enters the selected member, right enters
## the stat scroller, and ui_cancel backs out to the shell before closing.
func testCharacterControllerFocusHandoff() -> void:
	print("--- Character controller focus handoff ---")
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	journal.selectTab("character")
	journal.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var characterTab = journal._tabInstances.get("character")
	check(characterTab != null, "the real character tab is active for the handoff test")
	if characterTab == null:
		journal.close()
		return
	var party = get_node("/root/Party")
	check(characterTab.characterProvider == null, "the production character tab uses default provider resolution")
	check(characterTab._connectedProvider == party, "the character tab resolves the real Party provider")
	check(party.isCharacterDataAvailable(), "the production Party exposes character data")
	check(characterTab._selectedMemberKey == "Walker Langley", "the character tab selects the real party member")
	check(get_viewport().gui_get_focus_owner() == journal.tabBar, "the character handoff starts on the tab bar")
	check(characterTab.getFocusTarget() == characterTab._memberButtons["Walker Langley"], "the character tab exposes its selected member")
	check(characterTab.hpText.size.x >= 60.0 and characterTab.hpText.size.y <= 20.0, "the real Journal gives HP a readable single line, got %s" % characterTab.hpText.size)
	check(characterTab.get_node("ContentView/IdentityPanel").size.y <= 50.0, "the real Journal keeps the identity header compact, got %s" % characterTab.get_node("ContentView/IdentityPanel").size)
	check(characterTab.statsScroll.size.y >= 90.0, "the real Journal gives the stat scroller usable space, got %s" % characterTab.statsScroll.size)
	check(characterTab._statValueLabels["maxHp"]["effective"].size.x >= 48.0, "the real Journal keeps the Effective column wide enough")
	check(characterTab.find_child("EffectiveHeader", true, false).size.y <= 20.0, "the real Journal keeps the Effective header on one line")
	await pressAction("ui_down")
	check(get_viewport().gui_get_focus_owner() == characterTab._memberButtons["Walker Langley"], "D-pad down enters the member selector")
	await pressAction("ui_right")
	check(get_viewport().gui_get_focus_owner() == characterTab.statsScroll, "D-pad right enters the stat scroller")
	await pressAction("ui_left")
	check(get_viewport().gui_get_focus_owner() == characterTab._memberButtons["Walker Langley"], "D-pad left returns to the member")
	await pressAction("ui_cancel")
	check(journal.isOpen and get_viewport().gui_get_focus_owner() == journal.tabBar, "back returns character focus to the tab bar")
	await pressAction("ui_cancel")
	check(!journal.isOpen, "closing from shell chrome still closes the journal")


## Real-shell Character production behavior (Docs/System Design/Journal/
## Character.md, patch 3): real Party provider resolution, live and
## activation-time refresh after a domain command, selection independence,
## connection counting, and no authoritative writes from inspection.
func testCharacterProductionRefresh() -> void:
	print("--- Character: production refresh and no side effects ---")
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	var party = get_node("/root/Party")
	var partyBefore: Dictionary = party.party.duplicate(true)
	var inventoryBefore: Array = party.inventory.duplicate(true)
	var moneyBefore: int = int(party.money)
	var nextIdBefore: int = int(party._nextInstanceNumber)

	var second: Dictionary = party.party["Walker Langley"].duplicate(true)
	second["actorName"] = "Second Member"
	party.party["Second Member"] = second

	journal.selectTab("inventory")
	journal.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var inventoryTab = journal._tabInstances.get("inventory")
	check(inventoryTab != null, "the real inventory tab is available for selection independence")
	if inventoryTab != null:
		inventoryTab._onMemberPressed("Second Member")
		check(inventoryTab._selectedMemberKey == "Second Member", "Inventory can select a different member")
	journal.selectTab("character")
	await get_tree().process_frame
	await get_tree().process_frame
	var characterTab = journal._tabInstances.get("character")
	check(characterTab != null, "the real character tab is available for production refresh")
	if characterTab == null:
		journal.close()
		_restorePartyState(party, partyBefore, inventoryBefore, moneyBefore, nextIdBefore)
		return
	check(characterTab.characterProvider == null and characterTab._connectedProvider == party, "the real character tab uses the production Party provider")
	check(characterTab._selectedMemberKey == "Walker Langley", "Character keeps its own selected member")
	check(inventoryTab == null or inventoryTab._selectedMemberKey == "Second Member", "Character selection does not change the Inventory selection")
	check(characterTab.getFocusTarget() == characterTab._memberButtons["Walker Langley"], "the production tab exposes the selected member as its focus target")

	var connections = party.partyChanged.get_connections().filter(
		func(connection): return connection.callable.get_object() == characterTab)
	check(connections.size() == 1, "the active character tab holds exactly one provider connection, got %d" % connections.size())

	var walker = party.party["Walker Langley"]
	var injuryBefore = int(walker.injuryDamage)
	party.applyFleeCost("Walker Langley")
	var expectedFight = party.getFightData("Walker Langley")
	var expectedMaxHp = int(expectedFight.maxHp)
	await get_tree().process_frame
	await get_tree().process_frame
	check(int(walker.injuryDamage) > injuryBefore, "the production command changed the Party injury state")
	check(characterTab._statValueLabels["maxHp"]["effective"].get_parsed_text() == str(expectedMaxHp), "the active character tab renders the post-command projection")
	check(characterTab.hpText.get_parsed_text() == "HP %d / %d" % [int(expectedFight.hp), expectedMaxHp], "identity HP uses the refreshed effective MxHP")

	characterTab.statsScroll.scroll_vertical = 30
	await get_tree().process_frame
	journal.close()
	journal.open()
	journal.selectTab("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	party.applyFleeCost("Walker Langley")
	var expectedAfterHidden = int(party.getFightData("Walker Langley").maxHp)
	journal.selectTab("character")
	await get_tree().process_frame
	await get_tree().process_frame
	check(characterTab._statValueLabels["maxHp"]["effective"].get_parsed_text() == str(expectedAfterHidden), "activation re-reads statistics instead of showing stale cached values")
	check(characterTab.statsScroll.scroll_vertical == 30, "stat scroll position survives tab switching, got %d" % characterTab.statsScroll.scroll_vertical)

	var stableParty: Dictionary = party.party.duplicate(true)
	var stableInventory: Array = party.inventory.duplicate(true)
	var stableMoney: int = int(party.money)
	var stableNextId: int = int(party._nextInstanceNumber)
	for cycle in 3:
		journal.selectTab("character")
		await get_tree().process_frame
		var tab = journal._tabInstances.get("character")
		if tab == null:
			check(false, "the character tab is available on inspection cycle %d" % cycle)
			break
		tab._onMemberPressed("Walker Langley")
		tab.statsScroll.scroll_vertical = 10
		tab._onMemberPressed("Second Member")
		journal.selectTab("inventory")
		await get_tree().process_frame
		journal.close()
		journal.open()
	check(party.party == stableParty, "inspection and repeated open/close write no member state")
	check(party.inventory == stableInventory, "inspection and repeated open/close write no inventory state")
	check(int(party.money) == stableMoney, "inspection and repeated open/close write no money")
	check(int(party._nextInstanceNumber) == stableNextId, "inspection and repeated open/close allocate no ids")

	journal.selectTab("character")
	await get_tree().process_frame
	characterTab.setTabActive(false)
	var afterDeactivate = party.partyChanged.get_connections().filter(
		func(connection): return connection.callable.get_object() == characterTab)
	check(afterDeactivate.is_empty(), "a deactivated character tab disconnects from the provider")
	characterTab.setTabActive(true)
	journal.close()
	_restorePartyState(party, partyBefore, inventoryBefore, moneyBefore, nextIdBefore)


func _restorePartyState(party, partyBefore: Dictionary, inventoryBefore: Array, moneyBefore: int, nextIdBefore: int) -> void:
	party.party = partyBefore
	party.inventory = inventoryBefore
	party.money = moneyBefore
	party._nextInstanceNumber = nextIdBefore
	party.partyChanged.emit("")


func testSceneTreeSetup() -> void:
	var journalLayer: CanvasLayer = sceneManager.get_node("JournalLayer")
	var transitionLayer: CanvasLayer = sceneManager.get_node("TransitionLayer")
	check(journalLayer.layer < transitionLayer.layer, "the journal layer stays below the transition layer")
	check(journal.get_parent() == journalLayer, "the journal is a persistent child of its layer")
	check(sceneManager.process_mode == Node.PROCESS_MODE_ALWAYS, "SceneManager keeps processing while paused")
	check(sceneManager.get_node("CurrentScene").process_mode == Node.PROCESS_MODE_PAUSABLE, "CurrentScene is explicitly pausable")


## The production return-to-menu route lives in the real Settings tab. The test
## first checks its confirmation behavior, then lets the tab use SceneManager.
func testSettingsReturnToMenu() -> void:
	print("--- Settings return-to-menu route ---")
	journal.setTabDefinitions(Journal.DEFAULT_TABS.duplicate(true))
	journal.selectTab("settings")
	journal.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var settings = journal._tabInstances.get("settings")
	check(settings != null, "the real Settings tab is active")
	if settings == null:
		journal.close()
		return
	check(settings.find_child("QuitToMenuButton", true, false) != null, "Settings exposes a production quit-to-menu action")
	check(settings.getFocusTarget() != null, "the quit action is available to controller focus")
	journal.tabBar.grab_focus()
	await pressAction("ui_down")
	check(get_viewport().gui_get_focus_owner() == settings.getFocusTarget(), "D-pad down enters the Settings action")

	var routed := { "count": 0 }
	settings.menuRouteProvider = func() -> void: routed["count"] += 1
	settings.find_child("QuitToMenuButton", true, false).pressed.emit()
	await get_tree().process_frame
	var confirmation = settings.find_child("QuitConfirmation", true, false)
	check(confirmation != null and confirmation.visible, "quitting first requests confirmation")
	check(!settings.canCloseTab(), "the open confirmation blocks the Journal")
	settings._hideConfirmation()
	confirmation.hide()
	check(settings.canCloseTab(), "cancelling the confirmation restores Journal navigation")

	settings._returnToMainMenu()
	check(int(routed["count"]) == 1, "the confirmed action routes through the tab's SceneManager provider")
	settings.menuRouteProvider = func() -> void: sceneManager.call_deferred("change_scene", "main_menu")
	settings._returnToMainMenu()
	for _frame in 180:
		if sceneManager.currentSceneKey == "main_menu":
			break
		await get_tree().process_frame
	check(sceneManager.currentSceneKey == "main_menu", "the production Settings action returns to the main menu through SceneManager")
	check(journal.process_mode == Node.PROCESS_MODE_ALWAYS, "the journal processes while the game is paused")