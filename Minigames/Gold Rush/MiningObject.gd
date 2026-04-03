extends TextureRect

var objectType
var parentScene: TextureRect
var rockSize: float = 1.0  # Scale variation (0.7 to 1.3)
var rockRotation: float = 0.0  # Rotation variation

# Mining mechanics
var durability: int = 3  # Number of clicks needed to break
var isBroken: bool = false

# Collectible sprites that can be spawned
var collectibleSprites = [
	"res://Assets/Gold Rush/Panning/RockTiny.png",
	"res://Assets/Gold Rush/Panning/SoilTiny.png",
	"res://Assets/Gold Rush/Panning/GoldPieceTiny.png",
	"res://Assets/Gold Rush/Panning/GoldPieceTiny2.png",
	"res://Assets/Gold Rush/Panning/EmeraldTiny.png",
	"res://Assets/Gold Rush/Panning/SapphireTiny.png",
]

# Gem sprites (rarer, higher value)
var gemSprites = [
	"res://Assets/Gold Rush/Panning/Emerald.png",
	"res://Assets/Gold Rush/Panning/Sapphire.png",
	"res://Assets/Gold Rush/Panning/Morganite.png",
	"res://Assets/Gold Rush/Panning/RoseQuartz.png",
]

var miningTextures = [
	# Regular rocks
	"res://Assets/Gold Rush/Mining/Rock1.png",
	"res://Assets/Gold Rush/Mining/Rock2.png",
	"res://Assets/Gold Rush/Mining/Rock3.png",
	"res://Assets/Gold Rush/Mining/Rock4.png",
	"res://Assets/Gold Rush/Mining/Rock5.png",
	"res://Assets/Gold Rush/Mining/Rock6.png",
	# Gold rocks (rarer, more valuable)
	"res://Assets/Gold Rush/Mining/RockGold1.png",
	"res://Assets/Gold Rush/Mining/RockGold2.png",
	"res://Assets/Gold Rush/Mining/RockGold3.png",
	"res://Assets/Gold Rush/Mining/RockGold4.png",
	"res://Assets/Gold Rush/Mining/RockGold5.png",
	"res://Assets/Gold Rush/Mining/RockGold6.png",
]

func _ready() -> void:
	# Select a random rock sprite for this instance
	# Gold rocks are rarer (only 1/3 chance)
	var textureIndex: int
	if randi() % 3 == 0:  # 33% chance for gold rocks
		textureIndex = 6 + (randi() % 6)  # Gold rocks are indices 6-11
	else:
		textureIndex = randi() % 6  # Regular rocks are indices 0-5

	var randomTexturePath = miningTextures[textureIndex]
	texture = load(randomTexturePath)
	
	# Random size variation for visual variety
	rockSize = randf_range(0.8, 1.3)
	scale = Vector2(rockSize, rockSize)
	
	# Store if this is a gold rock for potential scoring
	objectType = "gold" if textureIndex >= 6 else "regular"
	
	# Set durability with variation
	# Gold rocks: 4-6 clicks, Regular rocks: 2-4 clicks
	if objectType == "gold":
		durability = randi_range(4, 6)
	else:
		durability = randi_range(2, 4)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not isBroken:
			mineRock()

func mineRock() -> void:
	durability -= 1

	# Spawn mining particles
	spawnMiningParticles()

	# Spawn collectible sprites
	spawnCollectibles()

	# Visual feedback - slight scale animation
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(rockSize - 0.1, rockSize - 0.1), 0.05)
	tween.tween_property(self, "scale", Vector2(rockSize, rockSize), 0.05)

	# Check if rock is broken
	if durability <= 0:
		isBroken = true
		# Spawn final collectibles (more valuable)
		spawnFinalCollectibles()
		# Emit break particles and remove object
		spawnBreakParticles()
		queue_free()

func spawnCollectibles() -> void:
	var numCollectibles = randi() % 3 + 2
	
	for i in range(numCollectibles):
		var collectible = createCollectible()
		if collectible:
			parentScene.add_child(collectible)

func spawnFinalCollectibles() -> void:
	var numValuables = randi() % 2 + 1
	
	for i in range(numValuables):
		var collectible = createValuableCollectible()
		if collectible:
			parentScene.add_child(collectible)

