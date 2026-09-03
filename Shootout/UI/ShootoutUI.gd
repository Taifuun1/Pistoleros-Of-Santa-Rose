extends Control

signal attack
signal move
signal item
signal moveActsRequested
signal itemActsRequested

var actOpen = null
var playerHasControl = false


func setHoveredActorStats(characterData, characterStats) -> void:
	var panel = $VBoxContainer/GridContainer/PanelContainer3
	panel.visible = true
	panel.get_node("MarginContainer/GridContainer/HoveredData/HoveredName").text = characterData.Name
	panel.get_node("MarginContainer/GridContainer/HoveredData/HoveredHPContainer/HoveredHP").text = str(characterData.HP)
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredSixShootinContainer/HoveredSixShootin").text = str(characterStats.SixShootin)
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredHighTailinContainer/HoveredHighTailin").text = str(characterStats.HighTailin)
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredTaffyinContainer/HoveredTaffyin").text = str(characterStats.Taffyin)
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredRevolverContainer/HoveredRevolver").text = str(characterStats.Revolver)
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredRifleContainer/HoveredRifle").text = str(characterStats.Rifle)
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredShotgunContainer/HoveredShotgun").text = str(characterStats.Shotgun)

func clearHoveredActorStats() -> void:
	var panel = $VBoxContainer/GridContainer/PanelContainer3
	panel.get_node("MarginContainer/GridContainer/HoveredData/HoveredName").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredData/HoveredHPContainer/HoveredHP").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredSixShootinContainer/HoveredSixShootin").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredHighTailinContainer/HoveredHighTailin").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredTaffyinContainer/HoveredTaffyin").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredRevolverContainer/HoveredRevolver").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredRifleContainer/HoveredRifle").text = "-"
	panel.get_node("MarginContainer/GridContainer/HoveredStats/HoveredShotgunContainer/HoveredShotgun").text = "-"

func setPlayerCharacterStats(characterData, characterStats) -> void:
	get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/NameContainer/Name").text = characterData.Name
	get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/HPContainer/HP").setRichTextLabel(characterData.HP)
	for stat in characterStats:
		get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}".format({ "stat": stat })).setRichTextLabel(characterStats[stat])

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
