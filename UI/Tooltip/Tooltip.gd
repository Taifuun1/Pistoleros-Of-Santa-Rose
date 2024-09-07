extends Control

var showing


func _process(_delta):
	if showing:
		var cursorPosition = get_global_mouse_position()
		var adjustedPosition = Vector2()
		adjustedPosition.x = clamp(cursorPosition.x, 0, get_viewport_rect().size.x - size.x - 34)
		adjustedPosition.y = clamp(cursorPosition.y, 0, get_viewport_rect().size.y - size.y - 2)
		set_position(adjustedPosition)

func updateTooltip(title, description = null, _sprite = null):
	$MarginContainer/VBoxContainer/Title.setRichTextLabel(title)
	$MarginContainer/VBoxContainer/Text.setRichTextLabel(description)
	#if _description == null:
		#$TooltipContentContainer/TooltipTextContainer/TooltipTextContentContainer/Description.append_bbcode("?????")
	#else:
		#$TooltipContentContainer/TooltipTextContainer/TooltipTextContentContainer/Description.append_bbcode(_description)
	#if _sprite == null:
		#$TooltipContentContainer/Sprite.hide()
	#else:
		#$TooltipContentContainer/Sprite.texture = _sprite

func showTooltip():
	showing = true
	$"..".visible = true

func hideTooltip():
	showing = false
	$"..".visible = false
