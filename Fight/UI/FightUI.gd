extends Control

signal attack
signal ability


func setPlayerCharacterStats(characterData):#, characterStats):
	for data in characterData:
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/{data}Container/{data}Title".format({ "data": data })).createRichTextLabel(characterData[data])
		get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Data/{data}Container/{data}".format({ "data": data })).createRichTextLabel(characterData[data])
	#for stat in characterStats:
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}Title".format({ "stat": stat }))
		#get_node("VBoxContainer/GridContainer/PanelContainer/MarginContainer/GridContainer/Stats/{stat}Container/{stat}".format({ "stat": stat }))


func _on_fight_button_pressed():
	attack.emit()
