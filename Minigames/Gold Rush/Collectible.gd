extends TextureRect

var collectibleType: String = "rock"  # rock, gold, gem
var value: int = 1
var pickupRange: float = 15.0  # Distance in pixels to pick up
var isCollected: bool = false
var animating = true

func _ready() -> void:
	var texturePath = texture.resource_path
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if "GoldPiece" in texturePath:
		collectibleType = "gold"
		value = 5
	elif "Emerald" in texturePath or "Sapphire" in texturePath or "Morganite" in texturePath or "RoseQuartz" in texturePath:
		collectibleType = "gem"
		value = 10
	else:
		collectibleType = "rock"
		value = 1

func _process(delta: float) -> void:
	if isCollected or animating:
		return

	# Check if mouse is close enough to pick up
	var mousePos = get_viewport().get_mouse_position() - size / 2
	var distance = global_position.distance_to(mousePos)

	if distance <= pickupRange:
		collect()

func collect() -> void:
	isCollected = true

	# Spawn collection particles
	spawnCollectionParticles()

	# Visual feedback - scale up and fade
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

	# TODO: Add to player inventory/score
	print("Collected ", collectibleType, " worth ", value)

	# You could emit a signal here to notify the parent scene
	# emit_signal("collectible_collected", collectibleType, value)

func spawnCollectionParticles() -> void:
	# Create sparkle/glow particles when collecting
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	# Position relative to this collectible's position within the parent
	particles.position = position + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	
	# Configure particle system
	particles.amount = 12
	particles.lifetime = 0.35  # Shorter duration
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 8.0
	
	# Particle appearance based on collectible type
	match collectibleType:
		"gem":
			particles.color = Color(0.2, 0.8, 1.0, 0.9)  # Blue sparkle for gems
		"gold":
			particles.color = Color(1.0, 0.9, 0.2, 0.9)  # Gold sparkle
		_:
			particles.color = Color(0.6, 0.6, 0.6, 0.8)  # Gray sparkle for rocks
	
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	
	# Movement - outward burst (faster)
	particles.direction = Vector2.UP
	particles.spread = 360.0  # Full circle
	particles.gravity = Vector2(0, -50)  # Slight upward drift
	particles.initial_velocity_min = 80.0  # Faster
	particles.initial_velocity_max = 150.0  # Faster
	
	# Auto-remove after emission
	var timer = Timer.new()
	timer.wait_time = particles.lifetime + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	add_child(timer)
	timer.start()

func animatingDone():
	mouse_filter = Control.MOUSE_FILTER_PASS
	animating = false
