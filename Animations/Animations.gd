extends Node2D

var idleAnimation = ""
var oneshotAnimation = false
var animationFrameHit = -1
var frameHit = false
var nextAnimation = null

signal onAnimationFrameHit
signal onNextAnimation


func initAnimations(initIdleAnimation, initAnimationFrameHit = -1):
	idleAnimation = initIdleAnimation
	animationFrameHit = initAnimationFrameHit

func playAnimation(animation, isOneshotAnimation = false, lookForFrameHit = false, assignNextAnimation = null):
	oneshotAnimation = isOneshotAnimation
	frameHit = lookForFrameHit
	nextAnimation = assignNextAnimation
	$AnimationSprite.animation = animation
	# AnimationPlayer.play() silently continues an already-playing animation,
	# so an actor acting on back-to-back turns (closing one round and opening
	# the next) never reached the frame hit again and the turn hung forever.
	# Stop + play forces a restart; the explicit frame reset mirrors what
	# changing the animation property does for a different animation.
	$AnimationSprite.frame = 0
	$AnimationPlayer.stop()
	$AnimationPlayer.play(animation)

func flipAnimation():
	$AnimationSprite.set_flip_h(!$AnimationSprite.flip_h)


func _on_animation_sprite_frame_changed() -> void:
	if frameHit and $AnimationSprite.frame == animationFrameHit:
		onAnimationFrameHit.emit()

func _on_animation_player_animation_finished(animation) -> void:
	if oneshotAnimation:
		if nextAnimation == null:
			$AnimationSprite.animation = idleAnimation
			$AnimationPlayer.play(idleAnimation)
			oneshotAnimation = false
			frameHit = false
			return
		onNextAnimation.emit(nextAnimation)
		nextAnimation = null
	else:
		$AnimationSprite.animation = animation
		$AnimationPlayer.play(animation)


# --- act motion ---
# Darkest-Dungeon style act presentation (Docs/System Design/Shootout/Shootout
# UI.md): the acting fighter lunges and leans slightly toward their target and
# the struck fighter recoils away from the hit. Both run on this node, so the
# sprite and its drop shadow move together while the actor's input collision
# rectangle (a sibling under the actor root) stays put — hover and click
# targeting keep working unchanged mid-act.

const LUNGE_DISTANCE = 10.0
const LUNGE_LEAN = 0.0
const LUNGE_TIME = 1.5
const SETTLE_TIME = 0.24
const RECOIL_DISTANCE = 10.0
const RECOIL_LEAN = 0.0
const RECOIL_TIME = 1.5
const FOCUS_ZOOM = 2
const FOCUS_ZOOM_IN_TIME = 0.15
const FOCUS_ZOOM_OUT_TIME = 0.25

# The rest transform is captured on the first motion: animation scenes may
# place this node off the origin, and the motion always returns to where the
# scene put it rather than to a hardcoded zero.
var motionBasePosition = Vector2.ZERO
var motionBaseRotation = 0.0
var motionBaseScale = Vector2.ONE
var motionBaseCaptured = false
var motionTween = null
var focusTween = null
var focusFlipCaptured = false
var focusBaseFlip = false


## Slight movement and rotation toward the target; holds until settleMotion()
## so the fighter stays leaning into the act until the impact frame.
func playLunge(direction: Vector2) -> void:
	startMotion(direction, LUNGE_DISTANCE, LUNGE_LEAN, LUNGE_TIME, 0.0)

## Slight movement and rotation away from the attacker; holds until
## settleMotion() just like playLunge so both fighters drift during the act.
func playRecoil(direction: Vector2) -> void:
	startMotion(direction, RECOIL_DISTANCE, RECOIL_LEAN, RECOIL_TIME, 0.0)

