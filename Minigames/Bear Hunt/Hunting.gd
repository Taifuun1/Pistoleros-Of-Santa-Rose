extends TextureRect

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MINIGAME_DURATION := 20.0
const SPAWN_INTERVAL := 2.5
const SHOOT_COOLDOWN := 1.5
const MAX_PLAYER_HITS := 3

const PLAYER_SPRITESHEET := "res://Assets/Bear Hunt/Hunting/PlayerMinigame.png"
const PLAYER_FRAME_COUNT := 2
const PLAYER_ANIMATION_SPEED := 10.0
const PLAYER_MOVE_SPEED := 150.0

const BEAR_SPRITESHEET := "res://Assets/Bear Hunt/Hunting/PolarbearWalk.png"
const BEAR_FRAME_COUNT := 4
const BEAR_ANIMATION_SPEED := 8.0
const BEAR_SPEED := 70.0
const BEAR_PROJECTILE_SPEED := 90.0

const BULLET_TEXTURE := "res://Assets/Bear Hunt/Hunting/BulletTiny.png"
const BULLET_SPEED := 250.0
const BEAR_PROJECTILE_TEXTURE := "res://Assets/Bear Hunt/Hunting/SnowballTiny.png"

const PELT_TEXTURE := "res://Assets/Bear Hunt/Hunting/Pelt.png"
const PELT_LIFETIME_MIN := 1.0
const PELT_LIFETIME_MAX := 2.0

const PLAYFIELD_SIZE := 240.0
const PLAYFIELD_MIN_Y := 20.0
const PLAYFIELD_MAX_Y := 220.0
const BEAR_MIN_X := 20.0
const BEAR_MAX_X := 180.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var player: Area2D
var player_sprite: AnimatedSprite2D
var cooldown_bar: ProgressBar

var bullets: Array = []
var bears: Array = []
var bear_projectiles: Array = []
var pelts: Array = []

var pelt_count := 0
var player_hits := 0
var spawn_timer := 0.0
var shoot_cooldown_timer := 0.0
var time_remaining := MINIGAME_DURATION
var game_over := false

var time_label: Label
var score_label: Label

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_create_labels()
	_create_player()
	_create_cooldown_bar()


func _process(delta: float) -> void:
	if game_over:
		return

	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_end_minigame(pelt_count)
		return

	time_label.text = "Time: %.1f" % time_remaining
	score_label.text = "Pelts: %d  Lives: %d" % [pelt_count, MAX_PLAYER_HITS - player_hits]

	_handle_player_movement(delta)
	_handle_shooting(delta)
	_handle_bear_spawning(delta)


func _physics_process(delta: float) -> void:
	_move_bullets(delta)
	_move_bears(delta)
	_move_bear_projectiles(delta)

# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

func _create_labels() -> void:
	time_label = Label.new()
	time_label.position = Vector2(0, 0)
	add_child(time_label)

	score_label = Label.new()
	score_label.position = Vector2(0, 18)
	add_child(score_label)


func _create_player() -> void:
	player = Area2D.new()
	player_sprite = AnimatedSprite2D.new()

	var sprite_frames := _build_sprite_frames(
		PLAYER_SPRITESHEET, PLAYER_FRAME_COUNT, "idle", PLAYER_ANIMATION_SPEED
	)
	player_sprite.sprite_frames = sprite_frames
	player_sprite.play("idle")
	player.add_child(player_sprite)

	var collision_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	collision_shape.shape = rect
	player.add_child(collision_shape)

	player.position = Vector2(220, 120)
	player.set_meta("is_player", true)
	add_child(player)


func _create_cooldown_bar() -> void:
	cooldown_bar = ProgressBar.new()
	cooldown_bar.max_value = SHOOT_COOLDOWN
	cooldown_bar.value = 0
	cooldown_bar.modulate = Color.RED
	cooldown_bar.visible = false
	cooldown_bar.show_percentage = false
	cooldown_bar.size = Vector2(30, 3)
	add_child(cooldown_bar)


