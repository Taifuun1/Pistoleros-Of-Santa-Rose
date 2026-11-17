extends Node


# Class data (decided: dedicated Data/Shootout/Classes folder).
# Magazine/moves/beltSpace are placeholders for balancing. `moves` grants real
# canonical Move ids; `futureAbilities` keeps the unimplemented design prose out
# of the runtime loadout (Docs/System Design/First Steps Implementation Plan.md,
# commit 11).
var data = {
	"name": "Gunslinger",
	"magazine": [1, 0, 1, -1],
	"moves": [
		"Sharp Shot",
		"Hold Steady",
		"Duck Down"
	],
	"futureAbilities": [
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
