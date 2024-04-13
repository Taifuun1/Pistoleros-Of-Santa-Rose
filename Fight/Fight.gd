extends Node2D

@onready var fightActor = preload("res://Actors/Fight/FightActor.tscn")

var fightActors = {}

var turnOrder = []
var playerAction = true


func _ready():
	init(
		{
			"player team": {
				"Named People": {
					"Walker Langley": {
						"positions": [
							#{
								#"column": 1,
								#"row": 1
							#},
							{
								"column": 1,
								"row": 2
							},
							#{
								#"column": 1,
								#"row": 3
							#},
							#{
								#"column": 1,
								#"row": 4
							#},
							#{
								#"column": 2,
								#"row": 1
							#},
							#{
								#"column": 2,
								#"row": 2
							#},
							#{
								#"column": 2,
								#"row": 3
							#},
							#{
								#"column": 2,
								#"row": 4
							#},
							#{
								#"column": 3,
								#"row": 1
							#},
							#{
								#"column": 3,
								#"row": 2
							#},
							#{
								#"column": 3,
								#"row": 3
							#},
							#{
								#"column": 3,
								#"row": 4
							#},
							#{
								#"column": 4,
								#"row": 1
							#},
							#{
								#"column": 4,
								#"row": 2
							#},
							#{
								#"column": 4,
								#"row": 3
							#},
							#{
								#"column": 4,
								#"row": 4
							#}
						]
					}
				}
			},
			"enemy team": {
				"Animals": {
					"Squeky Rat": {
						"positions": [
							#{
								#"column": 1,
								#"row": 1
							#},
							{
								"column": 1,
								"row": 2
							},
							#{
								#"column": 1,
								#"row": 3
							#},
							#{
								#"column": 1,
								#"row": 4
							#},
							#{
								#"column": 2,
								#"row": 1
							#},
							#{
								#"column": 2,
								#"row": 2
							#},
							#{
								#"column": 2,
								#"row": 3
							#},
							#{
								#"column": 2,
								#"row": 4
							#},
							#{
								#"column": 3,
								#"row": 1
							#},
							#{
								#"column": 3,
								#"row": 2
							#},
							#{
								#"column": 3,
								#"row": 3
							#},
							#{
								#"column": 3,
								#"row": 4
							#},
							#{
								#"column": 4,
								#"row": 1
							#},
							#{
								#"column": 4,
								#"row": 2
							#},
							#{
								#"column": 4,
								#"row": 3
							#},
							#{
								#"column": 4,
								#"row": 4
							#}
						]
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
				for actorPosition in actors[actorSide][actorType][actorName].positions:
					var newFightActor = fightActor.instantiate()
					$Actors.add_child(newFightActor)
					$Actors.get_children()[$Actors.get_child_count() - 1].init()
					$Actors.get_children()[$Actors.get_child_count() - 1].initFightActor(actorType, actorName, actorPosition, actorSide)
					turnOrder.append(actorName)

#func _input(event):


func _on_fight_ui_attack():
	if playerAction:
		print("attacked")
		get_node("Actors/{actorName}").format({ "actorName": turnOrder.pop_front() })
