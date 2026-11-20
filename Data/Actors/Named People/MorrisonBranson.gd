extends Node


# Main party member (commit 17): the gang's guard.
var data = {
	"actorName": "Morrison Branson",
	"hp": 11,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 2,
		"highTailin": 4,
		"taffyin": 2,
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
		"defense": { "style": 1, "sand": 2 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"characterClass": "Bobtail Guard",
	"moves": ["Venom Shot", "Mark Target", "Hold Steady"],
	"items": ["Paregoric"],
	"magazine": [0, 1, 0, 1],
	"weapon": {
		"type": "lead",
		"weapon": "rifle",
		"baseDamage": 3
	}
}
