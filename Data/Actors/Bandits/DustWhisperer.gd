extends Node


# Whispering Pines Reach bandit (commit 17): the support/affliction class.
# Offense is the actor's own authored Sharp Shot; the class list is
# utility-only (see Data/Shootout/Classes/DustWhisperer.gd).
var data = {
	"actorName": "Dust Whisperer",
	"hp": 7,
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
		"defense": { "style": 0, "sand": 0 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"ai": {
		"archetype": "support",
		"pickFromTop": 2,
		"weights": { "offense": 0.3, "support": 1.0, "defense": 0.5, "reposition": 0.5 },
		"preferredColumns": [3, 4],
	},
	"characterClass": "Dust Whisperer",
	"moves": ["Sharp Shot", "Weaken", "Toxin Throw"],
	"items": ["Paregoric", "Paregoric"],
	"magazine": [-1, 0, 1, 0],
	"weapon": {
		"type": "lead",
		"weapon": "rifle",
		"baseDamage": 2
	}
}
