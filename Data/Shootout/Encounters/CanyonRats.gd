extends Node


# Regular canyon encounter (Docs/System Design/Shootout/Encounters.md and
# Location Vendors Implementation.md, Newspaper data): a small rat pack that
# raids the trail caches. Uses the authored Squeky rat enemy actor and the
# default rout win condition, so the newspaper projection matches real content.
var data = {
	"name": "Canyon Rats",
	"kind": "dustup",
	"flavor": "Scuffle",
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