extends Node


# Whispering Pines Reach bandit grunt (commit 17): a revolver Gunslinger.
# Animations resolve through the commit-17a registry (Docs/System Design/
# Actor Animations.md).
var data = {
	"actorName": "Pistolero",
	"hp": 6,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 2,
		"highTailin": 4,
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
		"defense": { "style": 1, "sand": 0 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"ai": {
		"archetype": "damage",
		"pickFromTop": 3,
		"weights": { "offense": 1.0, "support": 0.2, "defense": 0.5, "reposition": 0.5 },
	},
	"characterClass": "Gunslinger",
	"moves": ["Sharp Shot", "Duck Down"],
	"items": ["Paregoric"],
	"magazine": [1, 0, 1],
	"weapon": {
		"type": "lead",
		"weapon": "revolver",
		"baseDamage": 3
	}
}
