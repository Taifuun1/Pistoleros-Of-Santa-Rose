extends JournalTab

## Journal Quests tab (Docs/System Design/Journal/Quests.md, stage 2): a
## read-only Active/Completed master list and quest detail view. Quest state is
## read through an injectable provider (the Quests autoload by default) on
## activation and on its change signal; this tab never mutates quest state and
## never reaches into Journal/Map nodes.

signal showOnMapRequested(request: Dictionary)

const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATE_UNAVAILABLE := "Quest data unavailable"
const STATE_EMPTY := "No quests yet"
const STATE_NO_HISTORY := "No progress recorded yet."
const STATE_SELECT_PROMPT := "Select a quest."

const CURRENT_ICON := preload("res://Assets/Journal/CurrentQuestIcon.png")
const ACTIVE_ICON := preload("res://Assets/Journal/ActiveQuestIcon.png")
const COMPLETED_ICON := preload("res://Assets/Journal/CompletedQuestIcon.png")

## Provider Node contract: isQuestDataAvailable() -> bool,
## getQuestJournalEntries() -> Array[Dictionary], and
## signal questStateChanged(questId: String). Null resolves /root/Quests.
var questProvider: Node = null

var _entriesById: Dictionary = {}
var _invalidEntryIds: Dictionary = {}
var _orderedEntries: Array[Dictionary] = []
var _questRows: Dictionary = {}
var _focusOrder: Array[String] = []
var _selectedQuestId := ""
var _connectedProvider: Node = null
var _pendingListScroll := 0
var _pendingDetailScroll := 0
var _restoreFocusQuestId := ""

@onready var contentView: Control = $ContentView
@onready var listScroll: ScrollContainer = $ContentView/QuestListPanel/QuestListScroll
@onready var activeHeader: Control = $ContentView/QuestListPanel/QuestListScroll/QuestList/ActiveHeader
@onready var activeQuestRows: Control = $ContentView/QuestListPanel/QuestListScroll/QuestList/ActiveQuestRows
@onready var completedHeader: Control = $ContentView/QuestListPanel/QuestListScroll/QuestList/CompletedHeader
@onready var completedQuestRows: Control = $ContentView/QuestListPanel/QuestListScroll/QuestList/CompletedQuestRows
@onready var titleLabel: Label = $ContentView/QuestDetailPanel/DetailLayout/TitleLabel
@onready var questStateLabel: Label = $ContentView/QuestDetailPanel/DetailLayout/QuestStateLabel
@onready var summaryLabel: Label = $ContentView/QuestDetailPanel/DetailLayout/SummaryLabel
@onready var nextPanel: Control = $ContentView/QuestDetailPanel/DetailLayout/NextPanel
@onready var nextLabel: Label = $ContentView/QuestDetailPanel/DetailLayout/NextPanel/NextLayout/NextLabel
@onready var showOnMapButton: Button = $ContentView/QuestDetailPanel/DetailLayout/NextPanel/NextLayout/ShowOnMapButton
@onready var progressScroll: ScrollContainer = $ContentView/QuestDetailPanel/DetailLayout/ProgressScroll
@onready var progressEntries: Control = $ContentView/QuestDetailPanel/DetailLayout/ProgressScroll/ProgressLayout/ProgressEntries
@onready var stateView: Control = $StateView
@onready var stateTabSprite: TabSprite = $StateView/StateLayout/StateTabSprite
@onready var stateMessageLabel: Label = $StateView/StateLayout/StateMessageLabel


func _ready() -> void:
	stateTabSprite.tabIcon = tabIcon
	showOnMapButton.pressed.connect(_onShowOnMapPressed)
	_showStateMessage(STATE_UNAVAILABLE)


func refreshTab() -> void:
	_captureViewState()
	_entriesById = {}
	_invalidEntryIds = {}
	_orderedEntries = []

	var provider := _resolveQuestProvider()
	if active:
		_connectProvider(provider)
	else:
		_disconnectProvider()
	if !_providerCanRead(provider):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	if !bool(provider.isQuestDataAvailable()):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return

	var entriesValue = provider.getQuestJournalEntries()
	if !(entriesValue is Array):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	for entryValue in entriesValue:
		if !(entryValue is Dictionary):
			push_warning("Quests tab: ignored a non-Dictionary journal entry.")
			continue
		var rawEntry := entryValue as Dictionary
		var questId := str(rawEntry.get("quest_id", ""))
		var normalized := _normalizeEntry(rawEntry)
		if normalized.is_empty():
			if !questId.is_empty():
				_invalidEntryIds[questId] = true
			continue
		_orderedEntries.append(normalized)
		_entriesById[normalized["quest_id"]] = normalized

	if _orderedEntries.is_empty():
		_clearView()
		_showStateMessage(STATE_EMPTY if _invalidEntryIds.is_empty() else STATE_UNAVAILABLE)
		return
	_rebuildRows()
	_reconcileSelection()
	_renderSelectedQuest()
	_showContent()
	_restoreViewState()


