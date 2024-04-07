extends AStar

var speed = 75

var aIType = "passive"

var movementPath = []
var currentMovementTarget = null


func init(newAIType):
	aIType = newAIType

func _physics_process(delta):
	if currentMovementTarget != null:
		var direction = Vector2.ZERO
		var localActorPosition = get_tree().current_scene.get_node("Entities/Actors/NpcActor").global_position
		#localActorPosition.y += 6
		
		direction = currentMovementTarget - localActorPosition
		direction = direction.normalized()
		
		get_tree().current_scene.get_node("Entities/Actors/NpcActor").global_position = localActorPosition.move_toward(currentMovementTarget, delta * speed)
		
		#get_tree().current_scene.get_node("Entities/Actors/NpcActor").velocity = direction * speed
		#
		#get_tree().current_scene.get_node("Entities/Actors/NpcActor").move_and_slide()
		
		#print(currentMovementTarget)
		#print(movementPath)
		#print(direction)
		if get_tree().current_scene.get_node("Entities/Actors/NpcActor").position.distance_to(currentMovementTarget) < 1:
			currentMovementTarget = null
		
		return
	
	checkMovementTarget()

func checkMovementTarget():
	if currentMovementTarget == null and !movementPath.is_empty():
		changeMovementTarget()

func changeMovementTarget():
	currentMovementTarget = get_tree().current_scene.get_node("Map").map_to_local(movementPath[0])
	#currentMovementTarget.x += HelperVariables.tileSize.x / 2
	currentMovementTarget.y += HelperVariables.tileSize.y / 2
	movementPath.remove_at(0)


func _on_timer_timeout():
	if currentMovementTarget == null and movementPath.is_empty():
		match aIType:
			"passive":
				if randi() % 2 == 0:
					var randomNearbyPosition = Vector2i(get_tree().current_scene.get_node("Entities/Actors/NpcActor").position) + Vector2i(((randi() % 4 + 1) + -2) * HelperVariables.tileSize.x, ((randi() % 4 + 1) + -2) * HelperVariables.tileSize.y)
					if get_tree().current_scene.has_node("Map"):
						movementPath = get_tree().current_scene.get_node("AI/Pathfinding").calculatePath(pathfindingAstarNode, get_tree().current_scene.get_node("Map").local_to_map(to_local(get_tree().current_scene.get_node("Entities/Actors/NpcActor").position - Vector2(0, HelperVariables.tileSize.y / 2))), get_tree().current_scene.get_node("Map").local_to_map(to_local(randomNearbyPosition)))
					checkMovementTarget()
				$Timer.start(3)
