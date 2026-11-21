extends SceneTree

## Headless validation for the shared actor animation service (Docs/System
## Design/Actor Animations.md, commit 17a): registry-built SpriteFrames, the
## generated playback library, weapon-idle selection, unknown-actor/state
## degradation and the legacy-scene merge. Run with: godot --headless --script
## res://Tests/TestActorAnimations.gd

const AnimationServiceScript = preload("res://Globals/ActorAnimationService.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var service = AnimationServiceScript.new()

	print("--- Registry-built frames ---")
	var walker = service.forActor("Named People", "Walker Langley")
	_check(walker != null, "Walker Langley resolves through the registry")
	if walker != null:
		var frames: SpriteFrames = walker.get_node("AnimationSprite").sprite_frames
		# Commit 19: the full hand-authored state set is converted to data, so
		# the legacy Walker scene could be deleted.
		for state in ["Idle", "Idle Look", "Idle Revolver", "Idle Rifle", "Run", "Walk", "Ponder", "Push Hat", "Tip", "Throw", "Shoot Revolver", "Shoot Rifle", "Snap", "Draw Revolver Cool", "Draw Revolver Super Cool"]:
			_check(frames.has_animation(state), "the registry builds '%s'" % state)
		_check(frames.get_frame_count("Idle") == 8 and !frames.get_animation_loop("Idle"), "Idle keeps its frame count and non-looping flag")
		_check(frames.get_frame_count("Ponder") == 18 and frames.get_frame_count("Draw Revolver Super Cool") == 30, "the converted extra states keep their frame counts")
		_check(frames.get_frame_count("Shoot Rifle") == 9, "Shoot Rifle follows the shrunken 360px sheet (9 frames)")
		var idleFrame: Texture2D = frames.get_frame_texture("Idle", 0)
		_check(idleFrame is AtlasTexture and is_equal_approx((idleFrame as AtlasTexture).region.size.x, 40.0), "registry frames slice 40px cells from the sheet")
		var player: AnimationPlayer = walker.get_node("AnimationPlayer")
		_check(player.has_animation("Idle"), "the generated playback library drives the states")
		var idleAnimation: Animation = player.get_animation("Idle")
		_check(int(idleAnimation.track_get_key_value(0, 0)) == 0, "the playback track keys frame indices")
		# Recovered legacy timings (commit 19^ history): uniform states play at
		# their authored step, non-uniform states keep the hand-held key times.
		_check(is_equal_approx(player.get_animation("Ponder").length, 18 * 0.2), "SpriteFrames-only states keep the legacy 5fps step")
		var shootRevolver: Animation = player.get_animation("Shoot Revolver")
		_check(is_equal_approx(shootRevolver.track_get_key_time(0, 1), 0.5) and is_equal_approx(shootRevolver.track_get_key_time(0, 8), 1.35), "Shoot Revolver keeps the legacy draw and recoil holds")
		_check(is_equal_approx(shootRevolver.length, 1.65), "Shoot Revolver keeps the legacy total length")
		var shootRifle: Animation = player.get_animation("Shoot Rifle")
		_check(shootRifle.track_get_key_count(0) == 10 and int(shootRifle.track_get_key_value(0, 9)) == 0, "Shoot Rifle plays the legacy ten-entry sequence ending on the return-to-ready frame 0")
		_check(is_equal_approx(shootRifle.track_get_key_time(0, 6), 0.3) and is_equal_approx(shootRifle.track_get_key_time(0, 7), 0.65) and is_equal_approx(shootRifle.track_get_key_time(0, 9), 0.75) and is_equal_approx(shootRifle.length, 1.0), "Shoot Rifle keeps the fired-frame hold, the return-to-ready hold and the legacy 1.0s length")
		_check(is_equal_approx(player.get_animation("Snap").length, 1.6), "Snap keeps the legacy total length")
	_check(walker.get_node("AnimationSprite").offset == Vector2(0, -15), "the authored sprite offset is preserved")

	print("\n--- Whole-sheet and small-cell states ---")
	var rat = service.forActor("Animals", "Squeky rat")
	_check(rat != null, "Squeky rat resolves through the registry")
	if rat != null:
		var ratFrames: SpriteFrames = rat.get_node("AnimationSprite").sprite_frames
		_check(ratFrames.has_animation("Idle") and ratFrames.get_frame_count("Idle") == 1, "the whole-sheet Idle state is a single full frame")
		_check(!(ratFrames.get_frame_texture("Idle", 0) is AtlasTexture), "the whole-sheet Idle uses the sheet texture directly")
		_check(ratFrames.has_animation("Melee") and ratFrames.get_frame_count("Melee") == 5, "the Melee state keeps its frame count")
		_check(is_equal_approx(ratFrames.get_animation_speed("Melee"), 5.0), "state speed is uniform for the AnimatedSprite2D read")

	print("\n--- Cached frames are shared between instances ---")
	var walker2 = service.forActor("Named People", "Walker Langley")
	_check(walker2 != null and walker2.get_node("AnimationSprite").sprite_frames == walker.get_node("AnimationSprite").sprite_frames, "two instances share one SpriteFrames resource")

	print("\n--- Weapon idle selection ---")
	_check(service.idleForWeapon("WalkerLangley", "revolver") == "Idle Revolver", "the revolver idle comes from idleByWeapon")
	_check(service.idleForWeapon("WalkerLangley", "rifle") == "Idle Rifle", "the rifle idle comes from idleByWeapon")
	_check(service.idleForWeapon("WalkerLangley", "melee") == "Idle", "weapons without an authored idle fall back to the default")
	_check(service.idleForWeapon("SquekyRat", "melee") == "Idle", "unprofiled actors use their default idle")
	_check(service.idleForWeapon("UnknownActor", "revolver") == "Idle", "unregistered actors fall back to the default idle")

	print("\n--- Commit 17 registry actors ---")
	var pistolero = service.forActor("Bandits", "Pistolero0")
	_check(pistolero != null, "the indexed Pistolero spawn id resolves through the registry")
	if pistolero != null:
		var pistoleroFrames: SpriteFrames = pistolero.get_node("AnimationSprite").sprite_frames
		_check(pistoleroFrames.has_animation("Idle Revolver") and pistoleroFrames.get_frame_count("Idle Revolver") == 8, "the Pistolero builds its authored revolver states")
		_check(pistoleroFrames.has_animation("Shoot Revolver") and pistoleroFrames.get_frame_count("Shoot Revolver") == 11, "the Pistolero Draw Revolver sheet slices 11 frames")
	pistolero.free()
	var aiyana = service.forActor("Named People", "Aiyana")
	_check(aiyana != null, "Aiyana resolves through the registry")
	if aiyana != null:
		var aiyanaFrames: SpriteFrames = aiyana.get_node("AnimationSprite").sprite_frames
		for state in ["Idle", "Idle Revolver", "Idle Rifle", "Run", "Walk", "Shoot Revolver", "Shoot Rifle", "Throw"]:
			_check(aiyanaFrames.has_animation(state), "Aiyana builds '%s'" % state)
		# The draw timings are the recovered legacy data, shared by every
		# actor whose draw sheets slice the same frame counts.
		var aiyanaRevolver: Animation = aiyana.get_node("AnimationPlayer").get_animation("Shoot Revolver")
		_check(is_equal_approx(aiyanaRevolver.track_get_key_time(0, 1), 0.5) and is_equal_approx(aiyanaRevolver.length, 1.65), "Aiyana's Shoot Revolver carries the shared legacy timing")
		_check(is_equal_approx(aiyana.get_node("AnimationPlayer").get_animation("Shoot Rifle").track_get_key_time(0, 6), 0.3), "Aiyana's Shoot Rifle carries the shared legacy timing")
		aiyana.free()
	var guard = service.forActor("Bandits", "Bobtail Guard")
	_check(guard != null, "the Bobtail Guard resolves through the registry")
	if guard != null:
		var guardRifle: Animation = guard.get_node("AnimationPlayer").get_animation("Shoot Rifle")
		_check(guardRifle.track_get_key_count(0) == 10 and is_equal_approx(guardRifle.track_get_key_time(0, 9), 0.75), "the rifle bandit's Shoot Rifle carries the shared legacy sequence")
		guard.free()
	_check(service.idleForWeapon("BobtailGuard", "rifle") == "Idle Rifle", "the rifle bandit's idle comes from idleByWeapon")
	_check(service.idleForWeapon("BobtailGuard", "revolver") == "Idle Rifle", "the rifle bandit's default idle matches its carried weapon")
	var cardenas = service.forActor("Named People", "Manuel Cárdenas")
	_check(cardenas != null, "Manuel Cárdenas resolves through the registry (accented id)")
	if cardenas != null:
		cardenas.free()

	print("\n--- Unknown actors and the runtime contract ---")
	_check(service.forActor("Animals", "Squeky rat0") != null, "indexed spawn ids resolve to the un-indexed registry entry")
	_check(service.forActor("Named People", "Nobody") == null, "an unregistered actor without a legacy scene resolves to null")
	_check(walker.has_method("playAnimation") and walker.has_method("initAnimations"), "the built node runs the shared Animations.gd runtime")
	root.add_child(walker)
	walker.initAnimations("Idle", -1)
	walker.playAnimation("Idle")
	_check(walker.get_node("AnimationSprite").animation == &"Idle", "playAnimation drives the generated playback")
	# Attack acts must not loop: Animations.gd's finished->replay handler owns
	# looping, and the sequencer closes each act on animation_finished.
	_check(walker.get_node("AnimationPlayer").get_animation("Shoot Revolver").loop_mode == Animation.LOOP_NONE, "act animations stay LOOP_NONE like the legacy library")
	var finishedAct := [false]
	walker.get_node("AnimationPlayer").animation_finished.connect(func(_n): finishedAct[0] = true)
	walker.playAnimation("Shoot Revolver", true, true)
	await create_timer(2.0).timeout
	_check(finishedAct[0], "a one-shot act reaches animation_finished")
	_check(walker.get_node("AnimationSprite").animation == &"Idle", "a finished one-shot act returns to idle")
	walker.queue_free()

	print("\n--- Legacy fallback keeps unregistered actors working ---")
	var legacy = service.forActor("Named People", "Some Gunslinger")
	_check(legacy == null, "an actor with neither registry nor legacy scene resolves to null")
	# The migrated Overworld rabbit now resolves through the overworld
	# registry runtime instead of its deleted scene (commit 19).
	var overworldRabbit = service.forActor("Animals", "FluffyRabbit", { "overworld": true })
	_check(overworldRabbit != null, "the Overworld rabbit resolves through the overworld registry runtime")
	if overworldRabbit != null:
		var idleSprite = overworldRabbit.get_node_or_null("Idle")
		_check(idleSprite != null and idleSprite is Sprite2D, "the overworld runtime builds a per-state Sprite2D")
		if idleSprite != null:
			var canvas = idleSprite.texture
			_check(canvas is CanvasTexture and canvas.normal_texture != null, "the overworld state keeps its CanvasTexture normal map")
			_check(idleSprite.hframes == 4, "the overworld state keeps its hframes")
		var rabbitPlayer: AnimationPlayer = overworldRabbit.get_node("AnimationPlayer")
		_check(rabbitPlayer.has_animation("Idle") and rabbitPlayer.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR, "overworld states loop like the legacy scenes")
		_check(rabbitPlayer.autoplay == "Idle", "the overworld runtime autoplays its idle")
		var unregisteredOverworld = service.forActor("Animals", "Some Rabbit", { "overworld": true })
		_check(unregisteredOverworld == null, "an unregistered Overworld actor with no legacy scene resolves to null")
		overworldRabbit.free()

	print("\n--- Commit 19: the player actors are registry data ---")
	var locationPlayer = service.forActor("Player", "Player Location")
	_check(locationPlayer != null, "the location player resolves through the registry")
	if locationPlayer != null:
		var locationFrames: SpriteFrames = locationPlayer.get_node("AnimationSprite").sprite_frames
		for state in ["Idle", "Idle2", "Run", "Run2"]:
			_check(locationFrames.has_animation(state), "the location player builds '%s'" % state)
		_check(locationFrames.get_frame_count("Idle") == 8 and locationFrames.get_frame_count("Run") == 8, "the location states keep their frame counts")
		if locationPlayer.get_node("AnimationPlayer").has_animation("Idle"):
			_check(is_equal_approx(locationPlayer.get_node("AnimationPlayer").get_animation("Idle").length, 0.8), "Idle keeps its authored 0.8s length")
		_check(locationPlayer.get_node("AnimationSprite").offset == Vector2(0, -15), "the location player keeps its sprite offset")
		locationPlayer.free()
	var wagon = service.forActor("Player", "Player Overworld")
	_check(wagon != null, "the overworld wagon resolves through the registry")
	if wagon != null:
		var wagonFrames: SpriteFrames = wagon.get_node("AnimationSprite").sprite_frames
		for state in ["Move Down", "Move Down Side", "Move Side", "Move Up", "Move Up Side"]:
			_check(wagonFrames.has_animation(state), "the wagon builds '%s'" % state)
		_check(wagonFrames.get_frame_count("Move Down") == 2 and wagonFrames.get_frame_count("Move Side") == 4, "the wagon states keep their frame counts")
		var sideFrame: Texture2D = wagonFrames.get_frame_texture("Move Side", 0)
		_check(sideFrame is AtlasTexture and is_equal_approx((sideFrame as AtlasTexture).region.size.x, 24.0), "the wagon slices 24px cells")
		_check(is_equal_approx(wagon.get_node("AnimationPlayer").get_animation("Move Side").length, 2.0), "the wagon keeps its slow authored steps")
		_check(wagon.get_node("AnimationSprite").offset == Vector2(0, -24), "the wagon keeps its sprite offset")
		wagon.free()

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures)
	quit(failures)