extends Node2D
class_name PlayerRevealController

## Controller for the PlayerReveal shader effect.
## Attach this to a node in your location scene and call init() after the player is ready.

# The player node to track
var player: Node2D = null

# Shader material resource path
const SHADER_MATERIAL_PATH = "res://Shaders/PlayerReveal.tres"

# Group name for objects that should have the reveal effect
const REVEALABLE_GROUP = "revealable"

# Group name so RevealableObject components can find this controller
const CONTROLLER_GROUP = "player_reveal_controller"

# Cached shader material
var reveal_material: ShaderMaterial = null

# Whether the effect is enabled
var enabled: bool = true:
	set(value):
		enabled = value
		_update_material_enabled()

# Reveal radius (can be adjusted at runtime)
var reveal_radius: float = 70.0:
	set(value):
		reveal_radius = value
		_update_material_property("reveal_radius", value)

# Reveal softness (edge feathering)
var reveal_softness: float = 10.0:
	set(value):
		reveal_softness = value
		_update_material_property("reveal_softness", value)

# Minimum alpha for objects inside the reveal radius
var min_alpha: float = 0.0:
	set(value):
		min_alpha = value
		_update_material_property("min_alpha", value)


func _ready():
	# Make the controller discoverable for RevealableObject components
	add_to_group(CONTROLLER_GROUP)
	# Create or load the shader material
	_recreate_material()


func init(player_node: Node2D):
	"""Initialize the controller with the player node."""
	player = player_node
	_apply_material_to_revealables()


func _recreate_material():
	"""Create a new shader material instance."""
	var shader = load("res://Shaders/PlayerReveal.gdshader")
	if shader == null:
		push_error("PlayerReveal shader not found at res://Shaders/PlayerReveal.gdshader")
		return
	
	reveal_material = ShaderMaterial.new()
	reveal_material.shader = shader
	
	# Set initial values
	reveal_material.set_shader_parameter("reveal_radius", reveal_radius)
	reveal_material.set_shader_parameter("reveal_softness", reveal_softness)
	reveal_material.set_shader_parameter("min_alpha", min_alpha)
	reveal_material.set_shader_parameter("enabled", enabled)


func _apply_material_to_revealables():
	"""Apply the reveal material to all nodes in the revealable group."""
	var revealables = get_tree().get_nodes_in_group(REVEALABLE_GROUP)
	for node in revealables:
		_apply_material_to_node(node)


func _apply_material_to_node(node: Node):
	"""Apply the reveal material to a specific node."""
	if reveal_material == null:
		return
	
	# Handle different node types that might have materials
	if node is Sprite2D:
		node.material = reveal_material.duplicate()
	elif node is AnimatedSprite2D:
		node.material = reveal_material.duplicate()
	elif node is TileMap:
		# For TileMap, we need to apply to the layer
		for i in range(node.get_layers_count()):
			var existing_mat = node.get_layer_material(i)
			if existing_mat == null:
				node.set_layer_material(i, reveal_material.duplicate())
	elif node is Node2D:
		# Try to find child sprites
		for child in node.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				child.material = reveal_material.duplicate()


func add_revealable(node: Node):
	"""Add a node to the revealable group and apply the material."""
	node.add_to_group(REVEALABLE_GROUP)
	_apply_material_to_node(node)


func remove_revealable(node: Node):
	"""Remove a node from the revealable group and clear its material."""
	node.remove_from_group(REVEALABLE_GROUP)
	if node is Sprite2D or node is AnimatedSprite2D:
		node.material = null
	# Also clear materials from child sprites (e.g. StaticBody2D parents)
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.material = null


func _process(_delta):
	if player == null or reveal_material == null:
		return
	
	# Center the reveal on the visible character. Sprite offsets move rendered
	# pixels without moving the Node2D origin, so using player.global_position
	# places the reveal below sprites whose artwork is offset upward.
	var player_reveal_position = _get_player_reveal_position()
	var revealables = get_tree().get_nodes_in_group(REVEALABLE_GROUP)
	
	for node in revealables:
		var shader_mats = _get_node_materials(node)
		if shader_mats.is_empty():
			# Nodes that joined the group after init() (dynamically spawned or
			# via the RevealableObject component) never received a material yet.
			_apply_material_to_node(node)
			shader_mats = _get_node_materials(node)
		for shader_mat in shader_mats:
			shader_mat.set_shader_parameter("player_reveal_position", player_reveal_position)


func _get_player_reveal_position() -> Vector2:
	"""Return the world-space center of the player's rendered sprite."""
	for child in player.get_children():
		if child is Sprite2D:
			return child.to_global(child.offset)
		if child is AnimatedSprite2D:
			return child.to_global(child.offset)
	return player.global_position


func _get_node_materials(node: Node) -> Array[ShaderMaterial]:
	"""Get all shader materials of a node (its own and its child sprites')."""
	var materials: Array[ShaderMaterial] = []
	if node is Sprite2D or node is AnimatedSprite2D:
		var own_material = node.material as ShaderMaterial
		if own_material != null:
			materials.append(own_material)
	elif node is TileMap:
		for i in range(node.get_layers_count()):
			var layer_material = node.get_layer_material(i) as ShaderMaterial
			if layer_material != null:
				materials.append(layer_material)
	# Also check child sprites (for nodes like StaticBody2D that have Sprite2D children)
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			var child_material = child.material as ShaderMaterial
			if child_material != null:
				materials.append(child_material)
	return materials


func _update_material_enabled():
	"""Update the enabled state on all materials."""
	_update_material_property("enabled", enabled)


func _update_material_property(property: String, value: Variant):
	"""Update a property on all revealable materials."""
	if reveal_material == null:
		return
	
	var revealables = get_tree().get_nodes_in_group(REVEALABLE_GROUP)
	for node in revealables:
		for shader_mat in _get_node_materials(node):
			shader_mat.set_shader_parameter(property, value)
