class_name ActorShadow
extends Node2D

## Flat drop shadow under an actor's sprite: a dark squashed ellipse as wide
## as the sprite's current frame, centered on the sprite's bottom line (the
## actor's feet). Re-measures on frame/animation changes and draws directly
## behind the sprite — as a sprite child with show_behind_parent — so every
## actor kind — shootout fighters, overworld wanderers, cutscene and location
## actors — can share it.
##
## The shadow must NOT use a negative z_index: z_index is global to the whole
## canvas layer, so z_index -1 placed the shadow behind ground tilemaps (which
## sit at z_index 0) and the tiles painted over it — shadows vanished in
## locations, most visibly through the transparency shader's see-through
## trees (Docs/Features and Issues.md). Parenting under the sprite instead
## keeps the shadow in the character's own z- and y-sort context, so ground
## tiles, buildings and transparent trees only ever render above or below the
## shadow by the whole character's Y-sort position.

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


## Attaches a shadow directly behind the first sprite (Sprite2D/AnimatedSprite2D)
## found under container. No-op when there is no sprite.
static func attachTo(container: Node) -> void:
	var spriteNode = findSprite(container)
	if spriteNode == null:
		return
	# load() rather than the class name: the script may not be in the global
	# class cache yet (freshly created, editor has not rescanned).
	var shadow = load("res://Nodes/Actor Shadow/ActorShadow.gd").new()
	# initShadow BEFORE add_child: once the shadow is parented under the
	# sprite, a _ready auto-find would match the sprite itself (findSprite
	# accepts any Sprite2D in the subtree, and the sprite IS one).
	shadow.initShadow(spriteNode)
	spriteNode.add_child(shadow)


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
		# Created from a scene as a sprite sibling: find the sprite, then
		# move under it so the draw order is correct.
		var spriteSibling = findSprite(get_parent())
		if spriteSibling != null:
			sprite = spriteSibling
	_attach()


func _attach() -> void:
	if attached or sprite == null:
		return
	attached = true
	# Render directly behind the sprite's own pixels: show_behind_parent
	# draws the shadow just under the sprite while keeping it inside the
	# sprite's z-context (it inherits the sprite's z_index) and its y-sort
	# context — y-sorted parents sort the (sprite, shadow) pair as one unit,
	# so a feet-height shadow can never pop in front of the body.
	show_behind_parent = true
	sprite.frame_changed.connect(remeasure)
	if sprite is AnimatedSprite2D:
		sprite.animation_changed.connect(remeasure)
	if get_parent() != sprite:
		# A scene-created shadow (LocationActor.tscn) starts as a sprite
		# sibling and moves under the sprite itself. Deferred because
		# _ready can run while the parent is still mid-add_child of this
		# node, which rejects a direct reparent; remeasure follows the
		# completed move so the position lands in the sprite-local space.
		reparent.call_deferred(sprite)
		remeasure.call_deferred()
	else:
		remeasure()


## Recomputes the ellipse size and the feet position from the sprite's current
## frame; keeps the last known values when a frame briefly has no texture.
## The shadow is parented to the sprite, so its position is sprite-local.
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


## Bottom-center of the sprite's drawn rect, in the shadow's local space (the
## shadow is parented to the sprite, so the sprite's own space is its local
## space), lifted by FEET_LIFT above the drawn bottom.
func spriteFeet(drawnSize: Vector2) -> Vector2:
	var topLeft = sprite.offset
	if sprite.centered:
		topLeft -= drawnSize / 2
	return topLeft + Vector2(drawnSize.x / 2.0, drawnSize.y - FEET_LIFT)