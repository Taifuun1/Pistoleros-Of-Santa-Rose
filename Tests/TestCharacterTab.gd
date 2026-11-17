extends Node

## Scene-run validation of the Journal Character tab (Docs/System Design/Journal/
## Character.md, patch 2). Uses a fake provider so rendering, states and focus
## are deterministic. Run as TestCharacterTab.tscn.

const CharacterTabScene = preload("res://UI/Journal/Tabs/CharacterTab.tscn")
const PartyMemberArtScript = preload("res://UI/Journal/PartyMemberArt.gd")

var failures := 0
var provider: FakeProvider
var tab


class FakeProvider:
	extends Node

	signal partyChanged(memberKey: String)

	var available := true
	var snapshot: Dictionary = {}
	var snapshotCalls := 0

	func isCharacterDataAvailable() -> bool:
		return available

	func getCharacterJournalSnapshot() -> Dictionary:
		snapshotCalls += 1
		return snapshot.duplicate(true)

	var moveCalls: Array = []
	var moveFailure := ""

	func getMoveLoadoutSnapshot(memberKey: String) -> Dictionary:
		var loadout = _member(memberKey).get("moveLoadout", null)
		return loadout.duplicate(true) if loadout is Dictionary else {}

	func activateMove(memberKey: String, moveId: String) -> Dictionary:
		moveCalls.append(["activate", memberKey, moveId])
		return _applyMove(memberKey, moveId, true)

	func deactivateMove(memberKey: String, moveId: String) -> Dictionary:
		moveCalls.append(["deactivate", memberKey, moveId])
		return _applyMove(memberKey, moveId, false)

	## Minimal loadout semantics: toggle the row and keep the used count honest.
	func _applyMove(memberKey: String, moveId: String, activate: bool) -> Dictionary:
		if moveFailure != "":
			return { "success": false, "reason": moveFailure }
		var loadout = _member(memberKey).get("moveLoadout", null)
		if !(loadout is Dictionary):
			return { "success": false, "reason": "data_unavailable" }
		for entry in loadout.get("available", []):
			if entry is Dictionary and str(entry.get("name", "")) == moveId:
				entry["active"] = activate
				loadout["used"] = int(loadout.get("used", 0)) + (1 if activate else -1)
				return { "success": true, "reason": "" }
		return { "success": false, "reason": "move_not_available" }

	func _member(memberKey: String) -> Dictionary:
		for member in snapshot.get("members", []):
			if member is Dictionary and str(member.get("key", "")) == memberKey:
				return member
		return {}

	func emitPartyChanged(memberKey := "") -> void:
		partyChanged.emit(memberKey)


func _ready() -> void:
	provider = FakeProvider.new()
	provider.snapshot = makeSnapshot()
	tab = CharacterTabScene.instantiate()
	tab.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tab.position = Vector2(40, 60)
	tab.size = Vector2(560, 240)
	tab.characterProvider = provider
	add_child(tab)
	await get_tree().process_frame
	await get_tree().process_frame

	await testUnavailableMalformedAndEmpty()
	await testContentAndSelection()
	await testRodeoAndModifierStates()
	await testMoveLoadout()
	await testFocusScrollAndLiveUpdates()
	await testLongContentAndLayout()

	tab.setTabActive(false)
	tab.free()
	provider.free()
	print("\nTestCharacterTab: %d failure(s)" % failures)
	get_tree().quit(failures)


func refreshTab() -> void:
	tab.setTabActive(true)
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame


