class_name ShootoutFocusManager
extends Node


## Darkest-Dungeon style act presentation (Docs/System Design/Shootout/Shootout
## UI.md): while an act plays, only the fighters the act affects scale up and
## move to fixed on-screen focus positions, the shootout background blurs and
## dims slightly, the acting fighter lunges and leans toward their target and
## the struck fighter recoils on the impact frame.
## The camera stays at its rest framing so bystanders and the HUD do not zoom.
## Everything returns to its rest state when the act sequence finishes.
##
## Pure presentation: it never touches HP, the turn order or the resolution
## flow, and every hook is null-safe so a missing camera/UI/animation node
## degrades to "no focus" instead of breaking a turn.

# Background defocus while an act plays: blur radius in texture pixels (the
# shootout background is authored at the 640x360 viewport size, so texture
# pixels are screen pixels) and how much darker it gets.
const BLUR_AMOUNT = 1.4
const BLUR_DIM = 0.22
# Background focus in/out durations. Fighter scale uses the same pacing.
const FOCUS_IN_TIME = 0.25
const FOCUS_OUT_TIME = 0.35
const SHAKE_STRENGTH = 2.0
const SHAKE_TIME = 0.12
# Fixed viewport-space stage positions (the project viewport is 640x360).
# Player fighters always stay on the left and enemies on the right, whichever
# one is acting. Distinct same-team targets use an inner slot to avoid overlap;
# self-targeted acts use the center.
const PLAYER_FOCUS_POSITION = Vector2(230, 180)
const ENEMY_FOCUS_POSITION = Vector2(410, 180)
const PLAYER_INNER_FOCUS_POSITION = Vector2(300, 180)
const ENEMY_INNER_FOCUS_POSITION = Vector2(340, 180)
const SOLO_FOCUS_POSITION = Vector2(320, 180)

const CHARACTER_UI_NODES = ["HPIndicator", "Highlight", "Highlight2"]

var shootout = null
var camera = null
var ui = null
var focused = false
var shakeTween = null
# Fighters the act zooms (and whose motion an interrupted act has to settle).
var motionActors = []
# Actor roots carry the focus translation; the animations children carry the
# smaller lunge/recoil, so the two motions never fight over the same property.
var actorFocusTweens = {}
var actorRestPositions = {}
var actorFocusPositions = {}
# World-space character UI nodes (HPIndicator, Highlight, Highlight2) hidden
# while the act animation plays, mapped to their pre-act visibility.
var hiddenCharacterUINodes = {}
var hiddenCharacterUIActors = []
# The acting fighter, leaning into the act until its impact resolves. Only this
# fighter is settled when the act ends: a struck fighter's recoil settles on its
# own, and settling it again would cut the reaction short.
var lungingActor = null


func init(shootoutRoot, cameraNode, uiNode) -> void:
	shootout = shootoutRoot
	camera = cameraNode
	ui = uiNode

## Starts the act presentation: scale the affected fighters, blur the
## background and lunge the acting fighter toward their target.
func beginAct(actingActor, targetActor) -> void:
	focusedActors(actingActor, targetActor)
	focused = true
	hideCharacterUI()
	for actor in motionActors:
		playMotion(actor, "playFocusZoom", Vector2.ZERO)
	var layoutDirection = Vector2.ZERO
	if targetActor != null and targetActor != actingActor:
		var actingAnchor = teamFocusPosition(actingActor)
		var targetAnchor = teamFocusPosition(targetActor)
		if isEnemy(actingActor) == isEnemy(targetActor):
			targetAnchor = ENEMY_INNER_FOCUS_POSITION if isEnemy(targetActor) else PLAYER_INNER_FOCUS_POSITION
		layoutDirection = (targetAnchor - actingAnchor).normalized()
		moveToFocusAnchor(actingActor, actingAnchor)
		moveToFocusAnchor(targetActor, targetAnchor)
		playMotion(actingActor, "playFocusFacing", layoutDirection)
		playMotion(targetActor, "playFocusFacing", -layoutDirection)
	else:
		moveToFocusAnchor(actingActor, SOLO_FOCUS_POSITION)
	if ui != null and ui.has_method("setBackgroundFocus"):
		var blurTween = create_tween()
		blurTween.tween_method(Callable(ui, "setBackgroundFocus"), currentBlur(), BLUR_AMOUNT, FOCUS_IN_TIME)
	lunge(actingActor, targetActor, layoutDirection)

