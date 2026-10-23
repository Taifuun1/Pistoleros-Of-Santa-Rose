extends Control

signal move
signal item
signal reposition(direction)
signal flee

const TURN_ORDER_PATH = "MarginContainer/VBoxContainer/MarginContainer/PanelContainer/Turn Order"

## The Acts row of the player panel holds the acting character's act icons:
## moves/reposition choices after the Moves icon, belt items after the Belt icon.
const ACTS_PATH = "MarginContainer/VBoxContainer/GridContainer/PanelContainer/MarginContainer/VBoxContainer/Acts"

## Chamber quality icons and the current-Chamber underline from Assets/Stats,
## rendered into the pre-existing MagazineContainer/Magazine rows of the stats
## panels (one slot VBoxContainer with an icon TextureRect per Chamber).
const MAGAZINE_ICONS = [
	preload("res://Assets/Stats/HitrateMiss.png"),
	preload("res://Assets/Stats/HitrateGraze.png"),
	preload("res://Assets/Stats/HitrateHit.png"),
	preload("res://Assets/Stats/HitrateCriticalHit.png"),
]
const MAGAZINE_NAMES = ["Miss", "Graze", "Hit", "Critical Hit"]
const MAGAZINE_LINE = preload("res://Assets/Stats/CylinderLine.png")

## Effect icons from Assets/Effects for the Effects boxes of the stat panels;
## types without art fall back to the placeholder icon.
const EFFECT_ICONS = {
	"bleed": preload("res://Assets/Effects/Bleed.png"),
	"poison": preload("res://Assets/Effects/Poison.png"),
	"mark": preload("res://Assets/Effects/Mark.png"),
	"damage_type_mark": preload("res://Assets/Effects/Mark.png"),
	"silence": preload("res://Assets/Effects/Silence.png"),
	"taunt": preload("res://Assets/Effects/Taunt.png"),
}
const EFFECT_PLACEHOLDER_ICON = preload("res://Assets/Icons/PlaceholderIcon.png")

## The shared tooltip node (UI/Tooltip/Tooltip.tscn): all runtime-created icons
## show their info through it instead of built-in control tooltips.
const TOOLTIP_PATH = "Tooltip/Tooltip"


## Wires a control's hover to the shared Tooltip node. Safe to call repeatedly
## on persistent controls (e.g. the magazine slots): the signals are connected
## once and re-attaching only updates the shown title/text.
func attachTooltip(control: Control, title: String, text: String) -> void:
	control.set_meta("tooltipTitle", title)
	control.set_meta("tooltipText", text)
	if control.has_meta("tooltipWired"):
		return
	control.set_meta("tooltipWired", true)
	var tooltip = get_node_or_null(TOOLTIP_PATH)
	if tooltip == null:
		return
	control.mouse_entered.connect(_showSharedTooltip.bind(control))
	control.mouse_exited.connect(tooltip.hideTooltip)

func _showSharedTooltip(control: Control) -> void:
	var tooltip = get_node_or_null(TOOLTIP_PATH)
	if tooltip == null:
		return
	tooltip.updateTooltip(control.get_meta("tooltipTitle"), control.get_meta("tooltipText"))
	tooltip.showTooltip()

var actOpen = null
var playerHasControl = false
var turnOrderNames = []


## The Round order renders into the scene's Turn Order container (the
## TurnOrderStrip script is attached to that node in ShootoutUI.tscn).
func setTurnOrder(actorNames: Array) -> void:
	turnOrderNames = actorNames
	get_node(TURN_ORDER_PATH).setTurnOrder(actorNames)


