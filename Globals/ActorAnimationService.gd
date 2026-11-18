extends RefCounted
class_name ActorAnimationService

## Builds actor animation nodes from the data registry (Docs/System Design/
## Actor Animations.md, commit 17a). One `SpriteFrames` + one `Animation`
## library per actor id, built once and shared by every instance. States missing
## from the registry are merged from the actor's legacy `*Animations.tscn`, so
## conversion is incremental and unregistered actors keep working unchanged.

const RegistryScript = preload("res://Data/Actors/ActorAnimationRegistry.gd")
const AnimationsScript = preload("res://Animations/Animations.gd")

const DEFAULT_IDLE := "Idle"

var registry = RegistryScript.new()
var _framesCache := {}
var _legacyCache := {}
var _warnedActors := {}


## Returns the animation node for an actor, or null when neither the registry
## nor a legacy scene can resolve it (call sites already tolerate that).
## `options.overworld` resolves legacy paths under
## `res://Animations/Overworld/{type}/{name}` instead of the Shootout layout.
func forActor(actorType: String, actorName: String, options := {}) -> Node:
	var actorId := _actorId(actorName)
	var frames := _spriteFramesFor(actorId)
	if frames == null:
		# No registry entry: the legacy scene keeps the actor working unchanged.
		var legacyOnly = _legacyScene(_legacyScenePath(actorId, actorType, options))
		if legacyOnly == null and !_warnedActors.has(actorId):
			_warnedActors[actorId] = true
			push_warning("ActorAnimationService: no animations for actor '%s'." % actorId)
		return legacyOnly
	var node := Node2D.new()
	node.name = "Animation"
	node.set_script(AnimationsScript)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimationSprite"
	sprite.sprite_frames = frames
	sprite.animation = &""
	sprite.offset = registry.getActor(actorId).get("spriteOffset", Vector2.ZERO)
	node.add_child(sprite)

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	node.add_child(player)
	var library := AnimationLibrary.new()
	for stateName in frames.get_animation_names():
		library.add_animation(stateName, _buildStateAnimation(frames, stateName, actorId))
	if !player.has_animation_library(""):
		player.add_animation_library("", library)
	_mergeLegacy(actorId, actorType, options, frames, player)

	_wireSignals(node, sprite, player)
	return node


## Weapon-specific idle: the authored `idleByWeapon` entry, else the actor's
## default idle. Unregistered actors fall back to `fallback`.
func idleForWeapon(actorId: String, weaponId: String, fallback := DEFAULT_IDLE) -> String:
	if registry.hasActor(actorId):
		return registry.idleForWeapon(actorId, weaponId, fallback)
	return fallback


func _spriteFramesFor(actorId: String) -> SpriteFrames:
	if _framesCache.has(actorId):
		return _framesCache[actorId]
	if !registry.hasActor(actorId):
		return null
	var entry := registry.getActor(actorId)
	var frames := SpriteFrames.new()
	var states: Dictionary = entry.get("states", {})
	for stateName in states:
		var state: Dictionary = states[stateName]
		var sheetPath := str(state.get("sheet", ""))
		if sheetPath == "" or !FileAccess.file_exists(sheetPath):
			# Uncommitted/new art resolves when its files land; the state is
			# skipped meanwhile (the legacy merge can also supply it).
			push_warning("ActorAnimationService: sheet missing for '%s/%s' (%s); state skipped." % [actorId, stateName, sheetPath])
			continue
		var sheet: Texture2D = load(sheetPath)
		frames.add_animation(str(stateName))
		frames.set_animation_speed(str(stateName), 5.0)
		frames.set_animation_loop(str(stateName), bool(state.get("loop", true)))
		if bool(state.get("wholeSheet", false)):
			frames.add_frame(str(stateName), sheet)
			continue
		var frameSize: Vector2i = state.get("frameSize", registry.DEFAULT_FRAME_SIZE)
		var frameCount := maxi(1, int(state.get("frames", 1)))
		for frameIndex in frameCount:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(frameIndex * frameSize.x, 0), Vector2(frameSize.x, frameSize.y))
			frames.add_frame(str(stateName), atlas)
	_framesCache[actorId] = frames
	return frames


