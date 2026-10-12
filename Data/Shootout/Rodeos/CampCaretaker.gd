extends Node


var data = {
	"name": "Camp Caretaker",
	"description": "At the end of the turn, cleanse one random affliction from adjacent characters",
	"trigger": "turn_end",
	"conditions": {
		"target": "adjacent_allies"
	},
	"effects": [
		{ "op": "cleanse_effect", "effect": "random", "amount": 1 }
	],
	"scaling": {}
}
