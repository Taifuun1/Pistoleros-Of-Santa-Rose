extends TextureRect

@onready var player: Area2D
var player_sprite: AnimatedSprite2D
var bullets = []
var bears = []
var bear_projectiles = []
var score = 0
var spawn_timer = 0.0
var shoot_cooldown_timer = 0.0
var cooldown_bar: ProgressBar
const SPAWN_INTERVAL = 2.5
const SHOOT_COOLDOWN = 1.5

const MINIGAME_DURATION = 60.0
var time_remaining = MINIGAME_DURATION
var game_over = false

var time_label: Label
var score_label: Label

const PLAYER_SPRITESHEET = "res://Assets/Bear Hunt/Hunting/PlayerMinigame.png"
const PLAYER_FRAME_COUNT = 2
const PLAYER_ANIMATION_SPEED = 10.0
const PLAYER_MOVE_SPEED = 150.0

const BEAR_SPRITESHEET = "res://Assets/Bear Hunt/Hunting/PolarbearWalk.png"
const BEAR_FRAME_COUNT = 4
const BEAR_ANIMATION_SPEED = 8.0
const BEAR_SPEED = 80.0
const BEAR_PROJECTILE_SPEED = 100.0
const BEAR_SHOOT_INTERVAL = 3.0

const BULLET_TEXTURE = "res://Assets/Bear Hunt/Hunting/BulletTiny.png"
const BULLET_SPEED = 250.0
const BEAR_PROJECTILE_TEXTURE = "res://Assets/Bear Hunt/Hunting/SnowballTiny.png"
const POINTS_PER_HIT = -5

# Lose condition: player is eliminated when hit this many times
const MAX_PLAYER_HITS = 5
var player_hits = 0

func _ready():
	# Create UI labels
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.position = Vector2(0, 0)
	add_child(time_label)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.position = Vector2(0, 40)
	add_child(score_label)

	# Create player as Area2D for collision detection
	player = Area2D.new()
	player_sprite = AnimatedSprite2D.new()
	
	# Create SpriteFrames with animation
	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("idle")
	spriteFrames.set_animation_loop("idle", true)
	spriteFrames.set_animation_speed("idle", PLAYER_ANIMATION_SPEED)
	
	# Load spritesheet and create texture atlas frames
	var spritesheet = load(PLAYER_SPRITESHEET)
	var frameWidth = spritesheet.get_width() / PLAYER_FRAME_COUNT
	var frameHeight = spritesheet.get_height()
	
	for frame in range(PLAYER_FRAME_COUNT):
		var atlas = AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(frame * frameWidth, 0, frameWidth, frameHeight)
		spriteFrames.add_frame("idle", atlas)
	
	player_sprite.sprite_frames = spriteFrames
	player_sprite.play("idle")
	player.add_child(player_sprite)
	
	# Add collision shape to player
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	collision_shape.shape = rect
	player.add_child(collision_shape)
	
	player.position = Vector2(220, 120)  # Position on right side to shoot bears
	player.set_meta("is_player", true)
	add_child(player)
	
	# Create cooldown indicator bar
	cooldown_bar = ProgressBar.new()
	cooldown_bar.max_value = SHOOT_COOLDOWN
	cooldown_bar.value = 0
	cooldown_bar.modulate = Color.RED
	cooldown_bar.visible = false
	cooldown_bar.show_percentage = false
	cooldown_bar.size = Vector2(30, 3)
	add_child(cooldown_bar)

func _process(delta):
	if game_over:
		return

	# Update countdown timer
	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_end_minigame(score)
		return

	time_label.text = "Time: %.1f" % time_remaining
	score_label.text = "Score: %d  Lives: %d" % [score, MAX_PLAYER_HITS - player_hits]

	# Move player up/down
	var move_speed = PLAYER_MOVE_SPEED
	if Input.is_action_pressed("MOVE_UP"):
		player.position.y -= move_speed * delta
	if Input.is_action_pressed("MOVE_DOWN"):
		player.position.y += move_speed * delta
	
	# Clamp player position (playable area is 0-240 vertically)
	player.position.y = clamp(player.position.y, 20, 220)
	
	# Update cooldown and position bar above player
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
		cooldown_bar.value = SHOOT_COOLDOWN - shoot_cooldown_timer
		cooldown_bar.position = player.position + Vector2(-15, -15)
	else:
		cooldown_bar.visible = false
	
	# Shoot on space or mouse click
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_select"):
		shoot()
	
	# Spawn bears on interval
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL:
		for i in range(randi() % 3 + 1):
			spawn_bear()
		spawn_timer = 0.0

