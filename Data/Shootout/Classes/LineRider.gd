extends Node


var data = {
	"name": "Line Rider",
	"magazine": [1, 1, -1, 0],
	"moves": [],
	"futureAbilities": [
		"Poison cleanse",
		"Self-increase damage piercing",
		"Disrupt first and second position positioning"
	],
	"beltSpace": 2,
	"defense": { "sand": 1 },
	"explosiveBase": 0,
	"jammed": {
		"target": "self",
		"effects": [
			{ "op": "apply_effect", "effect": "decrease", "amount": 1, "turns": 1 }
		]
	}
}
