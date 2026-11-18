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
		for state in ["Idle", "Idle Revolver", "Idle Rifle", "Run", "Shoot Revolver", "Shoot Rifle", "Snap"]:
			_check(frames.has_animation(state), "the registry builds '%s'" % state)
		_check(frames.get_frame_count("Idle") == 8 and !frames.get_animation_loop("Idle"), "Idle keeps its frame count and non-looping flag")
		var idleFrame: Texture2D = frames.get_frame_texture("Idle", 0)
		_check(idleFrame is AtlasTexture and is_equal_approx((idleFrame as AtlasTexture).region.size.x, 40.0), "registry frames slice 40px cells from the sheet")
		# States the registry does not cover merge in from the legacy scene.
		_check(frames.has_animation("Ponder") or frames.has_animation("Draw Revolver Cool"), "the legacy merge supplies registry-uncovered states")
		var player: AnimationPlayer = walker.get_node("AnimationPlayer")
		_check(player.has_animation("Idle"), "the generated playback library drives the states")
		var idleAnimation: Animation = player.get_animation("Idle")
		_check(int(idleAnimation.track_get_key_value(0, 0)) == 0, "the playback track keys frame indices")
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
	# A registered actor type with a legacy scene but no registry entry keeps
	# working through the fallback (Overworld animal scenes keep their runtime).
	var overworldLegacy = service.forActor("Animals", "FluffyRabbit", { "overworld": true })
	_check(overworldLegacy != null, "a legacy-only Overworld actor still resolves through the fallback")

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures)
	quit(failures)