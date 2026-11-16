extends Node


var data = {
	"name": "Dust Whisperer",
	"magazine": [-1, 0, 1, 0],
	"abilities": [
		"Bleed cleanse and affliction",
		"Poison cleanse and affliction",
		"Damage type mark applications",
		"Damage decrease applications",
		"Damage piercing application"
	],
	"beltSpace": 5,
	"defense": { "sand": 0 },
	"explosiveBase": 3,
	"jammed": {
		"target": "self",
		"effects": [
			{ "op": "apply_effect", "effect": "decrease", "amount": 1, "turns": 1 }
		]
	}
}
