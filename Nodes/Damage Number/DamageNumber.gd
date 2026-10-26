extends Node2D

const RISE_DISTANCE := 25.0
const LIFETIME := 0.5


func init(labelText, labelColor, labelPosition, _effects = null) -> void:
	var label = $Label
	pinLabelToAnchor(label)
	setLabelText(label, labelText, labelColor)
	position = labelPosition
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.finished.connect(tweenDone)
	tween.tween_property(self, "position:y", labelPosition.y - RISE_DISTANCE, LIFETIME)


## The shared RichTextLabelExtended scene carries a +2/+5 transform offset so
## panel text sits inside its box; a world-space popup must land exactly on the
## spawn point, so the offset is dropped here (not only in the scene file).
func pinLabelToAnchor(label) -> void:
	label.offset_transform_enabled = false
	label.offset_transform_position = Vector2.ZERO
	label.position = Vector2.ZERO


## Colors come from the shared RichTextLabelExtended palette; unknown keys
## fall back to a raw BBCode color so callers can pass any color string.
func setLabelText(label, labelText, labelColor) -> void:
	var colorKey = str(labelColor).to_lower()
	if colorKey in label.colors:
		label.setRichTextLabel(labelText, colorKey, "center")
	else:
		label.setRichTextLabel("[color=%s]%s[/color]" % [labelColor, labelText], null, "center")


func tweenDone():
	queue_free()
