extends AnimationPlayer

var cutscene

var fade = null
var playerAction = false
var wait = true

var pendingAnimations: int = 0
var pendingMoves: int = 0


func _ready():
	initCutscene(Cutscene.cutsceneArc, Cutscene.cutsceneName)
	initCamera(cutscene.initialCameraPosition)
	$Fade.playAnimation("Fade In")

func initCutscene(cutsceneArc: String = "Pistoleros Regroup", cutsceneName: String = "Finch Pond") -> void:
	cutscene = load("res://Data/Cutscenes/{cutsceneArc}/{cutsceneName}.gd".format({ "cutsceneArc": cutsceneArc, "cutsceneName": cutsceneName.capitalize().replace(" ", "") })).new().data
	$Setting.add_child(load("res://Location/Locations/{cutsceneArc}/{cutsceneName}/{cutsceneNameNoWhitespace}.tscn".format({ "cutsceneArc": cutsceneArc, "cutsceneName": cutsceneName, "cutsceneNameNoWhitespace": cutsceneName.capitalize().replace(" ", "") })).instantiate())
	$Setting.get_children()[$Setting.get_child_count() - 1].get_node("Fade/CanvasLayer/ColorRect").visible = false
	for actorData in cutscene.actors:
		var actor = load("res://Actors/Cutscene/CutsceneActor.tscn").instantiate()
		actor.initCutsceneActor(actorData.type, actorData.name, actorData.position, false, "Idle")
		$Actors.add_child(actor)

func initCamera(position) -> void:
	$Camera2D.position = position

func _process(_delta):
	if !wait and !playerAction:
		advanceScene()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		$Dialog.hide()
		playerAction = false

# Returns the Animations node for a named actor.
func getActor(actorName: String) -> Node:
	return $Actors.get_node(actorName).get_node(actorName)

# Finds a node by name anywhere inside the $Setting subtree.
func getSettingNode(nodeName: String) -> Node:
	return _findNodeByName($Setting, nodeName)

func _findNodeByName(parent: Node, nodeName: String) -> Node:
	for child in parent.get_children():
		if child.name == nodeName:
			return child
		var found = _findNodeByName(child, nodeName)
		if found:
			return found
	return null

func advanceScene() -> void:
	var scene = cutscene.shots.pop_front()

	if scene == null:
		wait = true
		$Fade.playAnimation("Fade Out")
	else:
		match scene.object:
			"dialog":
				playerAction = true
				$Dialog.setDialog(scene.data.text)

			"camera":
				$Camera2D.position = scene.data.position

			"wait":
				wait = true
				$Waiter.start(scene.data.time)

			"animation":
				_playAnimationShot(scene.data)

			"particles":
				_playParticlesShot(scene.data)

			"move":
				_playMoveShot(scene.data)

# ── Animation shot ────────────────────────────────────────────────────────────

func _playAnimationShot(data: Dictionary) -> void:
	var blocking: bool = data.get("blocking", true)

	if blocking:
		wait = true
		pendingAnimations = data.animations.size()

	for entry in data.animations:
		var animNode = getActor(entry.actor)
		# One-shot if blocking so the animation doesn't loop forever;
		# non-one-shot if non-blocking (caller likely wants a looping animation).
		animNode.playAnimation(entry.animation, blocking)
		if blocking:
			# Connect a one-shot lambda that decrements the counter.
			animNode.get_node("AnimationPlayer").animation_finished.connect(
				_onAnimationShotFinished, CONNECT_ONE_SHOT
			)

	if !blocking:
		# Non-blocking: advance immediately so the next shot can run in parallel.
		advanceScene()

func _onAnimationShotFinished(_animName: StringName) -> void:
	pendingAnimations -= 1
	if pendingAnimations <= 0:
		pendingAnimations = 0
		wait = false

# ── Particles shot ────────────────────────────────────────────────────────────

func _playParticlesShot(data: Dictionary) -> void:
	var blocking: bool = data.get("blocking", false)
	var particleNode: Node

	match data.source:
		"setting":
			particleNode = getSettingNode(data.node)
		"actor":
			particleNode = getActor(data.actor).get_node(data.node)

	if particleNode == null:
		push_warning("Cutscene: particles node '%s' not found." % data.node)
		if !blocking:
			advanceScene()
		return

	particleNode.restart()
	particleNode.emitting = true

	if blocking:
		wait = true
		particleNode.finished.connect(_onParticlesShotFinished, CONNECT_ONE_SHOT)
	else:
		advanceScene()

func _onParticlesShotFinished() -> void:
	wait = false

# ── Move shot ─────────────────────────────────────────────────────────────────

func _playMoveShot(data: Dictionary) -> void:
	var blocking: bool = data.get("blocking", true)
	var duration: float = data.get("duration", 1.0)

	if blocking:
		wait = true
		pendingMoves = data.moves.size()

	for entry in data.moves:
		var actorNode = $Actors.get_node(entry.actor)
		var tween = create_tween()
		tween.tween_property(actorNode, "position", Vector2(entry.position), duration)
		if blocking:
			tween.finished.connect(_onMoveShotFinished, CONNECT_ONE_SHOT)

	if !blocking:
		advanceScene()

func _onMoveShotFinished() -> void:
	pendingMoves -= 1
	if pendingMoves <= 0:
		pendingMoves = 0
		wait = false

# ── Existing signal handlers ──────────────────────────────────────────────────

func _on_waiter_timeout() -> void:
	wait = false

func _on_fade_animation_finished(animationName: StringName) -> void:
	if animationName == "Fade Out":
		Locations.currentLocation = cutscene.nextLocation
		#Locations.currentQuest = cutscene.nextLocation
		get_tree().change_scene_to_file("res://Location/Locations/Location.tscn")
	wait = false
	advanceScene()
