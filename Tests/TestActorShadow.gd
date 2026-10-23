extends SceneTree

## Headless validation for actor drop shadows (Nodes/Actor Shadow/ActorShadow.gd):
## the ellipse sits on the sprite's drawn bottom line, sizes to the frame width
## and re-measures on animation changes; scene-created shadows auto-find their
## sprite sibling.
## Run with: godot --headless --script res://Tests/TestActorShadow.gd

const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")
const PlayerLocationActorScene = preload("res://Actors/Location/PlayerLocationActor.tscn")

# Geometry expectations derive from the shadow's own tweakable constants, so
# appearance tweaks (width/height ratio, feet lift) never break the checks.
const IDLE_SIZE = 24.0
const BIG_SIZE = 40.0


func expectedWidth(frameWidth: float) -> float:
	return maxf(2.0, frameWidth * ShadowScript.WIDTH_RATIO)


func expectedFeetY(spriteOffsetY: float, frameHeight: float) -> float:
	return spriteOffsetY + frameHeight / 2.0 - ShadowScript.FEET_LIFT

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Actor shadows ---")
	_test_attached_shadow_geometry()
	_test_scene_created_shadow_auto_finds_sprite()
	_test_sprite2d_hframes_geometry()
	_test_location_actor_scenes_get_shadows()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## AnimatedSprite2D with 24x24 frames centered at offset (0,-15): the feet sit
## at y = -15 + 12 - FEET_LIFT and the ellipse spans WIDTH_RATIO of 24px wide.
func _test_attached_shadow_geometry() -> void:
	var actor = Node2D.new()
	var sprite = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.add_animation("Idle")
	frames.add_animation("Big")
	frames.add_frame("Idle", makeTexture(int(IDLE_SIZE), int(IDLE_SIZE)))
	frames.add_frame("Big", makeTexture(int(BIG_SIZE), int(IDLE_SIZE)))
	sprite.sprite_frames = frames
	sprite.animation = "Idle"
	sprite.frame = 0
	sprite.offset = Vector2(0, -15)
	actor.add_child(sprite)
	root.add_child(actor)
	ShadowScript.attachTo(actor)
	var shadow = _findShadow(actor)
	_check(shadow != null, "attachTo creates a shadow below the sprite's parent")
	if shadow == null:
		return
	_check(shadow.position.is_equal_approx(Vector2(0, expectedFeetY(-15, IDLE_SIZE))), "the shadow sits on the sprite's drawn bottom line (got %s)" % shadow.position)
	_check(is_equal_approx(shadow.shadowSize.x, expectedWidth(IDLE_SIZE)), "the ellipse width follows the frame width (got %f)" % shadow.shadowSize.x)
	_check(shadow.z_index == -1, "the shadow draws behind the sprite")
	# Switching to a wider animation re-measures through animation_changed.
	sprite.animation = "Big"
	_check(shadow.position.is_equal_approx(Vector2(0, expectedFeetY(-15, IDLE_SIZE))), "the shadow keeps the feet line on the wider animation (got %s)" % shadow.position)
	_check(is_equal_approx(shadow.shadowSize.x, expectedWidth(BIG_SIZE)), "the ellipse re-measures on animation change (got %f)" % shadow.shadowSize.x)
	actor.free()


## A plain ActorShadow node created from a scene picks up its sprite sibling
## in _ready without any explicit init.
func _test_scene_created_shadow_auto_finds_sprite() -> void:
	var actor = Node2D.new()
	var sprite = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.add_animation("Idle")
	frames.add_frame("Idle", makeTexture(int(IDLE_SIZE), int(IDLE_SIZE)))
	sprite.sprite_frames = frames
	sprite.animation = "Idle"
	sprite.offset = Vector2(0, -10)
	actor.add_child(sprite)
	var shadow = ShadowScript.new()
	actor.add_child(shadow)
	root.add_child(actor)
	_check(shadow.attached, "a scene-created shadow auto-finds its sprite sibling")
	_check(shadow.position.is_equal_approx(Vector2(0, expectedFeetY(-10, IDLE_SIZE))), "the auto-found shadow still measures the feet (got %s)" % shadow.position)
	actor.free()


## Sprite2D sheet sprites (hframes) measure per-frame size, not sheet size.
func _test_sprite2d_hframes_geometry() -> void:
	var actor = Node2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = makeTexture(48, int(IDLE_SIZE))
	sprite.hframes = 2
	sprite.offset = Vector2(0, -12)
	actor.add_child(sprite)
	root.add_child(actor)
	ShadowScript.attachTo(actor)
	var shadow = _findShadow(actor)
	_check(shadow != null and shadow.position.is_equal_approx(Vector2(0, expectedFeetY(-12, IDLE_SIZE))), "a sheet Sprite2D shadow sits at the per-frame bottom (got %s)" % (shadow.position if shadow != null else Vector2.INF))
	_check(shadow != null and is_equal_approx(shadow.shadowSize.x, expectedWidth(IDLE_SIZE)), "a sheet Sprite2D shadow sizes to the per-frame width (got %f)" % (shadow.shadowSize.x if shadow != null else -1.0))
	actor.free()


## The player location scene carries the shadow setup itself (attached from
## _ready). The NPC scene uses the same plain-node auto-find path covered
## above; instantiating it here would pull in AI.gd, which needs autoloads that
## don't exist in --script runs.
func _test_location_actor_scenes_get_shadows() -> void:
	var player = PlayerLocationActorScene.instantiate()
	root.add_child(player)
	var playerShadow = _findShadow(player)
	_check(playerShadow != null and playerShadow.attached, "a PlayerLocationActor scene instance attaches its shadow from _ready")
	if playerShadow != null:
		_check(playerShadow.shadowSize != Vector2.ZERO, "the PlayerLocationActor shadow measures its sprite (got %s)" % playerShadow.shadowSize)
	player.free()


func _findShadow(actor: Node) -> Node:
	for child in actor.get_children():
		if child.get_script() == ShadowScript:
			return child
	return null


func makeTexture(width: int, height: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create_empty(width, height, false, Image.FORMAT_RGBA8))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)