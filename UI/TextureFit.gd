class_name TextureFit

## Sizes pixel-art textures inside a fixed box on ONE shared scale, so all sprites
## keep consistent apparent sizes and even pixel proportions.
##
## Per-sprite "scale up until it fits" was wrong on both counts: a 12x12 hat was
## drawn at 2x (24x24, as large as a 24x24 revolver) while 24x24 art stayed at 1x,
## so the same frame showed wildly different sprite scales. Drawing everything at
## a single whole scale (SCALE = 1, the art's native resolution) gives even pixel
## proportions and preserves each sprite's authored size.
##
## Textures larger than the box fall back to an aspect-preserving fit, which
## TextureRect does with STRETCH_KEEP_ASPECT_CENTERED.

const SCALE := 1


static func fits(sourceSize: Vector2, box: Vector2, scale := SCALE) -> bool:
	if sourceSize.x <= 0.0 or sourceSize.y <= 0.0:
		return false
	var drawn = sourceSize * scale
	return drawn.x <= box.x and drawn.y <= box.y


## Size to draw at. `sourceSize * scale` when it fits (whole pixels of the source
## map to whole pixels on screen), otherwise the caller uses the aspect fallback.
static func fittedSize(sourceSize: Vector2, box: Vector2, scale := SCALE) -> Vector2:
	if fits(sourceSize, box, scale):
		return sourceSize * scale
	return box


## Applies the fit to a TextureRect: native-scale and centered when the sprite
## fits, otherwise aspect-preserving inside the box.
static func applyTo(textureRect: TextureRect, box: Vector2, scale := SCALE) -> void:
	var sourceSize = Vector2.ZERO
	if textureRect.texture != null:
		sourceSize = textureRect.texture.get_size()
	if sourceSize == Vector2.ZERO:
		textureRect.custom_minimum_size = box
		return
	textureRect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if fits(sourceSize, box, scale):
		textureRect.custom_minimum_size = fittedSize(sourceSize, box, scale)
		textureRect.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		textureRect.custom_minimum_size = box
		textureRect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED