extends Node


# Bobtail Guard (Docs/Combat.md classes): anti-Style rifle guard. The former
# futureAbilities prose is executable now (commit 17) and lives in canonical
# `moves` grants; the position-disruption designs stay deferred.
var data = {
	"name": "Bobtail Guard",
	"magazine": [0, 1, 0, 1],
	"moves": [
		"Venom Shot",
		"Cylinder Drop",
		"Mark Target"
	],
	"futureAbilities": [],
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
