extends Node

## Scene-run validation of the Journal Quests tab (Docs/System Design/Journal/
## Quests.md, stage 2): sections, selection, detail/Next/completed rendering,
## malformed-provider handling, live updates, focus, navigation signal, and
## long-content scrolling at 640x360. Uses a fake provider Node, matching the
## tab's injectable-provider contract.

const QuestsTabScene = preload("res://UI/Journal/Tabs/QuestsTab.tscn")

var failures := 0
var provider: FakeProvider
var tab


class FakeProvider:
	extends Node

	signal questStateChanged(questId: String)

	var available := true
	var entries: Array = []

	func isQuestDataAvailable() -> bool:
		return available

	func getQuestJournalEntries() -> Array:
		var result: Array = []
		for entry in entries:
			result.append(entry)
		return result

	func setEntries(values: Array) -> void:
		entries.clear()
		entries.assign(values)

	func emitQuestState(questId: String) -> void:
		questStateChanged.emit(questId)


func _ready() -> void:
	provider = FakeProvider.new()
	tab = QuestsTabScene.instantiate()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.questProvider = provider
	add_child(tab)
	await get_tree().process_frame

	await testUnavailableAndEmptyStates()
	await testSectionsAndSelection()
	await testDetailStates()
	await testMalformedEntries()
	await testLiveUpdatesAndConnections()
	await testFocusAndRestoration()
	await testNavigationSignal()
	await testLongContentScrolling()

	tab.free()
	provider.free()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func refreshTab() -> void:
	tab.setTabActive(true)
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame


func activeEntry(questId: String, title: String, summary: String, nextText: String, targetId: String, history: Array = []) -> Dictionary:
	return {
		"quest_id": questId,
		"title": title,
		"summary": summary,
		"status": "active",
		"history": history,
		"current_objective": {
			"objective_id": questId + "_objective",
			"text": nextText,
			"target_id": targetId,
		},
	}


func completedEntry(questId: String, title: String, summary: String, history: Array = []) -> Dictionary:
	return {
		"quest_id": questId,
		"title": title,
		"summary": summary,
		"status": "completed",
		"history": history,
		"current_objective": {},
	}


func historyItem(objectiveId: String, text: String) -> Dictionary:
	return { "objective_id": objectiveId, "text": text }


func malformedActiveEntry(questId: String) -> Dictionary:
	return {
		"quest_id": questId,
		"title": "Broken quest",
		"summary": "Broken.",
		"status": "active",
		"history": [],
		"current_objective": {},
	}


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("CHECK FAILED: ", message)


func testUnavailableAndEmptyStates() -> void:
	print("--- Unavailable and empty states ---")
	provider.available = false
	provider.setEntries([activeEntry("q_a", "Quest A", "Summary.", "Next A", "Finch Pond")])
	await refreshTab()
	check(!tab.contentView.visible and tab.stateView.visible, "unavailable data hides content and shows the state view")
	check(tab.stateMessageLabel.text == "Quest data unavailable", "unavailable data shows the unavailable message")
	check(tab._questRows.is_empty(), "unavailable data leaves no rows")
	check(tab.getFocusTarget() == null, "unavailable data exposes no focus target")

	provider.available = true
	provider.setEntries([])
	await refreshTab()
	check(tab.stateView.visible and tab.stateMessageLabel.text == "No quests yet", "a valid empty journal shows the empty message")
	check(tab.getFocusTarget() == null, "an empty journal exposes no focus target")

	var brokenProvider := Node.new()
	tab.questProvider = brokenProvider
	await refreshTab()
	check(tab.stateMessageLabel.text == "Quest data unavailable", "a provider without the read API is unavailable")
	brokenProvider.free()
	tab.questProvider = provider