func makeSnapshot() -> Dictionary:
	return {
		"level": 3,
		"members": [
			{
				"key": "walker",
				"actorName": "Walker Langley",
				"characterClass": "Gunslinger",
				"downed": false,
				"hp": 12,
				"maxHp": 15,
				"statRows": statRows(),
				"modifiers": [
					{
						"kind": "class", "sourceId": "Gunslinger", "name": "Gunslinger", "slot": "",
						"effects": [{ "path": "class.explosiveBase", "label": "Explosive base", "amount": 2, "format": "integer" }],
						"shootoutsLeft": 0, "detail": "",
					},
					{
						"kind": "equipment", "sourceId": "belt_1", "name": "Fine Belt", "slot": "belt",
						"effects": [{ "path": "beltSpace", "label": "Belt space", "amount": 1, "format": "integer" }],
						"shootoutsLeft": 0, "detail": "",
					},
				],
				"rodeo": {
					"key": "leaders duck", "available": true, "name": "Leaders Duck",
					"description": "Every other turn, at the end of the turn, move one column backward",
				},
				"moveLoadout": {
					"success": true, "used": 2, "cap": 4, "managementAllowed": true,
					"available": [
						{ "name": "Sharp Shot", "origin": "class", "active": true, "offensive": true },
						{ "name": "Hold Steady", "origin": "class", "active": true, "offensive": false },
						{ "name": "Duck Down", "origin": "class", "active": false, "offensive": false },
					],
				},
			},
			{
				"key": "squeky",
				"actorName": "Squeky Rat",
				"characterClass": "Dust Whisperer",
				"downed": true,
				"hp": 0,
				"maxHp": 8,
				"statRows": statRows(),
				"modifiers": [
					{
						"kind": "injury", "sourceId": "injury", "name": "Journey injury", "slot": "",
						"effects": [{ "path": "maxHp", "label": "MxHP", "amount": -1, "format": "integer" }],
						"shootoutsLeft": 0, "detail": "Town entry resets journey injuries; camp items reduce them.",
					},
					{
						"kind": "knockout", "sourceId": "knockout:0", "name": "Knockout", "slot": "",
						"effects": [{ "path": "stats.sixShootin", "label": "Six Shootin'", "amount": -1, "format": "integer" }],
						"shootoutsLeft": 2, "detail": "",
					},
				],
				"rodeo": null,
			},
		],
	}


func statRows() -> Array:
	var specs = [
		["Vitality", "maxHp", "MxHP", "integer", 12, 15],
		["Core", "stats.sixShootin", "Six Shootin'", "integer", 3, 3],
		["Core", "stats.highTailin", "High Tailin'", "integer", 6, 7],
		["Core", "stats.taffyin", "Taffyin'", "integer", 2, 2],
		["Lead", "stats.damage.lead.revolver", "Revolver", "integer", 1, 1],
		["Lead", "stats.damage.lead.rifle", "Rifle", "integer", 1, 1],
		["Lead", "stats.damage.lead.shotgun", "Shotgun", "integer", 1, 1],
		["Explosive", "stats.damage.explosive.gunpowder", "Gunpowder", "integer", 1, 1],
		["Explosive", "stats.damage.explosive.liquid", "Liquid", "integer", 1, 1],
		["Explosive", "stats.damage.explosive.shrapnel", "Shrapnel", "integer", 1, 1],
		["Offense", "stats.damage.lasso", "Lasso", "integer", 0, 0],
		["Defense", "stats.defense.style", "Style", "integer", 2, 5],
		["Defense", "stats.defense.sand", "Sand", "integer", 1, 3],
		["Resistances", "stats.resistances.bleed", "Bleed", "percent", 0.0, 0.25],
		["Resistances", "stats.resistances.poison", "Poison", "percent", 0.0, 0.0],
		["Weapon", "weapon.weapon", "Family", "text", "", "rifle"],
		["Weapon", "weapon.baseDamage", "Damage", "integer", 0, 9],
		["Loadout", "beltSpace", "Belt space", "integer", 1, 2],
	]
	var rows = []
	for spec in specs:
		rows.append({
			"group": spec[0], "path": spec[1], "label": spec[2], "format": spec[3],
			"base": spec[4], "effective": spec[5],
		})
	return rows


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("CHECK FAILED: ", message)


