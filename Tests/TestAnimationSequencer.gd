extends SceneTree

## Headless validation for the shootout turn-resolution animation flow
## (the "stuck on the enemy turn" soft lock):
## 1. Animations.playAnimation restarts an animation that is already playing,
##    so an actor acting on back-to-back turns (closing one round, opening the
##    next) reaches the armed frame hit again. The old code continued the
##    leftover animation tail, the hit never fired and the turn hung forever.
## 2. The sequencer completes an acting step whose armed frame hit never fires
##    (unreachable hit-frame index) through sequenceDone instead of hanging.
## 3. The sequencer completes an acting step for a missing animation instead
##    of arming a hit that can never fire.
## Run with: godot --headless --script res://Tests/TestAnimationSequencer.gd

const AnimationsScript = preload("res://Animations/Animations.gd")
const SequencerScript = preload("res://Shootout/ShootoutAnimationSequencer.gd")

const MELEE_LENGTH = 0.6
const MELEE_HIT_FRAME = 1

var failures = 0


# GDScript lambdas capture local variables by value, so signal counts need a
# reference-type holder to be observable.
class Counter:

	extends RefCounted

	var count = 0


	func bump() -> void:
		count += 1


class FakeActingActor:

	extends Node2D

	var weapon = { "weapon": "scratch" }
	var animationsNode = null


	func getAnimations() -> Node:
		return animationsNode


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Turn resolution animation flow ---")
	await _test_back_to_back_restarts_reach_the_hit_again()
	await _test_unreachable_hit_frame_completes_via_sequence_done()
	await _test_missing_animation_completes_immediately()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## An Animations node whose "Melee" is a discrete frame track over 0.6s
## (like the actor animation scenes), with the frame_changed signal wired the
## same way the scenes connect it.
func makeAnimations(hitFrame: int) -> Node:
	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("Idle")
	spriteFrames.add_animation("Melee")
	for i in 3:
		spriteFrames.add_frame("Melee", AtlasTexture.new())
	var animation = Animation.new()
	animation.length = MELEE_LENGTH
	var track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("AnimationSprite:frame"))
	for i in 3:
		animation.track_insert_key(track, 0.2 * i, i)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	var idle = Animation.new()
	idle.length = 0.2
	var idleTrack = idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(idleTrack, NodePath("AnimationSprite:frame"))
	idle.track_insert_key(idleTrack, 0.0, 0)
	idle.value_track_set_update_mode(idleTrack, Animation.UPDATE_DISCRETE)
	var library = AnimationLibrary.new()
	library.add_animation("Idle", idle)
	library.add_animation("Melee", animation)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "AnimationSprite"
	sprite.sprite_frames = spriteFrames
	var player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", library)
	var node = Node2D.new()
	node.set_script(AnimationsScript)
	node.add_child(sprite)
	node.add_child(player)
	node.initAnimations("Idle", hitFrame)
	sprite.frame_changed.connect(node._on_animation_sprite_frame_changed)
	player.animation_finished.connect(node._on_animation_player_animation_finished)
	return node


## The soft-lock repro: the second turn's armed play must restart the still
## running attack animation and reach the frame hit again.
func _test_back_to_back_restarts_reach_the_hit_again() -> void:
	var animationsNode = makeAnimations(MELEE_HIT_FRAME)
	root.add_child(animationsNode)
	var hits = Counter.new()
	animationsNode.onAnimationFrameHit.connect(hits.bump)
	# Turn 1: arm the hit and let the animation play mid-way (past its hit).
	animationsNode.playAnimation("Melee", true, true)
	await create_timer(0.35).timeout
	_check(hits.count == 1, "the first armed play reaches the frame hit (got %d hits)" % hits.count)
	# Turn 2 arrives while the first animation is still playing: this is where
	# the fight used to hang forever (the continuation never re-hit the frame).
	animationsNode.playAnimation("Melee", true, true)
	await create_timer(MELEE_LENGTH + 0.2).timeout
	_check(hits.count == 2, "a back-to-back armed play restarts the running animation and hits again (got %d hits)" % hits.count)
	animationsNode.free()


## An armed acting step whose hit-frame data can never fire (index past the
## animation) must complete the sequence so the pending turn resolves.
func _test_unreachable_hit_frame_completes_via_sequence_done() -> void:
	var actor = FakeActingActor.new()
	actor.animationsNode = makeAnimations(99)
	root.add_child(actor)
	actor.add_child(actor.animationsNode)
	var sequencer = SequencerScript.new()
	root.add_child(sequencer)
	var hits = Counter.new()
	var done = Counter.new()
	sequencer.frameHit.connect(hits.bump)
	sequencer.sequenceDone.connect(done.bump)
	sequencer.play([{ "target": "actingActor" }], actor)
	await create_timer(MELEE_LENGTH + 0.5).timeout
	_check(done.count == 1 and hits.count == 0, "an acting step with an unreachable hit frame completes via sequenceDone instead of hanging (done=%d, hits=%d)" % [done.count, hits.count])
	sequencer.free()
	actor.free()


## A missing attack animation must not arm a hit at all: the sequence
## completes immediately so the turn stays resolvable.
func _test_missing_animation_completes_immediately() -> void:
	var actor = FakeActingActor.new()
	var animationsNode = Node2D.new()
	animationsNode.set_script(AnimationsScript)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "AnimationSprite"
	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("Melee")
	sprite.sprite_frames = spriteFrames
	var player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	animationsNode.add_child(sprite)
	animationsNode.add_child(player)
	animationsNode.initAnimations("Melee", MELEE_HIT_FRAME)
	actor.animationsNode = animationsNode
	root.add_child(actor)
	actor.add_child(animationsNode)
	var sequencer = SequencerScript.new()
	root.add_child(sequencer)
	var done = Counter.new()
	sequencer.sequenceDone.connect(done.bump)
	sequencer.play([{ "target": "actingActor" }], actor)
	_check(done.count == 1, "a missing attack animation completes the sequence immediately instead of hanging (done=%d)" % done.count)
	sequencer.free()
	actor.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
