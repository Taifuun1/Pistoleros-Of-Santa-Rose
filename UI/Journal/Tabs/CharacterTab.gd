extends JournalTab

## Journal Character tab (Docs/System Design/Journal/Character.md, patch 2): a
## read-only party character sheet. It reads an injectable provider on
## activation and party changes, never mutates domain state and never reaches
## into Inventory/Journal internals through node paths.

const TextScene = preload("res://UI/RichTextLabel Extended 8px/RichTextLabelExtended8px.tscn")
const PartyMemberArtScript = preload("res://UI/Journal/PartyMemberArt.gd")

const STATE_UNAVAILABLE := "Character data unavailable"
const STATE_NO_MEMBERS := "No party members"
const MEMBER_BUTTON_SIZE = Vector2(28, 28)
const STAT_VALUE_WIDTH = 48.0
const CONDITION_KINDS = ["injury", "knockout"]
const MODIFIER_KINDS = ["injury", "knockout", "class", "equipment"]
const STAT_FORMATS = ["integer", "percent", "text"]
## Move loadout (Docs/System Design/First Steps Implementation Plan.md, commit
## 11): the tab renders the provider's projection and sends activation commands
## back through it. It never owns the loadout.
const MOVE_CAP := 4
const MOVE_ORIGIN_LABELS = { "direct": "personal", "class": "class", "equipment": "equipment" }
const MOVE_REASON_TEXT = {
	"data_unavailable": "Move data unavailable.",
	"management_unavailable": "Loadout changes are unavailable here.",
	"unknown_member": "That party member is unavailable.",
	"unknown_move": "That Move is not authored.",
	"move_not_available": "That Move is not granted to this member.",
	"already_active": "That Move is already active.",
	"not_active": "That Move is not active.",
	"move_cap_reached": "Activated Move limit reached (4).",
	"last_offensive_move": "At least one offensive Move must stay active.",
	"invalid_loadout": "The stored loadout is unavailable.",
}

## Provider Node contract: isCharacterDataAvailable(),
## getCharacterJournalSnapshot(), and partyChanged(memberKey: String).
## Null resolves /root/Party.
var characterProvider: Node = null

var _snapshot: Dictionary = {}
var _membersByKey: Dictionary = {}
var _selectedMemberKey := ""
var _memberButtons: Dictionary = {}
var _statValueLabels: Dictionary = {}
var _statGroupRows: Array = []
var _connectedProvider: Node = null
var _pendingStatsScroll := 0
var _pendingDetailScroll := 0
var _focusWasInside := false
var _focusRegion := ""

@onready var contentView: Control = $ContentView
@onready var memberScroll: ScrollContainer = $ContentView/MemberScroll
@onready var memberButtons: Control = $ContentView/MemberScroll/MemberButtons
@onready var memberIcon: TextureRect = $ContentView/IdentityPanel/IdentityMargin/IdentityLayout/MemberIcon
@onready var nameText = $ContentView/IdentityPanel/IdentityMargin/IdentityLayout/IdentityTextBox/NameText
@onready var classLevelText = $ContentView/IdentityPanel/IdentityMargin/IdentityLayout/IdentityTextBox/ClassLevelText
@onready var hpText = $ContentView/IdentityPanel/IdentityMargin/IdentityLayout/HpText
@onready var downedText = $ContentView/IdentityPanel/IdentityMargin/IdentityLayout/DownedText
@onready var statsScroll: ScrollContainer = $ContentView/BodyColumns/StatsPanel/StatsMargin/StatsLayout/StatsScroll
@onready var statRows: Control = $ContentView/BodyColumns/StatsPanel/StatsMargin/StatsLayout/StatsScroll/StatRows
@onready var detailScroll: ScrollContainer = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll
@onready var rodeoNameText = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/RodeoNameText
@onready var rodeoDescriptionText = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/RodeoDescriptionText
@onready var conditionRows: Control = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/ConditionRows
@onready var modifierRows: Control = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/ModifierRows
@onready var movesHeader = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/MovesHeader
@onready var moveRows: Control = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/MoveRows
@onready var moveFeedbackText = $ContentView/BodyColumns/DetailPanel/DetailMargin/DetailLayout/DetailScroll/DetailContent/MoveFeedbackText
@onready var stateView: Control = $StateView
@onready var stateTabSprite: TabSprite = $StateView/StateLayout/StateTabSprite
@onready var stateMessageLabel = $StateView/StateLayout/StateMessageLabel


