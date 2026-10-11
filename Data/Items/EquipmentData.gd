## Equipment base data for item generation: equipment slots, generic base items
## and zone-tied items.
## Design source: Docs/Weapons and affixes.md ("Zone-Tied Items" section) and
## Docs/Combat.md ("Equipment" section).
##
## ASSUMPTIONS (not specified in the docs):
## - Zone item names are mapped onto the six Combat.md equipment slots:
##   headwear (John B.), bandana, duster, belt, trousers, justins (boots).
##   Spurs/Boots -> justins, Veil/Neckerchief -> bandana,
##   Coat/Poncho/Vest/Waistcoat -> duster, Bandolier -> belt.
## - "dropsAnywhere" is false for all zone items (the doc says items are either
##   zone-locked or drop anywhere, but doesn't say which are which).
## - "baseStats" (Style/Sand granted by the slot) are PLACEHOLDERS.

var slots = ["headwear", "bandana", "duster", "belt", "trousers", "justins"]

## Generic equipment used when no zone-tied item is rolled.
var genericBases = {
	"headwear": { "name": "John B.", "baseStats": { "style": 1 } },
	"bandana": { "name": "Bandana", "baseStats": {} },
	"duster": { "name": "Duster", "baseStats": { "style": 2, "sand": 2 } },
	"belt": { "name": "Belt", "baseStats": {} },
	"trousers": { "name": "Trousers", "baseStats": { "style": 1, "sand": 1 } },
	"justins": { "name": "Justins", "baseStats": { "sand": 1 } },
}

