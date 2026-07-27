extends TextureRect

@onready var player: Area2D
var projectiles = []
var collectibles = []
var pattern_count = 0
var MAX_PATTERNS
var current_pattern_index = 0
const PATTERNS = [
	"line",
	"shotgun",
	"rapid",
	"wave",
	"spiral",
	"double_spread",
	"burst_circle",
	"crossfire",
	"rain",
	"zigzag",
	"fan"
]

const PATTERN_CHAINS = {
	"line": ["line", "rapid"],
	"shotgun": ["wave", "double_spread"],
	"rapid": ["rapid", "rain"],
	"wave": ["wave", "shotgun"],
	"spiral": ["burst_circle", "fan"],
	"double_spread": ["crossfire", "zigzag"],
	"burst_circle": ["spiral", "shotgun"],
	"crossfire": ["zigzag"],
	"rain": ["rapid"],
	"zigzag": ["double_spread"],
	"fan": ["burst_circle"]
}
const CHAIN_DELAY = 1.25
var pattern_queue: Array[String] = []

const PLAYER_SPRITESHEET = "res://Assets/Bear Hunt/Dodging/PlayerMinigame.png"
const PLAYER_FRAME_COUNT = 2
const PLAYER_ANIMATION_SPEED = 6.0

const PELT_TEXTURE = "res://Assets/Bear Hunt/Hunting/Pelt.png"
const COLLECTIBLE_INTERVAL = 5.0
const COLLECTIBLE_FALL_SPEED = 90.0
const COLLECTIBLE_POINTS = 5

var game_over = false
var score = 0

var score_label: Label

func _ready():
	MAX_PATTERNS = randi() % 5 + 7
	
	player = Area2D.new()
	
	var player_sprite = AnimatedSprite2D.new()
	
	var spriteFrames = SpriteFrames.new()
	spriteFrames.add_animation("idle")
	spriteFrames.set_animation_loop("idle", true)
	spriteFrames.set_animation_speed("idle", PLAYER_ANIMATION_SPEED)
	
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
	player.position = Vector2(120, 180)
	add_child(player)
	
	var collision_shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 12
	capsule.height = 24
	collision_shape.shape = capsule
	player.add_child(collision_shape)
	
	player.connect("area_entered", Callable(self, "_on_area_entered"))
	
	_setup_ui()
	
	get_tree().create_timer(1.5).connect("timeout", Callable(self, "spawn_pattern").bind(PATTERNS[current_pattern_index]))
	_schedule_next_collectible()

func _setup_ui():
	score_label = Label.new()
	score_label.position = Vector2(4, 4)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_label)

func _process(delta):
	if game_over:
		return
	
	_update_ui()

	var move_speed = 200
	if Input.is_action_pressed("MOVE_LEFT"):
		player.position.x -= move_speed * delta
	if Input.is_action_pressed("MOVE_RIGHT"):
		player.position.x += move_speed * delta
	
	player.position.x = clamp(player.position.x, 20, 220)

func _update_ui():
	if score_label != null:
		score_label.text = "Score: %d" % score