func _ready() -> void:
	stateTabSprite.tabIcon = tabIcon
	for label in [nameText, classLevelText, hpText, downedText, rodeoNameText, rodeoDescriptionText, moveFeedbackText, stateMessageLabel]:
		label.setRichTextLabel("")
	downedText.visible = false
	_showStateMessage(STATE_UNAVAILABLE)


func refreshTab() -> void:
	_captureViewState()
	_clearNormalized()
	var provider := _resolveCharacterProvider()
	if active:
		_connectProvider(provider)
	else:
		_disconnectProvider()
	if !_providerCanRead(provider):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	if !bool(provider.isCharacterDataAvailable()):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	var snapshotValue = provider.getCharacterJournalSnapshot()
	if !(snapshotValue is Dictionary) or !_normalizeSnapshot(snapshotValue):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	if _membersByKey.is_empty():
		_clearView()
		_showStateMessage(STATE_NO_MEMBERS)
		return
	_rebuildViews()
	_showContent()
	_restoreViewState()


func setTabActive(tabActive: bool) -> void:
	super.setTabActive(tabActive)
	if tabActive:
		_connectProvider(_resolveCharacterProvider())
	else:
		_disconnectProvider()


func getFocusTarget() -> Control:
	var selected: Button = _memberButtons.get(_selectedMemberKey, null)
	if selected != null and selected.is_visible_in_tree():
		return selected
	for memberKey in _memberButtons:
		var button: Button = _memberButtons[memberKey]
		if button.is_visible_in_tree():
			return button
	return null


func _exit_tree() -> void:
	_disconnectProvider()


func _resolveCharacterProvider() -> Node:
	if characterProvider != null:
		return characterProvider
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Party")


func _providerCanRead(provider: Node) -> bool:
	return provider != null and provider.has_method("isCharacterDataAvailable") and provider.has_method("getCharacterJournalSnapshot")


func _connectProvider(provider: Node) -> void:
	if _connectedProvider == provider:
		return
	_disconnectProvider()
	if provider == null:
		return
	if provider.has_signal("partyChanged"):
		var callback := Callable(self, "_onProviderChanged")
		if !provider.is_connected("partyChanged", callback):
			provider.connect("partyChanged", callback)
	_connectedProvider = provider


func _disconnectProvider() -> void:
	if _connectedProvider == null:
		return
	var callback := Callable(self, "_onProviderChanged")
	if _connectedProvider.has_signal("partyChanged") and _connectedProvider.is_connected("partyChanged", callback):
		_connectedProvider.disconnect("partyChanged", callback)
	_connectedProvider = null


func _onProviderChanged(_memberKey = "") -> void:
	if active:
		refreshTab()


func _clearNormalized() -> void:
	_snapshot = {}
	_membersByKey = {}

func _normalizeSnapshot(value: Dictionary) -> bool:
	if !(value.get("members", null) is Array):
		return false
	var levelValue = value.get("level", null)
	if typeof(levelValue) != TYPE_INT and typeof(levelValue) != TYPE_FLOAT:
		return false
	var normalized = []
	for index in value.members.size():
		var member = _normalizeMember(value.members[index])
		if member.is_empty():
			push_warning("Character tab: ignored invalid member at index %d." % index)
			continue
		normalized.append(member)
	if !value.members.is_empty() and normalized.is_empty():
		return false
	_snapshot = {
		"level": int(levelValue),
		"members": normalized,
	}
	_membersByKey = {}
	for member in normalized:
		_membersByKey[member.key] = member
	return true


