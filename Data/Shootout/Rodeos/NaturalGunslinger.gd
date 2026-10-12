extends Node


var data = {
	"name": "Natural Gunslinger",
	"description": "Cannot Miss or Graze",
	"trigger": "always",
	"conditions": {
		"target": "self"
	},
	"effects": [
		{ "op": "set_hit_quality_floor", "value": 2 }
	],
	"scaling": {}
}
