extends Node


var data = {
	"name": "Bobtail Guard",
	"magazine": [0, 1, 0, 1],
	"moves": [],
	"futureAbilities": [
		"Attack and poison affliction",
		"Cylinder drop affliction",
		"Mark affliction"
	],
	"beltSpace": 2,
	"defense": { "sand": 3 },
	"explosiveBase": 0,
	"jammed": {
		"target": "self",
		"effects": [
			{ "op": "apply_effect", "effect": "decrease", "amount": 1, "turns": 1 }
		]
	}
}
