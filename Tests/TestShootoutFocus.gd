extends SceneTree

## Headless validation for the Darkest-Dungeon style act presentation
## (Docs/System Design/Shootout/Shootout UI.md):
## 1. Animations.playLunge steps and leans toward the target and HOLDS there
##    until settleMotion() brings it home — the lean has to survive until the
##    impact frame instead of springing back on its own.
## 2. Animations.playRecoil shoves away from the attacker and returns on its own
##    (a reaction has no follow-up call to wait for).
## 3. Animations.resetMotion snaps a running motion and focus zoom home.
## 4. beginAct moves only the acting/target fighters to fixed screen anchors,
##    preserving authored scales and leaving the camera and bystanders at rest.
## 5. Reversing the actor/target does not change the anchors or lunge direction.
## 6. onActResolved/endAct drive hit reactions and restoration — and only a
##    landed hit recoils the target.
## Run with: godot --headless --script res://Tests/TestShootoutFocus.gd

const AnimationsScript = preload("res://Animations/Animations.gd")
const FocusManagerScript = preload("res://Shootout/ShootoutFocusManager.gd")

# The Shootout scene's rest camera transform.
const REST_ZOOM = Vector2(2, 2)
const REST_POSITION = Vector2(313, 228)

var failures = 0


class FakeUI:

	extends Node

	var focus = 0.0


	func setBackgroundFocus(amount: float) -> void:
		focus = amount

	func getBackgroundFocus() -> float:
		return focus


class FakeTurnManager:

	extends Node

	var sides = {}


	func sideOfActor(actorName: String) -> String:
		return sides.get(actorName, "player team")


class FakeShootout:

	extends Node

	var turnManager = null


class FakeActor:

	extends Node2D

	var animationsNode = null


	func getAnimations() -> Node:
		return animationsNode


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Shootout act focus presentation ---")
	await _test_lunge_holds_until_settled()
	await _test_recoil_returns_on_its_own()
	await _test_reset_motion_snaps_home()
	await _test_miss_leaves_the_target_still()
	await _test_end_act_leaves_the_recoil_alone()
	await _test_act_focus_lifecycle()
	await _test_team_focus_positions()
	await _test_self_target_uses_center()
	await _test_same_team_targets_use_inner_slots()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func makeAnimations() -> Node2D:
	var node = Node2D.new()
	node.set_script(AnimationsScript)
	return node

## The lunge is the "lean into the act" pose: it has to stay put through the
## whole attack animation and only come home when the act settles.
func _test_lunge_holds_until_settled() -> void:
	var animations = makeAnimations()
	root.add_child(animations)
	var base = Vector2(10, 20)
	animations.position = base
	animations.playLunge(Vector2.RIGHT)
	await create_timer(AnimationsScript.LUNGE_TIME + 0.05).timeout
	_check(animations.position.distance_to(base + Vector2(AnimationsScript.LUNGE_DISTANCE, 0)) < 0.5, "the lunge steps toward the target (got %s, want %s)" % [animations.position, base + Vector2(AnimationsScript.LUNGE_DISTANCE, 0)])
	_check(is_equal_approx(animations.rotation, AnimationsScript.LUNGE_LEAN), "the lunge leans into the movement (got %s)" % animations.rotation)
	# Longer than the settle time: the pose must not spring back by itself.
	await create_timer(0.5).timeout
	_check(animations.position.distance_to(base + Vector2(AnimationsScript.LUNGE_DISTANCE, 0)) < 0.5, "the lunge holds until it is settled (got %s)" % animations.position)
	animations.settleMotion()
	await create_timer(AnimationsScript.SETTLE_TIME + 0.15).timeout
	_check(animations.position.distance_to(base) < 0.5 and absf(animations.rotation) < 0.01, "settling returns the fighter to their rest pose (got %s / %s)" % [animations.position, animations.rotation])
	animations.free()


func _test_recoil_returns_on_its_own() -> void:
	var animations = makeAnimations()
	root.add_child(animations)
	var base = Vector2(10, 20)
	animations.position = base
	animations.playRecoil(Vector2.LEFT)
	await create_timer(AnimationsScript.RECOIL_TIME + 0.05).timeout
	_check(animations.position.distance_to(base + Vector2(-AnimationsScript.RECOIL_DISTANCE, 0)) < 0.5, "the recoil lunges away from the attacker (got %s, want %s)" % [animations.position, base + Vector2(-AnimationsScript.RECOIL_DISTANCE, 0)])
	_check(is_equal_approx(animations.rotation, -AnimationsScript.RECOIL_LEAN), "the recoil matches the configured lean (got %s)" % animations.rotation)
	animations.settleMotion()
	await create_timer(AnimationsScript.SETTLE_TIME + 0.15).timeout
	_check(animations.position.distance_to(base) < 0.5 and absf(animations.rotation) < 0.01, "settling returns the recoiling fighter to their rest pose (got %s / %s)" % [animations.position, animations.rotation])
	animations.free()


