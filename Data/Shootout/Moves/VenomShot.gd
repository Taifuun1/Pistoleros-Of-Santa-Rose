extends Node


# Bobtail Guard, "Attack and poison affliction" (Docs/Combat.md classes): an
# attack ability that leaves poison on the target (Docs/System Design/Shootout/
# Effects.md). Resolves through the shared resolver/effects pipeline.
var data = {
	"name": "Venom Shot",
	"category": "attack_ability",
	"baseAmount": 3,
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
	],
	"animations": [
		{
			"target": "actingActor",
			"animation": "Shoot"
		}
	]
}