extends Node


var data = {
	"name": "Sharp Shot",
	"baseAmount": 5,
	"statScaling": 0.25,
	"scalingStat": "sixShootin",
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
			"target": "selectedActor",
			"sprite": "icon",
			"path": "res://Animations/Shootout/Moves/SharpShot.tscn"
		},
		{
			"target": "actingActor",
			"animation": "Shoot"
		}
	]
}
