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

func _ready() -> void:
	# Calculate spawn bounds (within the TextureRect area)
	spawnBounds = Rect2(Vector2.ZERO, size)
	
	# Create and setup spawn timer
	spawnTimer = Timer.new()
	add_child(spawnTimer)
	spawnTimer.wait_time = spawnInterval
	spawnTimer.timeout.connect(_onSpawnTimerTimeout)
	spawnTimer.start()

func _onSpawnTimerTimeout() -> void:
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
	for child in get_children():
		if child is Node2D and child.name == "RobbingObject":
			if "velocity" in child:
				child.position += child.velocity * delta
				
				# Clamp position to stay within bounds
				child.position.x = clamp(child.position.x, spawnBounds.position.x, spawnBounds.position.x + spawnBounds.size.x - 24)
				child.position.y = clamp(child.position.y, spawnBounds.position.y, spawnBounds.position.y + spawnBounds.size.y - 24)
