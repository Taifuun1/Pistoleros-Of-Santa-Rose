extends Node


# Main party member (commit 17): the gang's tank.
var data = {
	"actorName": "Manuel Cárdenas",
	"hp": 13,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 1,
		"highTailin": 3,
		"taffyin": 3,
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
		"defense": { "style": 0, "sand": 3 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"characterClass": "Bottle Courage Bulldozer",
	"moves": ["Sharp Shot", "Bottle Up", "Duck Down"],
	"items": ["Paregoric"],
	"magazine": [0, 2, 0, -1],
	"weapon": {
		"type": "lead",
		"weapon": "revolver",
		"baseDamage": 3
	}
}
