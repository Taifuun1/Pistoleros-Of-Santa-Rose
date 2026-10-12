extends Node


var data = {
	"name": "Leaders Duck",
	"description": "Every other turn, at the end of the turn, move one column backward",
	"trigger": "turn_end",
	"conditions": {
		"target": "self",
		"everyOtherTurn": 2
	},
	"effects": [
		{ "op": "move_position", "direction": "backward", "amount": 1 }
	],
	"scaling": {}
}