func setHoveredActorStats(characterData, characterStats) -> void:
	var panel = $MarginContainer/VBoxContainer/GridContainer/PanelContainer3
	panel.visible = true
	var content = panel.get_node("MarginContainer/VBoxContainer")
	content.get_node("HBoxContainer/RichTextLabelExtended").setRichTextLabel(characterData.Name)
	content.get_node("HBoxContainer/HBoxContainer/RichTextLabelExtended3").setRichTextLabel(str(characterData.HP))
	content.get_node("RodeoContainer/HoveredRodeo").setRichTextLabel(characterData.get("Rodeo", "-"))
	for stat in characterStats:
		var statNode = content.get_node_or_null("HBoxContainer3/Stats/{stat}Container/{stat}".format({ "stat": stat }))
		if statNode != null:
			statNode.setRichTextLabel(str(characterStats[stat]))
	showCylinder(content, characterData.get('Cylinder', []), int(characterData.get('ChamberIndex', 0)), "HBoxContainer3/MagazineContainer/Magazine")
	showEffects(content, characterData.get('Effects', []))

func clearHoveredActorStats() -> void:
	var panel = $MarginContainer/VBoxContainer/GridContainer/PanelContainer3
	var content = panel.get_node("MarginContainer/VBoxContainer")
	content.get_node("HBoxContainer/RichTextLabelExtended").setRichTextLabel("-")
	content.get_node("HBoxContainer/HBoxContainer/RichTextLabelExtended3").setRichTextLabel("-")
	content.get_node("RodeoContainer/HoveredRodeo").setRichTextLabel("-")
	for stat in ["SixShootin", "HighTailin", "Taffyin", "Revolver", "Rifle", "Shotgun"]:
		content.get_node("HBoxContainer3/Stats/{stat}Container/{stat}".format({ "stat": stat })).setRichTextLabel("-")

func setPlayerCharacterStats(characterData, characterStats) -> void:
	var content = get_node("MarginContainer/VBoxContainer/GridContainer/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer")
	content.get_node("HBoxContainer/VBoxContainer/RichTextLabelExtended8px").setRichTextLabel(characterData.Name)
	content.get_node("HBoxContainer/VBoxContainer/HBoxContainer/RichTextLabelExtended8px3").setRichTextLabel(characterData.get("Rodeo", "-"))
	content.get_node("HBoxContainer/VBoxContainer4/HPContainer/HP").setRichTextLabel(str(characterData.HP))
	for stat in characterStats:
		var statNode = content.get_node_or_null("HBoxContainer2/Stats/{stat}Container/{stat}".format({ "stat": stat }))
		if statNode != null:
			statNode.setRichTextLabel(str(characterStats[stat]))
	showCylinder(content, characterData.get('Cylinder', []), int(characterData.get('ChamberIndex', 0)), "HBoxContainer2/MagazineContainer/Magazine")
	showEffects(content, characterData.get('Effects', []))

## Tooltip for act buttons: description, range and the usability reason.
func actTooltip(actName: String, actType: String, info: Dictionary) -> String:
	var data = {}
	if actType == "Moves":
		data = Shootout.movesData.get(actName, {})
	elif actType == "Items":
		data = Shootout.itemsData.get(actName, {})
	var lines = []
	if data.get("description", "") != "":
		lines.append(data.description)
	if data.has("positions") and data.positions.has("actorUser"):
		lines.append("Usable from position {columns}".format({ "columns": data.positions.actorUser }))
	if info.get("reason", "") != "":
		lines.append(info.reason)
	return "\n".join(lines)

## Act icons in the pre-existing Acts row of the player panel: one ShootoutAct
## icon per available act (Docs/System Design/Shootout/Shootout UI.md). There
## is no act menu: the icons render whenever they are set and stay visible
## until the turn ends. Moves/reposition choices and belt items each have
## their own group in the row.
func setPlayerCharacterActs(acts: Array, actType: String, usability := {}) -> void:
	var actNode = load("res://Shootout/UI/ShootoutAct.tscn")
	var containerName = "Items" if actType == Shootout.ACT_TYPE_ITEMS else "Moves"
	var row = get_node(ACTS_PATH).get_node(containerName)
	for actButton in row.get_children():
		# Detach immediately so the group rebuilds within the same frame.
		actButton.queue_free()
		row.remove_child(actButton)
	for actName in acts:
		var newAct = actNode.instantiate()
		var info = usability.get(actName, { "usable": true, "reason": "" })
		newAct.init(actName, actType, info.get("usable", true))
		row.add_child(newAct)
		attachTooltip(newAct, actName, actTooltip(actName, actType, info))
		newAct.actClicked.connect(func():
			if actType == Shootout.ACT_TYPE_ITEMS:
				item.emit(actName)
			elif actType == Shootout.ACT_TYPE_MOVES:
				move.emit(actName)
			elif actType == Shootout.ACT_TYPE_REPOSITION:
				reposition.emit(actName.to_lower())
		)
	if actType == Shootout.ACT_TYPE_MOVES:
		_renderUtilityActs()