func testSectionsAndSelection() -> void:
	print("\n--- Sections and selection ---")
	provider.available = true
	provider.setEntries([
		completedEntry("q_done", "Done Quest", "Finished.", [historyItem("done", "Did the thing")]),
		activeEntry("q_a", "Quest A", "Summary A.", "Next A", "Finch Pond"),
		activeEntry("q_b", "Quest B", "Summary B.", "Next B", ""),
	])
	await refreshTab()
	check(tab.contentView.visible and !tab.stateView.visible, "valid data shows the content view")
	check(tab.activeHeader.visible and tab.completedHeader.visible, "both section headers are visible")
	check(tab.activeQuestRows.get_child_count() == 2, "two active rows are created")
	check(tab.completedQuestRows.get_child_count() == 1, "one completed row is created")
	check(tab._focusOrder == ["q_a", "q_b", "q_done"], "focus order groups active before completed")
	check(tab._selectedQuestId == "q_a", "the first active quest is selected by default")
	check(tab.titleLabel.text == "Quest A" and tab.questStateLabel.text == "Active", "the selected active quest renders title and state")
	check(tab.summaryLabel.text == "Summary A.", "the summary renders")
	check(tab.nextPanel.visible and tab.nextLabel.text == "Next A", "the active quest shows its Next objective")
	check(tab.showOnMapButton.visible, "a targeted current objective shows Show on map")
	check(tab.progressEntries.get_child_count() == 1, "empty history renders the no-history message")
	check(tab.getFocusTarget() == tab._questRows["q_a"], "the selected row is the focus target")

	tab._onQuestRowPressed("q_done")
	check(tab._selectedQuestId == "q_done", "selecting a completed row updates selection")
	check(tab.titleLabel.text == "Done Quest" and tab.questStateLabel.text == "Completed", "the completed quest renders title and state")
	check(!tab.nextPanel.visible, "a completed quest hides Next")
	check(!tab.showOnMapButton.visible, "a completed quest hides Show on map")
	check(tab.progressEntries.get_child_count() == 1, "completed history renders one progress row")
	check(tab._questRows["q_done"].button_pressed, "the completed row shows selection")

	tab._onQuestRowPressed("q_b")
	check(tab.nextPanel.visible and !tab.showOnMapButton.visible, "a targetless active quest shows Next without Show on map")
	check(tab.getFocusTarget() == tab._questRows["q_b"], "focus target follows the selected row")


func testDetailStates() -> void:
	print("\n--- Detail states ---")
	provider.setEntries([completedEntry("q_done", "Done Quest", "Finished.", [historyItem("done", "Did the thing")])])
	await refreshTab()
	check(tab._selectedQuestId == "q_done", "with no active quest the first completed quest is selected")
	check(!tab.nextPanel.visible and !tab.showOnMapButton.visible, "a completed-only journal shows no current objective")

	provider.setEntries([activeEntry("q_a", "Quest A", "Summary A.", "Next A", "")])
	await refreshTab()
	check(tab.activeHeader.visible and !tab.completedHeader.visible, "an active-only journal hides the Completed header")
	check(tab.progressEntries.get_child_count() == 1 and tab.progressEntries.get_child(0) is Label, "no-history is a readable message")
	check(tab.progressEntries.get_child(0).text == "No progress recorded yet.", "the no-history message is explicit")


func testMalformedEntries() -> void:
	print("\n--- Malformed provider entries ---")
	provider.setEntries([activeEntry("q_a", "Quest A", "Summary A.", "Next A", "Finch Pond")])
	await refreshTab()
	tab._onQuestRowPressed("q_a")

	provider.setEntries([
		malformedActiveEntry("q_a"),
		activeEntry("q_b", "Quest B", "Summary B.", "Next B", ""),
	])
	await refreshTab()
	check(tab._selectedQuestId == "q_a", "a selected malformed entry keeps its selection")
	check(tab.titleLabel.text == "Quest data unavailable", "a selected malformed entry shows the unavailable detail")
	check(!tab.nextPanel.visible and !tab.showOnMapButton.visible, "malformed detail hides current-objective actions")
	check(!tab._questRows.has("q_a") and tab._questRows.has("q_b"), "malformed entries create no row")
	check(tab.getFocusTarget() == tab._questRows["q_b"], "focus falls back to the first valid row")

	provider.setEntries([42, activeEntry("q_b", "Quest B", "Summary B.", "Next B", "")])
	await refreshTab()
	check(tab._questRows.size() == 1 and tab._questRows.has("q_b"), "non-Dictionary entries are ignored")
	check(tab._selectedQuestId == "q_b", "selection falls back when the malformed entry disappears")


func testLiveUpdatesAndConnections() -> void:
	print("\n--- Live updates and connections ---")
	provider.setEntries([activeEntry("q_a", "Quest A", "Summary A.", "First", "Finch Pond")])
	await refreshTab()
	check(provider.get_signal_connection_list("questStateChanged").size() == 1, "an active tab connects to the provider once")
	check(tab.nextLabel.text == "First", "the initial objective renders")

	provider.setEntries([activeEntry("q_a", "Quest A", "Summary A.", "Second", "Lazysprings", [historyItem("find", "Found the trail")])])
	provider.emitQuestState("q_a")
	await get_tree().process_frame
	check(tab.nextLabel.text == "Second", "a provider signal refreshes the current objective")
	check(tab.progressEntries.get_child_count() == 1, "a provider signal refreshes progress history")
	check(tab.showOnMapButton.visible, "the refreshed objective keeps its map action")

	tab.setTabActive(false)
	check(provider.get_signal_connection_list("questStateChanged").is_empty(), "deactivation disconnects the provider")
	tab.setTabActive(true)
	tab.setTabActive(true)
	check(provider.get_signal_connection_list("questStateChanged").size() == 1, "repeated activation does not duplicate the connection")
	tab.refreshTab()
	await get_tree().process_frame
	check(tab._questRows.size() == 1 and tab.activeQuestRows.get_child_count() == 1, "repeated refresh does not duplicate rows")


