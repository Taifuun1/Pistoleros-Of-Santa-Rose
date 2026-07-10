extends TextureRect

@onready var robbingObject = preload("res://Minigames/Gold Rush/RobbingObject.tscn")

# Spawn settings
var spawnTimer: Timer
var spawnInterval: float = 0.5  # Spawn a new object every 0.5 seconds
var objectLifetime: float = 3.0  # Objects disappear after 3 seconds
var currentObjectCount: int = 0

# Movement settings
var movementSpeed: float = 200.0
var spawnBounds: Rect2

const MINIGAME_DURATION = 60.0
var time_remaining = MINIGAME_DURATION
var game_over = false
var score = 0

var time_label: Label
var score_label: Label

func _ready() -> void:
	# Calculate spawn bounds (within the TextureRect area)
	spawnBounds = Rect2(Vector2.ZERO, size)

	# Create UI labels
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.position = Vector2(0, 0)
	add_child(time_label)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.position = Vector2(0, 40)
	add_child(score_label)

	# Create and setup spawn timer
	spawnTimer = Timer.new()
	add_child(spawnTimer)
	spawnTimer.wait_time = spawnInterval
	spawnTimer.timeout.connect(_onSpawnTimerTimeout)
	spawnTimer.start()

func _onSpawnTimerTimeout() -> void:
	if not game_over:
		_spawnRobbingObject()

func _spawnRobbingObject() -> void:
	var obj = robbingObject.instantiate()
	add_child(obj)
	currentObjectCount += 1
	
	# Random spawn position within bounds
	var spawnPos = Vector2(
		randf_range(spawnBounds.position.x, spawnBounds.position.x + spawnBounds.size.x),
		randf_range(spawnBounds.position.y, spawnBounds.position.y + spawnBounds.size.y)
	)
	obj.position = spawnPos
	obj.parentScene = self
	# Random movement direction (8 directions + slight variations)
	var angle = randf() * TAU
	var velocity = Vector2(cos(angle), sin(angle)) * movementSpeed
	obj.velocity = velocity
	
	# Schedule disappearance
	await get_tree().create_timer(objectLifetime).timeout
	if is_instance_valid(obj):
		obj.queue_free()
		currentObjectCount -= 1

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

	for child in get_children():
		if child is Node2D and child.name == "RobbingObject":
			if "velocity" in child:
				child.position += child.velocity * delta
				
				# Clamp position to stay within bounds
				child.position.x = clamp(child.position.x, spawnBounds.position.x, spawnBounds.position.x + spawnBounds.size.x - 24)
				child.position.y = clamp(child.position.y, spawnBounds.position.y, spawnBounds.position.y + spawnBounds.size.y - 24)

func _on_robber_caught() -> void:
	score += 10
	print("Robbing score: ", score)

func _on_collectible_collected(collectibleType: String, value: int) -> void:
	score += value
	print("Robbing collectible score: ", score)

func _end_minigame(points: int) -> void:
	if game_over:
		return
	game_over = true
	spawnTimer.stop()
	print("Robbing minigame ended. Points: ", points)
	time_label.text = "TIME'S UP! Score: %d" % points

	# Store points in global
	Locations.minigamePoints["Robbing"] += points

	# Remove this minigame scene after a short delay so the player can see the score
	await get_tree().create_timer(2.0).timeout

	# Unpause the player
	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()
