class_name ActorShadow
extends Node2D

## Flat drop shadow under an actor's sprite: a dark squashed ellipse sized to
## the sprite's current frame, centered on the sprite's bottom line (the
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
##
## Sizes are taken from the frame's *visible* (non-transparent) pixel bounds,
## not the raw frame rect: assets pad their frames very differently (the
## overworld rabbit sheet packs ~10px bodies into 12x12 frames, character
## sheets pack ~17px bodies into 40x40 frames), so a ratio measured on the raw
## frame width gave tightly-cropped actors a much smaller shadow-to-body
## proportion than padded ones. Measuring the opaque pixels keeps every
## actor's shadow at the same fraction of its actual body.

## Shadow width as a fraction of the visible body width; 0.7 keeps the look
## the 40x40 character frames had before visible-body measurement.
const WIDTH_RATIO = 0.7
const HEIGHT_RATIO = 0.35
# The shadow sits this fraction of the visible body height above the body's
# bottom line (the drawn feet).
const FEET_LIFT_RATIO = 0.1
const ALPHA_THRESHOLD = 0.05
const COLOR = Color(0, 0, 0, 0.3)
const SEGMENTS = 16
# Bounded so a pathological stream of distinct textures cannot grow it forever.
const OPAQUE_RECT_CACHE_LIMIT = 256

enum Coverage {
	## Thin ellipse on the feet line — side/front views of a standing actor.
	FEET,
	## Full ellipse spanning the whole visible body, centered on it — for
	## sprites whose ground footprint covers the entire drawn body, e.g. the
	## overworld wagon seen diagonally (Move Up Side / Move Down Side): there
	## the thin feet ellipse sits under one corner of the wagon and the rest
	## of the sprite hangs over bare ground.
	BODY,
}

static var opaqueRectCache = {}

var sprite = null
var shadowSize = Vector2.ZERO
var attached = false
var coverage = Coverage.FEET: set = setCoverage


func setCoverage(newCoverage: Coverage) -> void:
	if coverage == newCoverage:
		return
	coverage = newCoverage
	remeasure()


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


## The shadow previously attached under container's sprite, or null. Owners
## use this to retune their shadow at runtime (e.g. the wagon switching to
## BODY coverage for its diagonal-move animations).
static func findShadow(container: Node) -> Node:
	var spriteNode = findSprite(container)
	if spriteNode == null:
		return null
	for child in spriteNode.get_children():
		# Same load() comparison as attachTo: the script may not be in the
		# global class cache yet.
		if child.get_script() == load("res://Nodes/Actor Shadow/ActorShadow.gd"):
			return child
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
	var bodyRect = spriteBodyRect()
	if bodyRect.size == Vector2.ZERO:
		return
	if coverage == Coverage.BODY:
		# Cover the whole visible body: an ellipse as large as the body rect,
		# centered on it (the sprite's own pixels draw over the shadow).
		shadowSize = Vector2(maxf(2.0, bodyRect.size.x), maxf(1.0, bodyRect.size.y))
		position = bodyRect.position + bodyRect.size / 2.0
		queue_redraw()
		return
	shadowSize = Vector2(
		maxf(2.0, bodyRect.size.x * WIDTH_RATIO),
		maxf(1.0, bodyRect.size.x * WIDTH_RATIO * HEIGHT_RATIO)
	)
	var lift = maxf(1.0, bodyRect.size.y * FEET_LIFT_RATIO)
	position = Vector2(
		bodyRect.position.x + bodyRect.size.x / 2.0,
		bodyRect.position.y + bodyRect.size.y - lift
	)
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
	var frame = _frameSource()
	if frame.is_empty():
		return Vector2.ZERO
	return Vector2(frame.rect.size)


## The sprite's visible body: the non-transparent pixel bounds of the current
## frame, positioned in the sprite's local space (offset applied, mirrored to
## the top left when the sprite is centered). Falls back to the raw frame when
## the pixels cannot be read, so the shadow always measures something.
func spriteBodyRect() -> Rect2:
	var frame = _frameSource()
	if frame.is_empty():
		return Rect2()
	var bodyRect = spriteOpaqueRect()
	if bodyRect.size == Vector2.ZERO:
		bodyRect = Rect2(Vector2.ZERO, frame.rect.size)
	var topLeft = sprite.offset
	if sprite.centered:
		topLeft -= Vector2(frame.rect.size) / 2
	return Rect2(topLeft + bodyRect.position, bodyRect.size)


