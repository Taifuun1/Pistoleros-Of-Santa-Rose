extends Node


# Regular canyon encounter (Docs/System Design/Shootout/Encounters.md and
# Location Vendors Implementation.md, Newspaper data): a full rat nest, four
# separate attackers. Same authored enemy actor and rout win condition as
# CanyonRats, so published compositions stay accurate.
var data = {
	"name": "Canyon Rat Nest",
	"kind": "dustup",
	"flavor": "Ruckus",
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
					"positions": [1, 2, 3, 4]
				}
			}
		}
	}
}