func testFocusAndRestoration() -> void:
	print("\n--- Focus and restoration ---")
	provider.setEntries([
		activeEntry("q_a", "Quest A", "Summary A.", "Next A", "Finch Pond"),
		completedEntry("q_b", "Quest B", "Summary B.", [historyItem("done", "Finished B")]),
	])
	await refreshTab()
	var rowA: Button = tab._questRows["q_a"]
	check(tab.getFocusTarget() == rowA, "the selected row is the focus target")
	rowA.grab_focus()
	await get_tree().process_frame
	check(get_viewport().gui_get_focus_owner() == rowA, "a quest row can take focus")
	check(rowA.get_node(rowA.focus_neighbor_right) == tab.showOnMapButton, "row-right focus reaches Show on map when visible")
	check(tab.showOnMapButton.get_node(tab.showOnMapButton.focus_neighbor_left) == rowA, "Show on map's left focus returns to the selected row")

	tab._onQuestRowPressed("q_b")
	var rowB: Button = tab._questRows["q_b"]
	check(rowB.get_node(rowB.focus_neighbor_right) == tab.progressScroll, "row-right focus reaches Progress when Show on map is hidden")
	check(tab.progressScroll.get_node(tab.progressScroll.focus_neighbor_left) == rowB, "Progress's left focus returns to the selected row")

	rowB.grab_focus()
	await get_tree().process_frame
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._selectedQuestId == "q_b", "selection survives a refresh")
	check(get_viewport().gui_get_focus_owner() == tab._questRows["q_b"], "row focus is restored across a refresh")


func testNavigationSignal() -> void:
	print("\n--- Show on map signal ---")
	provider.setEntries([activeEntry("q_a", "Quest A", "Summary A.", "Next A", "Finch Pond")])
	await refreshTab()
	var received: Array = []
	tab.showOnMapRequested.connect(func(request: Dictionary) -> void: received.append(request))
	tab.showOnMapButton.pressed.emit()
	check(received.size() == 1, "pressing Show on map emits one navigation request")
	if received.size() == 1:
		check(received[0]["quest_id"] == "q_a", "the request carries quest_id")
		check(received[0]["objective_id"] == "q_a_objective", "the request carries objective_id")
		check(received[0]["target_id"] == "Finch Pond", "the request carries target_id")
	check(tab._selectedQuestId == "q_a", "navigation does not change selection")

	tab._onQuestRowPressed("q_a")
	tab._onShowOnMapPressed()
	check(received.size() == 2, "the request path is repeatable without mutating state")

	provider.setEntries([activeEntry("q_b", "Quest B", "Summary B.", "Next B", "")])
	await refreshTab()
	tab._onShowOnMapPressed()
	check(received.size() == 2, "a targetless objective emits no navigation request")


func testLongContentScrolling() -> void:
	print("\n--- Long content at 640x360 ---")
	check(tab.size.is_equal_approx(Vector2(640, 360)), "the tab is laid out at the reference viewport size")
	check(tab.titleLabel.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "detail labels wrap instead of clipping")

	var entries: Array = []
	for index in 20:
		entries.append(activeEntry(
			"q_%d" % index,
			"Quest %d with a deliberately long title that should stay readable" % index,
			"A long summary that must wrap across the detail panel instead of shrinking the text.",
			"A long next objective that must remain readable and scrollable in the detail panel.",
			"Finch Pond"
		))
	provider.setEntries(entries)
	await refreshTab()
	check(tab._questRows.size() == 20, "all quests create rows")
	check(tab.listScroll.get_v_scroll_bar().max_value > 0.0, "a long quest list scrolls")

	var longHistory: Array = []
	for index in 30:
		longHistory.append(historyItem("objective_%d" % index, "A long completed step that explains what happened during objective %d." % index))
	provider.setEntries([activeEntry("q_long", "Long Quest", "Summary.", "Next.", "Finch Pond", longHistory)])
	await refreshTab()
	await get_tree().process_frame
	check(tab.progressEntries.get_child_count() == 30, "all history entries render")
	check(tab.progressScroll.get_v_scroll_bar().max_value > 0.0, "a long progress history scrolls")