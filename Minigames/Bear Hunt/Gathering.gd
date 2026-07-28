extends TextureRect

const TILE_SIZE = 12
const MAZE_WIDTH = 20
const MAZE_HEIGHT = 20
const GRID_SCALE = 2
const MOVE_DURATION = 0.2

const PLAYER_SPRITESHEET = "res://Assets/Bear Hunt/Gathering/PlayerMinigame.png"
const PLAYER_FRAME_COUNT = 2
const PLAYER_ANIMATION_SPEED = 6.0
const PLAYER_SPEED = 120.0

const BEAR_SPRITESHEET = "res://Assets/Bear Hunt/Gathering/PolarBearMinigame.png"
const BEAR_FRAME_COUNT = 4
const BEAR_ANIMATION_SPEED = 4.0
const BEAR_SPEED = 35.0

const BANDIT_SPRITESHEETS = [
	"res://Assets/Bear Hunt/Gathering/BanditGreen.png",
	"res://Assets/Bear Hunt/Gathering/BanditPink.png",
	"res://Assets/Bear Hunt/Gathering/BanditYellow.png",
]
const BANDIT_FRAME_COUNT = 2
const BANDIT_ANIMATION_SPEED = 5.0
const BANDIT_SPEED = 25.0

const BUNNY_SPRITESHEET = "res://Assets/Bear Hunt/Gathering/BunnySnowMinigame.png"
const BUNNY_FRAME_COUNT = 4
const BUNNY_ANIMATION_SPEED = 4.0
const BUNNY_SPEED = 50.0

const POWERUP_TEXTURE = "res://Assets/Bear Hunt/Gathering/SixShootinPowerup.png"
const POWERUP_DURATION = 5.0

const LOOT_TEXTURES = [
	"res://Assets/Bear Hunt/Gathering/GatheringClaw.png",
	"res://Assets/Bear Hunt/Gathering/GatheringEgg.png",
	"res://Assets/Bear Hunt/Gathering/GatheringPelt.png",
]

const WALL_TEXTURE = "res://Assets/Bear Hunt/Gathering/GatheringWall.png"

const ITEM_NUMBER_SCENE = preload("res://Nodes/Item Number/ItemNumber.tscn")

const MINIGAME_DURATION = 40.0

const SPAWN_INTERVAL_MIN = 3.0
const SPAWN_INTERVAL_MAX = 7.0
const MAX_ENEMIES = 8
const MAX_BEARS = 3
const MAX_BANDITS = 3
const MAX_BUNNIES = 4

const BUNNY_IDLE_CHANCE = 0.4
const BUNNY_MOVE_MIN = 0.5
const BUNNY_MOVE_MAX = 2.0

const POWERUP_INTERVAL_MIN = 10.0
const POWERUP_INTERVAL_MAX = 20.0

var player: Area2D
var player_sprite: AnimatedSprite2D
var player_tween: Tween
var player_input_direction = Vector2i.ZERO
var enemies = []
var enemy_tweens = {}
var loot = []
var walls = []
var score = 0
var time_remaining = MINIGAME_DURATION
var game_over = false
var spawn_timer = 0.0
var next_spawn_in = _random_spawn_interval()
var powerup = null
var powerup_active = false
var powerup_timer = 0.0
var powerup_spawn_timer = 0.0
var next_powerup_in = _random_powerup_interval()
var powerup_glow: CPUParticles2D = null

var time_label: Label
var score_label: Label

# Simple maze layout (0 = path, 1 = wall)
var maze = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,0,1,1,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1],
	[1,0,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,0,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,1,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1],
	[1,0,1,1,1,1,0,1,1,1,1,0,1,1,1,1,0,1,1,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,0,1,1,0,1,1,1,0,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1],
	[1,0,1,0,1,0,1,0,1,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,0,1,1,0,1,1,1,0,1,1,0,1,1,1,1,1,0,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,1,1,1,1,1,0,1,1,0,1,1,1,0,1,1,1,0,1],
	[1,0,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1],
	[1,0,0,0,0,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]

