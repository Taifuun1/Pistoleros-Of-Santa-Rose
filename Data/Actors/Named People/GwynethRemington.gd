extends Node


# Main party member (commit 17): the Rifle of the gang.
var data = {
	"actorName": "Gwyneth Remington",
	"hp": 11,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 3,
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
	"characterClass": "Gunslinger",
	"moves": ["Sharp Shot", "Hold Steady"],
	"items": ["Paregoric"],
	"magazine": [0, 1, 2],
	"weapon": {
		"type": "lead",
		"weapon": "rifle",
		"baseDamage": 4
	}
}
