extends Node


# Whispering Pines Reach regular encounter (commit 17): a Pistolero patrol.
# Same rout win condition and shared background as the canyon encounters, so
# the newspaper projection matches real content.
var data = {
	"name": "Whispering Pines Patrol",
	"kind": "dustup",
	"flavor": "Scuffle",
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"lootTable": "Bandits",
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
			"Bandits": {
				"Pistolero": {
					"positions": [1, 2, 3]
				}
			}
		}
	}
}
