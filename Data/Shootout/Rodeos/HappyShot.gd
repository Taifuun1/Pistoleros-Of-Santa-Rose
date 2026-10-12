extends Node


var data = {
	"name": "Happy Shot",
	"description": "Gain additional High Tailin' in the first column",
	"trigger": "always",
	"conditions": {
		"target": "self",
		"position": [1]
	},
	"effects": [
		{ "op": "modify_stat", "stat": "highTailin", "amount": 2, "duration": "fight" }
	],
	"scaling": { "stat": "level", "perLevel": 1, "appliesTo": "amount" }
}