var spritePools = {
	"headwear": [
		"res://Assets/Equipment/HatBlue.png",
		"res://Assets/Equipment/HatBrown.png",
		"res://Assets/Equipment/HatCyan.png",
		"res://Assets/Equipment/HatCyanBright.png",
		"res://Assets/Equipment/HatGreen.png",
		"res://Assets/Equipment/HatGreenBright.png",
		"res://Assets/Equipment/HatPink.png",
		"res://Assets/Equipment/HatPinkBright.png",
		"res://Assets/Equipment/HatPinkDark.png",
		"res://Assets/Equipment/HatRed.png",
		"res://Assets/Equipment/HatRose.png",
		"res://Assets/Equipment/HatRoseDark.png",
		"res://Assets/Equipment/HatViolet.png",
		"res://Assets/Equipment/HatYellow.png",
	],
	"bandana": [],
	"duster": [
		"res://Assets/Equipment/CoatBrown.png",
		"res://Assets/Equipment/CoatDeepGrey.png",
		"res://Assets/Equipment/CoatGreen.png",
		"res://Assets/Equipment/CoatGrey.png",
		"res://Assets/Equipment/CoatLongBrown.png",
		"res://Assets/Equipment/CoatLongCoattailsBrown.png",
		"res://Assets/Equipment/CoatLongCoattailsDarkGreen.png",
		"res://Assets/Equipment/CoatLongCoattailsDarkPurple.png",
		"res://Assets/Equipment/CoatLongCoattailsDarkYellow.png",
		"res://Assets/Equipment/CoatLongCoattailsGreen.png",
		"res://Assets/Equipment/CoatLongCoattailsOrange.png",
		"res://Assets/Equipment/CoatLongCoattailsRed.png",
		"res://Assets/Equipment/CoatOrange.png",
		"res://Assets/Equipment/CoatPurple.png",
		"res://Assets/Equipment/CoatPurplePink.png",
		"res://Assets/Equipment/CoatRed.png",
		"res://Assets/Equipment/CoatSpurs.png",
		"res://Assets/Equipment/CoatStripes.png",
		"res://Assets/Equipment/JacketShortBlackYellow.png",
		"res://Assets/Equipment/JacketShortBlue.png",
		"res://Assets/Equipment/JacketShortBrightGreen.png",
		"res://Assets/Equipment/JacketShortGreen.png",
		"res://Assets/Equipment/JacketShortGreenYellow.png",
		"res://Assets/Equipment/JacketShortGreyGreen.png",
		"res://Assets/Equipment/JacketShortGreyYellow.png",
		"res://Assets/Equipment/JacketShortOrange.png",
		"res://Assets/Equipment/JacketShortRed.png",
		"res://Assets/Equipment/JacketShortYellow.png",
		"res://Assets/Equipment/JacketShortYellowBrown.png",
		"res://Assets/Equipment/PonchoBlue.png",
		"res://Assets/Equipment/PonchoBrown.png",
		"res://Assets/Equipment/PonchoCyan.png",
		"res://Assets/Equipment/PonchoGreen.png",
		"res://Assets/Equipment/PonchoOrange.png",
		"res://Assets/Equipment/PonchoPink.png",
		"res://Assets/Equipment/PonchoPinkBright.png",
		"res://Assets/Equipment/PonchoPinkViolet.png",
		"res://Assets/Equipment/PonchoRed.png",
		"res://Assets/Equipment/PonchoViolet.png",
		"res://Assets/Equipment/PonchoYellow.png",
	],
	"belt": [
		"res://Assets/Equipment/BeltBrown.png",
		"res://Assets/Equipment/BeltDarkBrown.png",
		"res://Assets/Equipment/BeltDarkBrownPink.png",
		"res://Assets/Equipment/BeltDarkBrownYellow.png",
		"res://Assets/Equipment/BeltDarkGreen.png",
		"res://Assets/Equipment/BeltDarkGrey.png",
		"res://Assets/Equipment/BeltDarkYellow.png",
		"res://Assets/Equipment/BeltLargeDarkGreen.png",
		"res://Assets/Equipment/BeltLargeDarkPurple.png",
		"res://Assets/Equipment/BeltLargeDarkRose.png",
		"res://Assets/Equipment/BeltLargeGreen.png",
		"res://Assets/Equipment/BeltLargeOrange.png",
		"res://Assets/Equipment/BeltLargeRed.png",
		"res://Assets/Equipment/BeltOrange.png",
	],
	"trousers": [
		"res://Assets/Equipment/TrousersBrown.png",
		"res://Assets/Equipment/TrousersCrossSewnBrown.png",
		"res://Assets/Equipment/TrousersCyan.png",
		"res://Assets/Equipment/TrousersGreen.png",
		"res://Assets/Equipment/TrousersOrange.png",
		"res://Assets/Equipment/TrousersPurple.png",
		"res://Assets/Equipment/TrousersRose.png",
		"res://Assets/Equipment/TrousersWorkOrangePastel.png",
		"res://Assets/Equipment/TrousersWorkPantsBlue.png",
		"res://Assets/Equipment/TrousersWorkPantsBrown.png",
		"res://Assets/Equipment/TrousersWorkPantsCyan.png",
		"res://Assets/Equipment/TrousersWorkPantsGreenPastel.png",
		"res://Assets/Equipment/TrousersWorkPantsRed.png",
		"res://Assets/Equipment/TrousersWorkPantsRose.png",
		"res://Assets/Equipment/TrousersWorkPinkPastel.png",
		"res://Assets/Equipment/TrousersWorkYellowPastel.png",
		"res://Assets/Equipment/TrousersYellow.png",
	],
	"justins": [
		"res://Assets/Equipment/BootsBrown.png",
		"res://Assets/Equipment/BootsDarkGreen.png",
		"res://Assets/Equipment/BootsDarkPurple.png",
		"res://Assets/Equipment/BootsOrange.png",
		"res://Assets/Equipment/BootsRose.png",
		"res://Assets/Equipment/BootsYellow.png",
		"res://Assets/Equipment/BootsSpursBlue.png",
		"res://Assets/Equipment/BootsSpursBrown.png",
		"res://Assets/Equipment/BootsSpursBrownPink.png",
		"res://Assets/Equipment/BootsSpursCyan.png",
		"res://Assets/Equipment/BootsSpursDarkBrown.png",
		"res://Assets/Equipment/BootsSpursDarkRose.png",
		"res://Assets/Equipment/BootsSpursGreen.png",
		"res://Assets/Equipment/BootsSpursOrange.png",
		"res://Assets/Equipment/BootsSpursRose.png",
		"res://Assets/Equipment/BootsSpursYellow.png",
	],
}


