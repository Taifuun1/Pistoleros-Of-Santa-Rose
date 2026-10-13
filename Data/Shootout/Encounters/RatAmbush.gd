extends Node


# Debug/default encounter (Docs/System Design/Shootout/Encounters.md).
var data = {
	"name": "Rat Ambush",
	"kind": "dustup",
	"flavor": "Hold-up",
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"lootTable": "Rats",
	"winCondition": { "type": "rout" },
	"teams": {
		"player team": {
			"Named People": {
				"Walker Langley": {
					"positions": [1, 2, 3]
				}
			}
		},
		"enemy team": {
			"Animals": {
				"Squeky rat": {
					"positions": [1, 2, 3]
				}
			}
		}
	}
}
