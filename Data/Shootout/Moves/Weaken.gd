extends Node


# Dust Whisperer, "Damage decrease applications" (Docs/Combat.md classes):
# dulls the target's outgoing damage for a while.
var data = {
	"name": "Weaken",
	"description": "Sap their strength: their shots hit softer",
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
		{ "op": "apply_effect", "effect": "decrease", "amount": 2, "turns": 2 }
	]
}