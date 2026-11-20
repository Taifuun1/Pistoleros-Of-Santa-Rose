extends Node


# Whispering Pines Reach showdown (commit 17): the bandit crew's core — tank,
# support and rider — against three Pistoleros of Santa Rose. The support and
# tank archetypes play their commit-13 per-family weights in a real fight.
var data = {
	"name": "Whiskey Bend Standoff",
	"kind": "showdown",
	"flavor": "Gunfight",
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"lootTable": "Bandits",
	"winCondition": { "type": "rout" },
	"teams": {
		"player team": {
			"Named People": {
				"Walker Langley": {
					"positions": [1]
				},
				"Morrison Branson": {
					"positions": [2]
				},
				"Manuel Cárdenas": {
					"positions": [3]
				}
			}
		},
		"enemy team": {
			"Bandits": {
				"Whiskey Bulldozer": {
					"positions": [1]
				},
				"Line Rider": {
					"positions": [2]
				},
				"Dust Whisperer": {
					"positions": [3]
				}
			}
		}
	}
}