func _ready():
	# Build the maze walls
	_build_maze()
	
	# Create player
	_create_player()
	
	# Spawn initial loot
	_spawn_loot()
	
	# Spawn a few starting enemies
	for i in range(2):
		_spawn_random_enemy()
	
	time_label = Label.new()
	add_child(time_label)
	
	score_label = Label.new()
	score_label.position = Vector2(0, 18)
	add_child(score_label)

func _random_spawn_interval() -> float:
	return randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)

func _random_powerup_interval() -> float:
	return randf_range(POWERUP_INTERVAL_MIN, POWERUP_INTERVAL_MAX)

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
	player_sprite = _create_animated_sprite(PLAYER_SPRITESHEET, PLAYER_FRAME_COUNT, PLAYER_ANIMATION_SPEED)
	player.add_child(player_sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	collision_shape.shape = rect
	player.add_child(collision_shape)
	
	player.position = Vector2(TILE_SIZE * 3.5, TILE_SIZE * 3.5)
	player_tween = null
	add_child(player)

func _create_animated_sprite(spritesheet_path: String, frame_count: int, animation_speed: float) -> AnimatedSprite2D:
	var animated_sprite = AnimatedSprite2D.new()
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_loop("walk", true)
	sprite_frames.set_animation_speed("walk", animation_speed)
	
	var spritesheet = load(spritesheet_path)
	var frame_width = spritesheet.get_width() / frame_count
	var frame_height = spritesheet.get_height()
	
	for frame in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(frame * frame_width, 0, frame_width, frame_height)
		sprite_frames.add_frame("walk", atlas)
	
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("walk")
	return animated_sprite

func _spawn_loot():
	# Spawn several loot items randomly in open paths
	for i in range(3):
		_spawn_single_loot()

func _get_random_open_grid() -> Vector2i:
	var x = randi() % (MAZE_WIDTH - 2) + 1
	var y = randi() % (MAZE_HEIGHT - 2) + 1
	
	while maze[y][x] == 1:
		x = randi() % (MAZE_WIDTH - 2) + 1
		y = randi() % (MAZE_HEIGHT - 2) + 1
	
	return Vector2i(x, y)

func _get_far_open_grid(from_pos: Vector2) -> Vector2i:
	var best_grid = _get_random_open_grid()
	var best_dist = from_pos.distance_to(_grid_to_world(best_grid))
	
	for i in range(10):
		var candidate = _get_random_open_grid()
		var dist = from_pos.distance_to(_grid_to_world(candidate))
		if dist > best_dist:
			best_dist = dist
			best_grid = candidate
	
	return best_grid

func _spawn_single_loot():
	var grid = _get_random_open_grid()
	
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
	
	loot_item.position = _grid_to_world(grid)
	loot_item.set_meta("is_loot", true)
	loot_item.connect("area_entered", Callable(self, "_on_loot_collected").bind(loot_item))
	loot.append(loot_item)
	call_deferred("add_child", loot_item)

func _spawn_random_enemy():
	if enemies.size() >= MAX_ENEMIES:
		return
	
	# Pick enemy type with weighted randomness
	var type_roll = randf()
	var type: String
	
	# Determine available types based on current counts
	var can_spawn_bear = _count_enemies("bear") < MAX_BEARS
	var can_spawn_bandit = _count_enemies("bandit") < MAX_BANDITS
	var can_spawn_bunny = _count_enemies("bunny") < MAX_BUNNIES
	
	var choices = []
	if can_spawn_bear:
		choices.append("bear")
	if can_spawn_bandit:
		choices.append("bandit")
	if can_spawn_bunny:
		choices.append("bunny")
	
	if choices.is_empty():
		return
	
	type = choices[randi() % choices.size()]
	_spawn_enemy(type)

func _count_enemies(type: String) -> int:
	var count = 0
	for enemy in enemies:
		if enemy.get_meta("enemy_type") == type:
			count += 1
	return count

func _spawn_enemy(type: String):
	var enemy = Area2D.new()
	var sprite: AnimatedSprite2D
	var speed: float
	var collision_size: Vector2
	
	match type:
		"bear":
			sprite = _create_animated_sprite(BEAR_SPRITESHEET, BEAR_FRAME_COUNT, BEAR_ANIMATION_SPEED)
			speed = BEAR_SPEED
			collision_size = Vector2(10, 10)
		"bandit":
			var sheet = BANDIT_SPRITESHEETS[randi() % BANDIT_SPRITESHEETS.size()]
			sprite = _create_animated_sprite(sheet, BANDIT_FRAME_COUNT, BANDIT_ANIMATION_SPEED)
			speed = BANDIT_SPEED
			collision_size = Vector2(9, 9)
		"bunny":
			sprite = _create_animated_sprite(BUNNY_SPRITESHEET, BUNNY_FRAME_COUNT, BUNNY_ANIMATION_SPEED)
			speed = BUNNY_SPEED
			collision_size = Vector2(8, 8)
		_:
			return
	
	enemy.add_child(sprite)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = collision_size
	collision_shape.shape = rect
	enemy.add_child(collision_shape)
	
	# Spawn far from player to give them time to react
	var grid = _get_far_open_grid(player.position)
	enemy.position = _grid_to_world(grid)
	enemy.set_meta("enemy_type", type)
	enemy.set_meta("speed", speed)
	enemy.set_meta("bunny_timer", randf_range(BUNNY_MOVE_MIN, BUNNY_MOVE_MAX))
	enemy.set_meta("bunny_direction", Vector2i.ZERO)
	enemy.connect("area_entered", Callable(self, "_on_enemy_touched").bind(enemy))
	enemies.append(enemy)
	add_child(enemy)

func _spawn_powerup():
	if powerup != null:
		return
	
	var grid = _get_random_open_grid()
	# Don't spawn directly on the player
	while _grid_to_world(grid).distance_to(player.position) < TILE_SIZE * 3:
		grid = _get_random_open_grid()
	
	powerup = Area2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = load(POWERUP_TEXTURE)
	powerup.add_child(sprite)
	
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6
	collision_shape.shape = circle
	powerup.add_child(collision_shape)
	
	powerup.position = _grid_to_world(grid)
	powerup.set_meta("is_powerup", true)
	powerup.connect("area_entered", Callable(self, "_on_powerup_collected").bind(powerup))
	add_child(powerup)

func _process(delta):
	if game_over:
		return
	
	# Update timer
	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_end_minigame(score)
		return
	
	time_label.text = "Time: %.1f" % time_remaining
	score_label.text = "Score: %d" % score
	
	# Handle player input and tile-based movement (no diagonal movement)
	var input_direction = Vector2i.ZERO
	if Input.is_action_pressed("MOVE_UP"):
		input_direction.y -= 1
	elif Input.is_action_pressed("MOVE_DOWN"):
		input_direction.y += 1
	elif Input.is_action_pressed("MOVE_LEFT"):
		input_direction.x -= 1
	elif Input.is_action_pressed("MOVE_RIGHT"):
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
	
	# Spawn enemies periodically with randomized intervals
	spawn_timer += delta
	if spawn_timer >= next_spawn_in:
		_spawn_random_enemy()
		spawn_timer = 0.0
		next_spawn_in = _random_spawn_interval()
	
	# Spawn powerups periodically
	if not powerup_active:
		powerup_spawn_timer += delta
		if powerup_spawn_timer >= next_powerup_in:
			_spawn_powerup()
			powerup_spawn_timer = 0.0
			next_powerup_in = _random_powerup_interval()
	
	# Update active powerup timer
	if powerup_active:
		powerup_timer -= delta
		if powerup_timer <= 0:
			_deactivate_powerup()
		else:
			# Pulse the player scale to show powerup is active
			var pulse = 1.0 + 0.1 * sin(Time.get_ticks_msec() / 100.0)
			player_sprite.scale = Vector2(pulse, pulse)

func _physics_process(delta):
	# Move enemies using their unique AI behaviors
	for enemy in enemies:
		if enemy in enemy_tweens:
			continue
		
		var enemy_pos = _world_to_grid(enemy.position)
		var player_pos = _world_to_grid(player.position)
		var type = enemy.get_meta("enemy_type")
		var next_pos: Vector2i
		var speed = enemy.get_meta("speed")
		var duration = TILE_SIZE / speed
		
		if powerup_active:
			next_pos = _get_flee_target(enemy_pos, player_pos)
		else:
			match type:
				"bear":
					next_pos = _get_chase_target(enemy_pos, player_pos)
				"bandit":
					next_pos = _get_intercept_target(enemy_pos, player_pos)
				"bunny":
					next_pos = _get_bunny_target(enemy, enemy_pos)
				_:
					next_pos = enemy_pos
		
		if next_pos != enemy_pos:
			var world_pos = _grid_to_world(next_pos)
			_tween_enemy_movement(enemy, world_pos, duration)

func _tween_enemy_movement(enemy: Area2D, target: Vector2, duration: float):
	enemy_tweens[enemy] = create_tween()
	enemy_tweens[enemy].set_trans(Tween.TRANS_LINEAR)
	enemy_tweens[enemy].set_ease(Tween.EASE_IN_OUT)
	enemy_tweens[enemy].tween_property(enemy, "position", target, duration)
	enemy_tweens[enemy].finished.connect(func(): enemy_tweens.erase(enemy))

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

func _get_neighbors(grid: Vector2i) -> Array:
	var neighbors = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		var neighbor = grid + dir
		if _is_walkable(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

func _get_chase_target(enemy_pos: Vector2i, player_pos: Vector2i) -> Vector2i:
	var path = _astar_path(enemy_pos, player_pos)
	if path.size() > 1:
		return path[1]
	return enemy_pos

func _get_intercept_target(enemy_pos: Vector2i, player_pos: Vector2i) -> Vector2i:
	# Bandits try to cut the player off from a different angle.
	# If the player is moving, aim ahead of them and slightly to the side.
	var target = player_pos
	
	if player_input_direction != Vector2i.ZERO:
		var perpendicular = Vector2i(-player_input_direction.y, player_input_direction.x)
		if randf() < 0.5:
			perpendicular = -perpendicular
		
		var intercept = player_pos + player_input_direction * 4 + perpendicular * 2
		
		# Clamp to walkable area; try nearby tiles if the exact intercept is blocked
		if _is_walkable(intercept):
			target = intercept
		elif _is_walkable(player_pos + player_input_direction * 3):
			target = player_pos + player_input_direction * 3
		elif _is_walkable(player_pos + perpendicular):
			target = player_pos + perpendicular
	
	var path = _astar_path(enemy_pos, target)
	if path.size() > 1:
		return path[1]
	return enemy_pos

func _get_bunny_target(bunny: Area2D, bunny_pos: Vector2i) -> Vector2i:
	var timer = bunny.get_meta("bunny_timer")
	timer -= get_physics_process_delta_time()
	bunny.set_meta("bunny_timer", timer)
	
	if timer <= 0:
		bunny.set_meta("bunny_timer", randf_range(BUNNY_MOVE_MIN, BUNNY_MOVE_MAX))
		
		if randf() < BUNNY_IDLE_CHANCE:
			bunny.set_meta("bunny_direction", Vector2i.ZERO)
		else:
			var neighbors = _get_neighbors(bunny_pos)
			if neighbors.is_empty():
				bunny.set_meta("bunny_direction", Vector2i.ZERO)
			else:
				bunny.set_meta("bunny_direction", neighbors[randi() % neighbors.size()] - bunny_pos)
	
	var direction = bunny.get_meta("bunny_direction")
	var target = bunny_pos + direction
	if _is_walkable(target):
		return target
	return bunny_pos

func _get_flee_target(enemy_pos: Vector2i, player_pos: Vector2i) -> Vector2i:
	# Run away from the player: pick the walkable neighbor that maximizes distance.
	var neighbors = _get_neighbors(enemy_pos)
	if neighbors.is_empty():
		return enemy_pos
	
	var best = neighbors[0]
	var best_dist = _heuristic(best, player_pos)
	
	for neighbor in neighbors:
		var dist = _heuristic(neighbor, player_pos)
		if dist > best_dist:
			best_dist = dist
			best = neighbor
	
	return best

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
		score += 1
		print("Collected loot! Score: ", score)
		
		# Spawn particle effect and item number
		_spawn_pickup_particles(loot_item.position)
		_spawn_item_number(loot_item.position, 1)
		
		if loot_item in loot:
			loot.erase(loot_item)
			loot_item.queue_free()
		
		# Spawn new loot to replace it
		_spawn_single_loot()

func _on_powerup_collected(area: Area2D, collected_powerup: Area2D):
	if area == player and collected_powerup.get_meta("is_powerup"):
		_activate_powerup()
		
		if powerup == collected_powerup:
			powerup = null
		collected_powerup.queue_free()

func _activate_powerup():
	powerup_active = true
	powerup_timer = POWERUP_DURATION
	
	# Visual feedback
	player_sprite.modulate = Color(1.0, 0.8, 0.2, 1.0)
	_powerup_glow_start()

func _deactivate_powerup():
	powerup_active = false
	powerup_timer = 0.0
	
	# Reset visual feedback
	player_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	player_sprite.scale = Vector2(1.0, 1.0)
	_powerup_glow_stop()

func _powerup_glow_start():
	if powerup_glow != null:
		return
	
	powerup_glow = CPUParticles2D.new()
	powerup_glow.amount = 24
	powerup_glow.lifetime = 0.6
	powerup_glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	powerup_glow.emission_sphere_radius = 10.0
	powerup_glow.color = Color(1.0, 0.7, 0.1, 1.0)  # Golden glow
	powerup_glow.scale_amount_min = 0.5
	powerup_glow.scale_amount_max = 1.0
	powerup_glow.spread = 180.0
	powerup_glow.gravity = Vector2.ZERO
	powerup_glow.initial_velocity_min = 10
	powerup_glow.initial_velocity_max = 25
	powerup_glow.orbit_velocity_min = 0.5
	powerup_glow.orbit_velocity_max = 1.0
	powerup_glow.radial_accel_min = -20
	powerup_glow.radial_accel_max = -10
	
	player.add_child(powerup_glow)
	powerup_glow.emitting = true

func _powerup_glow_stop():
	if powerup_glow == null:
		return
	
	powerup_glow.emitting = false
	
	await get_tree().create_timer(powerup_glow.lifetime + 0.1).timeout
	powerup_glow.queue_free()
	powerup_glow = null

func _on_enemy_touched(area: Area2D, enemy: Area2D):
	if area != player:
		return
	
	if powerup_active:
		# Player eats the enemy
		score += 1
		print("Ate enemy! Score: ", score)
		_spawn_eat_particles(enemy.position)
		_remove_enemy(enemy)
	else:
		# Enemy catches the player
		print("Caught by ", enemy.get_meta("enemy_type"), "! Final score: ", score)
		_spawn_catch_particles(player.position)
		_end_minigame(score)

func _remove_enemy(enemy: Area2D):
	if enemy in enemy_tweens:
		if enemy_tweens[enemy] != null and enemy_tweens[enemy].is_valid():
			enemy_tweens[enemy].kill()
		enemy_tweens.erase(enemy)
	
	if enemy in enemies:
		enemies.erase(enemy)
	
	enemy.queue_free()

func _end_minigame(points: int):
	if game_over:
		return
	game_over = true
	print("Gathering minigame ended. Points: ", points)
	time_label.text = "GAME OVER! Score: %d" % points

	# Store points in global
	Locations.minigamePoints["Gathering"] += points

	# Make sure powerup glow is cleaned up
	_powerup_glow_stop()

	# Remove this minigame scene after a short delay so the player can see the score
	await get_tree().create_timer(2.0).timeout

	# Unpause the player
	var player_actor = get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()

func _spawn_item_number(spawn_position: Vector2, amount: int) -> void:
	var item_number = ITEM_NUMBER_SCENE.instantiate()
	add_child(item_number)
	item_number.init("+%d" % amount, spawn_position)

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

func _spawn_eat_particles(position: Vector2):
	var particles = CPUParticles2D.new()
	particles.position = position
	particles.amount = 16
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 12.0
	particles.color = Color(1.0, 0.4, 0.1, 1.0)  # Orange burst
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 80
	particles.initial_velocity_max = 160
	
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()