func _test_reset_motion_snaps_home() -> void:
	var animations = makeAnimations()
	root.add_child(animations)
	var base = Vector2(10, 20)
	var baseScale = Vector2(0.8, 1.2)
	animations.position = base
	animations.scale = baseScale
	animations.playLunge(Vector2.RIGHT)
	animations.playFocusZoom()
	await create_timer(0.05).timeout
	animations.resetMotion()
	_check(animations.position == base and animations.rotation == 0.0, "resetting snaps a running motion home (got %s / %s)" % [animations.position, animations.rotation])
	_check(animations.scale == baseScale, "resetting snaps a running focus zoom to its authored scale (got %s)" % animations.scale)
	animations.free()


## Builds the focus manager plus a camera, a UI stand-in and two fighters.
func makeFight() -> Dictionary:
	var turnManager = FakeTurnManager.new()
	turnManager.sides = { "acting": "player team", "target": "enemy team" }
	var shootout = FakeShootout.new()
	shootout.turnManager = turnManager
	shootout.add_child(turnManager)
	root.add_child(shootout)
	var ui = FakeUI.new()
	root.add_child(ui)
	var camera = Camera2D.new()
	camera.position = REST_POSITION
	camera.zoom = REST_ZOOM
	root.add_child(camera)
	var acting = FakeActor.new()
	acting.name = "acting"
	acting.animationsNode = makeAnimations()
	acting.add_child(acting.animationsNode)
	var actingHp = Node2D.new()
	actingHp.name = "HPIndicator"
	acting.add_child(actingHp)
	var actingTurnHighlight = Sprite2D.new()
	actingTurnHighlight.name = "Highlight2"
	actingTurnHighlight.visible = true
	acting.add_child(actingTurnHighlight)
	acting.position = Vector2(270, 222)
	root.add_child(acting)
	var target = FakeActor.new()
	target.name = "target"
	target.animationsNode = makeAnimations()
	target.animationsNode.scale = Vector2(0.9, 1.1)
	target.add_child(target.animationsNode)
	var targetHp = Node2D.new()
	targetHp.name = "HPIndicator"
	target.add_child(targetHp)
	var targetHighlight = Sprite2D.new()
	targetHighlight.name = "Highlight2"
	targetHighlight.visible = false
	target.add_child(targetHighlight)
	target.position = Vector2(350, 222)
	root.add_child(target)
	var bystander = FakeActor.new()
	bystander.animationsNode = makeAnimations()
	bystander.add_child(bystander.animationsNode)
	bystander.position = Vector2(440, 222)
	root.add_child(bystander)
	var focus = FocusManagerScript.new()
	root.add_child(focus)
	focus.init(shootout, camera, ui)
	return { "shootout": shootout, "ui": ui, "camera": camera, "acting": acting, "target": target, "bystander": bystander, "focus": focus }


func freeFight(fight: Dictionary) -> void:
	for key in fight:
		if fight[key] is Node:
			fight[key].free()


## A Miss (or a Reload/Jammed chamber) resolves without HP loss: the camera must
## not shake while the fighters continue their focus drift.
func _test_miss_leaves_the_target_still() -> void:
	var fight = makeFight()
	fight.focus.beginAct(fight.acting, fight.target)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	var cameraPosition = fight.camera.position
	fight.focus.onActResolved(fight.acting, fight.target, false)
	await create_timer(0.2).timeout
	_check(fight.target.animationsNode.position.x > 0.0, "the target continues its recoil lunge during the act (got %s)" % fight.target.animationsNode.position)
	_check(fight.camera.offset == Vector2.ZERO, "a miss does not shake the camera (got %s)" % fight.camera.offset)
	_check(fight.camera.position == cameraPosition, "a miss keeps the focus frame (got %s, want %s)" % [fight.camera.position, cameraPosition])
	freeFight(fight)


