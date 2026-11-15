extends Node

## One interaction director per Location/vendor room (Docs/System Design/
## Location Vendors Implementation.md, patch 3). It selects the closest
## eligible proximity target and activates only that target on INTERACT.

signal targetChanged(target)
signal activated(target)

@onready var promptLabel: Label = get_node_or_null("Prompt")

var currentTarget: Node = null


func _ready() -> void:
	add_to_group("location_interaction_director")
	_updatePrompt()


func _physics_process(_delta: float) -> void:
	var best = _findBestTarget()
	if best == currentTarget:
		return
	currentTarget = best
	_updatePrompt()
	targetChanged.emit(currentTarget)


## The exact target an INTERACT press would activate, or null.
func getBestTarget() -> Node:
	return currentTarget


func _findBestTarget() -> Node:
	var best: Node = null
	var bestDistance := INF
	var bestPath := ""
	for target in get_tree().get_nodes_in_group("location_interactables"):
		if !is_instance_valid(target) or !(target is Node2D):
			continue
		if !target.is_inside_tree() or !target.is_visible_in_tree():
			continue
		if !target.has_method("canActivate") or !target.canActivate():
			continue
		var distance = target.distanceToPlayer()
		var path := str(target.get_path())
		if distance < bestDistance or (is_equal_approx(distance, bestDistance) and path < bestPath):
			best = target
			bestDistance = distance
			bestPath = path
	return best


func _unhandled_input(event: InputEvent) -> void:
	if !event.is_action_pressed("INTERACT") or event.is_echo():
		return
	if currentTarget == null:
		return
	get_viewport().set_input_as_handled()
	var target = currentTarget
	target.activate()
	activated.emit(target)


func _updatePrompt() -> void:
	if promptLabel == null:
		return
	if currentTarget == null:
		promptLabel.visible = false
		return
	promptLabel.visible = true
	promptLabel.text = str(currentTarget.interactionPrompt)
	promptLabel.global_position = currentTarget.global_position + Vector2(-40.0, -46.0)
