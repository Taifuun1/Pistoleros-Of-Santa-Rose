extends Node


# Class data (decided: dedicated Data/Shootout/Classes folder).
# Magazine/abilities/beltSpace are placeholders for balancing.
var data = {
	"name": "Gunslinger",
	"magazine": [1, 0, 1, -1],
	"abilities": [
		"Attack and self cylinder increase",
		"Attack and bleed affliction",
		"Self-increase damage type",
		"Self-cleanse bleed"
	],
	"beltSpace": 1,
	"defense": { "sand": 1 },
	"explosiveBase": 0,
	# Authored Jammed payload (Docs/System Design/Shootout/Cylinders.md): a
	# jammed attack spends the Move and applies this to the acting actor.
	"jammed": {
		"target": "self",
		"effects": [
			{ "op": "apply_effect", "effect": "decrease", "amount": 1, "turns": 1 }
		]
	}
}
