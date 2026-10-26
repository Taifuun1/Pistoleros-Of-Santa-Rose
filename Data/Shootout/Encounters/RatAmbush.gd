extends Node


# Debug/default encounter (Docs/System Design/Shootout/Encounters.md).
var data = {
	"name": "Testing Encounter",
	"kind": "dustup",
	"flavor": "Test",
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"lootTable": "Rats",
	# Per-encounter music override (Docs/System Design/Music player.md):
	# a MusicPlayer track id. Omit to fall back to the MusicData encounter
	# registry / zone / default shootout list.
	# "music": "Shootout/Shootout1",
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
			"Named People": {
				"Walker Langley": {
					"positions": [1, 2, 3]
				}
			}
		}
	}
}