## Both acting and target fighters hold their lunge/recoil until endAct settles
## them back to their rest poses.
func _test_end_act_leaves_the_recoil_alone() -> void:
	var fight = makeFight()
	fight.focus.beginAct(fight.acting, fight.target)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	fight.focus.onActResolved(fight.acting, fight.target, true)
	_check(fight.acting.animationsNode.position.x > 0.0 and fight.target.animationsNode.position.x > 0.0, "both fighters lunge during the act (got %s / %s)" % [fight.acting.animationsNode.position, fight.target.animationsNode.position])
	fight.focus.endAct()
	await create_timer(AnimationsScript.SETTLE_TIME + 0.2).timeout
	_check(fight.target.animationsNode.position.distance_to(Vector2.ZERO) < 0.5, "the target recoil settles when the act ends (got %s)" % fight.target.animationsNode.position)
	_check(fight.acting.animationsNode.position.distance_to(Vector2.ZERO) < 0.5, "the acting fighter settles when the act ends (got %s)" % fight.acting.animationsNode.position)
	freeFight(fight)


## The full act: scale only the participants, defocus and lunge; recoil and
## shake on the impact frame; then everything returns to its authored rest state.
func _test_act_focus_lifecycle() -> void:
	var fight = makeFight()
	var actingScale = fight.acting.animationsNode.scale
	var targetScale = fight.target.animationsNode.scale
	var bystanderScale = fight.bystander.animationsNode.scale
	var actingPosition = fight.acting.position
	var targetPosition = fight.target.position
	var bystanderPosition = fight.bystander.position
	fight.focus.beginAct(fight.acting, fight.target)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	_check(fight.camera.zoom == REST_ZOOM and fight.camera.position == REST_POSITION, "focus leaves the camera at its rest zoom and position (got %s / %s)" % [fight.camera.zoom, fight.camera.position])
	_check(fight.acting.animationsNode.scale.distance_to(actingScale * AnimationsScript.FOCUS_ZOOM) < 0.001, "the acting fighter scales up from its authored scale (got %s)" % fight.acting.animationsNode.scale)
	_check(fight.target.animationsNode.scale.distance_to(targetScale * AnimationsScript.FOCUS_ZOOM) < 0.001, "the target scales up without losing its non-uniform authored scale (got %s)" % fight.target.animationsNode.scale)
	_check(fight.bystander.animationsNode.scale == bystanderScale, "a non-targeted fighter does not zoom (got %s)" % fight.bystander.animationsNode.scale)
	_check(is_equal_approx(fight.ui.focus, FocusManagerScript.BLUR_AMOUNT), "the background defocuses while the act plays (got %s)" % fight.ui.focus)
	_check(fight.acting.animationsNode.position.x > 0.0, "the acting fighter lunges toward the target (got %s)" % fight.acting.animationsNode.position)
	_check(screenPosition(fight.acting).distance_to(FocusManagerScript.PLAYER_FOCUS_POSITION) < 0.5, "the player fighter moves to the left anchor (got %s)" % screenPosition(fight.acting))
	_check(screenPosition(fight.target).distance_to(FocusManagerScript.ENEMY_FOCUS_POSITION) < 0.5, "the enemy fighter moves to the right anchor (got %s)" % screenPosition(fight.target))
	_check(fight.bystander.position == bystanderPosition, "a bystander does not move to a focus anchor (got %s)" % fight.bystander.position)
	_check(!fight.acting.get_node("HPIndicator").visible and !fight.target.get_node("HPIndicator").visible, "character HP bars hide while the act plays")
	_check(!fight.acting.get_node("Highlight2").visible and !fight.target.get_node("Highlight2").visible, "character highlights hide while the act plays")
	fight.focus.onActResolved(fight.acting, fight.target, true)
	# The kick lands synchronously and eases out over SHAKE_TIME, so it has to
	# be read before the recoil has had time to play out.
	_check(fight.camera.offset != Vector2.ZERO, "a landed hit kicks the camera (got %s)" % fight.camera.offset)
	await create_timer(0.12).timeout
	_check(fight.target.animationsNode.position.x > 0.0, "a landed hit recoils the target away from the attacker (got %s)" % fight.target.animationsNode.position)
	fight.focus.endAct()
	await create_timer(FocusManagerScript.FOCUS_OUT_TIME + 0.6).timeout
	_check(fight.camera.zoom == REST_ZOOM and fight.camera.position == REST_POSITION, "the camera remains at rest after the act (got %s / %s)" % [fight.camera.zoom, fight.camera.position])
	_check(fight.acting.animationsNode.scale.distance_to(actingScale) < 0.001 and fight.target.animationsNode.scale.distance_to(targetScale) < 0.001, "both participants return to their authored scales (got %s / %s)" % [fight.acting.animationsNode.scale, fight.target.animationsNode.scale])
	_check(fight.bystander.animationsNode.scale == bystanderScale, "the bystander remains unchanged after the act (got %s)" % fight.bystander.animationsNode.scale)
	_check(is_equal_approx(fight.ui.focus, 0.0), "the background sharpens again (got %s)" % fight.ui.focus)
	_check(fight.acting.animationsNode.position.distance_to(Vector2.ZERO) < 0.5, "the acting fighter settles back to rest (got %s)" % fight.acting.animationsNode.position)
	_check(fight.acting.position == actingPosition and fight.target.position == targetPosition, "both fighters return to their exact original positions")
	_check(fight.acting.get_node("HPIndicator").visible and fight.target.get_node("HPIndicator").visible, "character HP bars reappear after the act")
	_check(fight.acting.get_node("Highlight2").visible and !fight.target.get_node("Highlight2").visible, "character highlights return to their pre-act visibility")
	_check(fight.camera.offset == Vector2.ZERO, "the hit shake settles (got %s)" % fight.camera.offset)
	freeFight(fight)


