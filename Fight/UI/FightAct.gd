extends TextureRect

signal actClicked

var actName
var actType


func init(newActName: String, newActType: String) -> void:
	actName = newActName
	actType = newActType
	texture = load("res://Assets/{actType}/{actName}.png".format({ "actType": actType, "actName": actName.replace(" ", "") }))


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
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