## Builds a horizontally-sliced SpriteFrames resource from a spritesheet.
func _build_sprite_frames(
	texture_path: String, frame_count: int, anim_name: String, anim_speed: float
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, anim_speed)

	var spritesheet: Texture2D = load(texture_path)
	var frame_width: int = int(float(spritesheet.get_width()) / frame_count)
	var frame_height: int = spritesheet.get_height()

	for frame in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(frame * frame_width, 0, frame_width, frame_height)
		frames.add_frame(anim_name, atlas)

	return frames

# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------

func _handle_player_movement(delta: float) -> void:
	if Input.is_action_pressed("MOVE_UP"):
		player.position.y -= PLAYER_MOVE_SPEED * delta
	if Input.is_action_pressed("MOVE_DOWN"):
		player.position.y += PLAYER_MOVE_SPEED * delta

	player.position.y = clamp(player.position.y, PLAYFIELD_MIN_Y, PLAYFIELD_MAX_Y)


func _handle_shooting(delta: float) -> void:
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
		cooldown_bar.value = SHOOT_COOLDOWN - shoot_cooldown_timer
		cooldown_bar.position = player.position + Vector2(-15, -15)
	else:
		cooldown_bar.visible = false

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("INTERACT"):
		shoot()


func shoot() -> void:
	if shoot_cooldown_timer > 0:
		return

	shoot_cooldown_timer = SHOOT_COOLDOWN
	cooldown_bar.visible = true
	cooldown_bar.value = 0

	var bullet := Area2D.new()
	var bullet_sprite := Sprite2D.new()
	bullet_sprite.texture = load(BULLET_TEXTURE)
	bullet_sprite.centered = true
	bullet.add_child(bullet_sprite)

	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2
	collision_shape.shape = circle
	bullet.add_child(collision_shape)

	bullet.position = player.position + Vector2(-15, 0)
	bullet.set_meta("velocity", Vector2(-BULLET_SPEED, 0))
	bullet.set_meta("is_bullet", true)
	bullets.append(bullet)
	add_child(bullet)

	# Muzzle-flash particles for the player's bullet
	_spawn_particles(player.position + Vector2(-15, 0), Color(1.0, 0.85, 0.3, 1.0), 6, 0.2, 40.0, 80.0)

	bullet.connect("area_entered", Callable(self, "_on_bullet_hit").bind(bullet))

# ---------------------------------------------------------------------------
# Bears
# ---------------------------------------------------------------------------

func _handle_bear_spawning(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL:
		var count := randi() % 3 + 2
		for i in count:
			spawn_bear()
		spawn_timer = -1.5 + randf() + randf()


func spawn_bear() -> void:
	var bear := AnimatedSprite2D.new()

	var sprite_frames := _build_sprite_frames(
		BEAR_SPRITESHEET, BEAR_FRAME_COUNT, "walk", BEAR_ANIMATION_SPEED
	)
	bear.sprite_frames = sprite_frames
	bear.play("walk")

	# Spawn-in animation
	bear.scale = Vector2(0.5, 0.5)
	bear.modulate.a = 0.0
	var tween := bear.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bear, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(bear, "modulate:a", 1.0, 0.25)

	var bear_area := Area2D.new()
	bear_area.add_child(bear)

	var collision_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 14)
	collision_shape.shape = rect
	bear_area.add_child(collision_shape)

	# Bears spawn on the left and wander within the left region only
	var y_pos := randf_range(PLAYFIELD_MIN_Y + 10, PLAYFIELD_MAX_Y - 10)
	bear_area.position = Vector2(BEAR_MIN_X, y_pos)

	# Waypoints keep the bear on the left side of the playfield
	var waypoints: Array = []
	var num_waypoints := randi() % 3 + 2
	for i in num_waypoints:
		waypoints.append(Vector2(
			randf_range(BEAR_MIN_X, BEAR_MAX_X),
			randf_range(PLAYFIELD_MIN_Y + 10, PLAYFIELD_MAX_Y - 10)
		))

	bear_area.set_meta("waypoints", waypoints)
	bear_area.set_meta("current_waypoint", 0)
	bear_area.set_meta("is_bear", true)
	bear_area.set_meta("health", 1)
	bear_area.set_meta("shoot_timer", randf() + 1)
	bears.append(bear_area)
	add_child(bear_area)