func setTabActive(tabActive: bool) -> void:
	super.setTabActive(tabActive)
	if tabActive:
		_connectProvider(_resolveQuestProvider())
	else:
		_disconnectProvider()


## Shell focus handoff contract: the selected row (or the first row).
func getFocusTarget() -> Control:
	var row := _selectedRow()
	if row == null and !_focusOrder.is_empty():
		row = _questRows.get(_focusOrder[0]) as Button
	return row if row != null and row.is_visible_in_tree() else null


func _exit_tree() -> void:
	_disconnectProvider()


func _resolveQuestProvider() -> Node:
	if questProvider != null:
		return questProvider
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Quests")


func _providerCanRead(provider: Node) -> bool:
	return provider != null and provider.has_method("isQuestDataAvailable") and provider.has_method("getQuestJournalEntries")


func _connectProvider(provider: Node) -> void:
	if _connectedProvider == provider:
		return
	_disconnectProvider()
	if provider == null or !provider.has_signal("questStateChanged"):
		return
	var callback := Callable(self, "_onQuestStateChanged")
	if !provider.is_connected("questStateChanged", callback):
		provider.connect("questStateChanged", callback)
	_connectedProvider = provider


func _disconnectProvider() -> void:
	if _connectedProvider == null:
		return
	var callback := Callable(self, "_onQuestStateChanged")
	if is_instance_valid(_connectedProvider) and _connectedProvider.is_connected("questStateChanged", callback):
		_connectedProvider.disconnect("questStateChanged", callback)
	_connectedProvider = null


func _onQuestStateChanged(_questId: String) -> void:
	if active:
		refreshTab()


func _captureViewState() -> void:
	_pendingListScroll = 0
	_pendingDetailScroll = 0
	_restoreFocusQuestId = ""
	if !is_inside_tree():
		return
	_pendingListScroll = int(listScroll.scroll_vertical)
	_pendingDetailScroll = int(progressScroll.scroll_vertical)
	if !_focusIsInsideTab():
		return
	var focusOwner := get_viewport().gui_get_focus_owner()
	if focusOwner == null:
		return
	for questId in _questRows:
		var row: Button = _questRows[questId]
		if row == focusOwner or row.is_ancestor_of(focusOwner):
			_restoreFocusQuestId = questId
			return
	if focusOwner == showOnMapButton or focusOwner == progressScroll:
		_restoreFocusQuestId = _selectedQuestId


func _restoreViewState() -> void:
	listScroll.scroll_vertical = _pendingListScroll
	progressScroll.scroll_vertical = _pendingDetailScroll
	call_deferred("_applyPendingViewState")


func _applyPendingViewState() -> void:
	listScroll.scroll_vertical = _pendingListScroll
	progressScroll.scroll_vertical = _pendingDetailScroll
	if _restoreFocusQuestId.is_empty() or !active or !is_visible_in_tree():
		_restoreFocusQuestId = ""
		return
	var row: Button = _questRows.get(_restoreFocusQuestId) as Button
	if row != null:
		row.grab_focus()
	else:
		var target := getFocusTarget()
		if target != null:
			target.grab_focus()
	_restoreFocusQuestId = ""


func _focusIsInsideTab() -> bool:
	if !is_inside_tree():
		return false
	var focusOwner := get_viewport().gui_get_focus_owner()
	return focusOwner != null and is_ancestor_of(focusOwner)


func _showStateMessage(message: String) -> void:
	contentView.visible = false
	stateView.visible = true
	stateMessageLabel.text = message
	stateTabSprite.tabIcon = tabIcon


func _showContent() -> void:
	stateView.visible = false
	contentView.visible = true


func _clearView() -> void:
	_clearRows()
	_clearProgress()
	titleLabel.text = ""
	questStateLabel.text = ""
	summaryLabel.text = ""
	nextLabel.text = ""
	nextPanel.visible = false
	showOnMapButton.visible = false


