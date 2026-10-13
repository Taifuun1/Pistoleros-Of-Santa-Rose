extends HBoxContainer

## Full Round order strip (Docs/System Design/Shootout/Shootout UI.md): one
## label per living actor in turn order, the current actor highlighted.

const CURRENT_COLOR = Color(1.0, 0.85, 0.1)
const OTHER_COLOR = Color(0.8, 0.8, 0.8)


func setTurnOrder(actorNames: Array) -> void:
	for child in get_children():
		# Queue while still parented (safe deletion) and detach immediately so
		# the strip rebuilds within the same frame instead of keeping stale labels.
		child.queue_free()
		remove_child(child)
	for i in actorNames.size():
		var label = Label.new()
		label.name = "Turn{index}".format({ "index": i })
		label.text = str(actorNames[i])
		label.add_theme_color_override("font_color", CURRENT_COLOR if i == 0 else OTHER_COLOR)
		if i == 0:
			label.text = "> " + label.text
		add_child(label)