func _normalizeMember(value) -> Dictionary:
	if !(value is Dictionary):
		return {}
	var member = value as Dictionary
	var key = str(member.get("key", ""))
	var actorName = str(member.get("actorName", ""))
	if key.is_empty() or actorName.is_empty():
		return {}
	if !(member.get("statRows", null) is Array) or !(member.get("modifiers", null) is Array):
		return {}
	var hp = _numberOrNull(member.get("hp", null))
	var maxHp = _numberOrNull(member.get("maxHp", null))
	if hp == null or maxHp == null:
		return {}
	var rows = []
	for rowValue in member.statRows:
		var row = _normalizeStatRow(rowValue)
		if row.is_empty():
			return {}
		rows.append(row)
	var modifiers = []
	for modifierValue in member.modifiers:
		var modifier = _normalizeModifier(modifierValue)
		if modifier.is_empty():
			continue
		modifiers.append(modifier)
	var rodeo = null
	if member.get("rodeo", null) != null:
		rodeo = _normalizeRodeo(member.rodeo)
		if rodeo.is_empty():
			return {}
	return {
		"key": key,
		"actorName": actorName,
		"characterClass": str(member.get("characterClass", "")),
		"downed": bool(member.get("downed", false)),
		"hp": int(hp),
		"maxHp": int(maxHp),
		"statRows": rows,
		"modifiers": modifiers,
		"rodeo": rodeo,
		"moveLoadout": _normalizeMoveLoadout(member.get("moveLoadout", null)),
	}


## Provider loadout projection, normalized for rendering. A missing or failed
## projection renders the unavailable state instead of invalidating the member.
func _normalizeMoveLoadout(value) -> Dictionary:
	if !(value is Dictionary):
		return {}
	var loadout = value as Dictionary
	if !bool(loadout.get("success", false)):
		return {}
	var available := []
	for entryValue in loadout.get("available", []):
		if !(entryValue is Dictionary):
			continue
		var entry: Dictionary = entryValue
		var entryName := str(entry.get("name", ""))
		if entryName.is_empty():
			continue
		available.append({
			"name": entryName,
			"origin": str(entry.get("origin", "")),
			"active": bool(entry.get("active", false)),
			"offensive": bool(entry.get("offensive", false)),
		})
	return {
		"success": true,
		"available": available,
		"used": int(loadout.get("used", 0)),
		"cap": int(loadout.get("cap", MOVE_CAP)),
		"managementAllowed": bool(loadout.get("managementAllowed", false)),
	}


func _normalizeStatRow(value) -> Dictionary:
	if !(value is Dictionary):
		return {}
	var row = value as Dictionary
	for field in ["group", "path", "label", "format"]:
		if !(row.get(field, null) is String):
			return {}
	if !STAT_FORMATS.has(str(row.format)) or !row.has("base") or !row.has("effective"):
		return {}
	return {
		"group": str(row.group),
		"path": str(row.path),
		"label": str(row.label),
		"format": str(row.format),
		"base": row.base,
		"effective": row.effective,
	}


func _normalizeModifier(value) -> Dictionary:
	if !(value is Dictionary):
		return {}
	var modifier = value as Dictionary
	var kind = str(modifier.get("kind", ""))
	if !MODIFIER_KINDS.has(kind):
		return {}
	if !(modifier.get("effects", null) is Array):
		return {}
	var effects = []
	for effectValue in modifier.effects:
		if !(effectValue is Dictionary):
			continue
		var effect = effectValue as Dictionary
		if !(effect.get("path", null) is String) or !(effect.get("label", null) is String):
			continue
		var amount = _numberOrNull(effect.get("amount", null))
		if amount == null:
			continue
		effects.append({
			"path": str(effect.path),
			"label": str(effect.label),
			"amount": amount,
			"format": str(effect.get("format", "integer")),
		})
	if effects.is_empty():
		return {}
	return {
		"kind": kind,
		"sourceId": str(modifier.get("sourceId", "")),
		"name": str(modifier.get("name", "")),
		"slot": str(modifier.get("slot", "")),
		"effects": effects,
		"shootoutsLeft": int(_numberOrZero(modifier.get("shootoutsLeft", 0))),
		"detail": str(modifier.get("detail", "")),
	}


