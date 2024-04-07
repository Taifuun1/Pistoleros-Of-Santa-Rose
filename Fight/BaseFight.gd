extends Node2D

@onready var fightActor = preload("res://Actors/Fight/FightActor.tscn")

var fightActors = {}


func _ready():
	init(
		{
			"player team": {
				"Named People": {
					"Walker Langley": {
						"row": 1,
						"column": 2
					}
				}
			},
			"enemy team": {
				"Animals": {
					"Squeky Rat": {
						"row": 1,
						"column": 2
					}
				}
			}
		}
	)

func init(actors: Dictionary):
	fightActors = actors
	for actorSide in actors:
		for actorType in actors[actorSide]:
			for actorName in actors[actorSide][actorType]:
				var newFightActor = fightActor.instantiate()
				$Actors.add_child(newFightActor)
				$Actors.get_children()[$Actors.get_child_count() - 1].init(actorType, actorName, actors[actorSide][actorType][actorName], actorSide)
	
