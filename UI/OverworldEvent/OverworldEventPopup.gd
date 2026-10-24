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

# Reference to the player actor — set when the popup is shown.
var _player_actor: Node = null
# Whether this popup pushed its own music (restored on close).
var _music_pushed := false

func _ready() -> void:
	OverworldEvents.event_triggered.connect(show_event)

func show_event(event_name: String, event_data: Dictionary) -> void:
	# Resolve the player actor reference.
	var overworld = get_tree().current_scene
	if overworld and overworld.has_node("Actors/PlayerOverworldActor"):
		_player_actor = overworld.get_node("Actors/PlayerOverworldActor")

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

	# Add choice buttons.
	var choices: Array = event_data.get("choices", [])
	for choice in choices:
		var btn = Button.new()
		btn.text = choice.get("label", "")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var result_value: String = choice.get("result", "")
		btn.pressed.connect(_on_choice_pressed.bind(result_value))
		content_box.add_child(btn)

	show()


func _on_choice_pressed(result: String) -> void:
	_closePopup()
	if _player_actor and _player_actor.has_method("process_event_result"):
		_player_actor.process_event_result(result)
	OverworldEvents.on_event_closed()
	hide()


func _on_close_button_pressed() -> void:
	# Closing without a choice counts as dismissing — still unblocks events.
	_closePopup()
	OverworldEvents.on_event_closed()
	hide()


# Restores the music that was playing before this popup pushed its own.
func _closePopup() -> void:
	if _music_pushed:
		_music_pushed = false
		MusicPlayer.pop_music()
