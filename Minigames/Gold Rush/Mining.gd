extends TextureRect

@onready var miningObject = preload("res://Minigames/Gold Rush/MiningObject.tscn")

var objectSize: float = 48.0
var initialObjectCount: int = 18

var spawnBounds: Rect2
var minSpawnDistance: float = 50.0  # Minimum distance from other rocks

func _ready() -> void:
	spawnBounds = Rect2(Vector2.ZERO, size)
	for i in range(initialObjectCount):
		spawnMiningObjectAt(generateRandomPosition())

func generateRandomPosition() -> Vector2:
	var spawnPos = Vector2.ZERO
	var attempts = 0
	
	while attempts < 10:
		spawnPos = Vector2(
			randf_range(spawnBounds.position.x + objectSize/2, spawnBounds.position.x + spawnBounds.size.x - objectSize/2),
			randf_range(spawnBounds.position.y + objectSize/2, spawnBounds.position.y + spawnBounds.size.y - objectSize/2)
		)
		
		spawnPos = spawnPos.clamp(spawnBounds.position + Vector2(objectSize/2, objectSize/2), 
							spawnBounds.position + spawnBounds.size - Vector2(objectSize/2, objectSize/2))
		
		if isValidSpawnPosition(spawnPos):
			return spawnPos
		
		attempts += 1
	
	return spawnPos

func isValidSpawnPosition(pos: Vector2) -> bool:
	for child in get_children():
		if child is TextureRect and child.has_meta("is_mining_object"):
			if child.global_position.distance_to(pos) < minSpawnDistance:
				return false
	
	return true

func spawnMiningObjectAt(positionParam: Vector2) -> void:
	var obj = miningObject.instantiate()
	add_child(obj)
	obj.position = positionParam
	obj.parentScene = self
	obj.set_meta("is_mining_object", true)
