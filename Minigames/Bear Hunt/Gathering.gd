extends TextureRect

const TILE_SIZE = 12
const MAZE_WIDTH = 20
const MAZE_HEIGHT = 20
const GRID_SCALE = 2
const MOVE_DURATION = 0.2  # Duration of tween for player movement
const BEAR_MOVE_DURATION = 0.5  # Bears move slower

const PLAYER_SPRITESHEET = "res://Assets/Bear Hunt/Gathering/PlayerMinigame.png"
const PLAYER_FRAME_COUNT = 2
const PLAYER_ANIMATION_SPEED = 6.0
const PLAYER_SPEED = 100.0

const BEAR_SPRITESHEET = "res://Assets/Bear Hunt/Gathering/PolarBearMinigame.png"
const BEAR_FRAME_COUNT = 4
const BEAR_ANIMATION_SPEED = 4.0
const BEAR_SPEED = 70.0

const LOOT_TEXTURES = [
	"res://Assets/Bear Hunt/Gathering/GatheringClaw.png",
	"res://Assets/Bear Hunt/Gathering/GatheringEgg.png",
	"res://Assets/Bear Hunt/Gathering/GatheringPelt.png",
]
const LOOT_VALUES = [10, 15, 20]

const WALL_TEXTURE = "res://Assets/Bear Hunt/Gathering/GatheringWall.png"

var player: Area2D
var player_sprite: AnimatedSprite2D
var player_tween: Tween
var player_input_direction = Vector2i.ZERO
var bears = []
var bear_tweens = {}
var loot = []
var walls = []
var score = 0
var time_remaining = 60.0
var game_over = false
var bear_spawn_timer = 0.0
const BEAR_SPAWN_INTERVAL = 5.0
const BEAR_SPAWN_MAX = 5

var time_label: Label
var score_label: Label

# Simple maze layout (0 = path, 1 = wall)
var maze = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,1],
	[1,0,1,1,0,1,0,1,0,1,1,1,0,1,1,0,1,1,0,1],
	[1,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1],
	[1,0,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,0,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,1,1,1,1,0,1,1,1,1,0,1,1,1,1,0,1,1,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,0,1,1,0,1,1,1,0,1,1,0,1,1,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1],
	[1,0,1,0,1,0,1,1,1,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,0,1,1,0,1,1,1,0,1,1,0,1,1,1,1,1,0,1],
	[1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,1,1,1,1,1,0,1,1,0,1,1,1,0,1,1,1,1,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]

func _ready():
	# Create UI labels
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	add_child(time_label)
	
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.position = Vector2(0, 40)
	add_child(score_label)
	
	# Build the maze walls
	_build_maze()
	
	# Create player
	_create_player()
	
	# Spawn initial loot
	_spawn_loot()
	
	# Spawn first bear
	_spawn_bear()

func _build_maze():
	for y in range(maze.size()):
		for x in range(maze[y].size()):
			if maze[y][x] == 1:
				var wall = Sprite2D.new()
				wall.texture = load(WALL_TEXTURE)
				wall.position = Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2)
				add_child(wall)

func _create_player():
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
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	collision_shape.shape = rect
	player.add_child(collision_shape)
	
	player.position = Vector2(TILE_SIZE * 1.5, TILE_SIZE * 1.5)  # Spawn near start
	player_tween = null
	add_child(player)

func _spawn_loot():
	# Spawn several loot items randomly in open paths
	for i in range(3):
		var x = randi() % (MAZE_WIDTH - 2) + 1
		var y = randi() % (MAZE_HEIGHT - 2) + 1
		
		# Keep trying until we find an open path
		while maze[y][x] == 1:
			x = randi() % (MAZE_WIDTH - 2) + 1
			y = randi() % (MAZE_HEIGHT - 2) + 1
		
		var loot_item = Area2D.new()
		var loot_sprite = Sprite2D.new()
		var loot_type = randi() % LOOT_TEXTURES.size()
		loot_sprite.texture = load(LOOT_TEXTURES[loot_type])
		loot_item.add_child(loot_sprite)
		
		# Add collision shape
		var collision_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 6
		collision_shape.shape = circle
		loot_item.add_child(collision_shape)
		
		loot_item.position = Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2)
		loot_item.set_meta("value", LOOT_VALUES[loot_type])
		loot_item.set_meta("is_loot", true)
		loot_item.connect("area_entered", Callable(self, "_on_loot_collected").bind(loot_item))
		loot.append(loot_item)
		add_child(loot_item)