## Reversing which fighter acts must not swap the team positions. The enemy
## actor stays on the right and lunges left toward the player.
func _test_team_focus_positions() -> void:
	var fight = makeFight()
	var actingPosition = fight.target.position
	var targetPosition = fight.acting.position
	var actingSprite = AnimatedSprite2D.new()
	actingSprite.name = "AnimationSprite"
	actingSprite.flip_h = false
	fight.target.animationsNode.add_child(actingSprite)
	fight.focus.beginAct(fight.target, fight.acting)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	_check(screenPosition(fight.target).distance_to(FocusManagerScript.ENEMY_FOCUS_POSITION) < 0.5, "an acting enemy remains on the right (got %s)" % screenPosition(fight.target))
	_check(screenPosition(fight.acting).distance_to(FocusManagerScript.PLAYER_FOCUS_POSITION) < 0.5, "a targeted player remains on the left (got %s)" % screenPosition(fight.acting))
	_check(fight.target.animationsNode.position.x < 0.0, "the enemy actor lunges left toward the player (got %s)" % fight.target.animationsNode.position)
	_check(actingSprite.flip_h, "the enemy actor faces left in the fixed focus layout")
	fight.focus.endAct()
	await create_timer(FocusManagerScript.FOCUS_OUT_TIME + 0.6).timeout
	_check(fight.target.position == actingPosition and fight.acting.position == targetPosition, "reversed participants return to their exact original positions")
	_check(!actingSprite.flip_h, "the actor's authored facing is restored after the act")
	freeFight(fight)


func _test_self_target_uses_center() -> void:
	var fight = makeFight()
	fight.focus.beginAct(fight.target, fight.target)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	_check(screenPosition(fight.target).distance_to(FocusManagerScript.SOLO_FOCUS_POSITION) < 0.5, "a self-targeted enemy uses the center anchor (got %s)" % screenPosition(fight.target))
	fight.focus.endAct()
	await create_timer(FocusManagerScript.FOCUS_OUT_TIME + 0.15).timeout
	freeFight(fight)


func _test_same_team_targets_use_inner_slots() -> void:
	var fight = makeFight()
	fight.shootout.turnManager.sides["target"] = "player team"
	fight.focus.beginAct(fight.acting, fight.target)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	_check(screenPosition(fight.acting).distance_to(FocusManagerScript.PLAYER_FOCUS_POSITION) < 0.5, "a player actor uses the outer left slot")
	_check(screenPosition(fight.target).distance_to(FocusManagerScript.PLAYER_INNER_FOCUS_POSITION) < 0.5, "a distinct player target uses the inner left slot")
	fight.focus.endAct()
	await create_timer(FocusManagerScript.FOCUS_OUT_TIME + 0.15).timeout
	fight.shootout.turnManager.sides["acting"] = "enemy team"
	fight.shootout.turnManager.sides["target"] = "enemy team"
	fight.focus.beginAct(fight.target, fight.acting)
	await create_timer(FocusManagerScript.FOCUS_IN_TIME + 0.15).timeout
	_check(screenPosition(fight.target).distance_to(FocusManagerScript.ENEMY_FOCUS_POSITION) < 0.5, "an enemy actor uses the outer right slot")
	_check(screenPosition(fight.acting).distance_to(FocusManagerScript.ENEMY_INNER_FOCUS_POSITION) < 0.5, "a distinct enemy target uses the inner right slot")
	fight.focus.endAct()
	await create_timer(FocusManagerScript.FOCUS_OUT_TIME + 0.15).timeout
	freeFight(fight)


func screenPosition(actor: Node2D) -> Vector2:
	return root.get_canvas_transform() * actor.global_position


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)

