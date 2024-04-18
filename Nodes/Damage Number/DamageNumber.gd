extends RichTextLabel

var movement


func init(labelText, labelColor, labelPosition, _effects = null):
	var damageDumberText = "[center][color={labelColor}]{labelText}[/color][/center]".format({ "labelText": labelText, "labelColor": labelColor })
	text = damageDumberText
	position = labelPosition
	movement = Vector2(0, 48)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.finished.connect(tweenDone)
	tween.tween_property(self, "position:y", labelPosition.y - 50, 0.75)


func tweenDone():
	queue_free()