func spawn_pattern(type: String, is_chain: bool = false):
	print(type)
	match type:
		"line":
			for i in range(2):
				spawn_projectile(Vector2(30 + i * 50, 30), Vector2(0, 80))
			for i in range(2):
				spawn_projectile(Vector2(160 + i * 50, 30), Vector2(0, 80))
		"shotgun":
			for i in range(7):
				var angle = PI/2 + (i - 3) * 0.40
				var velocity = Vector2(cos(angle), sin(angle)) * 100
				spawn_projectile(Vector2(120, 30), velocity)
		"rapid":
			for i in range(7):
				get_tree().create_timer(i * 0.35).connect("timeout", Callable(self, "spawn_single_rapid"))
		"wave":
			for i in range(6):
				var x = 30 if i % 2 == 0 else 210
				var delay = i * 0.2
				get_tree().create_timer(delay).connect("timeout", Callable(self, "_spawn_wave_projectile").bind(x))
		"spiral":
			for i in range(8):
				var angle = (i / 8.0) * TAU + randf_range(-0.2, 0.2)
				var velocity = Vector2(cos(angle), sin(angle)) * 80
				spawn_projectile(Vector2(120, 30), velocity)
		"double_spread":
			for i in range(4):
				get_tree().create_timer(i * 0.1).connect("timeout", Callable(self, "_spawn_double_projectile"))
		"burst_circle":
			for i in range(3):
				var angle = ((i + 2)/ 12.0) * TAU
				var velocity = Vector2(cos(angle), sin(angle)) * 90
				spawn_projectile(Vector2(70, 20), velocity)
			for i in range(3):
				var angle = ((i + 2)/ 12.0) * TAU
				var velocity = Vector2(cos(angle), sin(angle)) * 90
				spawn_projectile(Vector2(150, 20), velocity)
		"crossfire":
			for i in range(4):
				var delay = i * 0.18
				get_tree().create_timer(delay).connect("timeout", Callable(self, "_spawn_crossfire_pair"))
		"rain":
			for i in range(10):
				var delay = i * 0.22
				get_tree().create_timer(delay).connect("timeout", Callable(self, "_spawn_rain_projectile"))
		"zigzag":
			for i in range(5):
				var x = randf_range(20, 60) + i * 35
				var delay = i * 0.2
				get_tree().create_timer(delay).connect("timeout", Callable(self, "_spawn_zigzag_projectile").bind(x))
		"fan":
			for i in range(6):
				var delay = i * 0.18
				var angle = PI/2 + (i - 3) * 0.32
				var velocity = Vector2(cos(angle), sin(angle)) * 95
				get_tree().create_timer(delay).connect("timeout", Callable(self, "spawn_projectile").bind(Vector2(120, 30), velocity))
			for i in range(5, -1, -1):
				var delay = 4 * 0.18 + (i * 0.18)
				var angle = PI/2 + (i - 3) * 0.32
				var velocity = Vector2(cos(angle), sin(angle)) * 95
				get_tree().create_timer(delay).connect("timeout", Callable(self, "spawn_projectile").bind(Vector2(120, 30), velocity))
	
	if not is_chain:
		var chain_options = PATTERN_CHAINS.get(type, [])
		if not chain_options.is_empty():
			pattern_queue.append(chain_options[randi() % chain_options.size()])
	
	var pattern_delay = CHAIN_DELAY if not pattern_queue.is_empty() else 3.0
	get_tree().create_timer(pattern_delay).connect("timeout", Callable(self, "_on_pattern_finished").bind(is_chain))

func spawn_single_rapid():
	if game_over:
		return
	spawn_projectile(Vector2(randf_range(20, 220), 30), Vector2(0, 100))

func _spawn_wave_projectile(x: float):
	if game_over:
		return
	spawn_projectile(Vector2(x, 30), Vector2(randf_range(-5, 5), 120))

func _spawn_double_projectile():
	if game_over:
		return
	spawn_projectile(Vector2(30, 30), Vector2(randf_range(30, 100), 100))
	spawn_projectile(Vector2(210, 30), Vector2(randf_range(-90, -40), 100))

func _spawn_crossfire_pair():
	if game_over:
		return
	spawn_projectile(Vector2(10, 40 + randf_range(-10, 30)), Vector2(95, 60))
	spawn_projectile(Vector2(230, 40 + randf_range(-10, 30)), Vector2(-95, 60))

func _spawn_rain_projectile():
	if game_over:
		return
	var x = randf_range(30, 210)
	var speed = randf_range(90, 140)
	spawn_projectile(Vector2(x, 20), Vector2(0, speed))

func _spawn_zigzag_projectile(x: float):
	if game_over:
		return
	var proj = Area2D.new()
	var proj_sprite = Sprite2D.new()
	proj_sprite.texture = load("res://Assets/Bear Hunt/Dodging/Snowball.png")
	proj.add_child(proj_sprite)
	
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8
	collision_shape.shape = circle
	proj.add_child(collision_shape)
	
	proj.position = Vector2(x, 30)
	proj.set_meta("velocity", Vector2(0, 80))
	proj.set_meta("zigzag", true)
	proj.set_meta("zigzag_timer", 0.0)
	proj.set_meta("zigzag_direction", 1 if randi() % 2 == 0 else -1)
	proj.set_meta("is_projectile", true)
	projectiles.append(proj)
	add_child(proj)