## Scales only this fighter's visuals for act focus. A separate tween keeps the
## zoom independent from lunge/recoil motion, and the captured scale preserves
## any non-uniform scale authored in the animation scene.
func playFocusZoom() -> void:
	if !is_inside_tree():
		return
	captureMotionBase()
	killFocusTween()
	focusTween = create_tween()
	focusTween.set_trans(Tween.TRANS_CUBIC)
	focusTween.set_ease(Tween.EASE_OUT)
	focusTween.tween_property(self, "scale", motionBaseScale * FOCUS_ZOOM, FOCUS_ZOOM_IN_TIME)

## The fixed focus layout always places the actor left of its target. Temporarily
## face the sprites toward one another, including when an enemy is acting.
func playFocusFacing(direction: Vector2) -> void:
	var sprite = get_node_or_null("AnimationSprite")
	if sprite == null:
		return
	if !focusFlipCaptured:
		focusBaseFlip = sprite.flip_h
		focusFlipCaptured = true
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

func restoreFocusFacing() -> void:
	var sprite = get_node_or_null("AnimationSprite")
	if sprite != null and focusFlipCaptured:
		sprite.flip_h = focusBaseFlip
	focusFlipCaptured = false

## Returns this fighter's visuals to their authored scale at the end of an act.
func settleFocusZoom() -> void:
	if !is_inside_tree() or !motionBaseCaptured:
		return
	killFocusTween()
	focusTween = create_tween()
	focusTween.set_trans(Tween.TRANS_CUBIC)
	focusTween.set_ease(Tween.EASE_OUT)
	focusTween.tween_property(self, "scale", motionBaseScale, FOCUS_ZOOM_OUT_TIME)
	focusTween.tween_callback(Callable(self, "restoreFocusFacing"))

## Tweens back to the rest pose (end of the act).
func settleMotion() -> void:
	if !is_inside_tree() or !motionBaseCaptured:
		return
	killMotionTween()
	motionTween = create_tween()
	motionTween.set_trans(Tween.TRANS_QUAD)
	motionTween.set_ease(Tween.EASE_OUT)
	motionTween.tween_property(self, "position", motionBasePosition, SETTLE_TIME)
	motionTween.parallel().tween_property(self, "rotation", motionBaseRotation, SETTLE_TIME)

## Snaps back to the scene's rest transform (battle end, interrupted act).
func resetMotion() -> void:
	killMotionTween()
	killFocusTween()
	if motionBaseCaptured:
		position = motionBasePosition
		rotation = motionBaseRotation
		scale = motionBaseScale
	restoreFocusFacing()

## Moves and leans the node over inTime; outTime > 0 continues back to the rest
## pose in the same tween.
func startMotion(direction: Vector2, distance: float, lean: float, inTime: float, outTime: float) -> void:
	if !is_inside_tree():
		return
	captureMotionBase()
	killMotionTween()
	var moveDirection = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	# The lean tilts the body's top into the movement (positive rotation is
	# clockwise, and a fighter's "up" is -y), so a push to the left leans left.
	var targetRotation = motionBaseRotation + lean * moveDirection.x
	motionTween = create_tween()
	motionTween.set_trans(Tween.TRANS_QUAD)
	motionTween.set_ease(Tween.EASE_OUT)
	motionTween.tween_property(self, "position", motionBasePosition + moveDirection * distance, inTime)
	motionTween.parallel().tween_property(self, "rotation", targetRotation, inTime)
	if outTime > 0.0:
		motionTween.tween_property(self, "position", motionBasePosition, outTime)
		motionTween.parallel().tween_property(self, "rotation", motionBaseRotation, outTime)

func captureMotionBase() -> void:
	if motionBaseCaptured:
		return
	motionBaseCaptured = true
	motionBasePosition = position
	motionBaseRotation = rotation
	motionBaseScale = scale

func killMotionTween() -> void:
	if motionTween != null and motionTween.is_valid():
		motionTween.kill()
	motionTween = null

func killFocusTween() -> void:
	if focusTween != null and focusTween.is_valid():
		focusTween.kill()
	focusTween = null
