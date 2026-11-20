extends Node


# Bottle Courage Bulldozer (Docs/Combat.md classes): tank. The defense/cylinder
# prose is executable now (commit 17) and taunting is the authored Duck Down;
# the position-disruption design has no move op yet and stays deferred.
var data = {
	"name": "Bottle Courage Bulldozer",
	"magazine": [0, 2, 0, -1],
	"moves": [
		"Bottle Up",
		"Cylinder Boost",
		"Duck Down"
	],
	"futureAbilities": [
		"Disrupt second and third position positioning"
	],
	"beltSpace": 1,
	"defense": { "sand": 4 },
	"explosiveBase": 0,
	"jammed": {
		"target": "self",
		"effects": [
			{ "op": "apply_effect", "effect": "decrease", "amount": 1, "turns": 1 }
		]
	}
}