func _spawn_bear():
	if bears.size() >= BEAR_SPAWN_MAX:
		return
	
	var bear = Area2D.new()
	var bear_sprite = AnimatedSprite2D.new()
	
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
	
	bear_sprite.sprite_frames = spriteFrames
	bear_sprite.play("walk")
	bear.add_child(bear_sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(10, 10)
	collision_shape.shape = rect
	bear.add_child(collision_shape)
	
	# Spawn at a random open location, preferably far from player
	var x = randi() % (MAZE_WIDTH - 2) + 1
	var y = randi() % (MAZE_HEIGHT - 2) + 1
	while maze[y][x] == 1:
		x = randi() % (MAZE_WIDTH - 2) + 1
		y = randi() % (MAZE_HEIGHT - 2) + 1
	
	bear.position = Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2)
	bear.set_meta("is_bear", true)
	bear.connect("area_entered", Callable(self, "_on_bear_caught").bind(bear))
	bears.append(bear)
	add_child(bear)

func _process(delta):
	if game_over:
		return
	
	# Update timer
	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_end_game()
	
	time_label.text = "Time: %.1f" % time_remaining
	score_label.text = "Score: %d" % score
	
	# Handle player input and tile-based movement (no diagonal movement)
	var input_direction = Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		input_direction.y -= 1
	elif Input.is_action_pressed("ui_down"):
		input_direction.y += 1
	elif Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	elif Input.is_action_pressed("ui_right"):
		input_direction.x += 1
	
	player_input_direction = input_direction
	
	if player_input_direction != Vector2i.ZERO and player_tween == null:
		var current_grid = _world_to_grid(player.position)
		var next_grid = current_grid + player_input_direction
		
		if _is_walkable(next_grid):
			var next_world = _grid_to_world(next_grid)
			player_tween = create_tween()
			player_tween.set_trans(Tween.TRANS_LINEAR)
			player_tween.set_ease(Tween.EASE_IN_OUT)
			player_tween.tween_property(player, "position", next_world, MOVE_DURATION)
			player_tween.finished.connect(func(): player_tween = null)
	
	# Spawn bears periodically
	bear_spawn_timer += delta
	if bear_spawn_timer >= BEAR_SPAWN_INTERVAL and bears.size() < BEAR_SPAWN_MAX:
		_spawn_bear()
		bear_spawn_timer = 0.0

func _physics_process(delta):
	# Move bears towards player using A*
	for bear in bears:
		if bear not in bear_tweens:
			var bear_pos = _world_to_grid(bear.position)
			var player_pos = _world_to_grid(player.position)
			var path = _astar_path(bear_pos, player_pos)
			
			if path.size() > 1:
				var next_pos = path[1]
				var world_pos = _grid_to_world(next_pos)
				_tween_bear_movement(bear, world_pos)

func _tween_bear_movement(bear: Area2D, target: Vector2):
	bear_tweens[bear] = create_tween()
	bear_tweens[bear].set_trans(Tween.TRANS_LINEAR)
	bear_tweens[bear].set_ease(Tween.EASE_IN_OUT)
	bear_tweens[bear].tween_property(bear, "position", target, BEAR_MOVE_DURATION)
	bear_tweens[bear].finished.connect(func(): bear_tweens.erase(bear))

func _world_to_grid(pos: Vector2) -> Vector2i:
	var grid_x = int(pos.x / TILE_SIZE)
	var grid_y = int(pos.y / TILE_SIZE)
	return Vector2i(grid_x, grid_y)

