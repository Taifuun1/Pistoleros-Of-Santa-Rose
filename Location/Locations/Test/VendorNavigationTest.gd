extends Node2D

## Generic-Location navigation fixture for TestVendorNavigation. Location.tscn
## loads this through Locations.currentLocation.location; initLocation mirrors
## BaseLocation's deferred Dictionary playerPosition contract without requiring
## cutscene/fade content.

func initLocation() -> void:
	var player = load("res://Actors/Location/PlayerLocationActor.tscn").instantiate()
	player.name = "PlayerActor"
	$Entities/Actors.add_child(player)
	if typeof(Locations.currentLocation) == TYPE_DICTIONARY:
		player.global_position = Locations.currentLocation.get("playerPosition", Vector2.ZERO)
