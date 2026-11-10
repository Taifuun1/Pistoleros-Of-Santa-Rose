extends Control

signal move
signal item
signal reposition(direction)
signal flee
## The Move icon toggled the reposition picker open/closed; Shootout marks the
## reachable destination columns in the field while it is open.
signal repositionPicker(open)
## The result screen was acknowledged. Shootout must not advance/emit its end
## signal until this fires (Docs/System Design/Journal/Inventory and Equipment.md).
signal endScreenContinuePressed

const TURN_ORDER_PATH = "MarginContainer/VBoxContainer/MarginContainer/PanelContainer/Turn Order"

## The Acts row of the player panel holds the acting character's act icons:
## moves/reposition choices after the Moves icon, belt items after the Belt icon.
const ACTS_PATH = "MarginContainer/VBoxContainer/GridContainer/PanelContainer/MarginContainer/VBoxContainer/Acts"

## The two stats panels of the HUD (player + hovered actor). Their content must
## never be taller than the panel: a panel that is even a pixel short makes the
## containers squeeze a row below its minimum and grow it back on the next layout
## pass, and that oscillation overflows the deferred-call queue and hard-crashes
## the engine ("Object was deleted while awaiting a callback" spam + segfault).
## Hovering a damaged actor (one-digit HP) and crossing into a neighbour (two
## digits) changes the content just enough to start it. The title row keeps a
## fixed single-line height (_setPanelText), effects grow horizontally instead of
## vertically (EFFECTS_BOX_MIN_SIZE), and the icons never derive a minimum size
## from the rect the grid assigns (_pinStatsPanelIcons).
const STATS_PANEL_PATHS = [
	"MarginContainer/VBoxContainer/GridContainer/PanelContainer",
	"MarginContainer/VBoxContainer/GridContainer/PanelContainer3",
]

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
## Shared rich-text scene for all runtime Shootout text (Journal UI rule: no
## native Label nodes for presentation).
const TextScene = preload("res://UI/RichTextLabel Extended 8px/RichTextLabelExtended8px.tscn")

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
## The armed act's name ("" = none): its act icon keeps the selected tint
## until another act is armed or the panel clears.
var selectedActName = ""

## The fight background (CanvasLayer below the world) defocuses while an act
## plays so the zoomed-in fighters read clearly — the Darkest-Dungeon style act
## focus (Docs/System Design/Shootout/Shootout UI.md). The material is a
## duplicate of Shaders/Blur.tres: the focus manager tweens its parameters, and
## tweening the cached resource would leak the blur into every other user of it.
const BACKGROUND_PATH = "BackgroundLayer/Background"
const BlurMaterial = preload("res://Shaders/Blur.tres")

var backgroundBlur = null


func _ready() -> void:
	_pinStatsPanelIcons()
	var background = get_node_or_null(BACKGROUND_PATH)
	if background == null:
		return
	backgroundBlur = BlurMaterial.duplicate()
	background.material = backgroundBlur

## Stat/move icons sit in pinned boxes, but their expand_mode derives the
## minimum size from the rect the container assigned (FIT_WIDTH / FIT_HEIGHT
## keep the aspect ratio), so every grid re-split recomputes their minimum
## height. Ignoring the texture size leaves the pinned box in charge, exactly
## like the Turn order strip's portraits.
func _pinStatsPanelIcons() -> void:
	for panelPath in STATS_PANEL_PATHS:
		var panel = get_node_or_null(panelPath)
		if panel != null:
			_pinIconSizes(panel)

func _pinIconSizes(node: Node) -> void:
	if node is TextureRect and node.expand_mode >= TextureRect.EXPAND_FIT_WIDTH:
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	for child in node.get_children():
		_pinIconSizes(child)

## The hovered panel's title row has room for one line, but the shared 12px
## label reserves 22px of height and draws its text 5px down, which pushed the
## panel's content past the height the grid gives it. Content taller than the
## panel makes the containers squeeze a row below its minimum and grow it back
## on the next pass, forever; that oscillation overflows the deferred-call queue
## and hard-crashes the engine (see STATS_PANEL_PATHS). These labels get a fixed
## single-line height with a smaller text offset, and a width measured from the
## string so the name and HP still sit side by side instead of overlapping.
const TITLE_ROW_HEIGHT = 16.0

