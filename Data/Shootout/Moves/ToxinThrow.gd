extends Node


# Dust Whisperer, "Poison cleanse and affliction" affliction half
# (Docs/Combat.md classes): throws a poison pouch at the target.
var data = {
	"name": "Toxin Throw",
	"description": "Hurl a poison pouch that lingers",
	"category": "ability",
	"side": "enemy",
	"positions": {
		"type": "single",
		"actorUser": [1, 2, 3, 4],
		"targets": {
			"columns": [1, 2, 3, 4]
		}
	},
	"effects": [
		{ "op": "apply_effect", "effect": "poison", "amount": 1, "rounds": 3 }
	]
}