extends Node


# Dust Whisperer, "Bleed cleanse and affliction" cleanse half
# (Docs/Combat.md classes): stops an ally's bleeding.
var data = {
	"name": "Bleed Cleanse",
	"description": "Staunch an ally's bleeding",
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
		{ "op": "cleanse_effect", "effect": "bleed", "amount": 1 }
	]
}