func _setPanelText(label: RichTextLabel, value) -> void:
	label.setRichTextLabel(str(value))
	label.fit_content = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.offset_transform_position = Vector2(2, 2)
	var font = label.get_theme_font("normal_font")
	var fontSize = label.get_theme_font_size("normal_font_size")
	var width = 0.0
	for line in label.get_parsed_text().split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x)
	label.custom_minimum_size = Vector2(ceilf(maxf(width, 6.0)) + 2.0, TITLE_ROW_HEIGHT)

## The placeholder panel is taller than the real stats, so the whole stats row
## lost a few pixels the first time an actor was hovered (and never grew back).
## Reserve that height once, before the first real content replaces the
## placeholder; the real content is shorter, so nothing gets squeezed.
var _hoveredHeightReserved := false

func _reserveHoveredPanelHeight(panel: Control) -> void:
	if _hoveredHeightReserved:
		return
	_hoveredHeightReserved = true
	panel.custom_minimum_size.y = maxf(panel.custom_minimum_size.y, panel.get_combined_minimum_size().y)

## Blur/dim strength of the fight background: 0.0 is the untouched image.
func setBackgroundFocus(amount: float) -> void:
	if backgroundBlur == null:
		return
	backgroundBlur.set_shader_parameter("amount", amount)
	backgroundBlur.set_shader_parameter("dim", amount * 0.16)

func getBackgroundFocus() -> float:
	if backgroundBlur == null:
		return 0.0
	return float(backgroundBlur.get_shader_parameter("amount"))


## The Round order renders into the scene's Turn Order container (the
## TurnOrderStrip script is attached to that node in ShootoutUI.tscn).
func setTurnOrder(actorNames: Array) -> void:
	turnOrderNames = actorNames
	get_node(TURN_ORDER_PATH).setTurnOrder(actorNames)


func setHoveredActorStats(characterData, characterStats) -> void:
	var panel = $MarginContainer/VBoxContainer/GridContainer/PanelContainer3
	_reserveHoveredPanelHeight(panel)
	panel.visible = true
	var content = panel.get_node("MarginContainer/VBoxContainer")
	_setPanelText(content.get_node("HBoxContainer/RichTextLabelExtended"), characterData.Name)
	_setPanelText(content.get_node("HBoxContainer/HBoxContainer/RichTextLabelExtended3"), characterData.HP)
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
	_setPanelText(content.get_node("HBoxContainer/RichTextLabelExtended"), "-")
	_setPanelText(content.get_node("HBoxContainer/HBoxContainer/RichTextLabelExtended3"), "-")
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
				setActSelected(actName)
				item.emit(actName)
			elif actType == Shootout.ACT_TYPE_MOVES:
				setActSelected(actName)
				move.emit(actName)
			elif actType == Shootout.ACT_TYPE_REPOSITION:
				reposition.emit(actName.to_lower())
		)
	if actType == Shootout.ACT_TYPE_MOVES:
		_renderUtilityActs()


## Marks the armed act's icon with the selected tint and clears the previous
## one, so the player can see which act is waiting for its target ("" clears).
func setActSelected(actName: String) -> void:
	selectedActName = actName
	var actsRow = get_node(ACTS_PATH)
	for containerName in ["Moves", "Items"]:
		var row = actsRow.get_node_or_null(containerName)
		if row == null:
			continue
		for actButton in row.get_children():
			actButton.setSelected(actButton.actName == actName)
	for iconName in ["Move", "Flee"]:
		var icon = actsRow.get_node_or_null(iconName)
		if icon != null:
			icon.setSelected(icon.actName == actName)

## Clearing the act icons (turn over, or the reposition picker closed).
func hideActsPanel() -> void:
	actOpen = null
	selectedActName = ""
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
		setActSelected("")
		repositionPicker.emit(false)
		return
	actOpen = "reposition"
	_setRepositionPickerVisible(true)
	setActSelected("Move")
	repositionPicker.emit(true)

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
		fleeIcon.setEnabled(enabled)