func spawn_projectile(pos: Vector2, vel: Vector2):
	var proj = Area2D.new()
	var proj_sprite = Sprite2D.new()
	proj_sprite.texture = load("res://Assets/Bear Hunt/Dodging/Snowball.png")
	proj.add_child(proj_sprite)
	
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8
	collision_shape.shape = circle
	proj.add_child(collision_shape)
	
	proj.position = pos
	proj.set_meta("velocity", vel)
	proj.set_meta("is_projectile", true)
	projectiles.append(proj)
	add_child(proj)

func _schedule_next_collectible():
	if game_over:
		return
	var interval = COLLECTIBLE_INTERVAL + randf_range(-1.0, 1.5)
	get_tree().create_timer(interval).connect("timeout", Callable(self, "spawn_collectible"))

func spawn_collectible():
	if game_over:
		return
	
	var collectible = Area2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = load(PELT_TEXTURE)
	collectible.add_child(sprite)
	
	var collision_shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	var texture_size = sprite.texture.get_size()
	rectangle.size = texture_size * 0.8
	collision_shape.shape = rectangle
	collectible.add_child(collision_shape)
	
	collectible.position = Vector2(randf_range(30, 210), -20)
	collectible.set_meta("velocity", Vector2(0, COLLECTIBLE_FALL_SPEED))
	collectible.set_meta("is_collectible", true)
	collectibles.append(collectible)
	add_child(collectible)
	
	_schedule_next_collectible()

func _physics_process(delta):
	# Update projectiles
	for i in range(projectiles.size() - 1, -1, -1):
		var proj = projectiles[i]
		var vel = proj.get_meta("velocity")
		
		if proj.get_meta("zigzag", false):
			var timer = proj.get_meta("zigzag_timer") + delta
			var direction = proj.get_meta("zigzag_direction")
			if timer >= 0.25:
				timer = 0.0
				direction *= -1
				proj.set_meta("zigzag_direction", direction)
			proj.set_meta("zigzag_timer", timer)
			vel.x = direction * 60
		
		proj.position += vel * delta
		
		if proj.position.y > 240 or proj.position.y < -40 or proj.position.x < -40 or proj.position.x > 280:
			projectiles.remove_at(i)
			proj.queue_free()
	
	# Update collectibles
	for i in range(collectibles.size() - 1, -1, -1):
		var collectible = collectibles[i]
		var vel = collectible.get_meta("velocity")
		collectible.position += vel * delta
		
		if collectible.position.y > 260:
			collectibles.remove_at(i)
			collectible.queue_free()

func _on_area_entered(area: Area2D):
	if game_over:
		return
	
	if area.get_meta("is_projectile", false):
		print("Player hit! Game over.")
		_end_minigame(max(score + randi() % 4 + 2, 2))
	elif area.get_meta("is_collectible", false):
		_collect_pelt(area)

func _collect_pelt(collectible: Area2D):
	score += COLLECTIBLE_POINTS
	print("Pelt collected! Score: ", score)
	
	collectibles.erase(collectible)
	collectible.queue_free()

func _on_pattern_finished(_from_chain: bool):
	if game_over:
		return
	
	if not pattern_queue.is_empty():
		spawn_pattern(pattern_queue.pop_front(), true)
	else:
		next_pattern()

func next_pattern():
	if game_over:
		return
	pattern_count += 1
	if pattern_count >= MAX_PATTERNS:
		print("All patterns dodged! You win.")
		_end_minigame(score + randi() % 20 + 10)
	else:
		current_pattern_index = (current_pattern_index + 1) % PATTERNS.size()
		spawn_pattern(PATTERNS[current_pattern_index])

func _end_minigame(points: int):
	if game_over:
		return
	game_over = true
	print("Dodging minigame ended. Points: ", points)

	Locations.minigamePoints["Dodging"] += points

	await get_tree().create_timer(2.0).timeout

	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()
