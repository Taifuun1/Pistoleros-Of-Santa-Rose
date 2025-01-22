extends Control

signal attack
signal ability
signal item

var actOpen = null


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
	var actNode = load("res://Fight/UI/FightAct.tscn")
	for actName in $VBoxContainer/CenterContainer/PanelContainer/Acts.get_children():
		actName.queue_free()
	for actName in acts:
		var newAct = actNode.instantiate()
		newAct.init(actName, actType)
		$VBoxContainer/CenterContainer/PanelContainer/Acts.add_child(newAct)
		$VBoxContainer/CenterContainer/PanelContainer/Acts.get_children()[$VBoxContainer/CenterContainer/PanelContainer/Acts.get_child_count() - 1].actClicked.connect(func(): if actType == "Items": item.emit(actName) elif actType == "Abilities": ability.emit(actName))

func manageActMenus(act: String):
	if $"/root/BaseFight".playerHasControl:
		if act == "fight":
			$VBoxContainer/CenterContainer.visible = false
		elif !(
			(actOpen == "item" and act == "ability") or
			(actOpen == "ability" and act == "item")
		):
			$VBoxContainer/CenterContainer.visible = !$VBoxContainer/CenterContainer.visible
		if act == actOpen or act == "fight":
			actOpen = null
			return
		actOpen = act


func _on_fight_button_pressed() -> void:
	manageActMenus("fight")
	attack.emit()

func _on_item_button_pressed() -> void:
	manageActMenus("item")
	setPlayerCharacterActs(get_node("../../Actors/{actorName}".format({ "actorName": $"../..".turnOrder.front() })).items, "Items")

func _on_ability_button_pressed() -> void:
	manageActMenus("ability")
	setPlayerCharacterActs(get_node("../../Actors/{actorName}".format({ "actorName": $"../..".turnOrder.front() })).abilities, "Abilities")