func shoot():
	# Check if still on cooldown
	if shoot_cooldown_timer > 0:
		return
	
	# Reset cooldown
	shoot_cooldown_timer = SHOOT_COOLDOWN
	cooldown_bar.visible = true
	cooldown_bar.value = 0
	
	var bullet = Area2D.new()
	var bullet_sprite = Sprite2D.new()
	bullet_sprite.texture = load(BULLET_TEXTURE)
	bullet.add_child(bullet_sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 2
	collision_shape.shape = circle
	bullet.add_child(collision_shape)
	
	bullet.position = player.position + Vector2(-15, 0)
	bullet.set_meta("velocity", Vector2(-BULLET_SPEED, 0))
	bullet.set_meta("is_bullet", true)
	bullets.append(bullet)
	add_child(bullet)
	
	# Connect collision detection
	bullet.connect("area_entered", Callable(self, "_on_bullet_hit").bind(bullet))

func spawn_bear():
	var bear = AnimatedSprite2D.new()
	
	# Create SpriteFrames with animation
	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("walk")
	spriteFrames.set_animation_loop("walk", true)
	spriteFrames.set_animation_speed("walk", BEAR_ANIMATION_SPEED)
	
	# Load spritesheet and create texture atlas frames
	var spritesheet = load(BEAR_SPRITESHEET)
	var frameWidth = spritesheet.get_width() / BEAR_FRAME_COUNT
	var frameHeight = spritesheet.get_height()
	
	for frame in range(BEAR_FRAME_COUNT):
		var atlas = AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(frame * frameWidth, 0, frameWidth, frameHeight)
		spriteFrames.add_frame("walk", atlas)
	
	bear.sprite_frames = spriteFrames
	bear.play("walk")
	
	# Wrap in Area2D for collision
	var bear_area = Area2D.new()
	bear_area.add_child(bear)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(24, 14)
	collision_shape.shape = rect
	bear_area.add_child(collision_shape)
	
	# Random spawn position from sides
	var y_pos = randf_range(30, 210)
	bear_area.position = Vector2(-20, y_pos)
	
	# Generate random path pattern (a few waypoints)
	var waypoints = [Vector2(80, y_pos)]  # First waypoint in middle
	
	# Add 1-2 random turns
	if randf() > 0.5:
		waypoints.append(Vector2(80, randf_range(40, 200)))
	
	# Exit point
	waypoints.append(Vector2(260, randf_range(30, 210)))
	
	bear_area.set_meta("waypoints", waypoints)
	bear_area.set_meta("current_waypoint", 0)
	bear_area.set_meta("is_bear", true)
	bear_area.set_meta("health", 1)
	bear_area.set_meta("shoot_timer", BEAR_SHOOT_INTERVAL)
	bears.append(bear_area)
	add_child(bear_area)

func _spawn_bear_projectile(bear: Area2D, target: Area2D):
	var proj = Area2D.new()
	var proj_sprite = Sprite2D.new()
	proj_sprite.texture = load(BEAR_PROJECTILE_TEXTURE)
	proj.add_child(proj_sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 3
	collision_shape.shape = circle
	proj.add_child(collision_shape)
	
	# Calculate direction towards player
	var direction = (target.position - bear.position).normalized()
	
	proj.position = bear.position
	proj.set_meta("velocity", direction * BEAR_PROJECTILE_SPEED)
	proj.set_meta("is_bear_projectile", true)
	bear_projectiles.append(proj)
	add_child(proj)
	
	# Connect collision detection
	proj.connect("area_entered", Callable(self, "_on_bullet_hit").bind(proj))

func _physics_process(delta):
	# Move bullets
	for bullet in bullets:
		var vel = bullet.get_meta("velocity")
		bullet.position += vel * delta
		
		# Remove if off screen
		if bullet.position.x > 240 or bullet.position.x < 0 or bullet.position.y < 0 or bullet.position.y > 240:
			bullets.erase(bullet)
			bullet.queue_free()
	
	# Move bears
	var bears_to_remove = []
	for bear in bears:
		var waypoints = bear.get_meta("waypoints")
		var current_wp = bear.get_meta("current_waypoint")
		
		if current_wp < waypoints.size():
			var target = waypoints[current_wp]
			var direction = (target - bear.position).normalized()
			bear.position += direction * BEAR_SPEED * delta
			
			# Check if reached waypoint
			if bear.position.distance_to(target) < 5:
				bear.set_meta("current_waypoint", current_wp + 1)
		else:
			# Mark bear for removal
			bears_to_remove.append(bear)
			continue
		
		# Handle bear shooting
		var shoot_timer = bear.get_meta("shoot_timer")
		shoot_timer -= delta
		bear.set_meta("shoot_timer", shoot_timer)
		
		if shoot_timer <= 0:
			# Bear shoots at player
			_spawn_bear_projectile(bear, player)
			bear.set_meta("shoot_timer", BEAR_SHOOT_INTERVAL)
	
	# Remove exited bears
	for bear in bears_to_remove:
		if bear in bears:
			bears.erase(bear)
			bear.queue_free()
	
	# Move bear projectiles
	var projectiles_to_remove = []
	for proj in bear_projectiles:
		var vel = proj.get_meta("velocity")
		proj.position += vel * delta
		
		# Remove if off screen
		if proj.position.x > 240 or proj.position.x < 0 or proj.position.y < 0 or proj.position.y > 240:
			projectiles_to_remove.append(proj)
	
	# Remove off-screen projectiles
	for proj in projectiles_to_remove:
		if proj in bear_projectiles:
			bear_projectiles.erase(proj)
			proj.queue_free()

func _on_bullet_hit(area: Area2D, bullet: Area2D):
	if game_over:
		return
	if area.has_meta("is_bear") and area.get_meta("is_bear") and bullet.has_meta("is_bullet") and bullet.get_meta("is_bullet"):
		# Hit a bear
		score += 10
		print("Hit! Score: ", score)
		
		# Spawn particle effect at bear position
		_spawn_hit_particles(area.position)
		
		# Remove bullet and bear
		if bullet in bullets:
			bullets.erase(bullet)
			bullet.queue_free()
		
		if area in bears:
			bears.erase(area)
			area.queue_free()
	elif area == player and bullet.has_meta("is_bear_projectile") and bullet.get_meta("is_bear_projectile"):
		# Player hit by bear projectile
		player_hits += 1
		score += POINTS_PER_HIT
		score = max(0, score)  # Don't let score go below 0
		print("Player hit! Hits: ", player_hits, " Score: ", score)
		
		# Spawn particle effect at player position
		_spawn_hit_particles(player.position)
		
		# Remove projectile
		if bullet in bear_projectiles:
			bear_projectiles.erase(bullet)
			bullet.queue_free()

		# Lose condition: too many hits
		if player_hits >= MAX_PLAYER_HITS:
			print("Player eliminated! Game over.")
			_end_minigame(score)

func _end_minigame(points: int):
	if game_over:
		return
	game_over = true
	print("Hunting minigame ended. Points: ", points)
	time_label.text = "GAME OVER! Score: %d" % points

	# Store points in global
	Locations.minigamePoints["Hunting"] += points

	# Remove this minigame scene after a short delay so the player can see the score
	await get_tree().create_timer(2.0).timeout

	# Unpause the player
	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()

func _spawn_hit_particles(position: Vector2):
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.position = position
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.color = Color(0.9, 0.9, 1.0, 1.0)  # Light blue for snow
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = 60
	particles.initial_velocity_max = 120
	
	# Clean up particles after they finish
	var timer = Timer.new()
	timer.wait_time = particles.lifetime + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	add_child(timer)
	timer.start()
