extends Node


# Dust Whisperer / Line Rider, "Poison cleanse and affliction" cleanse half
# (Docs/Combat.md classes): purges poison from an ally.
var data = {
	"name": "Poison Cleanse",
	"description": "Draw the poison out of an ally",
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
		{ "op": "cleanse_effect", "effect": "poison", "amount": 1 }
	]
}