func _move_bears(delta: float) -> void:
	var bears_to_remove: Array = []
	for bear in bears:
		var waypoints: Array = bear.get_meta("waypoints")
		var current_wp: int = bear.get_meta("current_waypoint")

		if current_wp < waypoints.size():
			var target: Vector2 = waypoints[current_wp]
			var direction: Vector2 = (target - bear.position).normalized()
			bear.position += direction * BEAR_SPEED * delta

			# Clamp bears to the left region so they never cross the player
			bear.position.x = clamp(bear.position.x, BEAR_MIN_X, BEAR_MAX_X)

			if bear.position.distance_to(target) < 5:
				bear.set_meta("current_waypoint", current_wp + 1)
		else:
			# Bear finished its route – fade out and remove on the left side
			bears_to_remove.append(bear)
			continue

		# Bear shooting
		var shoot_timer: float = bear.get_meta("shoot_timer")
		shoot_timer -= delta
		bear.set_meta("shoot_timer", shoot_timer)

		if shoot_timer <= 0:
			_spawn_bear_projectile(bear, player)
			bear.set_meta("shoot_timer", randf() * 2.0 + 1.5)

	for bear in bears_to_remove:
		_fade_out_and_free(bear)
		bears.erase(bear)


func _spawn_bear_projectile(bear: Area2D, target: Area2D) -> void:
	var proj := Area2D.new()
	var proj_sprite := Sprite2D.new()
	proj_sprite.texture = load(BEAR_PROJECTILE_TEXTURE)
	proj_sprite.centered = true
	proj.add_child(proj_sprite)

	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3
	collision_shape.shape = circle
	proj.add_child(collision_shape)

	var direction: Vector2 = (target.position - bear.position).normalized()
	proj.position = bear.position
	proj.set_meta("velocity", direction * BEAR_PROJECTILE_SPEED)
	proj.set_meta("is_bear_projectile", true)
	bear_projectiles.append(proj)
	add_child(proj)

	# Snow puff particles when a bear throws a snowball
	_spawn_particles(bear.position, Color(0.9, 0.9, 1.0, 1.0), 8, 0.25, 30.0, 60.0)

	proj.connect("area_entered", Callable(self, "_on_bullet_hit").bind(proj))

# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

func _move_bullets(delta: float) -> void:
	var to_remove: Array = []
	for bullet in bullets:
		var vel: Vector2 = bullet.get_meta("velocity")
		bullet.position += vel * delta

		if _is_offscreen(bullet.position):
			to_remove.append(bullet)

	for bullet in to_remove:
		if bullet in bullets:
			bullets.erase(bullet)
			bullet.queue_free()


func _move_bear_projectiles(delta: float) -> void:
	var to_remove: Array = []
	for proj in bear_projectiles:
		var vel: Vector2 = proj.get_meta("velocity")
		proj.position += vel * delta

		if _is_offscreen(proj.position):
			to_remove.append(proj)

	for proj in to_remove:
		if proj in bear_projectiles:
			bear_projectiles.erase(proj)
			proj.queue_free()


func _is_offscreen(pos: Vector2) -> bool:
	return pos.x > PLAYFIELD_SIZE or pos.x < 0 or pos.y < 0 or pos.y > PLAYFIELD_SIZE

# ---------------------------------------------------------------------------
# Pelts
# ---------------------------------------------------------------------------