func testUnavailableMalformedAndEmpty() -> void:
	print("--- Unavailable, malformed and empty states ---")
	provider.available = false
	provider.snapshot = makeSnapshot()
	await refreshTab()
	check(!tab.contentView.visible and tab.stateView.visible, "unavailable data shows the state view")
	check(tab.stateMessageLabel.get_parsed_text() == "Character data unavailable", "unavailable message is explicit")
	check(tab._memberButtons.is_empty() and tab.getFocusTarget() == null, "unavailable data leaves no focus target")

	provider.available = true
	provider.snapshot["members"] = "malformed"
	await refreshTab()
	check(tab.stateMessageLabel.get_parsed_text() == "Character data unavailable", "malformed members fail closed")

	var broken := Node.new()
	tab.characterProvider = broken
	provider.snapshot = makeSnapshot()
	await refreshTab()
	check(tab.stateMessageLabel.get_parsed_text() == "Character data unavailable", "provider without the read API fails closed")
	broken.free()
	tab.characterProvider = provider

	provider.snapshot = { "level": 3, "members": [] }
	await refreshTab()
	check(!tab.contentView.visible and tab.stateMessageLabel.get_parsed_text() == "No party members", "a valid empty party shows No party members")

	var partial = makeSnapshot()
	partial.members.append(null)
	partial.members.append({})
	partial.members.append({ "key": "Missing Identity" })
	provider.snapshot = partial
	await refreshTab()
	check(tab.contentView.visible and tab.memberButtons.get_child_count() == 2, "partially malformed snapshots keep valid members")

	provider.snapshot = { "level": 3, "members": [null, {}] }
	await refreshTab()
	check(tab.stateMessageLabel.get_parsed_text() == "Character data unavailable", "wholly invalid nonempty members fail closed")

	var badLevel = makeSnapshot()
	badLevel.level = "3"
	provider.snapshot = badLevel
	await refreshTab()
	check(tab.stateMessageLabel.get_parsed_text() == "Character data unavailable", "an invalid level fails closed")
	provider.snapshot = makeSnapshot()
	await refreshTab()


func testContentAndSelection() -> void:
	print("\n--- Content, identity, stat rows and member selection ---")
	provider.snapshot = makeSnapshot()
	await refreshTab()
	check(tab.contentView.visible and !tab.stateView.visible, "valid data shows content")
	check(tab.memberButtons.get_child_count() == 2, "one button per valid member is built")
	check(tab.nameText.get_parsed_text() == "Walker Langley", "identity shows the full actor name")
	check(tab.classLevelText.get_parsed_text() == "Gunslinger — Party level 3", "identity shows class and party level")
	check(tab.hpText.get_parsed_text() == "HP 12 / 15", "identity shows current and effective HP")
	check(!tab.downedText.visible, "a healthy member has no Downed state")
	check(tab.memberIcon.texture != null and tab.memberButtons.get_child(0).icon != null, "identity and selector use portrait art")

	check(_containerTexts(tab._statGroupRows) == ["Vitality", "Core", "Lead", "Explosive", "Offense", "Defense", "Resistances", "Weapon", "Loadout"], "stat group headers follow provider order")
	check(tab.statRows.get_child_count() == 27, "18 stat rows plus 9 group headers are rendered, got %d" % tab.statRows.get_child_count())
	check(_statText("maxHp", "base") == "12" and _statText("maxHp", "effective") == "15", "MxHP Base/Effective are rendered separately")
	check(_statText("stats.highTailin", "base") == "6" and _statText("stats.highTailin", "effective") == "7", "changed core stats show both values")
	check(_statText("stats.resistances.bleed", "effective") == "25%", "resistances render as whole percentages")
	check(_statText("weapon.weapon", "base") == "None" and _statText("weapon.weapon", "effective") == "rifle", "empty weapon family reads None")
	check(_statText("stats.damage.lasso", "effective") == "0", "legitimate zero stats render as zero")
	check(_statText("beltSpace", "base") == "1" and _statText("beltSpace", "effective") == "2", "belt space rows render class plus gear")
	check(tab.rodeoNameText.get_parsed_text() == "Leaders Duck", "Rodeo name is visible")
	check(str(tab.rodeoDescriptionText.get_parsed_text()).contains("Every other turn"), "full Rodeo description is visible")
	check(_containsText(tab.conditionRows, "No journey injuries or knockouts."), "clean members show the no-condition state")
	check(tab.modifierRows.get_child_count() == 2, "class and equipment modifiers render, got %d" % tab.modifierRows.get_child_count())
	check(_containsText(tab.modifierRows, "Explosive base") and _containsText(tab.modifierRows, "Belt space"), "modifier rows explain their effects")
	check(tab.getFocusTarget() == tab._memberButtons["walker"], "the selected member is the focus target")

	var callsBefore = provider.snapshotCalls
	tab._onMemberPressed("squeky")
	check(tab._selectedMemberKey == "squeky" and provider.snapshotCalls == callsBefore, "selection rerenders without another snapshot read")
	check(tab.downedText.visible and tab.hpText.get_parsed_text() == "HP 0 / 8", "downed identity updates on selection")
	check(tab.getFocusTarget() == tab._memberButtons["squeky"], "focus target follows selection")
	check(_containsText(tab.conditionRows, "Journey injury") and _containsText(tab.conditionRows, "2 Shootouts left"), "second member conditions render")

	provider.snapshot = makeSnapshot()
	await refreshTab()
	check(tab._selectedMemberKey == "squeky", "selection key survives a refresh")
	check(tab._memberButtons["squeky"].button_pressed, "selection is reflected by the button group")
	provider.snapshot = makeSnapshot()
	provider.snapshot.members.pop_back()
	await refreshTab()
	check(tab._selectedMemberKey == "walker", "a removed selection falls back to the first valid member")

