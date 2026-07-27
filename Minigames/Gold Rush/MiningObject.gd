extends TextureRect

var objectType
var parentScene: TextureRect

var durability: int = 3
var isBroken: bool = false

var rockSprites = [
	"res://Assets/Gold Rush/Panning/Rock.png",
	"res://Assets/Gold Rush/Panning/RockTiny.png"
]

var soilSprites = [
	"res://Assets/Gold Rush/Panning/Soil.png",
	"res://Assets/Gold Rush/Panning/SoilTiny.png"
]

var goldSprites = [
	"res://Assets/Gold Rush/Panning/GoldPiece.png",
	"res://Assets/Gold Rush/Panning/GoldPieceTiny.png",
	"res://Assets/Gold Rush/Panning/GoldPieceTiny2.png",
]

var gemSprites = [
	"res://Assets/Gold Rush/Panning/Emerald.png",
	"res://Assets/Gold Rush/Panning/Sapphire.png",
	"res://Assets/Gold Rush/Panning/Morganite.png",
	"res://Assets/Gold Rush/Panning/RoseQuartz.png",
	"res://Assets/Gold Rush/Panning/EmeraldTiny.png",
	"res://Assets/Gold Rush/Panning/SapphireTiny.png",
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
	pivot_offset = size / 2
	
	var textureIndex: int
	if randi() % 9 == 0:
		textureIndex = 6 + (randi() % 6)
	else:
		textureIndex = randi() % 6

	var randomTexturePath = miningTextures[textureIndex]
	texture = load(randomTexturePath)
	
	objectType = "gold" if textureIndex >= 6 else "regular"
	
	if objectType == "gold":
		durability = randi_range(7, 10)
	else:
		durability = randi_range(3, 5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not isBroken:
			mineRock()

func mineRock() -> void:
	durability -= 1

	spawnMiningParticles()

	spawnCollectibles()

	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.05)

	if durability <= 0:
		isBroken = true
		spawnFinalCollectibles()
		spawnBreakParticles()
		queue_free()

func spawnCollectibles() -> void:
	var numCollectibles = randi() % 2 + 1
	
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

func _track_panning_material(collectibleType: String) -> void:
	if collectibleType == "rock" or collectibleType == "soil":
		if Locations.collectedPanningMaterials.has(collectibleType):
			Locations.collectedPanningMaterials[collectibleType] += 1

func spawnMiningParticles() -> void:
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position + get_local_mouse_position()
	
	particles.amount = 3
	particles.lifetime = 0.2
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_sphere_radius = 3.0
	
	particles.color = Color(0.8, 0.6, 0.4, 0.8)  # Brownish dust color
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	
	particles.direction = Vector2.UP
	particles.spread = 90.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 25.0
	particles.initial_velocity_max = 50.0
	
	particles.finished.connect(func(): particles.queue_free())

func spawnBreakParticles() -> void:
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position + Vector2(texture.get_width() * scale.x / 2, texture.get_height() * scale.y / 2)
	
	particles.amount = 15
	particles.lifetime = 0.175
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 3.0
	
	particles.color = Color(1.0, 0.0, 0.8, 0.275)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 125.0
	particles.initial_velocity_max = 150.0
	particles.explosiveness = 1
	
	particles.finished.connect(func(): particles.queue_free())

func createCollectible() -> Node:
	var collectible = TextureRect.new()
	var spritePath: String
	if objectType == "gold" and randi() % 3 == 0:
		spritePath = goldSprites[randi() % goldSprites.size()]
	elif randi() % 10 == 0:
		spritePath = goldSprites[randi() % goldSprites.size()]
	if spritePath == null or spritePath.is_empty():
		var materialType = "rock" if randi() % 2 == 0 else "soil"
		spritePath = rockSprites[randi() % rockSprites.size()] if materialType == "rock" else soilSprites[randi() % soilSprites.size()]
	collectible.texture = load(spritePath)
	collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
	collectible.collected.connect(Callable(parentScene, "_on_collectible_collected"))
	collectible.collected.connect(_on_panning_material_collected)
	
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
	
	var materialType = "rock" if randi() % 2 == 0 else "soil"
	var spritePath: String = rockSprites[randi() % rockSprites.size()] if materialType == "rock" else soilSprites[randi() % soilSprites.size()]
	if objectType == "gold" and randi() % 3 == 0:
		spritePath = goldSprites[randi() % goldSprites.size()]
	elif objectType == "gold" and randi() % 10 == 0:
		spritePath = gemSprites[randi() % gemSprites.size()]
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
	
	collectible.collected.connect(Callable(parentScene, "_on_collectible_collected"))
	collectible.collected.connect(_on_panning_material_collected)

	var tween1 = collectible.create_tween()
	tween1.tween_property(collectible, "position:y", min(offset.y - 50, position.y - 50), 0.25).as_relative()
	tween1.tween_property(collectible, "position:y", targetY, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween1.tween_callback(collectible.animatingDone)
	var tween2 = collectible.create_tween()
	tween2.tween_property(collectible, "position:x", targetX, 0.5)
	
	return collectible

func _on_panning_material_collected(collectibleType: String, _value: int) -> void:
	if collectibleType == "rock" or collectibleType == "soil":
		if Locations.collectedPanningMaterials.has(collectibleType):
			Locations.collectedPanningMaterials[collectibleType] += 1

func createMiningObject(objectPosition: Vector2, objectTypeParam = null) -> void:
	position = objectPosition
	if objectTypeParam != null:
		objectType = objectTypeParam
