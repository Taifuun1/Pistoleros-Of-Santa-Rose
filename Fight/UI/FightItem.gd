extends TextureRect

signal itemClicked

var itemName


func init(newItemName: String) -> void:
	itemName = newItemName
	texture = load("res://Assets/Items/{itemName}.png".format({ "itemName": itemName }))


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if(
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		not event.is_pressed()
	):
		itemClicked.emit(itemName)

func _on_area_2d_mouse_entered() -> void:
	$Highlight.show()

func _on_area_2d_mouse_exited() -> void:
	$Highlight.hide()
