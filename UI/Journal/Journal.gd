extends Control
class_name Journal

## Journal modal shell (Docs/System Design/Journal/Journal.md): the game's
## central information overlay with independent tabs. The shell owns tab
## registration, lazy instantiation, session-remembered selection, modal
## input and pause coordination; tabs implement the JournalTab contract and
## read authoritative state through domain APIs, never Journal internals.

signal opened
signal closed
signal tabChanged(tabId: String)

## Default tab registry in the decided order: Map, Inventory, Quests,
## Character, Settings. Tab scenes load lazily on first selection and stay
## cached for the session.
const DEFAULT_TABS := [
	{
		"id": "map", "title": "Map", "tooltip": "The journey so far",
		"icon": preload("res://Assets/Journal/MapIcon.png"),
		"scene_path": "res://UI/Journal/Tabs/MapTab.tscn",
	},
	{
		"id": "inventory", "title": "Inventory", "tooltip": "Packs and equipment",
		"icon": preload("res://Assets/Journal/InventoryIcon.png"),
		"scene_path": "res://UI/Journal/Tabs/InventoryTab.tscn",
	},
	{
		"id": "quests", "title": "Quests", "tooltip": "What happened and what's next",
		"icon": preload("res://Assets/Journal/QuestsIcon.png"),
		"scene_path": "res://UI/Journal/Tabs/QuestsTab.tscn",
	},
	{
		"id": "character", "title": "Character", "tooltip": "Party members and their stats",
		"icon": preload("res://Assets/Journal/EquipmentIcon.png"),
		"scene_path": "res://UI/Journal/Tabs/CharacterTab.tscn",
	},
	{
		"id": "settings", "title": "Settings", "tooltip": "Options and save management",
		"icon": preload("res://Assets/Journal/SettingsIcon.png"),
		"scene_path": "res://UI/Journal/Tabs/SettingsTab.tscn",
	},
]

## Tab registry entries: {"id": String, "title": String, "tooltip": String
## (optional), "icon": Texture2D (optional), "scene_path": String or
## "instance": Control}. Tests inject pre-built instances instead of scenes.
var tabDefinitions: Array = []
var isOpen := false
## Selected tab, remembered for the current application session.
var selectedTabId := "map"
## Shared modal/pause coordinator, owned by SceneManager.
var pauseCoordinator: ModalPauseCoordinator = null

var _tabInstances := {}
var _activeTabId := ""

@onready var tabBar: TabBar = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/Header/TabBar
@onready var tabContentHost: Control = $CenterContainer/PanelContainer/VBoxContainer/TabContentHost
@onready var closeButton: Button = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/Header/CloseButton


func _ready() -> void:
	visible = false
	closeButton.pressed.connect(close)
	tabBar.tab_changed.connect(_onTabBarTabChanged)
	if tabDefinitions.is_empty():
		setTabDefinitions(DEFAULT_TABS.duplicate(true))


func setTabDefinitions(definitions: Array) -> void:
	tabDefinitions = definitions
	_tabInstances = {}
	_activeTabId = ""
	# Drop any focus handoff that pointed at a tab instance being replaced.
	tabBar.focus_neighbor_bottom = NodePath()
	for tab in tabContentHost.get_children():
		tabContentHost.remove_child(tab)
		# Free immediately instead of queue_free(): replaced tabs must not
		# survive as pending deletions when a test/process exits.
		tab.free()
	tabBar.clear_tabs()
	for definition in tabDefinitions:
		# Icon-only tabs: the strip never shows tab text; the tooltip carries
		# the name for hover/focus.
		tabBar.add_tab("", definition.get("icon") as Texture2D)
		var tooltip := str(definition.get("tooltip", definition.get("title", "")))
		if tooltip != "":
			tabBar.set_tab_tooltip(tabBar.tab_count - 1, tooltip)
	if !tabDefinitions.is_empty():
		if !_hasTabId(selectedTabId):
			selectedTabId = str(tabDefinitions[0].get("id", ""))
		var index := _tabIndexOf(selectedTabId)
		if index >= 0:
			tabBar.current_tab = index


func open() -> void:
	if isOpen:
		return
	isOpen = true
	visible = true
	if pauseCoordinator != null:
		pauseCoordinator.acquirePause(self)
	var index := _tabIndexOf(selectedTabId)
	if index >= 0 and tabBar.current_tab != index:
		tabBar.current_tab = index
	if _activeTabId != selectedTabId:
		_activateTab(selectedTabId)
	tabBar.grab_focus()
	opened.emit()


func close() -> void:
	if !isOpen:
		return
	if _activeTabId != "" and _tabInstances.has(_activeTabId):
		var tab: Control = _tabInstances[_activeTabId]
		# A modal sub-flow inside the tab backs out first instead of closing.
		if tab.has_method("canCloseTab") and !tab.canCloseTab():
			return
		if tab.has_method("setTabActive"):
			tab.setTabActive(false)
	_activeTabId = ""
	isOpen = false
	visible = false
	var focusOwner := get_viewport().gui_get_focus_owner()
	if focusOwner != null:
		focusOwner.release_focus()
	if pauseCoordinator != null:
		pauseCoordinator.releasePause(self)
	closed.emit()


