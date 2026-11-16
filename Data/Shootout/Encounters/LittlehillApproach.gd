extends Node


# Authored prologue quest fight. Payment belongs to quest progression, so the
# encounter itself produces no combat loot in either Trail state.
var data = {
	"name": "Littlehill Approach",
	"kind": "dustup",
	"flavor": "Ambush",
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"loot": false,
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
					"positions": [1, 2]
				}
			}
		}
	}
}