func spawnMiningParticles() -> void:
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position + get_local_mouse_position()
	
	# Configure particle system
	particles.amount = 8
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_sphere_radius = 5.0
	
	# Particle appearance - small dust particles
	particles.color = Color(0.8, 0.6, 0.4, 0.8)  # Brownish dust color
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	
	# Movement
	particles.direction = Vector2.UP
	particles.spread = 90.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	
	# Auto-remove after emission
	var timer = Timer.new()
	timer.wait_time = particles.lifetime + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	parentScene.add_child(timer)
	timer.start()

func spawnBreakParticles() -> void:
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position + Vector2(texture.get_width() * scale.x / 2, texture.get_height() * scale.y / 2)
	
	particles.amount = 15
	particles.lifetime = 0.1
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_sphere_radius = 12.0
	
	particles.color = Color(0.268, 0.568, 0.547, 0.95)
	particles.scale_amount_min = 1.8
	particles.scale_amount_max = 3.0
	
	particles.direction = Vector2.UP
	particles.spread = 180.0
	#particles.gravity = Vector2(0, 450)
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 280.0
	
	var timer = Timer.new()
	timer.wait_time = particles.lifetime + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	parentScene.add_child(timer)
	timer.start()

func createCollectible() -> Node:
	var collectible = TextureRect.new()
	var spritePath = collectibleSprites[randi() % collectibleSprites.size()]
	collectible.texture = load(spritePath)
	collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
	
	var xPos
	if randi() % 2 == 0:
		xPos = randf_range(-90, -25)
	else:
		xPos = randf_range(25, 90)
	var offset = Vector2(xPos, randf_range(-25, 25))
	collectible.position = position
	
	var targetX = clamp(position.x + offset.x, parentScene.spawnBounds.position.x + 12, parentScene.spawnBounds.position.x + parentScene.spawnBounds.size.x - collectible.size.x - 12)
	var targetY = clamp(position.y + offset.y, parentScene.spawnBounds.position.y + 12, parentScene.spawnBounds.position.y + parentScene.spawnBounds.size.y - collectible.size.y - 12)
	
	var tween1 = collectible.create_tween()
	tween1.tween_property(collectible, "position:y", min(offset.y - 50, position.y - 50), 0.2).as_relative().set_trans(Tween.TRANS_SINE)
	tween1.tween_property(collectible, "position:y", targetY, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween1.tween_callback(collectible.animatingDone)
	var tween2 = collectible.create_tween()
	tween2.tween_property(collectible, "position:x", targetX, 0.5).set_trans(Tween.TRANS_QUAD)
	
	return collectible

func createValuableCollectible() -> Node:
	var collectible = TextureRect.new()
	collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
	
	var spritePath: String
	if objectType == "gold" and randi() % 3 == 0:
		spritePath = gemSprites[randi() % gemSprites.size()]
	else:
		var valuables = ["res://Assets/Gold Rush/Panning/GoldPiece.png"]
		if randi() % 4 == 0:  # 25% chance for gem
			valuables.append_array(gemSprites)
		spritePath = valuables[randi() % valuables.size()]
	collectible.texture = load(spritePath)
	
	var xPos
	if randi() % 2 == 0:
		xPos = randf_range(-90, -25)
	else:
		xPos = randf_range(25, 90)
	var offset = Vector2(xPos, randf_range(-25, 25))
	collectible.position = position
	var targetX = clamp(position.x + offset.x, parentScene.spawnBounds.position.x + 12, parentScene.spawnBounds.position.x + parentScene.spawnBounds.size.x - collectible.size.x - 12)
	var targetY = clamp(position.y + offset.y, parentScene.spawnBounds.position.y + 12, parentScene.spawnBounds.position.y + parentScene.spawnBounds.size.y - collectible.size.y - 12)
	
	var tween1 = collectible.create_tween()
	tween1.tween_property(collectible, "position:y", min(offset.y - 50, position.y - 50), 0.25).as_relative()
	tween1.tween_property(collectible, "position:y", targetY, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween1.tween_callback(collectible.animatingDone)
	var tween2 = collectible.create_tween()
	tween2.tween_property(collectible, "position:x", targetX, 0.5)
	
	collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
	
	return collectible

func createMiningObject(objectPosition: Vector2, objectTypeParam = null) -> void:
	position = objectPosition
	if objectTypeParam != null:
		objectType = objectTypeParam
