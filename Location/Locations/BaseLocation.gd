extends Node2D


func initLocation():
	var player = load("res://Actors/Location/PlayerLocationActor.tscn").instantiate()
	player.position = Locations.currentLocation.playerPosition
	add_child(player)
	add_child(load("res://Cutscenes/Generic Cutscenes/Fade.tscn").instantiate())
	$Fade.play("Fade In")
