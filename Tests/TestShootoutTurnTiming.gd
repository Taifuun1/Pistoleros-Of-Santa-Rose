extends Node

## Runs as a normal scene so project autoloads are available to Shootout.gd.
## Verifies turn cleanup is immediate but the next-actor hand-off waits for the
## presentation's between-act pause.

const ShootoutScene = preload("res://Shootout/Shootout.tscn")

var failures = 0
var actorDoneCount = 0


class FakeTurnManager:
	extends Node
	var advances = 0

	func currentActorName() -> String:
		return "Actor"

	func advanceTurn() -> void:
		advances += 1

	func checkBattleEnd() -> void:
		pass


class FakeEffectManager:
	extends Node
	var turnEnds = 0

	func onTurnEnd(_actorName: String) -> void:
		turnEnds += 1


class FakeRodeoManager:
	extends Node
	var triggers = 0

	func trigger(_triggerName: String, _payload: Dictionary) -> void:
		triggers += 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Shootout between-act timing ---")
	var shootout = ShootoutScene.instantiate()
	add_child(shootout)
	# Stop any enemy turn that _ready() kicked off on spawn before running the
	# controlled staging and timing checks.
	shootout.pendingResolution = false
	shootout.animationSequencer.clearActingCompletion()
	shootout.animationSequencer.steps.clear()
	shootout.animationSequencer.running = false
	shootout.focusManager.endAct()
	# Staging needs the real turn manager's team registry; replace it afterward
	# to isolate finishTurn from the normal next-turn dispatcher.
	await _check_focus_staging(shootout)
	await _check_reposition_slide(shootout)
	shootout.actorDone.disconnect(shootout._on_actor_done)
	shootout.actorDone.connect(_on_actor_done)
	var turns = FakeTurnManager.new()
	var effects = FakeEffectManager.new()
	var rodeo = FakeRodeoManager.new()
	shootout.add_child(turns)
	shootout.add_child(effects)
	shootout.add_child(rodeo)
	shootout.turnManager = turns
	shootout.effectManager = effects
	shootout.rodeoManager = rodeo
	shootout.focusManager = null
	shootout.battleOver = false

	shootout.finishTurn(null)
	_check(turns.advances == 1 and effects.turnEnds == 1 and rodeo.triggers == 1, "turn cleanup resolves before the pause")
	_check(actorDoneCount == 0, "the next actor is not signalled synchronously")
	await get_tree().create_timer(shootout.BETWEEN_ACTS_PAUSE - 0.1).timeout
	_check(actorDoneCount == 0, "the next actor still waits during the between-act pause")
	await get_tree().create_timer(0.15).timeout
	_check(actorDoneCount == 1, "the next actor is signalled once after the pause")

	shootout.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


## Exercise the fixed stage anchors with real actors and the real Camera2D.
func _check_focus_staging(shootout: Node) -> void:
	var actors = shootout.actorsRoot.get_children()
	if actors.size() < 2:
		_check(false, "the real scene has two fighters for focus staging")
		return
	var acting = actors[0]
	var target = actors[actors.size() - 1]
	var actingPosition = acting.position
	var targetPosition = target.position
	var actingAnimations = acting.getAnimations()
	var motionPosition = actingAnimations.position
	acting.showActorTurn()
	shootout.focusManager.beginAct(acting, target)
	await get_tree().create_timer(shootout.focusManager.FOCUS_IN_TIME + 0.15).timeout
	var canvas = shootout.get_viewport().get_canvas_transform()
	_check((canvas * acting.global_position).distance_to(shootout.focusManager.PLAYER_FOCUS_POSITION) < 0.5, "the real player fighter reaches the left screen anchor (got %s)" % (canvas * acting.global_position))
	_check((canvas * target.global_position).distance_to(shootout.focusManager.ENEMY_FOCUS_POSITION) < 0.5, "the real enemy fighter reaches the right screen anchor (got %s)" % (canvas * target.global_position))
	_check(actingAnimations.position.distance_to(motionPosition) > 0.5, "the real acting fighter visibly lunges during the move")
	_check(!acting.get_node("HPIndicator").visible and !target.get_node("HPIndicator").visible, "real character HP bars hide during the animation")
	_check(!acting.get_node("Highlight2").visible and !target.get_node("Highlight2").visible, "real character highlights hide during the animation")
	acting.showActorTurn()
	_check(!acting.get_node("Highlight2").visible, "emitting actorTurn mid-animation keeps the highlight hidden")
	shootout.focusManager.endAct()
	_check(acting.position == actingPosition and target.position == targetPosition, "real fighters return before turn cleanup can reposition them")
	_check(acting.get_node("HPIndicator").visible and target.get_node("HPIndicator").visible, "real character HP bars reappear when the animation ends")
	_check(acting.get_node("Highlight2").visible, "the active character highlight reappears when the animation ends")
	await get_tree().create_timer(0.6).timeout


## The Reposition Move ("Move forward/backward") slides the fighter to the new
## column instead of teleporting (Docs/Features and Issues.md: the Move move
## doesn't have an animation).
func _check_reposition_slide(shootout: Node) -> void:
	var walker = Node2D.new()
	shootout.add_child(walker)
	var fromPosition = Vector2(100, 222)
	var toPosition = Vector2(130, 222)
	walker.position = toPosition
	shootout.playRepositionSlide(walker, fromPosition)
	_check(walker.position == fromPosition, "the slide starts from the old column (got %s)" % walker.position)
	await get_tree().create_timer(0.15).timeout
	var midSlide = walker.position
	_check(midSlide != fromPosition and midSlide != toPosition, "the fighter is visibly mid-slide (got %s)" % midSlide)
	await get_tree().create_timer(shootout.REPOSITION_SLIDE_TIME + 0.1).timeout
	_check(walker.position.is_equal_approx(toPosition), "the fighter reaches the new column (got %s)" % walker.position)
	walker.free()


func _on_actor_done() -> void:
	actorDoneCount += 1


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
