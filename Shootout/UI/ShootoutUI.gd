extends Control

signal attack
signal move
signal item
signal reposition(direction)
signal flee
signal moveActsRequested
signal itemActsRequested

const TurnOrderStripScript = preload("res://Shootout/UI/TurnOrderStrip.gd")
const CylinderRowScript = preload("res://Shootout/UI/CylinderRow.gd")

var actOpen = null
var playerHasControl = false
var turnOrderStrip = null


func _ready() -> void:
	# Full Round order strip at the top of the layout (decided).
	turnOrderStrip = TurnOrderStripScript.new()
	turnOrderStrip.name = "TurnOrderStrip"
	$MarginContainer/VBoxContainer.add_child(turnOrderStrip)
	$MarginContainer/VBoxContainer.move_child(turnOrderStrip, 0)


func setTurnOrder(actorNames: Array) -> void:
	if turnOrderStrip != null:
		turnOrderStrip.setTurnOrder(actorNames)


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
	showCylinder(content, characterData.get('Cylinder', []), int(characterData.get('ChamberIndex', 0)))
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
	content.get_node("HBoxContainer/Data/HPContainer/HP").setRichTextLabel(str(characterData.HP))
	for stat in characterStats:
		var statNode = content.get_node_or_null("HBoxContainer2/Stats/{stat}Container/{stat}".format({ "stat": stat }))
		if statNode != null:
			statNode.setRichTextLabel(str(characterStats[stat]))
	showCylinder(content, characterData.get('Cylinder', []), int(characterData.get('ChamberIndex', 0)))
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

func setPlayerCharacterActs(acts: Array, actType: String, usability := {}) -> void:
	var actNode = load("res://Shootout/UI/ShootoutAct.tscn")
	for actButton in $VBoxContainer/CenterContainer/PanelContainer/Acts.get_children():
		actButton.queue_free()
	for actName in acts:
		var newAct = actNode.instantiate()
		var info = usability.get(actName, { "usable": true, "reason": "" })
		newAct.init(actName, actType, info.get("usable", true), actTooltip(actName, actType, info))
		$VBoxContainer/CenterContainer/PanelContainer/Acts.add_child(newAct)
		newAct.actClicked.connect(func():
			if actType == "Items":
				item.emit(actName)
			elif actType == "Moves":
				move.emit(actName)
			elif actType == "Reposition":
				reposition.emit(actName.to_lower())
		)

func hideActsPanel() -> void:
	$VBoxContainer/CenterContainer.visible = false

func manageActMenus(act: String):
	if playerHasControl:
		var panel = $VBoxContainer/CenterContainer
		if act == "shootout":
			hideActsPanel()
			actOpen = null
			return
		if act == actOpen and panel.visible:
			# Same menu open: toggle it closed.
			panel.visible = false
			actOpen = null
			return
		# Opening or switching menus: keep the panel open and swap contents.
		panel.visible = true
		actOpen = act


func _on_shootout_button_pressed() -> void:
	manageActMenus("shootout")
	attack.emit()

func _on_item_button_pressed() -> void:
	manageActMenus("item")
	itemActsRequested.emit()

func _on_move_button_pressed() -> void:
	manageActMenus("move")
	moveActsRequested.emit()

func setFleeEnabled(enabled: bool) -> void:
	var fleeButton = get_node_or_null("MarginContainer/VBoxContainer/GridContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/FleeButton")
	if fleeButton != null:
		fleeButton.disabled = !enabled

func _on_flee_button_pressed() -> void:
	manageActMenus("shootout")
	flee.emit()

func _on_reposition_button_pressed() -> void:
	manageActMenus("reposition")
	if actOpen == "reposition":
		setPlayerCharacterActs(["Forward", "Backward"], "Reposition")

## Cylinder pips in a stats panel (lazily created; art can replace letters).
func showCylinder(content: Node, cylinder: Array, chamberIndex: int) -> void:
	if content == null:
		return
	var row = content.get_node_or_null("CylinderRow")
	if row == null:
		row = CylinderRowScript.new()
		row.name = "CylinderRow"
		content.add_child(row)
	row.setCylinder(cylinder, chamberIndex)

## Effect summary line in a stats panel.
func showEffects(content: Node, effectLines: Array) -> void:
	if content == null:
		return
	var label = content.get_node_or_null("EffectsLabel")
	if label == null:
		label = Label.new()
		label.name = "EffectsLabel"
		content.add_child(label)
	label.text = "Effects: " + (", ".join(effectLines) if !effectLines.is_empty() else "-")

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
