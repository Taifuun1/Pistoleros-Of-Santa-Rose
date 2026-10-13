extends Node


var data = {
	"name": "Hold Steady",
	"description": "Catch your breath: heal a little each Turn",
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
		{ "op": "apply_effect", "effect": "heal_over_time", "amount": 2, "turns": 3 }
	]
}
