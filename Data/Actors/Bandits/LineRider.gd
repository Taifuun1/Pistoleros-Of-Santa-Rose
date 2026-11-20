extends Node


# Whispering Pines Reach bandit (commit 17): the anti-Sand rider. Hits hard
# from the mid columns and keeps its own shots piercing.
var data = {
	"actorName": "Line Rider",
	"hp": 8,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 2,
		"highTailin": 5,
		"taffyin": 1,
		"damage": {
			"lead": {
				"revolver": 1,
				"rifle": 1,
				"shotgun": 1
			},
			"explosive": {
				"gunpowder": 1,
				"liquid": 1,
				"shrapnel": 1
			}
		},
		"defense": { "style": 1, "sand": 1 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"ai": {
		"archetype": "damage",
		"pickFromTop": 2,
		"weights": { "offense": 1.0, "support": 0.4, "defense": 0.4, "reposition": 0.8 },
		"preferredColumns": [2, 3],
	},
	"characterClass": "Line Rider",
	"moves": ["Sharp Shot", "Sharpened Spurs", "Poison Cleanse"],
	"items": ["Paregoric"],
	"magazine": [1, 1, -1, 0],
	"weapon": {
		"type": "lead",
		"weapon": "rifle",
		"baseDamage": 3
	}
}
