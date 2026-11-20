extends Node


# Line Rider, "Self-increase damage piercing" (Docs/Combat.md classes):
# spurs sharpen the rider's own shots to punch through defense.
var data = {
	"name": "Sharpened Spurs",
	"description": "Sharpen your own shots to punch through defense",
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