## Marks the picker's directions usable/blocked (Shootout calls this when the
## picker opens; blocked directions are greyed out instead of silently
## doing nothing on click).
func setDirectionsUsable(usability: Dictionary) -> void:
	var movesGroup = get_node(ACTS_PATH).get_node_or_null("Moves")
	if movesGroup == null:
		return
	for directionAct in movesGroup.get_children():
		if directionAct.actName in usability:
			directionAct.setEnabled(usability[directionAct.actName])

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
## The box is a horizontal row of fixed-size entries: stacking entries
## vertically made the title row taller with every additional effect until the
## panel's content no longer fit, and a squeezed row is what oscillates. Keeping
## the minimum pinned also stops the empty "-" placeholder from resizing the row
## on every hover rebuild.
const EFFECTS_BOX_MIN_SIZE = Vector2(30, 18)
## Guards against re-entrant rebuilds: a layout update during the rebuild must
## never call back into showEffects on the same frame.
var _rebuildingEffects := false

func showEffects(content: Node, effectLines: Array) -> void:
	if content == null or _rebuildingEffects:
		return
	var effects = content.get_node_or_null("HBoxContainer/Effects")
	if effects == null:
		return
	var normalized = []
	for line in effectLines:
		normalized.append(str(line))
	# Repeated hover enter/exit events with unchanged effects must not rebuild
	# (and relayout) this box.
	if content.has_meta("effectsLines") and content.get_meta("effectsLines") == normalized:
		return
	_rebuildingEffects = true
	content.set_meta("effectsLines", normalized)
	effects.custom_minimum_size = EFFECTS_BOX_MIN_SIZE
	for child in effects.get_children():
		# Detach immediately so the box rebuilds within the same frame.
		child.queue_free()
		effects.remove_child(child)
	if normalized.is_empty():
		var empty = _effectText("-")
		empty.name = "Empty"
		empty.custom_minimum_size = EFFECTS_BOX_MIN_SIZE
		effects.add_child(empty)
		_rebuildingEffects = false
		return
	for effectLine in normalized:
		# Lines are "{type}" or "{type} x{count}" (type names have no spaces).
		var parts = effectLine.split(" x")
		var effectType = parts[0]
		var entry = HBoxContainer.new()
		entry.name = effectType
		entry.add_theme_constant_override("separation", 2)
		# Pinned entry size keeps the box's minimum independent of its contents;
		# a content-derived minimum here trips a non-converging fit_content
		# relayout that overflows the deferred-call queue and crashes the engine.
		entry.custom_minimum_size = EFFECTS_BOX_MIN_SIZE
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.texture = EFFECT_ICONS.get(effectType, EFFECT_PLACEHOLDER_ICON)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry.add_child(icon)
		attachTooltip(icon, effectType.capitalize(), effectLine)
		if parts.size() > 1:
			var stacks = _effectText("x" + parts[1])
			stacks.name = "Stacks"
			entry.add_child(stacks)
		effects.add_child(entry)
	_rebuildingEffects = false

## Inline effect text from the shared rich-text scene. It deliberately has no
## fit_content and no wrapping: its minimum size must be a constant derived from
## the string, never from an assigned width, or the stats panel's pinned Effects
## box enters a non-converging relayout.
func _effectText(value: String) -> RichTextLabel:
	var label = TextScene.instantiate() as RichTextLabel
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(maxi(6, value.length() * 6), 10)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.setRichTextLabel(value)
	return label

## Fight start banner with the flavor name (auto-fades).
func showBanner(bannerText: String) -> void:
	var label = TextScene.instantiate()
	label.name = "FightBanner"
	label.setRichTextLabel(bannerText)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(label.queue_free)

## End screen: delegates to the static ShootoutEndScreen scene node, which owns
## the layout, text updates and one-shot acknowledgment state.
func showEndScreen(results: Dictionary) -> void:
	var endScreen = get_node_or_null("EndScreen")
	if endScreen != null:
		endScreen.showResults(results)


func hideEndScreen() -> void:
	var endScreen = get_node_or_null("EndScreen")
	if endScreen != null:
		endScreen.hideResults()


func _on_end_screen_continue_pressed() -> void:
	endScreenContinuePressed.emit()
