extends Node


# Bobtail Guard, "Cylinder drop affliction" (Docs/Combat.md classes): drops
# every numeric Chamber of the target's Cylinder by one (Docs/System Design/
# Shootout/Cylinders.md, modify_cylinder op).
var data = {
	"name": "Cylinder Drop",
	"description": "Rattle their cylinder: every Chamber drops one step",
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
		{ "op": "modify_cylinder", "chambers": "all", "amount": -1 }
	]
}