extends Node2D


func _ready() -> void:
	var location
	if Locations.currentQuest == "":
		location = load("res://Location/Locations/{currentLocation}.tscn".format({ "currentLocation": Locations.currentLocation.location })).instantiate()
	else:
		location = load("res://Location/Locations/{currentQuest}/{currentLocation}/{currentLocationNoWhitespace}.tscn".format({ "currentQuest": Locations.currentQuest, "currentLocation": Locations.currentLocation.location, "currentLocationNoWhitespace": Locations.currentLocation.location.capitalize().replace(" ", "") })).instantiate()
	add_child(location)
	location.initLocation()
