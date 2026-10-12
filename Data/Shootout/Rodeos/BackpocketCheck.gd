extends Node


var data = {
	"name": "Backpocket Check",
	"description": "At the end of a won fight, gain extra cash",
	"trigger": "fight_end",
	"conditions": {
		"target": "self",
		"winningSide": "player team"
	},
	"effects": [
		{ "op": "modify_loot", "stat": "money", "amount": 10 }
	],
	"scaling": { "stat": "level", "perLevel": 5, "appliesTo": "amount" }
}
