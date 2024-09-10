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

func setPlayerCharacterItems(items) -> void:
	var itemNode = load("res://Fight/UI/FightItem.tscn")
	for item in $VBoxContainer/CenterContainer/PanelContainer/Items.get_children():
		item.queue_free()
	for item in items:
		var newItem = itemNode.instantiate()
		$VBoxContainer/CenterContainer/PanelContainer/Items.add_child(newItem)


func _on_fight_button_pressed() -> void:
	attack.emit()

func _on_item_button_pressed() -> void:
	$VBoxContainer/CenterContainer.visible = !$VBoxContainer/CenterContainer.visible
	#item.emit()
