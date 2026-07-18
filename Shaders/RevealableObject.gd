extends Node2D
class_name RevealableObject

## Attach this script to any object (Sprite2D, AnimatedSprite2D, or parent Node2D)
## that should become transparent when the player is behind it.
## The object is added to the "revealable" group and requests the reveal
## material from the PlayerRevealController in the scene.

# Whether this object should be revealable
@export var is_revealable: bool = true

# Custom reveal radius override (0 = use default)
@export var custom_reveal_radius: float = 0.0

# Custom minimum alpha override (0 = use default)
@export var custom_min_alpha: float = 0.0

# How many frames to keep looking for a PlayerRevealController before giving up
const MAX_CONTROLLER_WAIT_FRAMES: int = 10


func _ready():
	if is_revealable:
		_register()


func _register():
	# Add this node to the revealable group
	add_to_group("revealable")
	# Group membership alone has no effect: the PlayerRevealController assigns
	# reveal materials only once in init(), so objects that enter the scene
	# afterwards (or before the controller is ready) must request the material
	# themselves. This runs deferred so it happens after every _ready().
	_ensure_material_applied()


func _ensure_material_applied(frames_waited: int = 0):
	if not is_inside_tree():
		return
	await get_tree().process_frame
	# The node may have been freed or removed (e.g. chunk unload) while waiting
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var controller = _get_reveal_controller()
	if controller == null or controller.reveal_material == null:
		# The controller may not have finished _ready() yet - retry a few frames
		if frames_waited < MAX_CONTROLLER_WAIT_FRAMES:
			_ensure_material_applied(frames_waited + 1)
		else:
			push_warning("RevealableObject '%s': no PlayerRevealController found in the scene, reveal effect disabled." % name)
		return
	
	controller._apply_material_to_node(self)
	# Apply custom settings only AFTER the material exists - otherwise they are
	# silently lost, or wiped when the controller (re)applies the material
	_apply_custom_settings()


func _get_reveal_controller() -> PlayerRevealController:
	var controllers = get_tree().get_nodes_in_group(PlayerRevealController.CONTROLLER_GROUP)
	if controllers.is_empty():
		return null
	return controllers[0] as PlayerRevealController


func _apply_custom_settings():
	if custom_reveal_radius <= 0.0 and custom_min_alpha <= 0.0:
		return
	for reveal_material in _get_materials():
		if custom_reveal_radius > 0.0:
			reveal_material.set_shader_parameter("reveal_radius", custom_reveal_radius)
		if custom_min_alpha > 0.0:
			reveal_material.set_shader_parameter("min_alpha", custom_min_alpha)


func _get_materials() -> Array[ShaderMaterial]:
	# Collect the shader materials of this node and its child sprites, matching
	# the nodes the PlayerRevealController applies materials to. Reading the own
	# material directly also covers the script being attached to a Sprite2D or
	# AnimatedSprite2D ("self is Sprite2D" would be a compile error here, since
	# this script statically extends Node2D - which broke the original script).
	var materials: Array[ShaderMaterial] = []
	var own_material = material as ShaderMaterial
	if own_material != null:
		materials.append(own_material)
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			var child_material = child.material as ShaderMaterial
			if child_material != null:
				materials.append(child_material)
	return materials


func set_revealable(value: bool):
	if value == is_revealable:
		return
	is_revealable = value
	if is_revealable:
		_register()
	else:
		var controller = _get_reveal_controller()
		if controller != null:
			# Also clears the reveal material(s), not just the group membership
			controller.remove_revealable(self)
		else:
			remove_from_group("revealable")


func set_enabled(enabled: bool):
	for reveal_material in _get_materials():
		reveal_material.set_shader_parameter("enabled", enabled)