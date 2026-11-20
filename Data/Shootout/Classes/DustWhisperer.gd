extends Node


# Dust Whisperer (Docs/Combat.md classes): support/affliction class. The
# cleanse/affliction/mark prose is executable now (commit 17); offense comes
# from the actor's own authored Moves because the class list is utility-only.
var data = {
	"name": "Dust Whisperer",
	"magazine": [-1, 0, 1, 0],
	"moves": [
		"Open Vein",
		"Bleed Cleanse",
		"Toxin Throw",
		"Poison Cleanse",
		"Type Mark",
		"Weaken",
		"Piercing Coat"
	],
	"futureAbilities": [],
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