## Mirrors the legacy scenes' playback: one discrete value track per state on
## `AnimationSprite:frame`, one key per frame at the state's step.
func _buildStateAnimation(frames: SpriteFrames, stateName: String, actorId: String) -> Animation:
	var states: Dictionary = registry.getStates(actorId)
	var state: Dictionary = states.get(stateName, {})
	var step := float(state.get("step", registry.DEFAULT_STEP))
	var frameCount := maxi(1, frames.get_frame_count(stateName))
	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, "AnimationSprite:frame")
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for frameIndex in frameCount:
		animation.track_insert_key(track, frameIndex * step, frameIndex)
	animation.length = frameCount * step
	animation.loop_mode = Animation.LOOP_LINEAR if bool(frames.get_animation_loop(stateName)) else Animation.LOOP_NONE
	return animation


func _mergeLegacy(actorId: String, actorType: String, options: Dictionary, frames: SpriteFrames, player: AnimationPlayer) -> void:
	var legacyPath := _legacyScenePath(actorId, actorType, options)
	if legacyPath == "":
		return
	var legacy = _legacyScene(legacyPath)
	if legacy == null:
		return
	var legacyFrames: SpriteFrames = null
	var legacyPlayer: AnimationPlayer = null
	for child in legacy.get_children():
		if legacyFrames == null and child is AnimatedSprite2D:
			legacyFrames = child.sprite_frames
		if legacyPlayer == null and child is AnimationPlayer:
			legacyPlayer = child
	if legacyFrames == null:
		return
	for animName in legacyFrames.get_animation_names():
		if frames.has_animation(animName):
			continue
		frames.add_animation(animName)
		frames.set_animation_speed(animName, legacyFrames.get_animation_speed(animName))
		frames.set_animation_loop(animName, legacyFrames.get_animation_loop(animName))
		for frameIndex in legacyFrames.get_frame_count(animName):
			frames.add_frame(animName, legacyFrames.get_frame_texture(animName, frameIndex))
		if player == null:
			continue
		var legacyAnimation = legacyPlayer.get_animation(animName)
		if legacyAnimation != null:
			player.get_animation_library("").add_animation(animName, legacyAnimation.duplicate(true))


## The legacy scene path for an actor: the Shootout layout by default, the
## Overworld layout with `options.overworld` (commit 17a migration seam).
func _legacyScenePath(actorId: String, actorType: String, options: Dictionary) -> String:
	if bool(options.get("overworld", false)):
		return "res://Animations/Overworld/%s/%sAnimations.tscn" % [actorType, actorId]
	return "res://Animations/%s/%sAnimations.tscn" % [actorType, actorId]


func _legacyScene(legacyScenePath: String):
	if legacyScenePath == "" or !ResourceLoader.exists(legacyScenePath):
		return null
	if !_legacyCache.has(legacyScenePath):
		_legacyCache[legacyScenePath] = load(legacyScenePath).instantiate()
	return _legacyCache[legacyScenePath]


func _wireSignals(node: Node2D, sprite: AnimatedSprite2D, player: AnimationPlayer) -> void:
	if !sprite.frame_changed.is_connected(node._on_animation_sprite_frame_changed):
		sprite.frame_changed.connect(node._on_animation_sprite_frame_changed)
	if !player.animation_finished.is_connected(node._on_animation_player_animation_finished):
		player.animation_finished.connect(node._on_animation_player_animation_finished)


## Shootout spawns append index suffixes ("Squeky rat0"); the registry keys on
## the un-indexed actor id, so trailing digits are stripped for the lookup.
func _actorId(actorName: String) -> String:
	var id := str(actorName).capitalize().replace(" ", "")
	while id.length() > 0 and id.right(1).is_valid_int():
		id = id.left(id.length() - 1)
	return id