extends Node


var data = {
	"name": "Paregoric",
	"baseAmount": 5,
	"side": "player",
	"positions": {
		"type": "single",
		"targets": {
			"columns": [1, 2, 3, 4]
		}
	},
	"animations": [
		{
			"target": "selectedActor",
			"sprite": "icon",
			"path": "res://Animations/Shootout/Items/Paregoric.tscn"
		}
	]
}
