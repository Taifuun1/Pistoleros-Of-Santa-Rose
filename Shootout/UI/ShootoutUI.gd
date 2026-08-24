extends Control

signal attack
signal ability
signal item

var actOpen = null


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
	#for data in characterData:
		##get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/{data}Container/{data}Title".format({ "data": data })).setRichTextLabel(characterData[data])
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/{data}Container/{data}".format({ "data": data })).setRichTextLabel(characterData[data])
	#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/NameContainer/Name").text = characterData.Name
	get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/NameContainer/Name").text = characterData.Name
	get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/HPContainer/HP").setRichTextLabel(characterData.HP)
	for stat in characterStats:
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}Title".format({ "stat": stat }))
		get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}".format({ "stat": stat })).setRichTextLabel(characterStats[stat])

func setPlayerCharacterActs(acts: Array, actType: String) -> void:
	var actNode = load("res://Shootout/UI/ShootoutAct.tscn")
	for actName in $VBoxContainer/CenterContainer/PanelContainer/Acts.get_children():
		actName.queue_free()
	for actName in acts:
		var newAct = actNode.instantiate()
		newAct.init(actName, actType)
		$VBoxContainer/CenterContainer/PanelContainer/Acts.add_child(newAct)
		$VBoxContainer/CenterContainer/PanelContainer/Acts.get_children()[$VBoxContainer/CenterContainer/PanelContainer/Acts.get_child_count() - 1].actClicked.connect(func(): if actType == "Items": item.emit(actName) elif actType == "Abilities": ability.emit(actName))

func manageActMenus(act: String):
	if $"/root/BaseShootout".playerHasControl:
		if act == "shootout":
			$VBoxContainer/CenterContainer.visible = false
		elif !(
			(actOpen == "item" and act == "ability") or
			(actOpen == "ability" and act == "item")
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
	setPlayerCharacterActs(get_node("../../Actors/{actorName}".format({ "actorName": $"../..".turnOrder.front() })).items, "Items")

func _on_ability_button_pressed() -> void:
	manageActMenus("ability")
	setPlayerCharacterActs(get_node("../../Actors/{actorName}".format({ "actorName": $"../..".turnOrder.front() })).abilities, "Abilities")
