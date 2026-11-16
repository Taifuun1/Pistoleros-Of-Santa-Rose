extends CenterContainer

# Maps image_type strings to icon asset paths.
const IMAGE_TYPE_PATHS: Dictionary = {
	"encounter": "res://Assets/Icons/RevolverIcon.png",
	"animal":    "res://Assets/Icons/HP.png",
	"item":      "res://Assets/Icons/MoneyIcon.png",
	"weather":   "res://Assets/Icons/HighTailinIcon.png",
	"nature":    "res://Assets/Icons/HP.png",
	"document":  "res://Assets/Icons/CardIcon.png",
}

# Fallback icon when image_type is unknown.
const FALLBACK_IMAGE_PATH: String = "res://Assets/Icons/RevolverIcon.png"

# Whether this popup pushed its own music (restored on close).
var _music_pushed := false
# Current event identity for outcome dispatch.
var _event_name := ""
var _event_data: Dictionary = {}

func _ready() -> void:
	OverworldEvents.event_triggered.connect(show_event)

func show_event(event_name: String, event_data: Dictionary) -> void:
	_event_name = event_name
	_event_data = event_data

	# Event/shop popup music (Docs/System Design/Music player.md): an event
	# with a "music" field pushes that track, restored when the popup closes.
	var popup_music := str(event_data.get("music", ""))
	if popup_music != "":
		MusicPlayer.push_music(popup_music)
		_music_pushed = true

	# Set header text.
	$PanelContainer/VBoxContainer/MarginContainer/HBoxContainer/Header.setRichTextLabel(event_name)

	# Clear any previously added content.
	var content_box = $PanelContainer/VBoxContainer/MarginContainer2/ScrollContainer/VBoxContainer
	for child in content_box.get_children():
		child.queue_free()

	# Add event image.
	var image_path: String = IMAGE_TYPE_PATHS.get(event_data.get("image_type", ""), FALLBACK_IMAGE_PATH)
	var image_node = load("res://UI/RichTextLabel Extended/RichTextLabelExtended.tscn").instantiate()
	content_box.add_child(image_node)
	image_node.add_image(load(image_path))

	# Add event text.
	var text_label = Label.new()
	text_label.text = event_data.get("text", "")
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_box.add_child(text_label)

	# Add a separator.
	var separator = HSeparator.new()
	content_box.add_child(separator)

	# Add choice buttons. Choices without a supported explicit outcome stay
	# disabled and explain why instead of silently closing as a no-op.
	var choices: Array = event_data.get("choices", [])
	for choiceValue in choices:
		if !(choiceValue is Dictionary):
			continue
		var choice: Dictionary = choiceValue
		var btn = Button.new()
		btn.text = choice.get("label", "")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var validation: Dictionary = OverworldEvents.can_resolve_choice(choice)
		btn.disabled = !bool(validation.get("success", false))
		if btn.disabled:
			btn.tooltip_text = "Unavailable: %s" % str(validation.get("reason", "missing_outcome"))
		btn.pressed.connect(_on_choice_pressed.bind(choice.duplicate(true)))
		content_box.add_child(btn)

	show()


func _on_choice_pressed(choice: Dictionary) -> void:
	_closePopup()
	OverworldEvents.on_event_closed()
	var resolution: Dictionary = OverworldEvents.resolve_event_choice(_event_name, _event_data, choice)
	if !bool(resolution.get("success", false)):
		push_warning("OverworldEventPopup: choice could not resolve (%s)." % str(resolution.get("reason", "")))
	_event_name = ""
	_event_data = {}
	hide()


func _on_close_button_pressed() -> void:
	# Closing without a choice counts as dismissing — still unblocks events.
	_closePopup()
	OverworldEvents.on_event_closed()
	_event_name = ""
	_event_data = {}
	hide()


# Restores the music that was playing before this popup pushed its own.
func _closePopup() -> void:
	if _music_pushed:
		_music_pushed = false
		MusicPlayer.pop_music()