func testRodeoAndModifierStates() -> void:
	print("\n--- Rodeo, condition and modifier inline states ---")
	var snapshot = makeSnapshot()
	snapshot.members[0].rodeo = null
	snapshot.members[0].modifiers = []
	provider.snapshot = snapshot
	await refreshTab()
	check(tab.rodeoNameText.get_parsed_text() == "No Rodeo" and tab.rodeoDescriptionText.get_parsed_text() == "No Rodeo assigned.", "no Rodeo has a distinct inline state")
	check(_containsText(tab.conditionRows, "No journey injuries or knockouts."), "no conditions has a distinct inline state")
	check(_containsText(tab.modifierRows, "No persistent modifiers."), "no modifiers has a distinct inline state")

	snapshot = makeSnapshot()
	snapshot.members[0].rodeo = { "key": "mystery", "available": false, "name": "mystery", "description": "" }
	provider.snapshot = snapshot
	await refreshTab()
	check(tab.rodeoNameText.get_parsed_text() == "mystery", "unknown Rodeo keys stay visible")
	check(tab.rodeoDescriptionText.get_parsed_text() == "Rodeo data unavailable.", "unknown Rodeo does not hide the sheet")

	snapshot = makeSnapshot()
	snapshot.members[0].modifiers = [
		{
			"kind": "injury", "sourceId": "injury", "name": "Journey injury", "slot": "",
			"effects": [{ "path": "maxHp", "label": "MxHP", "amount": -1, "format": "integer" }],
			"shootoutsLeft": 0, "detail": "Town entry resets journey injuries; camp items reduce them.",
		},
		{
			"kind": "knockout", "sourceId": "knockout:0", "name": "Knockout", "slot": "",
			"effects": [{ "path": "stats.sixShootin", "label": "Six Shootin'", "amount": -2, "format": "integer" }],
			"shootoutsLeft": 1, "detail": "",
		},
		{
			"kind": "class", "sourceId": "Gunslinger", "name": "Gunslinger", "slot": "",
			"effects": [{ "path": "class.explosiveBase", "label": "Explosive base", "amount": 2, "format": "integer" }],
			"shootoutsLeft": 0, "detail": "",
		},
		{
			"kind": "equipment", "sourceId": "belt_1", "name": "Fine Belt", "slot": "belt",
			"effects": [{ "path": "beltSpace", "label": "Belt space", "amount": 1, "format": "integer" }],
			"shootoutsLeft": 0, "detail": "",
		},
	]
	provider.snapshot = snapshot
	await refreshTab()
	check(tab.conditionRows.get_child_count() == 2, "injury and knockout render as condition rows")
	check(tab.modifierRows.get_child_count() == 2, "class and equipment render as modifier rows")
	check(_containsText(tab.conditionRows, "-1 MxHP") and _containsText(tab.conditionRows, "Town entry resets"), "injury row explains its effect")
	check(_containsText(tab.conditionRows, "-2 Six Shootin'") and _containsText(tab.conditionRows, "1 Shootout left"), "knockout row explains penalty and duration")
	check(_containsText(tab.modifierRows, "+2 Explosive base") and _containsText(tab.modifierRows, "+1 Belt space"), "modifier rows show signed effects")

	snapshot.members[0].modifiers = [
		{ "kind": "mystery", "name": "Unknown", "effects": [{ "path": "x", "label": "X", "amount": 1, "format": "integer" }] },
		{ "kind": "class", "name": "Broken", "effects": [{ "path": "x", "label": "X" }] },
		{
			"kind": "injury", "sourceId": "injury", "name": "Journey injury", "slot": "",
			"effects": [{ "path": "maxHp", "label": "MxHP", "amount": 0, "format": "integer" }],
			"shootoutsLeft": 0, "detail": "No MxHP lost yet",
		},
	]
	provider.snapshot = snapshot
	await refreshTab()
	check(tab.conditionRows.get_child_count() == 1 and tab.modifierRows.get_child_count() == 1, "malformed modifiers are skipped without hiding valid ones")
	check(_containsText(tab.conditionRows, "No MxHP lost yet"), "zero injury detail remains visible")
	check(_containsText(tab.modifierRows, "No persistent modifiers."), "missing valid modifiers fall back to the empty state")

