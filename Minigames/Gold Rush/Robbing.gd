extends TextureRect

@onready var robbingObject = preload("res://Minigames/Gold Rush/RobbingObject.tscn")

var spawnTimer: Timer
var packSize: int = 3
var spawnInterval: float = 2.5
var objectLifetime: float = 5.5

var movementSpeed: float = 125.0
var spawnBounds: Rect2
var objectSize: float = 24.0

const MINIGAME_DURATION = 20.0
const POINTS_PER_ROBBER = 1
var time_remaining = MINIGAME_DURATION
var game_over = false
var score = 0

var activeRobbers: Array = []

var time_label: Label
var score_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var boundsSize = size
	if boundsSize.x <= 0 or boundsSize.y <= 0:
		boundsSize = Vector2(240, 240)
	spawnBounds = Rect2(Vector2.ZERO, boundsSize)

	time_label = Label.new()
	time_label.position = Vector2(0, 0)
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.z_index = 10
	add_child(time_label)

	score_label = Label.new()
	score_label.position = Vector2(0, 18)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.z_index = 10
	add_child(score_label)

	var spawnTimerInitial = Timer.new()
	add_child(spawnTimerInitial)
	spawnTimerInitial.wait_time = 1
	spawnTimerInitial.one_shot = true
	spawnTimerInitial.timeout.connect(_onSpawnTimerTimeout)
	spawnTimerInitial.start()

	spawnTimer = Timer.new()
	add_child(spawnTimer)
	spawnTimer.wait_time = spawnInterval
	spawnTimer.timeout.connect(_onSpawnTimerTimeout)
	spawnTimer.start()

func _onSpawnTimerTimeout() -> void:
	if not game_over:
		_spawnPack()

func _spawnPack() -> void:
	for i in range(packSize):
		_spawnRobbingObject()

func _spawnRobbingObject() -> void:
	var obj = robbingObject.instantiate()
	add_child(obj)
	activeRobbers.append(obj)
	obj.tree_exited.connect(_on_robber_tree_exited.bind(obj))

	var halfSize = objectSize / 2.0
	var spawnPos = Vector2(
		randf_range(spawnBounds.position.x + halfSize, spawnBounds.position.x + spawnBounds.size.x - halfSize - objectSize),
		randf_range(spawnBounds.position.y + halfSize, spawnBounds.position.y + spawnBounds.size.y - halfSize - objectSize)
	)
	obj.position = spawnPos
	obj.parentScene = self
	var angle = randf() * TAU
	obj.velocity = Vector2(cos(angle), sin(angle)) * movementSpeed

	var obj_ref = weakref(obj)
	get_tree().create_timer(objectLifetime).timeout.connect(func():
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(obj_ref.get_ref(), "scale", Vector2(0.0, 0.0), 0.2)
		tween.tween_property(obj_ref.get_ref(), "modulate:a", 0.0, 0.2)
		tween.finished.connect(func(): obj_ref.get_ref().queue_free())
	)

func _gui_input(event: InputEvent) -> void:
	if game_over:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return

	for child in get_children():
		if child is TextureRect and child.has_method("collect"):
			if Rect2(child.position, child.size).has_point(event.position):
				return

	for i in range(activeRobbers.size() - 1, -1, -1):
		var robber = activeRobbers[i]
		var frameSize = robber.get_frame_size()
		var rect = Rect2(robber.position - frameSize / 2.0, frameSize)
		if rect.has_point(event.position):
			robber.collect()
			break

func _process(delta: float) -> void:
	if game_over:
		return

	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_end_minigame(score)
		return

	time_label.text = "Time: %.1f" % time_remaining
	score_label.text = "Score: %d" % score

	for robber in activeRobbers:
		var halfSize = robber.get_frame_size() / 2.0
		var newPos = robber.position + robber.velocity * delta

		# Bounce off walls instead of getting stuck
		if newPos.x < spawnBounds.position.x + halfSize.x:
			newPos.x = spawnBounds.position.x + halfSize.x
			robber.velocity.x = abs(robber.velocity.x)
		elif newPos.x > spawnBounds.position.x + spawnBounds.size.x - halfSize.x:
			newPos.x = spawnBounds.position.x + spawnBounds.size.x - halfSize.x
			robber.velocity.x = -abs(robber.velocity.x)

		if newPos.y < spawnBounds.position.y + halfSize.y:
			newPos.y = spawnBounds.position.y + halfSize.y
			robber.velocity.y = abs(robber.velocity.y)
		elif newPos.y > spawnBounds.position.y + spawnBounds.size.y - halfSize.y:
			newPos.y = spawnBounds.position.y + spawnBounds.size.y - halfSize.y
			robber.velocity.y = -abs(robber.velocity.y)

		robber.position = newPos

func _on_robber_caught(robber: AnimatedSprite2D) -> void:
	activeRobbers.erase(robber)
	score += POINTS_PER_ROBBER

func _on_robber_tree_exited(robber: AnimatedSprite2D) -> void:
	activeRobbers.erase(robber)

func _on_collectible_collected(_collectibleType: String, value: int) -> void:
	score += value

func _end_minigame(points: int) -> void:
	if game_over:
		return
	game_over = true
	spawnTimer.stop()
	time_label.text = "TIME'S UP! Score: %d" % points

	Locations.minigamePoints["Robbing"] += points

	await get_tree().create_timer(2.0).timeout

	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()
