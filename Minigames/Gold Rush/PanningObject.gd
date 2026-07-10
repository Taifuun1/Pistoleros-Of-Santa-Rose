extends TextureRect

var objectType
var parentScene: TextureRect

func createPanningObject(objectTexture, objectPosition, objectTypeParam):
	texture = objectTexture
	position = objectPosition
	objectType = objectTypeParam
	flip_h = randi() % 2
	flip_v = randi() % 2

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Do not allow clicking through if another object is higher Z / on top
		if _is_covered_by_top_object():
			return
		# Notify parent scene if this is a valuable item
		if parentScene != null and parentScene.has_method("_on_valuable_collected"):
			var debree = ["rock", "soil"]
			if objectType not in debree:
				parentScene._on_valuable_collected(objectType)
		queue_free()

func _is_covered_by_top_object() -> bool:
	var self_rect = get_global_rect()
	for sibling in get_parent().get_children():
		if sibling == self:
			continue
		if sibling is TextureRect and sibling.visible:
			var sibling_rect = sibling.get_global_rect()
			if self_rect.intersects(sibling_rect):
				if sibling.z_index > z_index or (sibling.z_index == z_index and sibling.get_index() > get_index()):
					return true
	return false
