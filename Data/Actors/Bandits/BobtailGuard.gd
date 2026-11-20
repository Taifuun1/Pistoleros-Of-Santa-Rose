extends Node


# Whispering Pines Reach bandit (commit 17): the anti-Style rifle guard.
# Afflicts from the back columns; animations resolve through the commit-17a
# registry (Docs/System Design/Actor Animations.md).
var data = {
	"actorName": "Bobtail Guard",
	"hp": 9,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 1,
		"highTailin": 3,
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
		"defense": { "style": 0, "sand": 3 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"ai": {
		"archetype": "support",
		"pickFromTop": 2,
		"weights": { "offense": 0.6, "support": 1.0, "defense": 0.8, "reposition": 0.5 },
		"preferredColumns": [3, 4],
	},
	"characterClass": "Bobtail Guard",
	"moves": ["Venom Shot", "Mark Target", "Cylinder Drop"],
	"items": ["Paregoric"],
	"magazine": [0, 1, 0, 1],
	"weapon": {
		"type": "lead",
		"weapon": "rifle",
		"baseDamage": 3
	}
}
