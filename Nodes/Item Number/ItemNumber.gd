extends Label

const RISE_DISTANCE := 28.0
const LIFETIME := 1.25
const FADE_DELAY := 0.4

func init(labelText: String, labelPosition: Vector2) -> void:
	text = labelText
	reset_size()
	position = labelPosition - size / 2.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME - FADE_DELAY).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN).set_delay(FADE_DELAY)
	tween.finished.connect(tweenDone)

func tweenDone() -> void:
	queue_free()
