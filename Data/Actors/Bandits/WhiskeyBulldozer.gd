extends Node


# Whispering Pines Reach bandit (commit 17): the Bottle Courage Bulldozer
# tank. Holds the line at the front and buffs itself; the authored rifle sheet
# decides the carried weapon (Docs/Combat.md's revolver-only note awaits the
# art follow-up).
var data = {
	"actorName": "Whiskey Bulldozer",
	"hp": 12,
	"walkingSpeed": 75,
	"runningSpeed": 25,
	"stats": {
		"sixShootin": 1,
		"highTailin": 2,
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
		"defense": { "style": 0, "sand": 4 },
		"resistances": { "bleed": 0.0, "poison": 0.0 }
	},
	"rodeo": null,
	"ai": {
		"archetype": "tank",
		"pickFromTop": 2,
		"weights": { "offense": 0.5, "support": 0.6, "defense": 1.2, "reposition": 0.4 },
		"preferredColumns": [1],
	},
	"characterClass": "Bottle Courage Bulldozer",
	"moves": ["Sharp Shot", "Bottle Up", "Cylinder Boost", "Duck Down"],
	"items": ["Paregoric"],
	"magazine": [0, 2, 0, -1],
	"weapon": {
		"type": "lead",
		"weapon": "rifle",
		"baseDamage": 3
	}
}