## Impact frame: a landed hit gives the camera a small hit shake while the
## fighters continue their act lunge/recoil until the animation finishes.
func onActResolved(_actingActor, _targetActor, damaged: bool) -> void:
	if camera != null and damaged:
		shake()

## Ends the act presentation: fighter scale, blur and fighter motion all return
## to their rest state. The camera never left its rest framing. Safe to call
## when nothing is focused.
func endAct() -> void:
	if !focused:
		return
	focused = false
	if ui != null and ui.has_method("setBackgroundFocus"):
		var blurTween = create_tween()
		blurTween.tween_method(Callable(ui, "setBackgroundFocus"), currentBlur(), 0.0, FOCUS_OUT_TIME)
	settle(lungingActor)
	lungingActor = null
	for actor in motionActors:
		settle(actor)
		playMotion(actor, "settleFocusZoom", Vector2.ZERO)
	restoreActorPositions()
	restoreCharacterUI()
	motionActors.clear()


## Move an actor root to a fixed viewport-space anchor, converted into its
## parent's local coordinates. The original local position is restored exactly.
func moveToFocusAnchor(actor, screenPosition: Vector2) -> void:
	if actor == null or !is_instance_valid(actor) or !actor.is_inside_tree():
		return
	if !actorRestPositions.has(actor):
		actorRestPositions[actor] = actor.position
	killActorFocusTween(actor)
	var worldPosition = get_viewport().get_canvas_transform().affine_inverse() * screenPosition
	var parent = actor.get_parent()
	var localPosition = worldPosition
	if parent is Node2D:
		localPosition = parent.get_global_transform().affine_inverse() * worldPosition
	actorFocusPositions[actor] = localPosition
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "position", localPosition, FOCUS_IN_TIME)
	actorFocusTweens[actor] = tween

## Captures any formation position changes made during turn-end resolution
## (such as Leaders Duck moving an actor) without pulling focused actors off
## their stage anchors mid-animation.
func syncRestPositionsFromTurnManager() -> void:
	if !focused or shootout == null:
		return
	var turnManager = shootout.get("turnManager")
	if turnManager == null or !turnManager.has_method("sideOfActor") or !turnManager.has_method("getActorPosition") or !shootout.has_method("getPositionForColumn"):
		return
	for actor in actorRestPositions.keys():
		if !is_instance_valid(actor):
			continue
		var actorName = str(actor.name)
		var side = turnManager.sideOfActor(actorName)
		var column = turnManager.getActorPosition(actorName)
		if side != "" and column != -1:
			actorRestPositions[actor] = shootout.getPositionForColumn(side, column)
		if actorFocusPositions.has(actor):
			actor.position = actorFocusPositions[actor]

func restoreActorPositions() -> void:
	for actor in actorRestPositions.keys():
		if !is_instance_valid(actor):
			continue
		killActorFocusTween(actor)
		# Restore before turn cleanup: deaths can compact the surviving team and
		# assign new actor-root positions in the same frame as finishTurn().
		actor.position = actorRestPositions[actor]
	actorRestPositions.clear()
	actorFocusPositions.clear()

func killActorFocusTween(actor) -> void:
	var tween = actorFocusTweens.get(actor)
	if tween != null and tween.is_valid():
		tween.kill()
	actorFocusTweens.erase(actor)


# --- character UI ---

## Hides world-space character UI elements (HP bars, turn/selection highlights
## and hover outlines) across shootout actors while the act animation plays.
func hideCharacterUI() -> void:
	for actor in collectActors():
		if !is_instance_valid(actor):
			continue
		if "characterUIHidden" in actor:
			actor.characterUIHidden = true
		if !hiddenCharacterUIActors.has(actor):
			hiddenCharacterUIActors.append(actor)
		for nodeName in CHARACTER_UI_NODES:
			var uiNode = actor.get_node_or_null(nodeName)
			if uiNode == null:
				continue
			if !hiddenCharacterUINodes.has(uiNode):
				hiddenCharacterUINodes[uiNode] = uiNode.visible
			uiNode.hide()
		var animations = actor.getAnimations() if actor.has_method("getAnimations") else null
		var sprite = animations.get_node_or_null("AnimationSprite") if animations != null else null
		if sprite != null and sprite.material != null:
			sprite.material = null

func restoreCharacterUI() -> void:
	for actor in hiddenCharacterUIActors:
		if is_instance_valid(actor) and "characterUIHidden" in actor:
			actor.characterUIHidden = false
	hiddenCharacterUIActors.clear()
	for uiNode in hiddenCharacterUINodes.keys():
		if is_instance_valid(uiNode):
			uiNode.visible = hiddenCharacterUINodes[uiNode]
	hiddenCharacterUINodes.clear()