## Defensive provider-entry normalization: malformed entries are skipped rather
## than shown as live data. Returns {} and warns on any invalid field.
func _normalizeEntry(rawEntry: Dictionary) -> Dictionary:
	var questId := str(rawEntry.get("quest_id", ""))
	if questId.is_empty():
		push_warning("Quests tab: ignored an entry without quest_id.")
		return {}
	var status := str(rawEntry.get("status", ""))
	if status != STATUS_ACTIVE and status != STATUS_COMPLETED:
		push_warning("Quests tab: entry '%s' has invalid status '%s'." % [questId, status])
		return {}
	var title := str(rawEntry.get("title", ""))
	if title.strip_edges().is_empty():
		push_warning("Quests tab: entry '%s' has an empty title." % questId)
		return {}

	var historyValue = rawEntry.get("history", [])
	if !(historyValue is Array):
		push_warning("Quests tab: entry '%s' has a non-Array history." % questId)
		return {}
	var history: Array[Dictionary] = []
	for historyValueItem in historyValue:
		if !(historyValueItem is Dictionary):
			push_warning("Quests tab: entry '%s' has a malformed history item." % questId)
			return {}
		var historyItem := historyValueItem as Dictionary
		var objectiveId := str(historyItem.get("objective_id", ""))
		var text := str(historyItem.get("text", ""))
		if objectiveId.is_empty() or text.strip_edges().is_empty():
			push_warning("Quests tab: entry '%s' has an incomplete history item." % questId)
			return {}
		history.append({ "objective_id": objectiveId, "text": text })

	var currentValue = rawEntry.get("current_objective", {})
	if !(currentValue is Dictionary):
		push_warning("Quests tab: entry '%s' has a non-Dictionary current_objective." % questId)
		return {}
	var currentRaw := currentValue as Dictionary
	var current: Dictionary = {}
	if status == STATUS_ACTIVE:
		var objectiveId := str(currentRaw.get("objective_id", ""))
		var text := str(currentRaw.get("text", ""))
		if objectiveId.is_empty() or text.strip_edges().is_empty():
			push_warning("Quests tab: active entry '%s' has no valid current objective." % questId)
			return {}
		current = {
			"objective_id": objectiveId,
			"text": text,
			"target_id": str(currentRaw.get("target_id", "")),
		}
	elif !currentRaw.is_empty():
		push_warning("Quests tab: completed entry '%s' has a current objective." % questId)
		return {}

	return {
		"quest_id": questId,
		"title": title,
		"summary": str(rawEntry.get("summary", "")),
		"status": status,
		"history": history,
		"current_objective": current,
	}


func _rebuildRows() -> void:
	_clearRows()
	var group := ButtonGroup.new()
	var activeIds: Array[String] = []
	var completedIds: Array[String] = []
	for entry in _orderedEntries:
		var questId := str(entry["quest_id"])
		var isActive := str(entry["status"]) == STATUS_ACTIVE
		var row := Button.new()
		row.text = str(entry["title"])
		row.icon = ACTIVE_ICON if isActive else COMPLETED_ICON
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_ALL
		row.toggle_mode = true
		row.button_group = group
		row.tooltip_text = row.text
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.set_meta("quest_id", questId)
		row.pressed.connect(_onQuestRowPressed.bind(questId))
		if isActive:
			activeQuestRows.add_child(row)
			activeIds.append(questId)
		else:
			completedQuestRows.add_child(row)
			completedIds.append(questId)
		_questRows[questId] = row
	_focusOrder = []
	_focusOrder.append_array(activeIds)
	_focusOrder.append_array(completedIds)
	activeHeader.visible = !activeIds.is_empty()
	completedHeader.visible = !completedIds.is_empty()


func _clearRows() -> void:
	for questId in _questRows:
		var row: Button = _questRows[questId]
		if is_instance_valid(row):
			if row.get_parent() != null:
				row.get_parent().remove_child(row)
			row.free()
	_questRows = {}
	_focusOrder = []


func _clearProgress() -> void:
	for child in progressEntries.get_children():
		progressEntries.remove_child(child)
		child.free()


func _reconcileSelection() -> void:
	if !_selectedQuestId.is_empty() and (_entriesById.has(_selectedQuestId) or _invalidEntryIds.has(_selectedQuestId)):
		return
	_selectedQuestId = ""
	var firstAny := ""
	var firstActive := ""
	for entry in _orderedEntries:
		var questId := str(entry["quest_id"])
		if firstAny.is_empty():
			firstAny = questId
		if firstActive.is_empty() and str(entry["status"]) == STATUS_ACTIVE:
			firstActive = questId
	_selectedQuestId = firstActive if !firstActive.is_empty() else firstAny


