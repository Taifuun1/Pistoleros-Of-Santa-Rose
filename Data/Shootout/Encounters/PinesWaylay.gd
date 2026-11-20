extends Node


# Whispering Pines Reach regular encounter (commit 17): a waylay with the
# anti-Style guard anchoring the back column behind two Pistoleros. Aiyana
# fights from her authored Data/Actors file (the live Party still only
# carries Walker Langley).
var data = {
	"name": "Whispering Pines Waylay",
	"kind": "dustup",
	"flavor": "Hold-up",
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"lootTable": "Bandits",
	"winCondition": { "type": "rout" },
	"teams": {
		"player team": {
			"Named People": {
				"Walker Langley": {
					"positions": [1]
				},
				"Aiyana": {
					"positions": [2]
				},
				"Gwyneth Remington": {
					"positions": [3]
				}
			}
		},
		"enemy team": {
			"Bandits": {
				"Pistolero": {
					"positions": [1, 2]
				},
				"Bobtail Guard": {
					"positions": [3]
				}
			}
		}
	}
}
