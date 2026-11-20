extends Node


# Dust Whisperer, "Bleed cleanse and affliction" affliction half
# (Docs/Combat.md classes): opens a bleeding wound on the target.
var data = {
	"name": "Open Vein",
	"description": "Open a wound that keeps bleeding",
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
		{ "op": "apply_effect", "effect": "bleed", "amount": 2 }
	]
}