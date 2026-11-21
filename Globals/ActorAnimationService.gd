extends RefCounted
class_name ActorAnimationService

## Builds actor animation nodes from the data registry (Docs/System Design/
## Actor Animations.md, commit 17a). One `SpriteFrames` + one `Animation`
## library per actor id, built once and shared by every instance. States missing
## from the registry are merged from the actor's legacy `*Animations.tscn`, so
## conversion is incremental and unregistered actors keep working unchanged.

const RegistryScript = preload("res://Data/Actors/ActorAnimationRegistry.gd")
const AnimationsScript = preload("res://Animations/Animations.gd")
const OverworldAnimationsScript = preload("res://Animations/Overworld/OverworldAnimations.gd")

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
	# "runtime": "overworld" entries build the OverworldAnimations runtime:
	# one Sprite2D per state carrying the CanvasTexture (diffuse + normal
	# map), looping frame tracks and the autoplay idle (commit 19).
	if registry.hasActor(actorId) and str(registry.getActor(actorId).get("runtime", "")) == "overworld":
		return _buildOverworldRuntime(actorId)
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


## Builds the OverworldAnimations runtime for a "runtime": "overworld" entry:
## one Sprite2D per state (named after the state) carrying a CanvasTexture
## with the authored normal map, looping frame tracks on "{state}:frame" and
## the autoplay idle — the same shape the hand-authored Overworld scenes
## produce. The runtime only drives the AnimationPlayer, so only the default
## idle state's sprite is visible (multi-state overworld actors need a
## visibility switch in the runtime first).
func _buildOverworldRuntime(actorId: String) -> Node:
	var entry := registry.getActor(actorId)
	var states: Dictionary = entry.get("states", {})
	var defaultIdle := registry.defaultIdleFor(actorId)
	var node := Node2D.new()
	node.name = "Animation"
	node.set_script(OverworldAnimationsScript)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	node.add_child(player)
	var library := AnimationLibrary.new()
	var reset := Animation.new()
	reset.length = 0.001
	library.add_animation("RESET", reset)
	for stateName in states:
		var state: Dictionary = states[stateName]
		var sheetPath := str(state.get("sheet", ""))
		if sheetPath == "" or !FileAccess.file_exists(sheetPath):
			push_warning("ActorAnimationService: sheet missing for '%s/%s' (%s); state skipped." % [actorId, stateName, sheetPath])
			continue
		var sprite := Sprite2D.new()
		sprite.name = str(stateName)
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = load(sheetPath)
		var normalPath := str(state.get("normalMap", ""))
		if normalPath != "" and FileAccess.file_exists(normalPath):
			canvas.normal_texture = load(normalPath)
		sprite.texture = canvas
		sprite.hframes = maxi(1, int(state.get("frames", 1)))
		sprite.visible = stateName == defaultIdle
		node.add_child(sprite)
		var frameCount := sprite.hframes
		var animation := Animation.new()
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, "%s:frame" % stateName)
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		var plan := _playbackPlan(state, frameCount, stateName, actorId)
		var time := 0.0
		for index in plan.frames.size():
			animation.track_insert_key(track, time, int(plan.frames[index]))
			time += float(plan.times[index])
		animation.length = time
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(str(stateName), animation)
	if !player.has_animation_library(""):
		player.add_animation_library("", library)
	player.autoplay = defaultIdle
	return node


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
## `AnimationSprite:frame`, one key per played frame. Key spacing uses the
## authored `frameTimes` durations when present (recovered hand-held timings),
## otherwise the state's uniform `step`.
func _buildStateAnimation(frames: SpriteFrames, stateName: String, actorId: String) -> Animation:
	var states: Dictionary = registry.getStates(actorId)
	var state: Dictionary = states.get(stateName, {})
	var frameCount := maxi(1, frames.get_frame_count(stateName))
	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, "AnimationSprite:frame")
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	var plan := _playbackPlan(state, frameCount, stateName, actorId)
	var time := 0.0
	for index in plan.frames.size():
		animation.track_insert_key(track, time, int(plan.frames[index]))
		time += float(plan.times[index])
	animation.length = time
	# The legacy library is LOOP_NONE across the board: looping behavior lives
	# in Animations.gd's finished->replay handler, and one-shot acts must fire
	# animation_finished so the sequencer can close the act.
	animation.loop_mode = Animation.LOOP_NONE
	return animation


## The state's playback plan: parallel frame-index and duration arrays. An
## authored `sequence` lists the frame indices to play in order — indices may
## repeat, e.g. Shoot Rifle's legacy return-to-ready tail that replays frame
## 0. Without a sequence every sheet frame plays once. Durations come from
## `frameTimes` (one per played entry) or the uniform `step`; a frameTimes
## array shorter than the plan keeps its entries and plays the tail at the
## step (the lint catches the mismatch, the runtime stays playable).
func _playbackPlan(state: Dictionary, frameCount: int, stateName: String, actorId: String) -> Dictionary:
	var step := float(state.get("step", registry.DEFAULT_STEP))
	var frames: Array = []
	var sequence: Array = state.get("sequence", [])
	if sequence.is_empty():
		for frameIndex in frameCount:
			frames.append(frameIndex)
	else:
		for entry in sequence:
			var frameIndex := int(entry)
			if frameIndex < 0 or frameIndex >= frameCount:
				push_warning("ActorAnimationService: state '%s' of '%s' sequences frame %d outside the sheet's %d frames; entry skipped." % [stateName, actorId, frameIndex, frameCount])
				continue
			frames.append(frameIndex)
	var frameTimes: Array = state.get("frameTimes", [])
	var times: Array = []
	for index in frames.size():
		if index < frameTimes.size():
			times.append(maxf(0.001, float(frameTimes[index])))
		else:
			if !frameTimes.is_empty() and index == frameTimes.size():
				push_warning("ActorAnimationService: state '%s' of '%s' has %d frameTimes entries for %d keys; the tail plays at the uniform step." % [stateName, actorId, frameTimes.size(), frames.size()])
			times.append(step)
	return { "frames": frames, "times": times }


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
		if !legacyPlayer.has_animation(animName):
			# Newer sprite states the legacy scene has not authored player
			# animations for yet: the frames still merge, playback comes later.
			continue
		player.get_animation_library("").add_animation(animName, legacyPlayer.get_animation(animName).duplicate(true))


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