func _normalizeRodeo(value) -> Dictionary:
	if !(value is Dictionary):
		return {}
	var key = str(value.get("key", ""))
	if key.is_empty():
		return {}
	var rodeoName = str(value.get("name", ""))
	if rodeoName.is_empty():
		rodeoName = key
	return {
		"key": key,
		"available": bool(value.get("available", false)),
		"name": rodeoName,
		"description": str(value.get("description", "")),
	}


func _numberOrNull(value):
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return value
	return null

func _rebuildViews() -> void:
	_reconcileSelection()
	_buildMemberButtons()
	_renderMember()
	_wireFocusNeighbours()


func _reconcileSelection() -> void:
	if _membersByKey.is_empty():
		_selectedMemberKey = ""
		return
	if !_membersByKey.has(_selectedMemberKey):
		_selectedMemberKey = str(_membersByKey.keys()[0])


func _selectedMember() -> Dictionary:
	return _membersByKey.get(_selectedMemberKey, {})


func _buildMemberButtons() -> void:
	_clearChildren(memberButtons)
	_memberButtons = {}
	var group := ButtonGroup.new()
	for memberKey in _membersByKey:
		var member = _membersByKey[memberKey]
		var actorName = str(member.get("actorName", memberKey))
		var button := Button.new()
		button.custom_minimum_size = MEMBER_BUTTON_SIZE
		button.icon = PartyMemberArtScript.textureForActorName(actorName)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.button_pressed = memberKey == _selectedMemberKey
		button.tooltip_text = actorName
		button.pressed.connect(_onMemberPressed.bind(str(memberKey)))
		memberButtons.add_child(button)
		_memberButtons[str(memberKey)] = button


func _renderMember() -> void:
	var member = _selectedMember()
	if member.is_empty():
		return
	_renderIdentity(member)
	_renderStats(member)
	_renderDetails(member)


func _renderIdentity(member: Dictionary) -> void:
	var actorName = str(member.get("actorName", member.key))
	memberIcon.texture = PartyMemberArtScript.textureForActorName(actorName)
	nameText.setRichTextLabel(_escape(actorName))
	var classText = str(member.get("characterClass", ""))
	if classText.is_empty():
		classText = "Class unavailable"
	classLevelText.setRichTextLabel(_escape("%s — Party level %d" % [classText, int(_snapshot.get("level", 1))]))
	hpText.setRichTextLabel("HP %d / %d" % [int(member.hp), int(member.maxHp)])
	downedText.visible = bool(member.get("downed", false))
	downedText.setRichTextLabel("Downed" if downedText.visible else "")


func _renderStats(member: Dictionary) -> void:
	_clearChildren(statRows)
	_statValueLabels = {}
	_statGroupRows = []
	var previousGroup = ""
	for rowValue in member.statRows:
		var row = rowValue as Dictionary
		var group = str(row.get("group", ""))
		if group != previousGroup:
			var groupLabel = _newTextLabel(_escape(group), "keyword")
			statRows.add_child(groupLabel)
			_statGroupRows.append(groupLabel)
			previousGroup = group
		var rowBox := HBoxContainer.new()
		rowBox.name = "Row_%s" % str(row.get("path", "")).replace(".", "_")
		rowBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rowBox.add_theme_constant_override("separation", 2)
		var label = _newTextLabel(_escape(str(row.get("label", ""))))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rowBox.add_child(label)
		var baseLabel = _newValueLabel()
		var effectiveLabel = _newValueLabel()
		baseLabel.setRichTextLabel(_formatValue(row.get("base", null), str(row.get("format", "integer"))))
		effectiveLabel.setRichTextLabel(_formatValue(row.get("effective", null), str(row.get("format", "integer"))))
		rowBox.add_child(baseLabel)
		rowBox.add_child(effectiveLabel)
		statRows.add_child(rowBox)
		_statValueLabels[str(row.get("path", ""))] = { "base": baseLabel, "effective": effectiveLabel }


