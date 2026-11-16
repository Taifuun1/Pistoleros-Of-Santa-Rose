extends Node


# Rats fight with authored Moves only (Docs/System Design/System Coherence.md,
# no basic attacks). Uses the rat's existing scratch weapon animation.
var data = {
	"name": "Scratch",
	"category": "attack_ability",
	"baseAmount": 2,
	"side": "enemy",
	"positions": {
		"type": "single",
		"actorUser": [1, 2, 3, 4],
		"targets": {
			"columns": [1, 2, 3, 4]
		}
	},
	"animations": [
		{
			"target": "actingActor",
			"animation": "Melee"
		}
	]
}