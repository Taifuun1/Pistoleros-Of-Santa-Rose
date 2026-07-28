extends TextureRect

const ITEM_NUMBER_SCENE = preload("res://Nodes/Item Number/ItemNumber.tscn")

var collectibleType: String = "rock"  # rock, gold, gem
var value: int = 1
var pickupRange: float = 15.0  # Distance in pixels to pick up
var isCollected: bool = false
var animating = true

signal collected(collectibleType: String, value: int)

func _ready() -> void:
	size = texture.get_size()
	pivot_offset = size / 2
	var texturePath = texture.resource_path
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if "GoldPiece" in texturePath:
		collectibleType = "gold"
		value = 5
	elif "Emerald" in texturePath or "Sapphire" in texturePath or "Morganite" in texturePath or "RoseQuartz" in texturePath:
		collectibleType = "gem"
		value = 25
	elif "CoinPile" in texturePath:
		collectibleType = "gold"
		value = 3
	elif "CashStack" in texturePath:
		collectibleType = "gold"
		value = 5
	elif "Coin" in texturePath:
		collectibleType = "gold"
		value = 1
	elif "Soil" in texturePath:
		collectibleType = "soil"
		value = 1
	elif "Rock" in texturePath:
		collectibleType = "rock"
		value = 1
	else:
		collectibleType = "rock"
		if randi() % 4 == 0:
			value = 1
		else:
			value = 0

#func _process(delta: float) -> void:
	#if isCollected or animating:
		#return
#
	#var mousePos = get_viewport().get_mouse_position() - size / 2
	#var distance = global_position.distance_to(mousePos)
#
	#if distance <= pickupRange:
		#collect()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		collect()
		accept_event()

func collect() -> void:
	if isCollected:
		return
	isCollected = true

	collected.emit(collectibleType, value)

	spawnCollectionParticles()
	spawnItemNumber(value)

	pivot_offset = size / 2
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.finished.connect(func(): queue_free())

func spawnItemNumber(itemValue: int) -> void:
	if itemValue <= 0:
		return
	var itemNumber = ITEM_NUMBER_SCENE.instantiate()
	get_parent().add_child(itemNumber)
	itemNumber.init("+%d" % itemValue, position + size / 2.0)

func spawnCollectionParticles() -> void:
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.position = position + size / 2
	
	particles.amount = 12
	particles.lifetime = 0.15
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	
	match collectibleType:
		"gem":
			particles.color = Color(0.2, 0.8, 1.0, 0.9)
		"gold":
			particles.color = Color(1.0, 0.9, 0.2, 0.9)
		_:
			particles.color = Color(0.259, 0.553, 0.435, 0.392)
	
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	
	particles.explosiveness = 0.85
	particles.spread = 360.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	
	particles.finished.connect(func(): particles.queue_free())

func animatingDone():
	mouse_filter = Control.MOUSE_FILTER_PASS
	animating = false
