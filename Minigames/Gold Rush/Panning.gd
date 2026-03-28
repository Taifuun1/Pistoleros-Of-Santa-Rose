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


func _ready() -> void:
	#if randi() % 5 == 0:
		#var newPanningObject = panningObject.instantiate()
		#add_child(newPanningObject)
		#newPanningObject.createPanningObject(load(panningObjects["morganite"]), Vector2i(randi() % 16 + 2, randi() % 16 + 2), "morganite")
	for count in range(randi() % 4 + 2):
		var newPanningObject = panningObject.instantiate()
		add_child(newPanningObject)
		newPanningObject.createPanningObject(load(panningObjects[valuables[randi() % valuables.size()]][randi() % 2]), Vector2i((randi() % 16 + 2) * 12, (randi() % 16 + 2) * 12), valuables[randi() % valuables.size()])
	for count in range(randi() % 50 + 225):
		var newPanningObject = panningObject.instantiate()
		add_child(newPanningObject)
		newPanningObject.createPanningObject(load(panningObjects[debree[randi() % debree.size()]][randi() % 2]), Vector2i((randi() % 16 + 2) * 12, (randi() % 16 + 2) * 12), debree[randi() % debree.size()])
