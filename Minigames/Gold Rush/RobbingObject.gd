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

var animationSpeed: float = 10.0
var frameCount: int = 2

var robbingCollectibleTextures = [
	"res://Assets/Gold Rush/Robbing/Coin.png",
	"res://Assets/Gold Rush/Robbing/CoinPile.png",
	"res://Assets/Gold Rush/Robbing/CashStack.png",
]

var panningMaterialTextures = {
	"rock": [
		"res://Assets/Gold Rush/Panning/Rock.png",
		"res://Assets/Gold Rush/Panning/RockTiny.png"
	],
	"soil": [
		"res://Assets/Gold Rush/Panning/Soil.png",
		"res://Assets/Gold Rush/Panning/SoilTiny.png"
	]
}

func _ready() -> void:
	var randomTexturePath = robbingTextures[randi() % robbingTextures.size()]

	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("walk")
	spriteFrames.set_animation_loop("walk", true)
	spriteFrames.set_animation_speed("walk", animationSpeed)

	var spritesheet = load(randomTexturePath)
	var frameWidth = spritesheet.get_width() / frameCount
	var frameHeight = spritesheet.get_height()

	for animationFrame in range(frameCount):
		var atlas = AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(animationFrame * frameWidth, 0, frameWidth, frameHeight)
		spriteFrames.add_frame("walk", atlas)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	scale = Vector2(0.5, 0.5)
	modulate.a = 0.0
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

	sprite_frames = spriteFrames
	play("walk")

func get_frame_size() -> Vector2:
	if sprite_frames != null and sprite_frames.has_animation("walk"):
		var animationFrame = sprite_frames.get_frame_texture("walk", 0)
		if animationFrame != null:
			return animationFrame.get_size()
	return Vector2(24, 24)

func collect() -> void:
	if parentScene != null and parentScene.has_method("_on_robber_caught"):
		parentScene._on_robber_caught(self)
	_spawnRobbingCollectibles()
	_spawnCatchParticles()
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.0, 0.0), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func(): queue_free())

