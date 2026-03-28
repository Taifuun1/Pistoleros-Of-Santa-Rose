extends TextureRect


var objectType

func createPanningObject(objectTexture, objectPosition, objectType):
	texture = objectTexture
	position = objectPosition
	objectType = objectType
	flip_h = randi() % 2
	flip_v = randi() % 2

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