## Clearing the act icons (turn over, or the reposition picker closed).
func hideActsPanel() -> void:
	actOpen = null
	var actsRow = get_node(ACTS_PATH)
	for containerName in ["Moves", "Items"]:
		var row = actsRow.get_node_or_null(containerName)
		if row == null:
			continue
		for actButton in row.get_children():
			actButton.queue_free()
			row.remove_child(actButton)
	for iconName in ["Move", "Flee"]:
		var icon = actsRow.get_node_or_null(iconName)
		if icon != null:
			icon.queue_free()
			actsRow.remove_child(icon)

## Utility acts with no data entry render as the last icons of the Acts row:
## the Move icon toggles the reposition direction picker, Flee ends the fight.
const UTILITY_ACTS = [
	{ "name": "Move", "icon": preload("res://Assets/Icons/BootsIcon.png"), "tooltip": "Move forward or backward" },
	{ "name": "Flee", "icon": preload("res://Assets/Icons/HighTailinIcon.png"), "tooltip": "Flee the fight" },
]


func _renderUtilityActs() -> void:
	var actsRow = get_node(ACTS_PATH)
	for utilityAct in UTILITY_ACTS:
		var previous = actsRow.get_node_or_null(utilityAct.name)
		if previous != null:
			previous.queue_free()
			actsRow.remove_child(previous)
		var icon = load("res://Shootout/UI/ShootoutAct.tscn").instantiate()
		icon.name = utilityAct.name
		icon.init(utilityAct.name, Shootout.ACT_TYPE_REPOSITION, true)
		icon.texture = utilityAct.icon
		attachTooltip(icon, utilityAct.name, utilityAct.tooltip)
		if utilityAct.name == "Move":
			icon.actClicked.connect(_on_move_act_clicked)
		else:
			icon.actClicked.connect(func(): flee.emit())
		actsRow.add_child(icon)

func _on_move_act_clicked() -> void:
	if actOpen == "reposition":
		actOpen = null
		_setRepositionPickerVisible(false)
		return
	actOpen = "reposition"
	_setRepositionPickerVisible(true)

## The direction picker renders into the Moves group; clicking a direction
## emits reposition (the reposition handler clears the whole acts row).
func _setRepositionPickerVisible(pickerVisible: bool) -> void:
	var movesGroup = get_node(ACTS_PATH).get_node_or_null("Moves")
	if movesGroup == null:
		return
	if !pickerVisible:
		for directionAct in movesGroup.get_children():
			if directionAct.actName in ["Forward", "Backward"]:
				directionAct.queue_free()
				movesGroup.remove_child(directionAct)
		return
	for direction in ["Forward", "Backward"]:
		var directionAct = load("res://Shootout/UI/ShootoutAct.tscn").instantiate()
		directionAct.init(direction, Shootout.ACT_TYPE_REPOSITION, true)
		attachTooltip(directionAct, direction, actTooltip(direction, Shootout.ACT_TYPE_REPOSITION, {}))
		directionAct.actClicked.connect(_on_direction_act_clicked.bind(direction))
		movesGroup.add_child(directionAct)

func _on_direction_act_clicked(direction: String) -> void:
	reposition.emit(direction.to_lower())

## Flee is greyed out while the fight kind does not allow it yet.
func setFleeEnabled(enabled: bool) -> void:
	var fleeIcon = get_node(ACTS_PATH).get_node_or_null("Flee")
	if fleeIcon != null:
		fleeIcon.modulate = Color(1, 1, 1) if enabled else Color(0.5, 0.5, 0.5, 0.7)

