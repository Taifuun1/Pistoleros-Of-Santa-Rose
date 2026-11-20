extends Node


# Bottle Courage Bulldozer, "Self-increase damage type defense"
# (Docs/Combat.md classes): liquid courage hardens the bulldozer's Sand.
var data = {
	"name": "Bottle Up",
	"description": "Take a swig and harden your Sand",
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
		{ "op": "apply_effect", "effect": "stat_modifier", "stat": "sand", "amount": 2, "turns": 2 }
	]
}