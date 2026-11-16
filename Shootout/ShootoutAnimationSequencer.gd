class_name ShootoutAnimationSequencer
extends Node


signal frameHit
signal sequenceDone

var steps = []
var actingActor = null
## Primary/first target, kept for single-target compatibility.
var targetActor = null
## Every target of the current act; one `selectedActor` animation step plays on
## each of them.
var targetActors: Array = []
var running = false
# The acting step resolves its turn through the armed frame hit; the
# animation_finished hook below closes the sequence out when the animation ends.
var awaitingActingHit = false
var actingAnimationsNode = null
# Target-effect steps wait for every target's effect, not only the first.
var _pendingTargetEffects = 0


func play(stepsInit: Array, actingActorInit: Node, targetActorInit = null) -> void:
	clearActingCompletion()
	steps = stepsInit.duplicate(true)
	actingActor = actingActorInit
	targetActors = normalizeTargets(targetActorInit)
	targetActor = targetActors[0] if !targetActors.is_empty() else null
	_pendingTargetEffects = 0
	running = true
	advance()


## Accepts one actor or an ordered set. Dead/freed entries are dropped; the
## caller decides their meaning before this point.
static func normalizeTargets(value) -> Array:
	var targets := []
	if value is Array:
		for target in value:
			if target != null and is_instance_valid(target):
				targets.append(target)
	elif value != null and is_instance_valid(value):
		targets.append(value)
	return targets

func advance() -> void:
	if steps.is_empty():
		running = false
		sequenceDone.emit()
		return
	var step = steps.pop_front()
	match step.get("target", ""):
		"selectedActor":
			playTargetEffect(step)
		"actingActor":
			playActingAnimation(step)
		_:
			advance()

func clearActingCompletion() -> void:
	awaitingActingHit = false
	# The acting actor can drop mid-act (last enemy dies at the impact frame):
	# touching a freed node is a hard error, and its connections died with it.
	if actingAnimationsNode != null and is_instance_valid(actingAnimationsNode):
		var animationPlayer = actingAnimationsNode.get_node_or_null("AnimationPlayer")
		if animationPlayer != null and animationPlayer.animation_finished.is_connected(_on_acting_animation_finished):
			animationPlayer.animation_finished.disconnect(_on_acting_animation_finished)
	actingAnimationsNode = null

func playTargetEffect(step: Dictionary) -> void:
	var effectPath = step.get("path", "")
	var targets := normalizeTargets(targetActors)
	if targets.is_empty() or effectPath == "" or !ResourceLoader.exists(effectPath):
		advance()
		return
	_pendingTargetEffects = targets.size()
	var spawned := 0
	for target in targets:
		if !target.is_inside_tree():
			_pendingTargetEffects -= 1
			continue
		var effect = load(effectPath).instantiate()
		target.add_child(effect)
		# Effect scenes default to the actor origin, which is the character's
		# FEET (sprite offsets draw the body above it): anchor the effect above
		# the drawn body instead (Docs/Features and Issues.md — centered on the
		# body still covers the character).
		effect.position = targetEffectAnchor(target, effect)
		effect.tree_exited.connect(_on_target_effect_exited)
		effect.playAnimation("Effect")
		spawned += 1
	if spawned == 0 or _pendingTargetEffects <= 0:
		advance()

## One target effect finished. The step only advances after every target's
## effect has left the tree, so a multi-target act stays on-screen as one beat.
func _on_target_effect_exited() -> void:
	_pendingTargetEffects -= 1
	if _pendingTargetEffects <= 0:
		_pendingTargetEffects = 0
		advance()

## Where an act effect belongs: horizontally centered on the target's drawn
## body, with the effect's bottom sitting on the body's top line so the whole
## effect reads as floating above the character.
static func targetEffectAnchor(actor, effect) -> Vector2:
	var body = targetSpriteRect(actor)
	var effectHeight = 0.0
	if effect is Sprite2D and effect.texture != null:
		effectHeight = effect.texture.get_height() / maxi(1, effect.vframes)
	return Vector2(
		body.position.x + body.size.x / 2.0,
		body.position.y - effectHeight / 2.0
	)

## The target's drawn sprite rect in the actor's space (the actor origin is
## the feet; sprite offsets draw the body above it). Matches the
## input-collision math in ShootoutActor.initShootoutActor; without sprite
## data it degenerates to the sprite's offset point.
static func targetSpriteRect(actor) -> Rect2:
	if actor == null or !actor.has_method("getAnimations"):
		return Rect2()
	var animations = actor.getAnimations()
	if animations == null or !is_instance_valid(animations):
		return Rect2()
	var sprite = animations.get_node_or_null("AnimationSprite")
	if sprite == null:
		return Rect2()
	var drawnSize = Vector2.ZERO
	if sprite.sprite_frames != null:
		var frameTexture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if frameTexture != null:
			drawnSize = frameTexture.get_size()
	var topLeft = animations.position + sprite.position + sprite.offset
	if sprite.centered:
		topLeft -= drawnSize / 2
	return Rect2(topLeft, drawnSize)

func playActingAnimation(step: Dictionary) -> void:
	var animationName = attackAnimationName(actingActor)
	var animationsNode = actingActor.getAnimations()
	if animationsNode == null:
		# No animations to play: advancing ends the sequence (sequenceDone
		# resolves the turn) instead of arming a frame hit that can never fire.
		advance()
		return
	if step.has("animation") and animationsNode.get_node("AnimationSprite").sprite_frames.has_animation(step.animation):
		animationName = step.animation
	var animationPlayer = animationsNode.get_node_or_null("AnimationPlayer")
	if animationPlayer == null or !animationPlayer.has_animation(animationName):
		# Missing animation: same as above, never wait on a dead sequence.
		advance()
		return
	awaitingActingHit = true
	actingAnimationsNode = animationsNode
	animationPlayer.animation_finished.connect(_on_acting_animation_finished)
	animationsNode.playAnimation(animationName, true, true)

static func attackAnimationName(actor) -> String:
	match actor.weapon.weapon:
		"revolver":
			return "Shoot Revolver"
		"rifle":
			return "Shoot Rifle"
	return "Melee"

func _on_acting_frame_hit() -> void:
	if running:
		awaitingActingHit = false
		frameHit.emit()

## The acting animation finished. It always closes the step out: an armed frame
## hit resolves the turn early (so damage lands on its frame), but the sequence
## still has to reach its end — sequenceDone resolves any pending turn when the
## hit never fired (missing hit-frame data, missing animation) and it is what
## releases the act focus (camera zoom, background defocus) once the act is over.
func _on_acting_animation_finished(_animation) -> void:
	clearActingCompletion()
	advance()
