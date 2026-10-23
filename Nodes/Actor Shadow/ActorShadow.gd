class_name ActorShadow
extends Node2D

## Flat drop shadow under an actor's sprite: a dark squashed ellipse as wide
## as the sprite's current frame, centered on the sprite's bottom line (the
## actor's feet). Re-measures on frame/animation changes and always draws
## behind the sprite (z_index -1), so every actor kind — shootout fighters,
## overworld wanderers, cutscene and location actors — can share it.

const WIDTH_RATIO = 0.3
const HEIGHT_RATIO = 0.35
# The shadow sits this far above the sprite's drawn bottom line (sprite edges
# usually carry a few blank pixels below the feet).
const FEET_LIFT = 4.0
const COLOR = Color(0, 0, 0, 0.3)
const SEGMENTS = 16

var sprite = null
var shadowSize = Vector2.ZERO
var attached = false


## Attaches a shadow below the first sprite (Sprite2D/AnimatedSprite2D) found
## under container. No-op when there is no sprite.
static func attachTo(container: Node) -> void:
	var spriteNode = findSprite(container)
	if spriteNode == null:
		return
	# load() rather than the class name: the script may not be in the global
	# class cache yet (freshly created, editor has not rescanned).
	var shadow = load("res://Nodes/Actor Shadow/ActorShadow.gd").new()
	spriteNode.get_parent().add_child(shadow)
	shadow.initShadow(spriteNode)


static func findSprite(node: Node) -> Node:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		var found = findSprite(child)
		if found != null:
			return found
	return null


## Explicit sprite reference; when the shadow is created from a scene instead
## (a plain ActorShadow node), _ready picks the first sprite sibling itself.
func initShadow(spriteInit: Node2D) -> void:
	sprite = spriteInit
	if is_inside_tree():
		_attach()


func _ready() -> void:
	if sprite == null:
		var spriteSibling = findSprite(get_parent())
		if spriteSibling != null:
			sprite = spriteSibling
	_attach()


func _attach() -> void:
	if attached or sprite == null:
		return
	attached = true
	z_index = -1
	sprite.frame_changed.connect(remeasure)
	if sprite is AnimatedSprite2D:
		sprite.animation_changed.connect(remeasure)
	remeasure()


## Recomputes the ellipse size and the feet position from the sprite's current
## frame; keeps the last known values when a frame briefly has no texture.
func remeasure() -> void:
	if sprite == null:
		return
	var drawnSize = spriteDrawnSize()
	if drawnSize == Vector2.ZERO:
		return
	shadowSize = Vector2(
		maxf(2.0, drawnSize.x * WIDTH_RATIO),
		maxf(1.0, drawnSize.x * WIDTH_RATIO * HEIGHT_RATIO)
	)
	position = spriteFeet(drawnSize)
	queue_redraw()


func _draw() -> void:
	if shadowSize == Vector2.ZERO:
		return
	var points = []
	for i in SEGMENTS:
		var angle = TAU * i / SEGMENTS
		points.append(Vector2(cos(angle) * shadowSize.x / 2.0, sin(angle) * shadowSize.y / 2.0))
	draw_colored_polygon(points, COLOR)


# --- sprite geometry ---

func spriteDrawnSize() -> Vector2:
	if sprite is AnimatedSprite2D:
		if sprite.sprite_frames == null:
			return Vector2.ZERO
		var frameTexture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		return frameTexture.get_size() if frameTexture != null else Vector2.ZERO
	if sprite is Sprite2D:
		if sprite.texture == null:
			return Vector2.ZERO
		var textureSize = sprite.texture.get_size()
		return Vector2(
			textureSize.x / maxi(1, sprite.hframes),
			textureSize.y / maxi(1, sprite.vframes)
		)
	return Vector2.ZERO


## Bottom-center of the sprite's drawn rect, in the shadow's parent space (the
## shadow is parented to the sprite's own parent, so this is its local space),
## lifted by FEET_LIFT above the drawn bottom.
func spriteFeet(drawnSize: Vector2) -> Vector2:
	var topLeft = sprite.position + sprite.offset
	if sprite.centered:
		topLeft -= drawnSize / 2
	return topLeft + Vector2(drawnSize.x / 2.0, drawnSize.y - FEET_LIFT)