func toggle() -> void:
	if isOpen:
		close()
	else:
		open()


func selectTab(tabId: String) -> void:
	if !_hasTabId(tabId):
		return
	selectedTabId = tabId
	var index := _tabIndexOf(tabId)
	if index < 0:
		return
	if tabBar.current_tab != index:
		tabBar.current_tab = index
	elif isOpen and _activeTabId != tabId:
		_activateTab(tabId)


## Journal-level navigation request ("Show on map"): selects the map tab and
## forwards the quest/objective/target request; the requesting tab never
## touches map nodes. Returns whether the exact quest marker was focused.
func showOnMap(request: Dictionary) -> bool:
	if !isOpen:
		return false
	for key in ["quest_id", "objective_id", "target_id"]:
		if str(request.get(key, "")).is_empty():
			return false
	selectTab("map")
	var mapTab: Control = _tabInstances.get("map")
	if mapTab == null or !mapTab.has_method("focusQuestTarget"):
		return false
	return bool(mapTab.focusQuestTarget(request))


func _unhandled_input(event: InputEvent) -> void:
	if !isOpen:
		return
	if event.is_action_pressed("TOGGLE_JOURNAL"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Controller/keyboard back: focused tab content hands focus back to the
		# tab bar first, so the next ui_cancel (or a tab change) still works.
		if _focusIsInTabContent():
			tabBar.grab_focus()
			return
		close()


## True when keyboard/controller focus currently sits inside the active tab's
## content instead of the shell chrome.
func _focusIsInTabContent() -> bool:
	var focusOwner := get_viewport().gui_get_focus_owner()
	return focusOwner != null and tabContentHost.is_ancestor_of(focusOwner)


## Shell focus handoff: a tab may expose getFocusTarget(); the tab bar then
## moves down into that control, and the control moves back up to the tab bar.
## Tabs without one keep the default traversal.
func _wireTabFocus(tab: Control) -> void:
	tabBar.focus_neighbor_bottom = NodePath()
	if !tab.has_method("getFocusTarget"):
		return
	var target := tab.getFocusTarget() as Control
	if target == null or !target.is_inside_tree():
		return
	tabBar.focus_neighbor_bottom = tabBar.get_path_to(target)
	target.focus_neighbor_top = target.get_path_to(tabBar)


func _onTabBarTabChanged(tab: int) -> void:
	var tabId := _idAtIndex(tab)
	if tabId == "":
		return
	selectedTabId = tabId
	if isOpen:
		_activateTab(tabId)


func _activateTab(tabId: String) -> void:
	if !_hasTabId(tabId):
		return
	var selectionChanged := _activeTabId != tabId
	var focusInContent := selectionChanged and _focusIsInTabContent()
	if selectionChanged and _activeTabId != "" and _tabInstances.has(_activeTabId):
		var previous: Control = _tabInstances[_activeTabId]
		if previous.has_method("setTabActive"):
			previous.setTabActive(false)
		previous.visible = false
	if focusInContent:
		tabBar.grab_focus()
	var tab := _getTabInstance(tabId)
	if tab == null:
		return
	if tab.get_parent() == null:
		tabContentHost.add_child(tab)
	tab.visible = true
	if tab.has_method("setTabActive"):
		tab.setTabActive(true)
	if tab.has_method("refreshTab"):
		tab.refreshTab()
	_wireTabFocus(tab)
	_activeTabId = tabId
	if selectionChanged:
		tabChanged.emit(tabId)


func _getTabInstance(tabId: String) -> Control:
	if _tabInstances.has(tabId):
		return _tabInstances[tabId]
	var definition := _definitionOf(tabId)
	if definition.is_empty():
		return null
	var tab: Control = null
	if definition.has("instance"):
		tab = definition["instance"] as Control
	elif definition.has("scene_path"):
		var scene := load(str(definition["scene_path"])) as PackedScene
		if scene == null:
			push_error("Journal: could not load tab scene '{path}'.".format({ "path": definition["scene_path"] }))
			return null
		tab = scene.instantiate()
	if tab == null:
		return null
	var journalTab := tab as JournalTab
	if journalTab != null and definition.has("icon"):
		journalTab.tabIcon = definition["icon"]
	# Cross-tab navigation requests are wired once per lazily created tab; the
	# tab only emits ids and never receives Journal/Map references.
	if tab.has_signal("showOnMapRequested") and !tab.is_connected("showOnMapRequested", Callable(self, "showOnMap")):
		tab.connect("showOnMapRequested", Callable(self, "showOnMap"))
	_tabInstances[tabId] = tab
	return tab


func _definitionOf(tabId: String) -> Dictionary:
	for definition in tabDefinitions:
		if str(definition.get("id", "")) == tabId:
			return definition
	return {}


func _hasTabId(tabId: String) -> bool:
	return _tabIndexOf(tabId) >= 0


func _tabIndexOf(tabId: String) -> int:
	for index in tabDefinitions.size():
		if str(tabDefinitions[index].get("id", "")) == tabId:
			return index
	return -1


func _idAtIndex(index: int) -> String:
	if index < 0 or index >= tabDefinitions.size():
		return ""
	return str(tabDefinitions[index].get("id", ""))
