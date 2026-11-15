extends Node2D

## Floating interaction/building icon (Docs/System Design/Location Vendors
## Implementation.md, patch 3). The icon bobs vertically while its scene is
## running; pausing the tree pauses the bound tween.

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_applyIcon()

@export var bobHeight := 3.0
@export var bobDuration := 0.8

var _baseY := 0.0
var _tween: Tween = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	_baseY = position.y
	_applyIcon()
	_startBob()


func _applyIcon() -> void:
	if sprite != null:
		sprite.texture = icon


func _startBob() -> void:
	if bobHeight <= 0.0 or bobDuration <= 0.0:
		return
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "position:y", _baseY - bobHeight, bobDuration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position:y", _baseY, bobDuration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
