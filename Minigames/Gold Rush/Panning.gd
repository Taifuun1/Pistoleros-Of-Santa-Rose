extends TextureRect

@onready var panningObject = preload("res://Minigames/Gold Rush/PanningObject.tscn")
@onready var collectibleScript = preload("res://Minigames/Gold Rush/Collectible.gd")

const panningTextures = {
	"rock": [
		"res://Assets/Gold Rush/Panning/Rock.png",
		"res://Assets/Gold Rush/Panning/RockTiny.png"
	],
	"soil": [
		"res://Assets/Gold Rush/Panning/Soil.png",
		"res://Assets/Gold Rush/Panning/SoilTiny.png"
	]
}

const valuableTextures = {
	"gold": [
		"res://Assets/Gold Rush/Panning/GoldPiece.png",
		"res://Assets/Gold Rush/Panning/GoldPieceTiny.png"
	],
	"emerald": [
		"res://Assets/Gold Rush/Panning/Emerald.png",
		"res://Assets/Gold Rush/Panning/EmeraldTiny.png"
	],
	"sapphire": [
		"res://Assets/Gold Rush/Panning/Sapphire.png",
		"res://Assets/Gold Rush/Panning/SapphireTiny.png"
	],
	"morganite": [
		"res://Assets/Gold Rush/Panning/Morganite.png"
	]
}

const MATERIAL_TO_VALUABLE_DROP_RATES = {
	"rock": {"gold": 0.50, "gem": 0.05},
	"soil": {"gold": 0.25, "gem": 0.01}
}

const GEM_TYPES = ["emerald", "sapphire", "morganite"]
const MAX_PAN_OBJECTS = 50

var materialTypes = ["rock", "soil"]

const MINIGAME_DURATION = 60.0
var time_remaining = MINIGAME_DURATION
var game_over = false
var score = 0

var time_label: Label
var score_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	time_label = Label.new()
	time_label.position = Vector2(0, 0)
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_label)

	score_label = Label.new()
	score_label.position = Vector2(0, 18)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_label)

	_spawn_pan_objects()

func _spawn_pan_objects() -> void:
	var availableRocks = min(Locations.collectedPanningMaterials["rock"], MAX_PAN_OBJECTS)
	var availableSoil = min(Locations.collectedPanningMaterials["soil"], MAX_PAN_OBJECTS - availableRocks)
	
	# Clamp total to MAX_PAN_OBJECTS in case soil would push us over
	if availableRocks + availableSoil > MAX_PAN_OBJECTS:
		availableSoil = MAX_PAN_OBJECTS - availableRocks
	
	# Consume the materials that will be used
	Locations.collectedPanningMaterials["rock"] -= availableRocks
	Locations.collectedPanningMaterials["soil"] -= availableSoil
	
	var objectsToSpawn: Array = []
	for i in range(availableRocks):
		objectsToSpawn.append("rock")
	for i in range(availableSoil):
		objectsToSpawn.append("soil")
	objectsToSpawn.shuffle()
	
	for objectType in objectsToSpawn:
		var newPanningObject = panningObject.instantiate()
		add_child(newPanningObject)
		var texturePath = panningTextures[objectType][randi() % panningTextures[objectType].size()]
		newPanningObject.createPanningObject(load(texturePath), _generate_random_position(), objectType)
		newPanningObject.parentScene = self
		newPanningObject.object_broken.connect(_on_pan_object_broken)

func _generate_random_position() -> Vector2:
	return Vector2i((randi() % 16 + 2) * 12, (randi() % 16 + 2) * 12)

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

func _on_pan_object_broken(objectType: String, breakPosition: Vector2) -> void:
	var drop = _roll_valuable_drop(objectType)
	if drop != "":
		_spawn_valuable_collectible(drop, breakPosition)

func _roll_valuable_drop(objectType: String) -> String:
	var rates = MATERIAL_TO_VALUABLE_DROP_RATES.get(objectType, {})
	
	if randf() < rates.get("gem", 0.0):
		return GEM_TYPES[randi() % GEM_TYPES.size()]
	elif randf() < rates.get("gold", 0.0):
		return "gold"
	return ""

func _spawn_valuable_collectible(valuableType: String, spawnPosition: Vector2) -> void:
	var collectible = TextureRect.new()
	var textureOptions = valuableTextures[valuableType]
	collectible.texture = load(textureOptions[randi() % textureOptions.size()])
	collectible.set_script(collectibleScript)
	collectible.size = collectible.texture.get_size()
	collectible.pivot_offset = collectible.size / 2
	collectible.position = spawnPosition - collectible.size / 2
	collectible.collected.connect(_on_valuable_collected)
	add_child(collectible)

	collectible.scale = Vector2(0.5, 0.5)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(collectible, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(collectible, "modulate:a", 1.0, 0.2)
	
	collectible.animatingDone()

func _on_valuable_collected(_collectibleType: String, value: int) -> void:
	score += value
	print("Panning score: ", score)

func _end_minigame(points: int) -> void:
	if game_over:
		return
	game_over = true
	print("Panning minigame ended. Points: ", points)
	time_label.text = "TIME'S UP! Score: %d" % points

	# Store points in global
	Locations.minigamePoints["Panning"] += points

	# Remove this minigame scene after a short delay so the player can see the score
	await get_tree().create_timer(2.0).timeout

	# Unpause the player
	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()