func _spawn_pelt(spawn_position: Vector2) -> void:
	pelt_count += 1
	var pelt := Area2D.new()
	var pelt_sprite := Sprite2D.new()
	pelt_sprite.texture = load(PELT_TEXTURE)
	pelt_sprite.centered = true
	pelt.add_child(pelt_sprite)

	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6
	collision_shape.shape = circle
	pelt.add_child(collision_shape)

	pelt.position = spawn_position
	pelt.set_meta("is_pelt", true)
	pelts.append(pelt)
	call_deferred("add_child", pelt)

	pelt.scale = Vector2(0.3, 0.3)
	var pop_in := pelt.create_tween()
	pop_in.set_parallel(true)
	pop_in.tween_property(pelt, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var lifetime := randf_range(PELT_LIFETIME_MIN, PELT_LIFETIME_MAX)
	var expire_timer := Timer.new()
	expire_timer.wait_time = lifetime
	expire_timer.one_shot = true
	expire_timer.timeout.connect(func(): _expire_pelt(pelt))
	add_child(expire_timer)
	expire_timer.start()


func _expire_pelt(pelt: Area2D) -> void:
	if not is_instance_valid(pelt) or not pelt in pelts:
		return

	pelts.erase(pelt)

	var fade := pelt.create_tween()
	fade.set_parallel(true)
	fade.tween_property(pelt, "scale", Vector2(0.3, 0.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fade.tween_property(pelt, "modulate:a", 0.0, 0.3)
	fade.finished.connect(func(): if is_instance_valid(pelt): pelt.queue_free())


# ---------------------------------------------------------------------------
# Collision handling
# ---------------------------------------------------------------------------

func _on_bullet_hit(area: Area2D, bullet: Area2D) -> void:
	if game_over:
		return

	if area.has_meta("is_bear") and area.get_meta("is_bear") and bullet.has_meta("is_bullet") and bullet.get_meta("is_bullet"):
		print("Bear hit! Pelts: ", pelt_count)

		_spawn_pelt(area.position)

		_spawn_particles(area.position, Color(0.9, 0.9, 1.0, 1.0), 12, 0.4, 60.0, 120.0)

		if bullet in bullets:
			bullets.erase(bullet)
			bullet.queue_free()

		if area in bears:
			bears.erase(area)
			_fade_out_and_free(area)

	elif area == player and bullet.has_meta("is_bear_projectile") and bullet.get_meta("is_bear_projectile"):
		player_hits += 1
		print("Player hit! Hits: ", player_hits)

		_spawn_particles(player.position, Color(1.0, 0.4, 0.4, 1.0), 12, 0.4, 60.0, 120.0)

		if bullet in bear_projectiles:
			bear_projectiles.erase(bullet)
			bullet.queue_free()

		if player_hits >= MAX_PLAYER_HITS:
			print("Player eliminated! Game over.")
			_end_minigame(pelt_count)

# ---------------------------------------------------------------------------
# Particles
# ---------------------------------------------------------------------------

func _spawn_particles(
	particle_position: Vector2, color: Color, amount: int, lifetime: float, vel_min: float, vel_max: float
) -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)
	particles.position = particle_position
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 8.0
	particles.color = color
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = vel_min
	particles.initial_velocity_max = vel_max

	var timer := Timer.new()
	timer.wait_time = lifetime + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())
	add_child(timer)
	timer.start()

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

func _fade_out_and_free(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.0, 0.25)
	tween.tween_property(node, "scale", Vector2(0.5, 0.5), 0.25)
	tween.finished.connect(func(): if is_instance_valid(node): node.queue_free())


func _end_minigame(points: int) -> void:
	if game_over:
		return
	game_over = true
	print("Hunting minigame ended. Pelts: ", points)
	time_label.text = "GAME OVER! Pelts: %d" % points

	Locations.minigamePoints["Hunting"] += points

	await get_tree().create_timer(2.0).timeout

	var player_actor := get_tree().current_scene.get_node_or_null("Entities/Actors/PlayerActor")
	if player_actor != null:
		player_actor.paused = false

	queue_free()
