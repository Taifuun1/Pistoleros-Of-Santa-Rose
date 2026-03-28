extends TextureRect

var objectType
var velocity: Vector2 = Vector2.ZERO
var parentScene: TextureRect

var robbingTextures = [
	"res://Assets/Gold Rush/Robbing/ProspectorBlue.png",
	"res://Assets/Gold Rush/Robbing/ProspectorGreen.png",
	"res://Assets/Gold Rush/Robbing/ProspectorPink.png",
	"res://Assets/Gold Rush/Robbing/ProspectorRed.png",
	"res://Assets/Gold Rush/Robbing/ProspectorYellow.png",
]

func _ready() -> void:
	# Select a random spritesheet for this instance
	var randomTexturePath = robbingTextures[randi() % robbingTextures.size()]
	texture = load(randomTexturePath)
	
	# Randomly flip for visual variation
	flip_h = randi() % 2 == 1
	flip_v = randi() % 2 == 1

func createRobbingObject(objectPosition: Vector2, objectTypeParam = null) -> void:
	position = objectPosition
	if objectTypeParam != null:
		objectType = objectTypeParam
