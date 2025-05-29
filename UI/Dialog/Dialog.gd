extends CanvasLayer


func setDialog(text):
	$DialogBackground/MarginContainer/VBoxContainer/HBoxContainer/Text.clear()
	$DialogBackground/MarginContainer/VBoxContainer/HBoxContainer/Text.append_text("%s" % text)
	show()