func _newValueLabel():
	var label = TextScene.instantiate()
	label.custom_minimum_size = Vector2(STAT_VALUE_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _newTextLabel(labelText := "", colorKey = null):
	var label = TextScene.instantiate()
	if colorKey != null:
		label.setRichTextLabel(labelText, colorKey)
	else:
		label.setRichTextLabel(labelText)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _renderDetails(member: Dictionary) -> void:
	_clearChildren(conditionRows)
	_clearChildren(modifierRows)
	_renderRodeo(member.get("rodeo", null))
	var conditions = []
	var modifiers = []
	for modifierValue in member.modifiers:
		var modifier = modifierValue as Dictionary
		if CONDITION_KINDS.has(str(modifier.get("kind", ""))):
			conditions.append(modifier)
		else:
			modifiers.append(modifier)
	if conditions.is_empty():
		_addDetailRow(conditionRows, "No journey injuries or knockouts.", null)
	else:
		for modifier in conditions:
			_addDetailRow(conditionRows, _modifierText(modifier), "status")
	if modifiers.is_empty():
		_addDetailRow(modifierRows, "No persistent modifiers.", null)
	else:
		for modifier in modifiers:
			var colorKey = "offense" if str(modifier.kind) == "class" else "defense"
			_addDetailRow(modifierRows, _modifierText(modifier), colorKey)
	_renderMoves(member)


## Move loadout rows: one Activate/Deactivate action per granted Move, driven by
## the provider's projection (never a second loadout list in the tab).
func _renderMoves(member: Dictionary) -> void:
	_clearChildren(moveRows)
	moveFeedbackText.setRichTextLabel("")
	var loadoutValue = member.get("moveLoadout", null)
	var loadout: Dictionary = loadoutValue if loadoutValue is Dictionary else {}
	if !bool(loadout.get("success", false)):
		movesHeader.visible = true
		_addDetailRow(moveRows, "Move data unavailable.", null)
		return
	var availableValue = loadout.get("available", null)
	var available: Array = availableValue if availableValue is Array else []
	var managementAllowed := bool(loadout.get("managementAllowed", false))
	var activeCount := int(loadout.get("used", 0))
	var cap := int(loadout.get("cap", MOVE_CAP))
	var offensiveActive := 0
	for entryValue in available:
		if entryValue is Dictionary and bool(entryValue.get("active", false)) and bool(entryValue.get("offensive", false)):
			offensiveActive += 1
	movesHeader.visible = true
	if available.is_empty():
		_addDetailRow(moveRows, "No granted Moves.", null)
		return
	for entryValue in available:
		if entryValue is Dictionary:
			moveRows.add_child(_makeMoveRow(entryValue, managementAllowed, activeCount, cap, offensiveActive))
	if !managementAllowed:
		moveFeedbackText.setRichTextLabel(MOVE_REASON_TEXT["management_unavailable"], "defense")


func _makeMoveRow(entry: Dictionary, managementAllowed: bool, activeCount: int, cap: int, offensiveActive: int) -> Button:
	var moveName := str(entry.get("name", ""))
	var isActive := bool(entry.get("active", false))
	var origin := str(MOVE_ORIGIN_LABELS.get(str(entry.get("origin", "")), "granted"))
	var row := Button.new()
	row.text = ("Active: " if isActive else "Inactive: ") + moveName + " (" + origin + ")"
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.focus_mode = Control.FOCUS_ALL
	row.tooltip_text = row.text
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("move_name", moveName)
	row.pressed.connect(_onMoveRowPressed.bind(moveName))
	var reason := ""
	if !managementAllowed:
		reason = MOVE_REASON_TEXT["management_unavailable"]
	elif isActive and bool(entry.get("offensive", false)) and offensiveActive <= 1:
		reason = MOVE_REASON_TEXT["last_offensive_move"]
	elif !isActive and activeCount >= cap:
		reason = MOVE_REASON_TEXT["move_cap_reached"]
	if reason != "":
		row.disabled = true
		row.tooltip_text = reason
	return row


## One Activate/Deactivate command through the resolved provider; the provider's
## partyChanged signal owns the re-render.
func _onMoveRowPressed(moveName: String) -> void:
	var provider := _resolveCharacterProvider()
	if !_providerCanRead(provider) or !provider.has_method("getMoveLoadoutSnapshot") or _selectedMemberKey == "":
		moveFeedbackText.setRichTextLabel(MOVE_REASON_TEXT["data_unavailable"], "defense")
		return
	var loadout: Dictionary = provider.getMoveLoadoutSnapshot(_selectedMemberKey)
	if !bool(loadout.get("success", false)):
		moveFeedbackText.setRichTextLabel(MOVE_REASON_TEXT["data_unavailable"], "defense")
		return
	var isActive := false
	for entryValue in loadout.get("available", []):
		if entryValue is Dictionary and str(entryValue.get("name", "")) == moveName:
			isActive = bool(entryValue.get("active", false))
	var result := {}
	if isActive and provider.has_method("deactivateMove"):
		result = provider.deactivateMove(_selectedMemberKey, moveName)
	elif !isActive and provider.has_method("activateMove"):
		result = provider.activateMove(_selectedMemberKey, moveName)
	if !bool(result.get("success", false)):
		var reason := str(result.get("reason", ""))
		moveFeedbackText.setRichTextLabel(str(MOVE_REASON_TEXT.get(reason, "That change was refused.")), "defense")
		return
	refreshTab()


func _renderRodeo(rodeo) -> void:
	if rodeo == null:
		rodeoNameText.setRichTextLabel("No Rodeo")
		rodeoDescriptionText.setRichTextLabel("No Rodeo assigned.")
		return
	var rodeoName = str(rodeo.get("name", rodeo.get("key", "")))
	if !bool(rodeo.get("available", false)):
		rodeoNameText.setRichTextLabel(_escape(rodeoName))
		rodeoDescriptionText.setRichTextLabel("Rodeo data unavailable.")
		return
	var description = str(rodeo.get("description", ""))
	if description.strip_edges().is_empty():
		description = "No description."
	rodeoNameText.setRichTextLabel(_escape(rodeoName))
	rodeoDescriptionText.setRichTextLabel(_escape(description))


func _addDetailRow(container: Node, text: String, colorKey) -> void:
	var label = TextScene.instantiate()
	if colorKey != null:
		label.setRichTextLabel(text, colorKey)
	else:
		label.setRichTextLabel(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)


func _modifierText(modifier: Dictionary) -> String:
	var parts = []
	for effectValue in modifier.effects:
		var effect = effectValue as Dictionary
		parts.append("%s %s" % [
			_signedAmount(effect.get("amount", 0), str(effect.get("format", "integer"))),
			_escape(str(effect.get("label", ""))),
		])
	var text = "%s: %s" % [_escape(str(modifier.get("name", ""))), ", ".join(parts)]
	var shootoutsLeft = int(modifier.get("shootoutsLeft", 0))
	if shootoutsLeft > 0:
		text += " — %d Shootout%s left" % [shootoutsLeft, "" if shootoutsLeft == 1 else "s"]
	var detail = str(modifier.get("detail", ""))
	if !detail.is_empty():
		text += " — %s" % _escape(detail)
	return text


func _signedAmount(amount, format: String) -> String:
	if format == "percent":
		var percent = roundi(float(amount) * 100.0)
		return "%+d%%" % percent if percent != 0 else "0%"
	var number = int(amount)
	return "%+d" % number if number != 0 else "0"


func _formatValue(value, format: String) -> String:
	if value == null:
		return "—"
	match format:
		"percent":
			return "%d%%" % roundi(float(value) * 100.0)
		"text":
			var text = str(value)
			return "None" if text.is_empty() else _escape(text)
		_:
			return str(int(value))


func _escape(value: String) -> String:
	return value.replace("[", "[lb]")


func _numberOrZero(value) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return 0.0


func _showStateMessage(message: String) -> void:
	contentView.visible = false
	stateView.visible = true
	stateTabSprite.tabIcon = tabIcon
	stateMessageLabel.setRichTextLabel(message)


func _showContent() -> void:
	stateView.visible = false
	contentView.visible = true


func _clearView() -> void:
	_clearChildren(memberButtons)
	_clearChildren(statRows)
	_clearChildren(conditionRows)
	_clearChildren(modifierRows)
	_clearChildren(moveRows)
	_memberButtons = {}
	_statValueLabels = {}
	_statGroupRows = []
	_selectedMemberKey = ""
	nameText.setRichTextLabel("")
	classLevelText.setRichTextLabel("")
	hpText.setRichTextLabel("")
	downedText.setRichTextLabel("")
	downedText.visible = false
	rodeoNameText.setRichTextLabel("")
	rodeoDescriptionText.setRichTextLabel("")
	moveFeedbackText.setRichTextLabel("")


## Remove every child and delete it deferred: a refresh can run inside a child's
## own signal (a Move row press), and freeing the emitting node immediately is a
## locked-object error.
func _clearChildren(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _onMemberPressed(memberKey: String) -> void:
	if !_membersByKey.has(memberKey):
		return
	_selectedMemberKey = memberKey
	_renderMember()
	_wireFocusNeighbours()


func _wireFocusNeighbours() -> void:
	var selected: Button = _memberButtons.get(_selectedMemberKey, null)
	if selected == null:
		return
	selected.focus_neighbor_right = selected.get_path_to(statsScroll)
	selected.focus_neighbor_bottom = selected.get_path_to(statsScroll)
	statsScroll.focus_neighbor_left = statsScroll.get_path_to(selected)
	statsScroll.focus_neighbor_right = statsScroll.get_path_to(detailScroll)
	detailScroll.focus_neighbor_left = detailScroll.get_path_to(statsScroll)


func _captureViewState() -> void:
	_pendingStatsScroll = int(statsScroll.scroll_vertical)
	_pendingDetailScroll = int(detailScroll.scroll_vertical)
	_focusWasInside = _focusIsInsideTab()
	_focusRegion = ""
	if !_focusWasInside:
		return
	var focusOwner := get_viewport().gui_get_focus_owner()
	if focusOwner == null:
		return
	for memberKey in _memberButtons:
		if _memberButtons[memberKey] == focusOwner or _memberButtons[memberKey].is_ancestor_of(focusOwner):
			_focusRegion = "member"
			return
	if focusOwner == statsScroll or statsScroll.is_ancestor_of(focusOwner):
		_focusRegion = "stats"
	elif focusOwner == detailScroll or detailScroll.is_ancestor_of(focusOwner):
		_focusRegion = "detail"


func _restoreViewState() -> void:
	statsScroll.scroll_vertical = _pendingStatsScroll
	detailScroll.scroll_vertical = _pendingDetailScroll
	call_deferred("_applyPendingViewState")


func _applyPendingViewState() -> void:
	statsScroll.scroll_vertical = _pendingStatsScroll
	detailScroll.scroll_vertical = _pendingDetailScroll
	if !_focusWasInside or !active or !is_visible_in_tree():
		_focusWasInside = false
		return
	match _focusRegion:
		"member":
			var selected: Button = _memberButtons.get(_selectedMemberKey, null)
			if selected != null:
				selected.grab_focus()
				_focusWasInside = false
				return
		"stats":
			statsScroll.grab_focus()
			_focusWasInside = false
			return
		"detail":
			detailScroll.grab_focus()
			_focusWasInside = false
			return
	var target := getFocusTarget()
	if target != null:
		target.grab_focus()
	_focusWasInside = false


func _focusIsInsideTab() -> bool:
	if !is_inside_tree():
		return false
	var focusOwner := get_viewport().gui_get_focus_owner()
	return focusOwner != null and is_ancestor_of(focusOwner)