func _selectedRow() -> Button:
	if _selectedQuestId.is_empty():
		return null
	return _questRows.get(_selectedQuestId) as Button


func _updateRowSelection() -> void:
	for questId in _questRows:
		var row: Button = _questRows[questId]
		row.button_pressed = questId == _selectedQuestId


func _onQuestRowPressed(questId: String) -> void:
	if !_entriesById.has(questId):
		return
	_selectedQuestId = questId
	_renderSelectedQuest()


func _onShowOnMapPressed() -> void:
	var entry: Dictionary = _entriesById.get(_selectedQuestId, {})
	if entry.is_empty():
		return
	var current: Dictionary = entry.get("current_objective", {})
	var targetId := str(current.get("target_id", ""))
	if targetId.is_empty():
		return
	showOnMapRequested.emit({
		"quest_id": _selectedQuestId,
		"objective_id": str(current.get("objective_id", "")),
		"target_id": targetId,
	})


func _renderSelectedQuest() -> void:
	if _invalidEntryIds.has(_selectedQuestId) and !_entriesById.has(_selectedQuestId):
		_renderUnavailableDetail()
		_updateRowSelection()
		_wireFocusNeighbours()
		return
	var entry: Dictionary = _entriesById.get(_selectedQuestId, {})
	if entry.is_empty():
		_renderEmptyDetail()
		_updateRowSelection()
		_wireFocusNeighbours()
		return

	var status := str(entry["status"])
	titleLabel.text = str(entry["title"])
	questStateLabel.text = "Active" if status == STATUS_ACTIVE else "Completed"
	summaryLabel.text = str(entry["summary"])
	var current: Dictionary = entry.get("current_objective", {})
	var hasCurrent := status == STATUS_ACTIVE and !current.is_empty()
	nextPanel.visible = hasCurrent
	if hasCurrent:
		nextLabel.text = str(current["text"])
		var targetId := str(current.get("target_id", ""))
		showOnMapButton.visible = !targetId.is_empty()
	else:
		nextLabel.text = ""
		showOnMapButton.visible = false
	var history: Array[Dictionary] = entry.get("history", [])
	_buildProgress(history)
	_updateRowSelection()
	_wireFocusNeighbours()


func _renderUnavailableDetail() -> void:
	titleLabel.text = STATE_UNAVAILABLE
	questStateLabel.text = ""
	summaryLabel.text = ""
	nextLabel.text = ""
	nextPanel.visible = false
	showOnMapButton.visible = false
	_clearProgress()


func _renderEmptyDetail() -> void:
	titleLabel.text = STATE_SELECT_PROMPT
	questStateLabel.text = ""
	summaryLabel.text = ""
	nextLabel.text = ""
	nextPanel.visible = false
	showOnMapButton.visible = false
	_clearProgress()


func _buildProgress(history: Array[Dictionary]) -> void:
	_clearProgress()
	if history.is_empty():
		_addProgressMessage(STATE_NO_HISTORY)
		return
	for item in history:
		_addProgressRow(str(item["text"]))


func _addProgressMessage(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progressEntries.add_child(label)


func _addProgressRow(text: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = COMPLETED_ICON
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	progressEntries.add_child(row)


func _wireFocusNeighbours() -> void:
	var selectedRow := _selectedRow()
	if selectedRow == null and !_focusOrder.is_empty():
		selectedRow = _questRows.get(_focusOrder[0]) as Button
	var rightTarget: Control = showOnMapButton if showOnMapButton.visible else progressScroll
	for index in _focusOrder.size():
		var row: Button = _questRows[_focusOrder[index]]
		row.focus_neighbor_right = row.get_path_to(rightTarget)
		if index > 0:
			row.focus_neighbor_top = row.get_path_to(_questRows[_focusOrder[index - 1]] as Node)
		if index + 1 < _focusOrder.size():
			row.focus_neighbor_bottom = row.get_path_to(_questRows[_focusOrder[index + 1]] as Node)
	if selectedRow == null:
		return
	if showOnMapButton.visible:
		showOnMapButton.focus_neighbor_left = showOnMapButton.get_path_to(selectedRow)
	progressScroll.focus_neighbor_left = progressScroll.get_path_to(selectedRow)