func _grid_to_world(grid: Vector2i) -> Vector2:
	return Vector2(grid.x * TILE_SIZE + TILE_SIZE/2, grid.y * TILE_SIZE + TILE_SIZE/2)

func _is_walkable(grid: Vector2i) -> bool:
	if grid.x < 0 or grid.x >= MAZE_WIDTH or grid.y < 0 or grid.y >= MAZE_HEIGHT:
		return false
	return maze[grid.y][grid.x] == 0

func _astar_path(start: Vector2i, goal: Vector2i) -> Array:
	var open_set = [start]
	var came_from = {}
	var g_score = {}
	var f_score = {}
	
	g_score[start] = 0
	f_score[start] = _heuristic(start, goal)
	
	while open_set.size() > 0:
		var current = open_set[0]
		var current_idx = 0
		
		for i in range(open_set.size()):
			if f_score.get(open_set[i], 999999) < f_score.get(current, 999999):
				current = open_set[i]
				current_idx = i
		
		if current == goal:
			return _reconstruct_path(came_from, current)
		
		open_set.remove_at(current_idx)
		
		for neighbor in _get_neighbors(current):
			var tentative_g = g_score.get(current, 999999) + 1
			
			if tentative_g < g_score.get(neighbor, 999999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, goal)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return [start]  # No path found, return start

func _get_neighbors(grid: Vector2i) -> Array:
	var neighbors = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		var neighbor = grid + dir
		if _is_walkable(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]
	while current in came_from:
		current = came_from[current]
		path.insert(0, current)
	return path

func _on_loot_collected(area: Area2D, loot_item: Area2D):
	if area == player and loot_item.get_meta("is_loot"):
		var value = loot_item.get_meta("value")
		score += value
		print("Collected loot! +", value, " Score: ", score)
		
		# Spawn particle effect
		_spawn_pickup_particles(loot_item.position)
		
		if loot_item in loot:
			loot.erase(loot_item)
			loot_item.queue_free()
		
		# Spawn new loot to replace it
		_spawn_single_loot()

func _spawn_single_loot():
	var x = randi() % (MAZE_WIDTH - 2) + 1
	var y = randi() % (MAZE_HEIGHT - 2) + 1
	
	while maze[y][x] == 1:
		x = randi() % (MAZE_WIDTH - 2) + 1
		y = randi() % (MAZE_HEIGHT - 2) + 1
	
	var loot_item = Area2D.new()
	var loot_sprite = Sprite2D.new()
	var loot_type = randi() % LOOT_TEXTURES.size()
	loot_sprite.texture = load(LOOT_TEXTURES[loot_type])
	loot_item.add_child(loot_sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6
	collision_shape.shape = circle
	loot_item.add_child(collision_shape)
	
	loot_item.position = Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2)
	loot_item.set_meta("value", LOOT_VALUES[loot_type])
	loot_item.set_meta("is_loot", true)
	loot_item.connect("area_entered", Callable(self, "_on_loot_collected").bind(loot_item))
	loot.append(loot_item)
	add_child(loot_item)

func _on_bear_caught(area: Area2D, bear: Area2D):
	if area == player:
		print("Caught by bear! Final score: ", score)
		
		# Spawn particle effect
		_spawn_catch_particles(player.position)
		
		_end_game()

func _end_game():
	game_over = true
	print("Game Over! Final Score: ", score)
	time_label.text = "GAME OVER! Score: %d" % score

func _spawn_pickup_particles(position: Vector2):
	var particles = CPUParticles2D.new()
	particles.position = position
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.color = Color(0.524, 0.444, 1.0, 1.0)  # Light blue for snow
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = 60
	particles.initial_velocity_max = 120
	
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()

func _spawn_catch_particles(position: Vector2):
	var particles = CPUParticles2D.new()
	particles.position = position
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.color = Color(0.302, 0.933, 0.51, 1.0)  # Light blue for snow
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = 60
	particles.initial_velocity_max = 120
	
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()
