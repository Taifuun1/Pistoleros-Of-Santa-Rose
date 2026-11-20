extends Node


# Line Rider (Docs/Combat.md classes): anti-Sand rider. Poison cleanse and the
# self piercing buff are executable now (commit 17); the position-disruption
# design has no move op yet and stays in futureAbilities.
var data = {
	"name": "Line Rider",
	"magazine": [1, 1, -1, 0],
	"moves": [
		"Poison Cleanse",
		"Sharpened Spurs"
	],
	"futureAbilities": [
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