func testMoveLoadout() -> void:
	print("\n--- Move loadout ---")
	provider.snapshot = makeSnapshot()
	provider.moveCalls.clear()
	provider.moveFailure = ""
	await refreshTab()
	check(tab.moveRows.get_child_count() == 3, "every granted Move renders a row, got %d" % tab.moveRows.get_child_count())
	var sharp: Button = _moveRow(tab, "Sharp Shot")
	var hold: Button = _moveRow(tab, "Hold Steady")
	var duck: Button = _moveRow(tab, "Duck Down")
	check(sharp != null and hold != null and duck != null, "the projection renders one row per grant")
	check(str(duck.text).contains("Inactive") and str(duck.text).contains("class"), "an inactive class grant renders with its origin: %s" % str(duck.text))
	check(str(sharp.text).contains("Active"), "an active grant renders as active")
	check(sharp.disabled, "the last offensive Move is disabled")
	check(!hold.disabled and !duck.disabled, "non-offensive actions stay actionable")

	provider.moveCalls.clear()
	duck.pressed.emit()
	await get_tree().process_frame
	check(provider.moveCalls.size() == 1 and provider.moveCalls[0][0] == "activate" and provider.moveCalls[0][2] == "Duck Down", "pressing a row sends one activate command: %s" % str(provider.moveCalls))
	check(str(_moveRow(tab, "Duck Down").text).contains("Active"), "the row re-renders after the command")
	check(str(_moveRow(tab, "Sharp Shot").text).contains("Active"), "the offensive Move stays active after the command")
	check(_moveRow(tab, "Sharp Shot").disabled, "the offensive Move stays protected after the command")

	provider.moveFailure = "move_cap_reached"
	var refused = _moveRow(tab, "Hold Steady")
	refused.disabled = false
	refused.pressed.emit()
	await get_tree().process_frame
	check(tab.moveFeedbackText.get_parsed_text().contains("limit"), "a refused command shows a readable reason: %s" % tab.moveFeedbackText.get_parsed_text())

	provider.snapshot = makeSnapshot()
	provider.snapshot.members[0].moveLoadout.managementAllowed = false
	await refreshTab()
	check(_moveRow(tab, "Hold Steady").disabled, "rows are disabled without the management policy")
	check(tab.moveFeedbackText.get_parsed_text().contains("unavailable"), "the tab explains the unavailable policy")

	provider.snapshot = makeSnapshot()
	provider.snapshot.members[0].erase("moveLoadout")
	await refreshTab()
	check(_containsText(tab.moveRows, "Move data unavailable"), "a missing projection renders the unavailable row")