## The readable Image source of the sprite's current frame and that frame's rect
## in image coordinates: { "texture": Texture2D, "rect": Rect2i }, or an
## empty Dictionary when nothing is drawn.
func _frameSource() -> Dictionary:
	if sprite is AnimatedSprite2D:
		if sprite.sprite_frames == null:
			return {}
		var frameTexture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if frameTexture == null:
			return {}
		if frameTexture is AtlasTexture:
			return { "texture": frameTexture.atlas, "rect": Rect2i(frameTexture.region) }
		# AnimatedSprite2D has no hframes/vframes: the frame texture is the frame.
		return { "texture": frameTexture, "rect": Rect2i(Vector2i.ZERO, frameTexture.get_size()) }
	if sprite is Sprite2D:
		var texture = sprite.texture
		if texture is CanvasTexture:
			# CanvasTexture has no readable pixels itself; measure its diffuse.
			texture = texture.diffuse_texture
		if texture == null:
			return {}
		if texture is AtlasTexture:
			return { "texture": texture.atlas, "rect": Rect2i(texture.region) }
		var regionRect = Rect2i(sprite.region_rect) if sprite.region_enabled else Rect2i()
		return _textureSource(texture, sprite.hframes, sprite.vframes, sprite.frame, regionRect)
	return {}


## Frame rect inside texture for a sheet sprite; an empty regionRect means no
## region (the sheet is split by hframes/vframes instead).
func _textureSource(texture: Texture2D, hframes: int, vframes: int, frame: int, regionRect: Rect2i) -> Dictionary:
	if texture == null:
		return {}
	var textureSize = texture.get_size()
	if textureSize == Vector2.ZERO:
		return {}
	if regionRect.size.x > 0 and regionRect.size.y > 0:
		return { "texture": texture, "rect": regionRect }
	var columns = maxi(1, hframes)
	var rows = maxi(1, vframes)
	var frameSize = Vector2i(int(textureSize.x) / columns, int(textureSize.y) / rows)
	if frameSize.x <= 0 or frameSize.y <= 0:
		return {}
	return {
		"texture": texture,
		"rect": Rect2i(Vector2i((frame % columns) * frameSize.x, (frame / columns) * frameSize.y), frameSize)
	}


## Non-transparent pixel bounds of the sprite's current frame, in frame-local
## coordinates (0,0 = the frame's top left). An empty rect means the pixels
## could not be read or the frame is blank; spriteBodyRect() falls back to the
## raw frame then. Cached per texture+frame — decoding sheet pixels on every
## frame change would be wasteful.
func spriteOpaqueRect() -> Rect2:
	var frame = _frameSource()
	if frame.is_empty():
		return Rect2()
	var key = "%d|%d|%d|%d|%d" % [
		frame.texture.get_instance_id(),
		frame.rect.position.x, frame.rect.position.y,
		frame.rect.size.x, frame.rect.size.y
	]
	if opaqueRectCache.has(key):
		return opaqueRectCache[key]
	var opaque = Rect2()
	var image = _readableImage(frame.texture)
	if image != null:
		opaque = scanOpaqueRect(image, frame.rect)
	if opaqueRectCache.size() >= OPAQUE_RECT_CACHE_LIMIT:
		opaqueRectCache.clear()
	opaqueRectCache[key] = opaque
	return opaque


func _readableImage(texture: Texture2D) -> Image:
	var image = texture.get_image()
	if image == null:
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	return image


## Bounding rect of pixels with visible alpha inside frameRect, returned in
## frameRect-local coordinates. Empty when the frame has no visible pixels.
static func scanOpaqueRect(image: Image, frameRect: Rect2i) -> Rect2:
	var visible = frameRect.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	if visible.size.x <= 0 or visible.size.y <= 0:
		return Rect2()
	var minX = visible.size.x
	var minY = visible.size.y
	var maxX = -1
	var maxY = -1
	for y in range(visible.position.y, visible.end.y):
		for x in range(visible.position.x, visible.end.x):
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				var localX = x - visible.position.x
				var localY = y - visible.position.y
				minX = mini(minX, localX)
				minY = mini(minY, localY)
				maxX = maxi(maxX, localX)
				maxY = maxi(maxY, localY)
	if maxX < 0:
		return Rect2()
	return Rect2(minX, minY, maxX - minX + 1, maxY - minY + 1)
