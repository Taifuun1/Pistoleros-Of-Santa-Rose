extends TextureRect

@onready var robbingObject = preload("res://Minigames/Gold Rush/RobbingObject.tscn")

# Spawn settings
var spawnTimer: Timer
var spawnInterval: float = 0.5  # Spawn a new object every 0.5 seconds
var objectLifetime: float = 3.0  # Objects disappear after 3 seconds
var maxObjectCount: int = 20  # Maximum concurrent objects
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
	if currentObjectCount < maxObjectCount:
		_spawnRobbingObject()

func _spawnRobbingObject() -> void:
	var obj = robbingObject.instantiate()
	add_child(obj)
	currentObjectCount += 1
	
	# Random spawn position within bounds
	var spawnPos = Vector2(
		randf_range(spawnBounds.position.x, spawnBounds.size.x),
		randf_range(spawnBounds.position.y, spawnBounds.size.y)
	)
	obj.position = spawnPos
	
	# Random movement direction (8 directions + slight variations)
	var angle = randf() * TAU
	var velocity = Vector2(cos(angle), sin(angle)) * movementSpeed
	obj.velocity = velocity
	obj.parentScene = self
	
	# Schedule disappearance
	await get_tree().create_timer(objectLifetime).timeout
	if is_instance_valid(obj):
		obj.queue_free()
		currentObjectCount -= 1

func _process(delta: float) -> void:
	# Move all robbing objects and keep them in bounds
	for child in get_children():
		if child is TextureRect and child.name == "RobbingObject":
			if child.get("velocity") != null:
				child.position += child.velocity * delta
				
				# Clamp position to stay within bounds
				child.position.x = clamp(child.position.x, spawnBounds.position.x, spawnBounds.size.x)
				child.position.y = clamp(child.position.y, spawnBounds.position.y, spawnBounds.size.y)
