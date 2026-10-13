extends Node


# Duck placeholder (Docs/System Design/Shootout/Moves Items and Ducks.md):
# defensive buff for allies; effects only, never advances the Cylinder.
var data = {
	"name": "Duck Down",
	"description": "Duck behind the line and draw fire: taunt the positions allies stand on",
	"category": "duck",
	"side": "player",
	"positions": {
		"type": "single",
		"actorUser": [1, 2, 3, 4],
		"targets": {
			"columns": [1, 2, 3, 4]
		}
	},
	"effects": [
		{ "op": "apply_effect", "effect": "taunt", "rounds": 2 }
	]
}
