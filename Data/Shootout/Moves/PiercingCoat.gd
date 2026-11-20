extends Node


# Dust Whisperer, "Damage piercing application" (Docs/Combat.md classes):
# coats an ally's shots so they punch through defense.
var data = {
	"name": "Piercing Coat",
	"description": "Coat an ally's shots so they punch through defense",
	"category": "ability",
	"side": "player",
	"positions": {
		"type": "single",
		"actorUser": [1, 2, 3, 4],
		"targets": {
			"columns": [1, 2, 3, 4]
		}
	},
	"effects": [
		{ "op": "apply_effect", "effect": "piercing", "amount": 2, "turns": 2 }
	]
}