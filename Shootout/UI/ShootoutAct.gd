extends TextureRect

signal actClicked

var actName
var actType


func init(newActName: String, newActType: String, enabled := true, tooltip := "") -> void:
	actName = newActName
	actType = newActType
	var iconPath = "res://Assets/{actType}/{actName}.png".format({ "actType": actType, "actName": actName.replace(" ", "") })
	if ResourceLoader.exists(iconPath):
		texture = load(iconPath)
	# Unusable acts are greyed out with the reason (Docs/System Design/Shootout/Shootout UI.md).
	if !enabled:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	tooltip_text = tooltip


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if modulate.r < 1.0:
		return
	if(
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		not event.is_pressed()
	):
		actClicked.emit()

func _on_area_2d_mouse_entered() -> void:
	$Highlight.show()

func _on_area_2d_mouse_exited() -> void:
	$Highlight.hide()