func testFocusScrollAndLiveUpdates() -> void:
	print("\n--- Focus, scroll restoration and live provider signals ---")
	provider.snapshot = makeSnapshot()
	await refreshTab()
	tab._onMemberPressed("walker")
	tab._memberButtons["walker"].grab_focus()
	await get_tree().process_frame
	await refreshTab()
	check(get_viewport().gui_get_focus_owner() == tab._memberButtons["walker"], "member focus survives a refresh")
	check(tab._memberButtons["walker"].get_node(tab._memberButtons["walker"].focus_neighbor_right) == tab.statsScroll, "member right focus reaches Stats")
	check(tab.statsScroll.get_node(tab.statsScroll.focus_neighbor_left) == tab._memberButtons["walker"], "Stats left focus returns to the member")
	check(tab.statsScroll.get_node(tab.statsScroll.focus_neighbor_right) == tab.detailScroll, "Stats right focus reaches Details")
	check(tab.detailScroll.get_node(tab.detailScroll.focus_neighbor_left) == tab.statsScroll, "Details left focus returns to Stats")

	tab.statsScroll.scroll_vertical = 40
	await get_tree().process_frame
	await refreshTab()
	check(tab.statsScroll.scroll_vertical == 40, "stat scroll position survives a refresh, got %d" % tab.statsScroll.scroll_vertical)
	tab.statsScroll.grab_focus()
	await get_tree().process_frame
	await refreshTab()
	check(get_viewport().gui_get_focus_owner() == tab.statsScroll, "Stats focus survives a refresh")
	tab.detailScroll.grab_focus()
	await get_tree().process_frame
	await refreshTab()
	check(get_viewport().gui_get_focus_owner() == tab.detailScroll, "Details focus survives a refresh")

	tab.setTabActive(true)
	var callsBefore = provider.snapshotCalls
	provider.emitPartyChanged("")
	await get_tree().process_frame
	await get_tree().process_frame
	check(provider.snapshotCalls == callsBefore + 1, "partyChanged refreshes the active tab once")
	callsBefore = provider.snapshotCalls
	tab.setTabActive(true)
	tab.setTabActive(true)
	provider.emitPartyChanged("walker")
	await get_tree().process_frame
	await get_tree().process_frame
	check(provider.snapshotCalls == callsBefore + 1, "repeated activation does not duplicate provider connections")
	tab.setTabActive(false)
	callsBefore = provider.snapshotCalls
	provider.emitPartyChanged("")
	await get_tree().process_frame
	check(provider.snapshotCalls == callsBefore, "a hidden tab disconnects from provider signals")
	tab.setTabActive(true)


