extends Control

signal attack
signal move
signal item
signal moveActsRequested
signal itemActsRequested

var actOpen = null
var playerHasControl = false


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

func setPlayerCharacterActs(acts: Array, actType: String) -> void:
	var actNode = load("res://Shootout/UI/ShootoutAct.tscn")
	for actButton in $VBoxContainer/CenterContainer/PanelContainer/Acts.get_children():
		actButton.queue_free()
	for actName in acts:
		var newAct = actNode.instantiate()
		newAct.init(actName, actType)
		$VBoxContainer/CenterContainer/PanelContainer/Acts.add_child(newAct)
		newAct.actClicked.connect(func():
			if actType == "Items":
				item.emit(actName)
			elif actType == "Moves":
				move.emit(actName)
		)

func hideActsPanel() -> void:
	$VBoxContainer/CenterContainer.visible = false

func manageActMenus(act: String):
	if playerHasControl:
		if act == "shootout":
			hideActsPanel()
		elif !(
			(actOpen == "item" and act == "move") or
			(actOpen == "move" and act == "item")
		):
			$VBoxContainer/CenterContainer.visible = !$VBoxContainer/CenterContainer.visible
		if act == actOpen or act == "shootout":
			actOpen = null
			return
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
