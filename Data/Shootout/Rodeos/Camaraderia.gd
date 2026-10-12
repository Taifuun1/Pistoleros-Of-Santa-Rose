extends Node


var data = {
	"name": "Camaradería",
	"description": "The ally in front gains additional MxHp",
	"trigger": "fight_start",
	"conditions": {
		"target": "ally_in_front"
	},
	"effects": [
		{ "op": "modify_stat", "stat": "maxHp", "amount": 2, "duration": "fight" }
	],
	"scaling": { "stat": "level", "perLevel": 1, "appliesTo": "amount" }
}
