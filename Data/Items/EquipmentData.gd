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
	"headwear": { "id": "john_b", "name": "John B.", "baseStats": { "style": 1 } },
	"bandana": { "id": "bandana", "name": "Bandana", "baseStats": {} },
	"duster": { "id": "duster", "name": "Duster", "baseStats": { "style": 2, "sand": 2 } },
	"belt": { "id": "belt", "name": "Belt", "baseStats": {} },
	"trousers": { "id": "trousers", "name": "Trousers", "baseStats": { "style": 1, "sand": 1 } },
	"justins": { "id": "justins", "name": "Justins", "baseStats": { "sand": 1 } },
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
			{ "id": "prairie_rider_duster", "name": "Prairie Rider Duster", "slot": "duster", "dropsAnywhere": false },
			{ "id": "green_hollow_bandana", "name": "Green Hollow Bandana", "slot": "bandana", "dropsAnywhere": false },
			{ "id": "meadowlark_boots", "name": "Meadowlark Boots", "slot": "justins", "dropsAnywhere": false },
		],
	},
	"hilly_mining": {
		"displayName": "Hilly Mining Area",
		"items": [
			{ "id": "prospector_britches", "name": "Prospector Britches", "slot": "trousers", "dropsAnywhere": false },
			{ "id": "silver_vein_belt", "name": "Silver Vein Belt", "slot": "belt", "dropsAnywhere": false },
			{ "id": "coal_dusted_stetson", "name": "Coal-Dusted Stetson", "slot": "headwear", "dropsAnywhere": false },
		],
	},
	"snowy_mountain": {
		"displayName": "Snowy Mountain",
		"items": [
			{ "id": "angora_winter_chaps", "name": "Angora Winter Chaps", "slot": "trousers", "dropsAnywhere": false },
			{ "id": "frostbit_duster", "name": "Frostbit Duster", "slot": "duster", "dropsAnywhere": false },
			{ "id": "snowshoe_trail_boots", "name": "Snowshoe Trail Boots", "slot": "justins", "dropsAnywhere": false },
			{ "id": "ice_crusted_bandolier", "name": "Ice-Crusted Bandolier", "slot": "belt", "dropsAnywhere": false },
		],
	},
	"desert_prairie": {
		"displayName": "Desert Prairie",
		"items": [
			{ "id": "sandstorm_veil", "name": "Sandstorm Veil", "slot": "bandana", "dropsAnywhere": false },
			{ "id": "sun_bleached_stetson", "name": "Sun-Bleached Stetson", "slot": "headwear", "dropsAnywhere": false },
			{ "id": "dust_devil_duster", "name": "Dust Devil Duster", "slot": "duster", "dropsAnywhere": false },
			{ "id": "cracked_leather_boots", "name": "Cracked-Leather Boots", "slot": "justins", "dropsAnywhere": false },
		],
	},
	"pine_forest": {
		"displayName": "Pine Forest",
		"items": [
			{ "id": "woodsman_flannel_coat", "name": "Woodsman Flannel Coat", "slot": "duster", "dropsAnywhere": false },
			{ "id": "pine_pitch_stetson", "name": "Pine Pitch Stetson", "slot": "headwear", "dropsAnywhere": false },
			{ "id": "needle_stitched_boots", "name": "Needle-Stitched Boots", "slot": "justins", "dropsAnywhere": false },
		],
	},
	"swamp": {
		"displayName": "Swamp",
		"items": [
			{ "id": "mudder_work_boots", "name": "Mudder Work Boots", "slot": "justins", "dropsAnywhere": false },
			{ "id": "gator_hide_belt", "name": "Gator-Hide Belt", "slot": "belt", "dropsAnywhere": false },
			{ "id": "swamp_rat_poncho", "name": "Swamp Rat Poncho", "slot": "duster", "dropsAnywhere": false },
			{ "id": "mossy_bandolier", "name": "Mossy Bandolier", "slot": "belt", "dropsAnywhere": false },
		],
	},
	"canyon": {
		"displayName": "Canyon",
		"items": [
			{ "id": "echo_walker_boots", "name": "Echo Walker Boots", "slot": "justins", "dropsAnywhere": false },
			{ "id": "red_rock_duster", "name": "Red Rock Duster", "slot": "duster", "dropsAnywhere": false },
			{ "id": "canyon_wind_bandana", "name": "Canyon Wind Bandana", "slot": "bandana", "dropsAnywhere": false },
		],
	},
	"ghost_town": {
		"displayName": "Ghost Town",
		"items": [
			{ "id": "undertaker_black_coat", "name": "Undertaker Black Coat", "slot": "duster", "dropsAnywhere": false },
			{ "id": "hangman_neckerchief", "name": "Hangman Neckerchief", "slot": "bandana", "dropsAnywhere": false },
			{ "id": "phantom_rider_spurs", "name": "Phantom Rider Spurs", "slot": "justins", "dropsAnywhere": false },
			{ "id": "six_feet_under_belt", "name": "Six Feet Under Belt", "slot": "belt", "dropsAnywhere": false },
		],
	},
	"town": {
		"displayName": "Town",
		"items": [
			{ "id": "gambler_waistcoat", "name": "Gambler Waistcoat", "slot": "duster", "dropsAnywhere": false },
			{ "id": "saloon_keeper_vest", "name": "Saloon-Keeper Vest", "slot": "duster", "dropsAnywhere": false },
			{ "id": "preacher_frock_coat", "name": "Preacher Frock Coat", "slot": "duster", "dropsAnywhere": false },
			{ "id": "marshal_badge_belt", "name": "Marshal Badge Belt", "slot": "belt", "dropsAnywhere": false },
		],
	},
}

# Authored base value per equipment definition (generic and zone-tied).
# VendorPricing requires an entry for every id; values are balance placeholders.
var baseValues = {
	"john_b": 25,
	"bandana": 15,
	"duster": 45,
	"belt": 20,
	"trousers": 30,
	"justins": 25,
	"prairie_rider_duster": 60,
	"green_hollow_bandana": 30,
	"meadowlark_boots": 40,
	"prospector_britches": 55,
	"silver_vein_belt": 45,
	"coal_dusted_stetson": 50,
	"angora_winter_chaps": 65,
	"frostbit_duster": 70,
	"snowshoe_trail_boots": 55,
	"ice_crusted_bandolier": 60,
	"sandstorm_veil": 45,
	"sun_bleached_stetson": 50,
	"dust_devil_duster": 65,
	"cracked_leather_boots": 45,
	"woodsman_flannel_coat": 65,
	"pine_pitch_stetson": 50,
	"needle_stitched_boots": 50,
	"mudder_work_boots": 45,
	"gator_hide_belt": 55,
	"swamp_rat_poncho": 65,
	"mossy_bandolier": 60,
	"echo_walker_boots": 50,
	"red_rock_duster": 65,
	"canyon_wind_bandana": 40,
	"undertaker_black_coat": 75,
	"hangman_neckerchief": 45,
	"phantom_rider_spurs": 55,
	"six_feet_under_belt": 55,
	"gambler_waistcoat": 70,
	"saloon_keeper_vest": 65,
	"preacher_frock_coat": 75,
	"marshal_badge_belt": 60,
}
