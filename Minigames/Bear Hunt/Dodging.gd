extends TextureRect

@onready var player: Area2D
var projectiles = []
var pattern_count = 0
const MAX_PATTERNS = 7
var current_pattern_index = 0
const PATTERNS = ["line", "shotgun", "rapid", "wave", "spiral", "double_spread", "burst_circle"]

const PLAYER_SPRITESHEET = "res://Assets/Bear Hunt/PlayerMinigame.png"
const PLAYER_FRAME_COUNT = 2
const PLAYER_ANIMATION_SPEED = 6.0

func _ready():
	# Create player as Area2D for collision detection
	player = Area2D.new()
	
	# Create AnimatedSprite2D child for spritesheet animation
	var player_sprite = AnimatedSprite2D.new()
	
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
	player.position = Vector2(120, 180)  # Position center-bottom
	add_child(player)
	
	# Add collision shape to player
	var collision_shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 12
	capsule.height = 24
	collision_shape.shape = capsule
	player.add_child(collision_shape)
	
	# Connect player hit detection
	player.connect("area_entered", Callable(self, "_on_projectile_hit"))
	
	# Start first pattern
	spawn_pattern(PATTERNS[current_pattern_index])

func _process(delta):
	# Move player left/right
	var move_speed = 200
	if Input.is_action_pressed("MOVE_LEFT"):
		player.position.x -= move_speed * delta
	if Input.is_action_pressed("MOVE_RIGHT"):
		player.position.x += move_speed * delta
	
	# Clamp player position (playable area is 0-240 horizontally)
	player.position.x = clamp(player.position.x, 20, 220)

func spawn_pattern(type: String):
	match type:
		"line":
			# Spawn 5 projectiles in a horizontal line
			for i in range(5):
				spawn_projectile(Vector2(40 + i * 40, 30), Vector2(0, 80))
		"shotgun":
			# Spawn projectiles in a spread
			for i in range(7):
				var angle = PI/2 + (i - 3) * 0.3
				var velocity = Vector2(cos(angle), sin(angle)) * 100
				spawn_projectile(Vector2(120, 30), velocity)
		"rapid":
			# Spawn projectiles rapidly
			for i in range(8):
				get_tree().create_timer(i * 0.15).connect("timeout", Callable(self, "spawn_single_rapid"))
		"wave":
			# Spawn projectiles in a wave pattern from alternating sides
			for i in range(6):
				var x = 30 if i % 2 == 0 else 210
				var delay = i * 0.2
				get_tree().create_timer(delay).connect("timeout", Callable(self, "_spawn_wave_projectile").bind(x))
		"spiral":
			# Spawn projectiles in a spiral pattern
			for i in range(8):
				var angle = (i / 8.0) * TAU + randf_range(-0.2, 0.2)
				var velocity = Vector2(cos(angle), sin(angle)) * 80
				spawn_projectile(Vector2(120, 30), velocity)
		"double_spread":
			# Spawn two rapid bursts from left and right
			for i in range(4):
				get_tree().create_timer(i * 0.1).connect("timeout", Callable(self, "_spawn_double_projectile").bind(i))
		"burst_circle":
			# Spawn projectiles in all directions
			for i in range(12):
				var angle = (i / 12.0) * TAU
				var velocity = Vector2(cos(angle), sin(angle)) * 90
				spawn_projectile(Vector2(120, 120), velocity)
	
	# Schedule next pattern after delay
	get_tree().create_timer(4.0).connect("timeout", Callable(self, "next_pattern"))

func spawn_single_rapid():
	spawn_projectile(Vector2(randf_range(20, 220), 30), Vector2(0, 100))

func _spawn_wave_projectile(x: float):
	spawn_projectile(Vector2(x, 30), Vector2(60 if x < 120 else -60, 120))

func _spawn_double_projectile(i: int):
	# Spawn from left side
	spawn_projectile(Vector2(30, 30), Vector2(randf_range(40, 100), 100))
	# Spawn from right side
	spawn_projectile(Vector2(210, 30), Vector2(randf_range(-100, -40), 100))

func spawn_projectile(pos: Vector2, vel: Vector2):
	var proj = Area2D.new()
	var proj_sprite = Sprite2D.new()
	proj_sprite.texture = load("res://Assets/Bear Hunt/Snowball.png")
	proj.add_child(proj_sprite)
	
	# Add collision shape to projectile
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8
	collision_shape.shape = circle
	proj.add_child(collision_shape)
	
	proj.position = pos
	proj.set_meta("velocity", vel)
	proj.set_meta("is_projectile", true)  # Tag as projectile for identification
	projectiles.append(proj)
	add_child(proj)

func _physics_process(delta):
	for proj in projectiles:
		var vel = proj.get_meta("velocity")
		proj.position += vel * delta
		
		# Remove if off screen (playable area is 0-240 both directions)
		if proj.position.y > 240 or proj.position.y < 0 or proj.position.x < 0 or proj.position.x > 240:
			projectiles.erase(proj)
			proj.queue_free()

func _on_projectile_hit(area: Area2D):
	if area.get_meta("is_projectile"):
		# Player hit by projectile
		print("Player hit! Game over.")
		# TODO: Handle game over (e.g., emit signal, change scene)

func next_pattern():
	pattern_count += 1
	if pattern_count >= MAX_PATTERNS:
		print("All patterns dodged! You win.")
		# TODO: Handle win (e.g., emit signal, change scene)
	else:
		current_pattern_index = (current_pattern_index + 1) % PATTERNS.size()
		spawn_pattern(PATTERNS[current_pattern_index])