## Cylinder display in the pre-existing MagazineContainer/Magazine row of a
## stats panel: one Chamber icon per slot (Docs/System Design/Shootout/Shootout
## UI.md), the current Chamber marked with the CylinderLine underline, unused
## slots hidden. Special Chambers (reload/jammed) have no icons yet.
func showCylinder(content: Node, cylinder: Array, chamberIndex: int, magazinePath: String) -> void:
	if content == null:
		return
	var magazine = content.get_node_or_null(magazinePath)
	if magazine == null:
		return
	var slots = magazine.get_children()
	for i in slots.size():
		var slot = slots[i]
		if i >= cylinder.size():
			slot.visible = false
			continue
		slot.visible = true
		var icon: TextureRect = slot.get_node("TextureRect")
		var chamber = cylinder[i]
		if chamber is String:
			icon.texture = null
			attachTooltip(icon, str(chamber).capitalize(), str(chamber))
		else:
			var quality = clampi(int(chamber), 0, 3)
			icon.texture = MAGAZINE_ICONS[quality]
			attachTooltip(icon, MAGAZINE_NAMES[quality], MAGAZINE_NAMES[quality])
		var line: TextureRect = slot.get_node_or_null("CylinderLine")
		if line != null:
			line.texture = MAGAZINE_LINE if i == chamberIndex else null

## Effect icons in the pre-existing Effects box of a stats panel: one icon per
## effect type from effectManager.displayEffects() (stack counts next to the
## icon and in the tooltip; Docs/System Design/Shootout/Shootout UI.md).
##
## The box keeps a fixed minimum size (icon entry at its widest/ tallest):
## letting the minimum shrink to the empty "-" label and grow back per entry
## trips a Godot layout oscillation (known engine bug: non-converging fit_content
## container relayout) that overflows the deferred-call queue and hard-crashes
## the engine ("Object was deleted while awaiting a callback" spam + segfault).
const EFFECTS_BOX_MIN_SIZE = Vector2(44, 24)

func showEffects(content: Node, effectLines: Array) -> void:
	if content == null:
		return
	var effects = content.get_node_or_null("HBoxContainer/Effects")
	if effects == null:
		return
	effects.custom_minimum_size = EFFECTS_BOX_MIN_SIZE
	for child in effects.get_children():
		# Detach immediately so the box rebuilds within the same frame.
		child.queue_free()
		effects.remove_child(child)
	if effectLines.is_empty():
		var empty = Label.new()
		empty.text = "-"
		effects.add_child(empty)
		return
	for effectLine in effectLines:
		# Lines are "{type}" or "{type} x{count}" (type names have no spaces).
		var parts = str(effectLine).split(" x")
		var effectType = parts[0]
		var entry = HBoxContainer.new()
		entry.name = effectType
		entry.add_theme_constant_override("separation", 2)
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.texture = EFFECT_ICONS.get(effectType, EFFECT_PLACEHOLDER_ICON)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry.add_child(icon)
		attachTooltip(icon, effectType.capitalize(), str(effectLine))
		if parts.size() > 1:
			var stacks = Label.new()
			stacks.name = "Stacks"
			stacks.text = "x" + parts[1]
			entry.add_child(stacks)
		effects.add_child(entry)

## Fight start banner with the flavor name (auto-fades).
func showBanner(bannerText: String) -> void:
	var label = Label.new()
	label.name = "FightBanner"
	label.text = bannerText
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(label.queue_free)

## End screen: outcome and loot summary.
func showEndScreen(results: Dictionary) -> void:
	var label = Label.new()
	label.name = "EndScreen"
	var loot = results.get("loot", {})
	var lines = [str(results.get("outcome", "")).capitalize()]
	if loot.get("money", 0) > 0 or !loot.get("items", []).is_empty():
		lines.append("Loot: {money} cash, {items} items".format({
			"money": loot.get("money", 0), "items": loot.get("items", []).size()
		}))
	label.text = String(" | ").join(lines)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)
