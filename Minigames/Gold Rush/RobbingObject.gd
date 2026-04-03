extends AnimatedSprite2D

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

var animationSpeed: float = 10.0  # Frames per second
var frameCount: int = 2  # Adjust based on your spritesheet

var robbingCollectibleTextures = [
	"res://Assets/Gold Rush/Robbing/Coin.png",
	"res://Assets/Gold Rush/Robbing/CoinPile.png",
	"res://Assets/Gold Rush/Robbing/CashStack.png",
]

func _ready() -> void:
	# Select a random spritesheet for this instance
	var randomTexturePath = robbingTextures[randi() % robbingTextures.size()]
	
	# Create SpriteFrames with animation
	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("walk")
	spriteFrames.set_animation_loop("walk", true)
	spriteFrames.set_animation_speed("walk", animationSpeed)
	
	# Load spritesheet and create texture atlas frames
	var spritesheet = load(randomTexturePath)
	var frameWidth = spritesheet.get_width() / frameCount
	var frameHeight = spritesheet.get_height()
	
	for frame in range(frameCount):
		var atlas = AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(frame * frameWidth, 0, frameWidth, frameHeight)
		spriteFrames.add_frame("walk", atlas)
	
	sprite_frames = spriteFrames
	play("walk")
	
	# Randomly flip for visual variation
	flip_h = randi() % 2 == 1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_collect()

func _collect() -> void:
	_spawnRobbingCollectibles()
	queue_free()

func _spawnRobbingCollectibles() -> void:
	var numCollectibles = randi() % 3 + 1
	for i in range(numCollectibles):
		var crates = TextureRect.new()
		crates.texture = load(robbingCollectibleTextures[randi() % robbingCollectibleTextures.size()])
		crates.size = Vector2(18, 18)
		crates.position = position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		crates.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
		parentScene.add_child(crates)

	# option: quick particle effect on break
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position
	particles.amount = 12
	particles.lifetime = 0.2
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.color = Color(1.0, 0.8, 0.2, 1.0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 80
	particles.initial_velocity_max = 140
	var timer = Timer.new()
	timer.wait_time = particles.lifetime + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	parentScene.add_child(timer)
	timer.start()

func createRobbingObject(objectPosition: Vector2, objectTypeParam = null) -> void:
	position = objectPosition
	if objectTypeParam != null:
		objectType = objectTypeParam