var zones = {
	"grassy_plains": {
		"displayName": "Grassy Plains / Forest",
		"items": [
			{ "name": "Prairie Rider Duster", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Green Hollow Bandana", "slot": "bandana", "dropsAnywhere": false },
			{ "name": "Meadowlark Boots", "slot": "justins", "dropsAnywhere": false },
		],
	},
	"hilly_mining": {
		"displayName": "Hilly Mining Area",
		"items": [
			{ "name": "Prospector Britches", "slot": "trousers", "dropsAnywhere": false },
			{ "name": "Silver Vein Belt", "slot": "belt", "dropsAnywhere": false },
			{ "name": "Coal-Dusted Stetson", "slot": "headwear", "dropsAnywhere": false },
		],
	},
	"snowy_mountain": {
		"displayName": "Snowy Mountain",
		"items": [
			{ "name": "Angora Winter Chaps", "slot": "trousers", "dropsAnywhere": false },
			{ "name": "Frostbit Duster", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Snowshoe Trail Boots", "slot": "justins", "dropsAnywhere": false },
			{ "name": "Ice-Crusted Bandolier", "slot": "belt", "dropsAnywhere": false },
		],
	},
	"desert_prairie": {
		"displayName": "Desert Prairie",
		"items": [
			{ "name": "Sandstorm Veil", "slot": "bandana", "dropsAnywhere": false },
			{ "name": "Sun-Bleached Stetson", "slot": "headwear", "dropsAnywhere": false },
			{ "name": "Dust Devil Duster", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Cracked-Leather Boots", "slot": "justins", "dropsAnywhere": false },
		],
	},
	"pine_forest": {
		"displayName": "Pine Forest",
		"items": [
			{ "name": "Woodsman Flannel Coat", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Pine Pitch Stetson", "slot": "headwear", "dropsAnywhere": false },
			{ "name": "Needle-Stitched Boots", "slot": "justins", "dropsAnywhere": false },
		],
	},
	"swamp": {
		"displayName": "Swamp",
		"items": [
			{ "name": "Mudder Work Boots", "slot": "justins", "dropsAnywhere": false },
			{ "name": "Gator-Hide Belt", "slot": "belt", "dropsAnywhere": false },
			{ "name": "Swamp Rat Poncho", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Mossy Bandolier", "slot": "belt", "dropsAnywhere": false },
		],
	},
	"canyon": {
		"displayName": "Canyon",
		"items": [
			{ "name": "Echo Walker Boots", "slot": "justins", "dropsAnywhere": false },
			{ "name": "Red Rock Duster", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Canyon Wind Bandana", "slot": "bandana", "dropsAnywhere": false },
		],
	},
	"ghost_town": {
		"displayName": "Ghost Town",
		"items": [
			{ "name": "Undertaker Black Coat", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Hangman Neckerchief", "slot": "bandana", "dropsAnywhere": false },
			{ "name": "Phantom Rider Spurs", "slot": "justins", "dropsAnywhere": false },
			{ "name": "Six Feet Under Belt", "slot": "belt", "dropsAnywhere": false },
		],
	},
	"town": {
		"displayName": "Town",
		"items": [
			{ "name": "Gambler Waistcoat", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Saloon-Keeper Vest", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Preacher Frock Coat", "slot": "duster", "dropsAnywhere": false },
			{ "name": "Marshal Badge Belt", "slot": "belt", "dropsAnywhere": false },
		],
	},
}