func testLongContentAndLayout() -> void:
	print("\n--- Long content and layout ---")
	var snapshot = makeSnapshot()
	var walker = snapshot.members[0]
	walker.actorName = "Storied Deadeye Walker Langley of the Endless Prairie"
	walker.characterClass = "Trail-Forged Gunslinger of the Western Reach"
	walker.rodeo.description = "A very long Rodeo description that must wrap across several lines without shrinking the shared pixel font or hiding any of its authored text."
	walker.modifiers[0].name = "Gunslinger Class Training of the Endless Prairie"
	walker.modifiers[0].effects[0].label = "Explosive base damage contribution"
	walker.modifiers[1].detail = "A long modifier explanation that must also wrap instead of clipping."
	provider.snapshot = snapshot
	await refreshTab()
	for _frame in 6:
		await get_tree().process_frame

	check(tab.nameText.get_parsed_text() == walker.actorName, "long identity names are not truncated")
	check(tab.nameText.autowrap_mode != TextServer.AUTOWRAP_OFF, "long identity names wrap")
	check(tab.rodeoDescriptionText.autowrap_mode != TextServer.AUTOWRAP_OFF, "long Rodeo descriptions wrap")
	check(tab.get_combined_minimum_size().x <= 570.0, "tab content minimum width fits the 560px Journal panel, got %s" % tab.get_combined_minimum_size())
	check(tab.get_combined_minimum_size().y <= 280.0, "tab content minimum height fits the Journal content area, got %s" % tab.get_combined_minimum_size())
	check(tab.hpText.custom_minimum_size.x >= 60.0, "HP keeps a readable fixed width")
	check(tab.hpText.size.x >= 60.0 and tab.hpText.size.y <= 20.0, "HP renders on one readable line, got %s" % tab.hpText.size)
	check(tab.get_node("ContentView/IdentityPanel").size.y <= 50.0, "identity header stays compact, got %s" % tab.get_node("ContentView/IdentityPanel").size)
	check(tab.statsScroll.size.y >= 100.0, "stat scroller keeps usable vertical space, got %s" % tab.statsScroll.size)
	check(tab.detailScroll.size.y >= 100.0, "detail scroller keeps usable vertical space, got %s" % tab.detailScroll.size)
	for path in tab._statValueLabels:
		for key in tab._statValueLabels[path]:
			check(tab._statValueLabels[path][key].custom_minimum_size.x >= 48.0, "numeric column keeps a usable fixed width")
	check(tab.find_child("EffectiveHeader", true, false).size.x >= 48.0 and tab.find_child("EffectiveHeader", true, false).size.y <= 20.0, "the Effective header fits on one row, got %s" % tab.find_child("EffectiveHeader", true, false).size)
	check(!_hasNativeLabel(tab), "dynamic rows use shared rich-text controls, not native Labels")
	check(!tab.has_method("equipItem") and !tab.has_method("dropItem") and !tab.has_method("applyLoot"), "the read-only tab exposes no mutation commands")

	snapshot = makeSnapshot()
	for rowValue in snapshot.members[0].statRows:
		if rowValue.path == "beltSpace":
			rowValue.base = null
			rowValue.effective = null
		if rowValue.path == "weapon.weapon":
			rowValue.base = null
	provider.snapshot = snapshot
	await refreshTab()
	check(_statText("beltSpace", "base") == "—" and _statText("beltSpace", "effective") == "—", "unavailable values render as an em dash")
	check(_statText("weapon.weapon", "base") == "—", "null text values are distinct from legitimately empty None")

func _statText(path: String, key: String) -> String:
	var labels = tab._statValueLabels.get(path, {})
	var label = labels.get(key, null)
	return label.get_parsed_text() if label != null else ""


func _containerTexts(labels: Array) -> Array:
	var texts = []
	for label in labels:
		texts.append(label.get_parsed_text())
	return texts


func _containsText(container: Node, needle: String) -> bool:
	for child in container.get_children():
		if child is RichTextLabel and str(child.get_parsed_text()).contains(needle):
			return true
	return false


func _moveRow(tab: Node, moveName: String) -> Button:
	for child in tab.moveRows.get_children():
		if child is Button and str(child.get_meta("move_name", "")) == moveName:
			return child
	return null


func _hasNativeLabel(node: Node) -> bool:
	if node is Label:
		return true
	for child in node.get_children():
		if _hasNativeLabel(child):
			return true
	return false
