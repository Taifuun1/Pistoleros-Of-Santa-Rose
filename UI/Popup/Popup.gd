extends CanvasLayer


func setPopupText(header: String, content: Array):
	$CenterContainer/PanelContainer/VBoxContainer/MarginContainer/HBoxContainer/Header.setRichTextLabel(header)
	for labelText in content:
		#var richTextLabelExtended = load("res://UI/RichTextLabel Extended/RichTextLabelExtended.tscn").instantiate()
		#$CenterContainer/PanelContainer/VBoxContainer.add_child(richTextLabelExtended)
		#richTextLabelExtended.setRichTextLabel(label)
		var label = Label.new()
		$CenterContainer/PanelContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer.add_child(label)
		label.text = labelText
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		#label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_close_button_pressed() -> void:
	hide()
