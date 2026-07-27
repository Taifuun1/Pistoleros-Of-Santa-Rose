extends TextureRect

signal object_broken(objectType: String, position: Vector2)

var objectType: String = "rock"
var parentScene: TextureRect

var durability: int = 1
var maxDurability: int = 1
var isBroken: bool = false
var isHovered: bool = false

var baseScale: Vector2 = Vector2.ONE

const HOVER_SCALE: float = 1.15
const HOVER_BRIGHTNESS: float = 1.2

var panningTextures = {
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2
	baseScale = scale
	_update_hover_visuals()

func createPanningObject(objectTexture, objectPosition: Vector2, objectTypeParam: String = "rock"):
	texture = objectTexture
	size = texture.get_size()
	pivot_offset = size / 2
	position = objectPosition
	objectType = objectTypeParam
	flip_h = randi() % 2
	flip_v = randi() % 2
	
	if objectType == "rock":
		durability = 3
	else:
		durability = 1
	maxDurability = durability

func _gui_input(event: InputEvent) -> void:
	if isBroken:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Do not allow clicking through if another object is higher Z / on top
		if _is_covered_by_top_object():
			return
		_break_object()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		isHovered = true
		_update_hover_visuals()
	elif what == NOTIFICATION_MOUSE_EXIT:
		isHovered = false
		_update_hover_visuals()

func _update_hover_visuals() -> void:
	if isBroken:
		return
	var targetScale = baseScale * HOVER_SCALE if isHovered else baseScale
	var targetBrightness = HOVER_BRIGHTNESS if isHovered else 1.0
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", targetScale, 0.1)
	tween.tween_property(self, "modulate", Color(targetBrightness, targetBrightness, targetBrightness, modulate.a), 0.1)

func _break_object() -> void:
	durability -= 1
	
	_spawn_hit_particles()
	
	# Shake animation
	var tween = get_tree().create_tween()
	var shakeOffset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	tween.tween_property(self, "position", position + shakeOffset, 0.03)
	tween.tween_property(self, "position", position - shakeOffset, 0.03)
	tween.tween_property(self, "position", position, 0.03)
	
	if durability <= 0:
		isBroken = true
		tween.finished.connect(_finish_break)

func _finish_break() -> void:
	_spawn_break_particles()
	object_broken.emit(objectType, position + size / 2)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func(): queue_free())

func _spawn_hit_particles() -> void:
	if parentScene == null:
		return
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position + size / 2
	particles.amount = 4
	particles.lifetime = 0.15
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0
	particles.color = Color(0.6, 0.5, 0.4, 0.7)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.spread = 360.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.finished.connect(func(): particles.queue_free())

func _spawn_break_particles() -> void:
	if parentScene == null:
		return
	var particles = CPUParticles2D.new()
	parentScene.add_child(particles)
	particles.position = position + size / 2
	particles.amount = 12
	particles.lifetime = 0.25
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	
	if objectType == "soil":
		particles.color = Color(0.4, 0.3, 0.2, 0.8)
	else:
		particles.color = Color(0.5, 0.5, 0.5, 0.8)
	
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.spread = 360.0
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.explosiveness = 0.5
	particles.finished.connect(func(): particles.queue_free())

func _is_covered_by_top_object() -> bool:
	var mouse_pos = get_global_mouse_position()
	for sibling in get_parent().get_children():
		if sibling == self:
			continue
		if sibling is TextureRect and sibling.visible:
			var sibling_rect = sibling.get_global_rect()
			if sibling_rect.has_point(mouse_pos):
				if sibling.z_index > z_index or (sibling.z_index == z_index and sibling.get_index() > get_index()):
					return true
	return false