func collectActors() -> Array:
	var actors = motionActors.duplicate()
	var actorsRoot = shootout.get("actorsRoot") if shootout != null else null
	if actorsRoot == null and shootout != null and shootout.has_method("get_node_or_null"):
		actorsRoot = shootout.get_node_or_null("Actors")
	if actorsRoot != null:
		for child in actorsRoot.get_children():
			if !actors.has(child):
				actors.append(child)
	return actors


## Small camera kick on a landed hit; Camera2D.offset does not change the rest
## zoom or position.
func shake() -> void:
	if shakeTween != null and shakeTween.is_valid():
		shakeTween.kill()
	camera.offset = Vector2(randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH), randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH))
	shakeTween = create_tween()
	shakeTween.tween_property(camera, "offset", Vector2.ZERO, SHAKE_TIME)


# --- background ---

func currentBlur() -> float:
	if ui == null or !ui.has_method("getBackgroundFocus"):
		return 0.0
	return float(ui.getBackgroundFocus())


# --- fighter motion ---

func focusedActors(actingActor, targetActor) -> void:
	motionActors.clear()
	for actor in [actingActor, targetActor]:
		if actor != null and is_instance_valid(actor) and !motionActors.has(actor):
			motionActors.append(actor)

## The acting fighter steps and leans toward their target; with no target (a
## self-buff, or an act whose target is only known at resolution) they lean
## toward the enemy line instead.
func lunge(actingActor, targetActor, layoutDirection: Vector2 = Vector2.ZERO) -> void:
	if actingActor == null:
		return
	# A previous act interrupted before its impact can leave its attacker leaning
	# in: bring them home before the new act takes over the motion.
	if lungingActor != null and lungingActor != actingActor:
		settle(lungingActor)
	lungingActor = actingActor
	# Use the staged positions, not the original spawn positions: enemy actors
	# lunge left toward the player, while player actors lunge right.
	var direction = layoutDirection if layoutDirection != Vector2.ZERO else motionDirection(actingActor, targetActor)
	if direction == Vector2.ZERO:
		direction = facing(actingActor)
	if direction == Vector2.ZERO:
		return
	playMotion(actingActor, "playLunge", direction)
	if targetActor != null and targetActor != actingActor:
		playMotion(targetActor, "playRecoil", direction)

func settle(actor) -> void:
	playMotion(actor, "settleMotion", Vector2.ZERO)

## Motion lives on the actor's animations node (sprite + drop shadow move
## together, the input collision rectangle stays put). has_method guards keep
## fakes and non-shootout actors working.
func playMotion(actor, methodName: String, direction: Vector2) -> void:
	if actor == null or !is_instance_valid(actor) or !actor.has_method("getAnimations"):
		return
	var animations = actor.getAnimations()
	if animations == null or !animations.has_method(methodName):
		return
	if direction == Vector2.ZERO:
		animations.call(methodName)
	else:
		animations.call(methodName, direction)

## Mostly-horizontal shove between two fighters: they stand on one line, so the
## vertical part is only a hint. Zero when either side is missing or the act
## targets the actor itself.
static func motionDirection(fromActor, toActor) -> Vector2:
	if fromActor == null or toActor == null or !is_instance_valid(fromActor) or !is_instance_valid(toActor):
		return Vector2.ZERO
	var delta = toActor.global_position - fromActor.global_position
	if delta == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(delta.x, delta.y * 0.3)

func teamFocusPosition(actor) -> Vector2:
	return ENEMY_FOCUS_POSITION if isEnemy(actor) else PLAYER_FOCUS_POSITION


func isEnemy(actor) -> bool:
	if actor == null or !is_instance_valid(actor):
		return false
	var turnManager = shootout.get("turnManager") if shootout != null else null
	return turnManager != null and turnManager.has_method("sideOfActor") and turnManager.sideOfActor(str(actor.name)) == "enemy team"


## Which way a fighter faces: the player team looks right, the enemy team left
## (ShootoutActor flips the enemy sprite at spawn).
func facing(actor) -> Vector2:
	var turnManager = shootout.get("turnManager") if shootout != null else null
	if turnManager == null or !turnManager.has_method("sideOfActor"):
		return Vector2.ZERO
	return Vector2.LEFT if isEnemy(actor) else Vector2.RIGHT
