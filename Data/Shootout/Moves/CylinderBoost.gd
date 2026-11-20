extends Node


# Bottle Courage Bulldozer, "Cylinder increase application" (Docs/Combat.md
# classes): loads an ally's Cylinder one Chamber heavier.
var data = {
	"name": "Cylinder Boost",
	"description": "Load an ally's Cylinder one Chamber heavier",
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
		{ "op": "modify_cylinder", "chambers": "all", "amount": 1 }
	]
}