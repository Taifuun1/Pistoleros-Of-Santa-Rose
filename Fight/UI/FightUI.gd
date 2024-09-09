extends Control

signal attack
signal ability


func setPlayerCharacterStats(characterData, characterStats):
	#for data in characterData:
		##get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/{data}Container/{data}Title".format({ "data": data })).setRichTextLabel(characterData[data])
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/{data}Container/{data}".format({ "data": data })).setRichTextLabel(characterData[data])
	#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/NameContainer/Name").text = characterData.Name
	get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/NameContainer/Name").text = characterData.Name
	get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/HPContainer/HP").setRichTextLabel(characterData.HP)
	for stat in characterStats:
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}Title".format({ "stat": stat }))
		get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}".format({ "stat": stat })).setRichTextLabel(characterStats[stat])


func _on_fight_button_pressed():
	attack.emit()
