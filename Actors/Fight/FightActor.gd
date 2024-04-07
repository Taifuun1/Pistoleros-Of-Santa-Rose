extends Node2D


func init(actorType, actorName, actorPosition, actorSide):
	var animations = load("res://Animations/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.replace(" ", "") })).instantiate()
	animations.name = actorName
	add_child(animations)
	
	position = Fight.fightPositions[actorSide][actorPosition.row][actorPosition.column]
