extends TextureRect

@onready var miningObject = preload("res://Minigames/Gold Rush/MiningObject.tscn")

var objectSize: float = 48.0
var initialObjectCount: int = 18

var spawnBounds: Rect2
var minSpawnDistance: float = 50.0

const MINIGAME_DURATION = 17.0
var time_remaining = MINIGAME_DURATION
var game_over = false
var score = 0

var time_label: Label
var score_label: Label

func _ready() -> void:
	spawnBounds = Rect2(Vector2.ZERO, size)

	time_label = Label.new()
	time_label.position = Vector2(0, 0)
	add_child(time_label)

	score_label = Label.new()
	score_label.position = Vector2(0, 18)
	add_child(score_label)

	for i in range(initialObjectCount):
		spawnMiningObjectAt(generateRandomPosition())

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

func _on_collectible_collected(collectibleType: String, value: int) -> void:
	score += value

func _end_minigame(points: int) -> void:
	if game_over:
		return
	game_over = true
	time_label.text = "TIME'S UP! Score: %d" % points

	Locations.minigamePoints["Mining"] += points

	await get_tree().create_timer(5.0).timeout

	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()
