extends CanvasLayer


func setDialog(text):
	$DialogBackground/Text.clear()
	$DialogBackground/Text.append_text(text)
	show()