func _spawnRobbingCollectibles() -> void:
	var numCollectibles = randi() % 3 + 1
	var numCoinCollectibles = randi() % 4 + 3
	var bounds = parentScene.spawnBounds if parentScene != null else Rect2(Vector2.ZERO, Vector2(240, 240))
	
	# Low chance to drop a rock or soil piece for the panning minigame
	if randi() % 4 == 0:
		var materialType = "rock" if randi() % 2 == 0 else "soil"
		_spawnPanningMaterialCollectible(materialType, bounds)
	
	for i in range(numCoinCollectibles):
		var collectible = TextureRect.new()
		collectible.texture = load(robbingCollectibleTextures[0])
		var collectibleSize = collectible.texture.get_size() if collectible.texture != null else Vector2(24, 24)
		var halfSize = collectibleSize / 2.0
		var spawnOffset = Vector2(randf_range(-75, 75), randf_range(-25, 25))
		var rawPos = position + spawnOffset
		var clampedPos = Vector2(
			clampf(rawPos.x, bounds.position.x + halfSize.x, bounds.position.x + bounds.size.x - halfSize.x - collectibleSize.x),
			clampf(rawPos.y, bounds.position.y + halfSize.y, bounds.position.y + bounds.size.y - halfSize.y - collectibleSize.y)
		)
		collectible.position.x = position.x
		collectible.position.y = clampedPos.y
		collectible.pivot_offset = halfSize
		collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
		if parentScene != null and parentScene.has_method("_on_collectible_collected"):
			collectible.collected.connect(Callable(parentScene, "_on_collectible_collected"))
		parentScene.add_child(collectible)

		collectible.scale = Vector2(0.5, 0.5)
		var tween = collectible.create_tween()
		tween.tween_property(collectible, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(collectible.animatingDone)

		var tween1 = collectible.create_tween()
		tween1.tween_property(collectible, "position:y", min(offset.y - 20, position.y - 20), 0.2).as_relative().set_trans(Tween.TRANS_SINE)
		tween1.tween_property(collectible, "position:y", clampedPos.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween1.tween_callback(collectible.animatingDone)
		var tween2 = collectible.create_tween()
		tween2.tween_property(collectible, "position:x", clampedPos.x, 0.4).set_trans(Tween.TRANS_QUAD)
	for i in range(numCollectibles):
		var collectible = TextureRect.new()
		collectible.texture = load(robbingCollectibleTextures[1 if randi() % 2 == 0 else 2])
		var collectibleSize = collectible.texture.get_size() if collectible.texture != null else Vector2(24, 24)
		var halfSize = collectibleSize / 2.0
		var spawnOffset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		var rawPos = position + spawnOffset
		var clampedPos = Vector2(
			clampf(rawPos.x, bounds.position.x + halfSize.x, bounds.position.x + bounds.size.x - halfSize.x - collectibleSize.x),
			clampf(rawPos.y, bounds.position.y + halfSize.y, bounds.position.y + bounds.size.y - halfSize.y - collectibleSize.y)
		)
		collectible.position.x = position.x
		collectible.position.y = clampedPos.y
		collectible.pivot_offset = halfSize
		collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
		if parentScene != null and parentScene.has_method("_on_collectible_collected"):
			collectible.collected.connect(Callable(parentScene, "_on_collectible_collected"))
		parentScene.add_child(collectible)

		collectible.scale = Vector2(0.5, 0.5)
		var tween = collectible.create_tween()
		tween.tween_property(collectible, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(collectible.animatingDone)

		var tween1 = collectible.create_tween()
		tween1.tween_property(collectible, "position:y", min(offset.y - 20, position.y - 20), 0.2).as_relative().set_trans(Tween.TRANS_SINE)
		tween1.tween_property(collectible, "position:y", clampedPos.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween1.tween_callback(collectible.animatingDone)
		var tween2 = collectible.create_tween()
		tween2.tween_property(collectible, "position:x", clampedPos.x, 0.4).set_trans(Tween.TRANS_QUAD)

func _spawnPanningMaterialCollectible(materialType: String, bounds: Rect2) -> void:
	var collectible = TextureRect.new()
	collectible.texture = load(panningMaterialTextures[materialType][randi() % panningMaterialTextures[materialType].size()])
	var collectibleSize = collectible.texture.get_size() if collectible.texture != null else Vector2(24, 24)
	var halfSize = collectibleSize / 2.0
	var spawnOffset = Vector2(randf_range(-60, 60), randf_range(-25, 25))
	var rawPos = position + spawnOffset
	var clampedPos = Vector2(
		clampf(rawPos.x, bounds.position.x + halfSize.x, bounds.position.x + bounds.size.x - halfSize.x - collectibleSize.x),
		clampf(rawPos.y, bounds.position.y + halfSize.y, bounds.position.y + bounds.size.y - halfSize.y - collectibleSize.y)
	)
	collectible.position.x = position.x
	collectible.position.y = clampedPos.y
	collectible.pivot_offset = halfSize
	collectible.set_script(load("res://Minigames/Gold Rush/Collectible.gd"))
	if parentScene != null and parentScene.has_method("_on_collectible_collected"):
		collectible.collected.connect(Callable(parentScene, "_on_collectible_collected"))
	collectible.collected.connect(_on_panning_material_collected)
	parentScene.add_child(collectible)

	collectible.scale = Vector2(0.5, 0.5)
	var tween = collectible.create_tween()
	tween.tween_property(collectible, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(collectible.animatingDone)

	var tween1 = collectible.create_tween()
	tween1.tween_property(collectible, "position:y", min(offset.y - 20, position.y - 20), 0.2).as_relative().set_trans(Tween.TRANS_SINE)
	tween1.tween_property(collectible, "position:y", clampedPos.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween1.tween_callback(collectible.animatingDone)
	var tween2 = collectible.create_tween()
	tween2.tween_property(collectible, "position:x", clampedPos.x, 0.4).set_trans(Tween.TRANS_QUAD)

func _on_panning_material_collected(collectibleType: String, _value: int) -> void:
	if collectibleType == "rock" or collectibleType == "soil":
		if Locations.collectedPanningMaterials.has(collectibleType):
			Locations.collectedPanningMaterials[collectibleType] += 1

func _spawnCatchParticles() -> void:
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
	particles.finished.connect(func(): particles.queue_free())

func createRobbingObject(objectPosition: Vector2, objectTypeParam = null) -> void:
	position = objectPosition
	if objectTypeParam != null:
		objectType = objectTypeParam
