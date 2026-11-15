extends Node2D

## Shared initializer for pregenerated Locations (Docs/System Design/Location
## Vendors Implementation.md, patch 3). SceneManager passes an explicit
## playerPosition when returning from a vendor room; ordinary entries leave the
## authored static player position untouched.

func initScene(context: Dictionary) -> void:
	if !context.has("playerPosition"):
		return
	var player = get_node_or_null("Entities/Actors/PlayerActor")
	if player is Node2D:
		player.global_position = context["playerPosition"]
