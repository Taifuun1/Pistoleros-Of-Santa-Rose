extends Node


# Dust Whisperer, "Damage type mark applications" (Docs/Combat.md classes):
# marks the target against one damage type so lead hits land harder.
var data = {
	"name": "Type Mark",
	"description": "Mark them for one damage type: that lead lands harder",
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
		{ "op": "apply_effect", "effect": "damage_type_mark", "damageType": "lead", "extraDamage": 2 }
	]
}