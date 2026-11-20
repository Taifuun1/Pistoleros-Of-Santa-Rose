extends Node


# Bobtail Guard, "Mark affliction" (Docs/Combat.md classes): marks the target
# so the next hit lands harder (Docs/System Design/Shootout/Effects.md).
var data = {
	"name": "Mark Target",
	"description": "Paint a target on them: the next hit lands harder",
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
		{ "op": "apply_effect", "effect": "mark", "extraDamage": 2, "rounds": 2 }
	]
}