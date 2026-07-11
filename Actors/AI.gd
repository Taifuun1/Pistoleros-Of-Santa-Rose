extends AStar

var speed = 75

var aIType = "passive"

var movementPath = []
var currentMovementTarget = null


func _location_scene() -> Node:
	var scene := get_tree().current_scene
	# Location scenes can be embedded by tests or transition wrappers.
	if scene != null and not scene.has_node("Entities/Actors/LocationActor") and get_parent() != null:
		return get_parent().get_parent()
	return scene


func init(newAIType):
	aIType = newAIType

func _physics_process(delta):
	if currentMovementTarget != null:
		var direction = Vector2.ZERO
		var scene := _location_scene()
		var localActorPosition = scene.get_node("Entities/Actors/LocationActor").global_position
		#localActorPosition.y += 6
		
		direction = currentMovementTarget - localActorPosition
		direction = direction.normalized()
		
		scene.get_node("Entities/Actors/LocationActor").global_position = localActorPosition.move_toward(currentMovementTarget, delta * speed)
		
		#get_tree().current_scene.get_node("Entities/Actors/NpcActor").velocity = direction * speed
		#
		#get_tree().current_scene.get_node("Entities/Actors/NpcActor").move_and_slide()
		
		#print(currentMovementTarget)
		#print(movementPath)
		#print(direction)
		if scene.get_node("Entities/Actors/LocationActor").position.distance_to(currentMovementTarget) < 1:
			currentMovementTarget = null
		
		return
	
	checkMovementTarget()

func checkMovementTarget():
	if currentMovementTarget == null and !movementPath.is_empty():
		changeMovementTarget()

func changeMovementTarget():
	currentMovementTarget = _location_scene().get_node("Map").map_to_local(movementPath[0])
	#currentMovementTarget.x += HelperVariables.tileSize.x / 2
	currentMovementTarget.y += HelperVariables.tileSize.y / 2
	movementPath.remove_at(0)


func _on_timer_timeout():
	if currentMovementTarget == null and movementPath.is_empty():
		match aIType:
			"passive":
				if randi() % 2 == 0:
					var scene := _location_scene()
					if scene == null or not scene.has_node("Entities/Actors/LocationActor"):
						return
					var randomNearbyPosition = Vector2i(scene.get_node("Entities/Actors/LocationActor").position) + Vector2i(((randi() % 4 + 1) + -2) * HelperVariables.tileSize.x, ((randi() % 4 + 1) + -2) * HelperVariables.tileSize.y)
					if scene.has_node("Map") and pathfindingAstarNode != null:
						movementPath = scene.get_node("AI/Pathfinding").calculatePath(pathfindingAstarNode, scene.get_node("Map").local_to_map(to_local(scene.get_node("Entities/Actors/LocationActor").position - Vector2(0, HelperVariables.tileSize.y / 2))), scene.get_node("Map").local_to_map(to_local(randomNearbyPosition)))
					checkMovementTarget()
				$Timer.start(3)
