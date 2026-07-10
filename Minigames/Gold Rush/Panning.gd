extends TextureRect

@onready var panningObject = preload("res://Minigames/Gold Rush/PanningObject.tscn")

const panningObjects = {
	"rock": [
		"res://Assets/Gold Rush/Panning/Rock.png",
		"res://Assets/Gold Rush/Panning/RockTiny.png"
	],
	"soil": [
		"res://Assets/Gold Rush/Panning/Soil.png",
		"res://Assets/Gold Rush/Panning/SoilTiny.png"
	],
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
	"morganite": "res://Assets/Gold Rush/Panning/Morganite.png"
}

var debree = ["rock", "soil"]
var valuables = ["gold", "emerald", "sapphire"]

var filledTiles = {
	"edges": 20,
	"filled": []
}

const MINIGAME_DURATION = 60.0
var time_remaining = MINIGAME_DURATION
var game_over = false
var score = 0

var time_label: Label
var score_label: Label

func _ready() -> void:
	# Create UI labels
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.position = Vector2(0, 0)
	add_child(time_label)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.position = Vector2(0, 40)
	add_child(score_label)

	for count in range(randi() % 4 + 2):
		var newPanningObject = panningObject.instantiate()
		add_child(newPanningObject)
		newPanningObject.createPanningObject(load(panningObjects[valuables[randi() % valuables.size()]][randi() % 2]), Vector2i((randi() % 16 + 2) * 12, (randi() % 16 + 2) * 12), valuables[randi() % valuables.size()])
		newPanningObject.parentScene = self
	for count in range(randi() % 50 + 225):
		var newPanningObject = panningObject.instantiate()
		add_child(newPanningObject)
		newPanningObject.createPanningObject(load(panningObjects[debree[randi() % debree.size()]][randi() % 2]), Vector2i((randi() % 16 + 2) * 12, (randi() % 16 + 2) * 12), debree[randi() % debree.size()])
		newPanningObject.parentScene = self

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

func _on_valuable_collected(objectType: String) -> void:
	match objectType:
		"gold":
			score += 5
		"emerald", "sapphire":
			score += 10
		"morganite":
			score += 20
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
