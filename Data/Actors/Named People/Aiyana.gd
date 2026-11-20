extends Node


# Main party member (commit 17): the Pistoleros' tracker. Animations resolve
# through the commit-17a registry; the production party is still initialized
# in Globals/Party.gd, so encounters reference this data file directly.
var data = {
	"actorName": "Aiyana",
	"hp": 10,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 3,
		"highTailin": 5,
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
		"defense": { "style": 2, "sand": 1 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"characterClass": "Gunslinger",
	"moves": ["Sharp Shot", "Hold Steady"],
	"items": ["Paregoric"],
	"magazine": [1, 0, 2],
	"weapon": {
		"type": "lead",
		"weapon": "revolver",
		"baseDamage": 4
	}
}
