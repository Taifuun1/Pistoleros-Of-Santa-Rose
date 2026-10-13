extends HBoxContainer

## Cylinder pip row (Docs/System Design/Shootout/Shootout UI.md): one label per
## Chamber, colored by hit quality, the current Chamber marked. Icons can
## replace the letters later without touching the callers.

const CHAMBER_LETTERS = ["M", "G", "H", "C"]
const CHAMBER_COLORS = [Color(0.6, 0.6, 0.6), Color(1.0, 0.65, 0.0), Color(0.85, 0.1, 0.1), Color(1.0, 0.85, 0.1)]
const SPECIAL_LETTERS = { "reload": "R", "jammed": "J" }
const SPECIAL_COLOR = Color(0.4, 0.7, 1.0)


func setCylinder(cylinder: Array, chamberIndex: int) -> void:
	for child in get_children():
		child.queue_free()
	for i in cylinder.size():
		var chamber = cylinder[i]
		var pip = Label.new()
		pip.name = "Pip{index}".format({ "index": i })
		if chamber is String:
			pip.text = SPECIAL_LETTERS.get(chamber, "?")
			pip.add_theme_color_override("font_color", SPECIAL_COLOR)
			pip.tooltip_text = chamber.capitalize()
		else:
			pip.text = CHAMBER_LETTERS[clampi(int(chamber), 0, 3)]
			pip.add_theme_color_override("font_color", CHAMBER_COLORS[clampi(int(chamber), 0, 3)])
			pip.tooltip_text = ["Miss", "Graze", "Hit", "Critical"][clampi(int(chamber), 0, 3)]
		if i == chamberIndex:
			pip.text = "[" + pip.text + "]"
		add_child(pip)
