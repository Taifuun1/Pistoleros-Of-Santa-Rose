extends Control

signal attack
signal ability
signal item


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


func _on_fight_button_pressed() -> void:
	$VBoxContainer/CenterContainer.visible = false
	attack.emit()

func _on_item_button_pressed() -> void:
	setPlayerCharacterActs(get_node("../../Actors/{actorName}".format({ "actorName": $"../..".turnOrder.front() })).items, "Items")
	if $VBoxContainer/CenterContainer/PanelContainer/Acts.get_child_count() > 0:
		$VBoxContainer/CenterContainer.visible = !$VBoxContainer/CenterContainer.visible

func _on_ability_button_pressed() -> void:
	setPlayerCharacterActs(get_node("../../Actors/{actorName}".format({ "actorName": $"../..".turnOrder.front() })).abilities, "Abilities")
	if $VBoxContainer/CenterContainer/PanelContainer/Acts.get_child_count() > 0:
		$VBoxContainer/CenterContainer.visible = !$VBoxContainer/CenterContainer.visible
