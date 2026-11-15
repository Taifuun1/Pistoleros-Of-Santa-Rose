# Cylinder Magazine contributed by each weapon id (see
# Docs/System Design/Shootout/Cylinders.md). Placeholders for balancing.
var magazines = {
	"revolver": [1, -1, 0],
	"rifle": [0, 1, -1],
	"shotgun": [-1, 0, 1],
	"scratch": [0, 0, 0],
}

# Position ranges per weapon id (Docs/System Design/Shootout/Positions and
# Targeting.md): columns the weapon can fire from and at. Placeholders derived
# from the class table in Docs/Combat.md; weapons without entries can fire from
# anywhere.
var ranges = {
	"revolver": { "actorUser": [1, 2, 3], "targets": [1, 2, 3, 4] },
	"rifle": { "actorUser": [3, 4], "targets": [1, 2, 3, 4] },
	"shotgun": { "actorUser": [1, 2, 3], "targets": [1, 2, 3] },
	"lasso": { "actorUser": [2, 3], "targets": [1, 2, 3] },
	"scratch": { "actorUser": [1, 2], "targets": [1, 2] },
}

var weaponFamilies = {
	"revolver": [
		{"id": "colt_paterson", "name": "Colt Paterson", "sprites": ["res://Assets/Weapons/ColtPatersonRevolver.png"]},
		{"id": "pepper_box", "name": "Pepper-box", "sprites": ["res://Assets/Weapons/Pepper-boxRevolver.png"]},
		{"id": "colt_walker", "name": "Colt Walker", "sprites": ["res://Assets/Weapons/ColtWalkerRevolver.png"]},
		{"id": "colt_1851_navy", "name": "Colt 1851 Navy", "sprites": ["res://Assets/Weapons/Colt1851NavyRevolver.png", "res://Assets/Weapons/ColtNavyRevolver2.png", "res://Assets/Weapons/ColtNavyRevolver3.png", "res://Assets/Weapons/ColtNavyRevolver4.png", "res://Assets/Weapons/ColtNavyWhiteHandleRevolver.png"]},
		{"id": "remington_army", "name": "Remington Army", "sprites": ["res://Assets/Weapons/RemingtonArmyRevolver.png"]},
		{"id": "colt_single_action_army", "name": "Colt Single Action Army", "sprites": ["res://Assets/Weapons/SingleActionRevolver.png"]},
		{"id": "remington_1875", "name": "Remington 1875", "sprites": ["res://Assets/Weapons/Remington187545Revolver.png"]},
		{"id": "smith_wesson", "name": "Smith & Wesson", "sprites": ["res://Assets/Weapons/Smith&WessonRevolver.png"]},
		{"id": "bisley", "name": "Bisley", "sprites": ["res://Assets/Weapons/SingleActionBisleyRevolver.png"]},
		{"id": "lemat", "name": "LeMat", "sprites": ["res://Assets/Weapons/LeMatRevolver.png"]},
		# { "name": "Smith & Wesson Schofield", "sprites": ["res://Assets/Weapons/Smith&WessonSchofieldRevolver.png"] },
		# { "name": "Smith & Wesson Model 3", "sprites": ["res://Assets/Weapons/Smith&WessonModel3Revolver.png"] },
		# { "name": "Smith & Wesson Model 10", "sprites": ["res://Assets/Weapons/Smith&WessonModel10Revolver.png"] },
		{"id": "cattleman", "name": "Cattleman", "sprites": ["res://Assets/Weapons/CattlemanRevolver.png", "res://Assets/Weapons/CattlemanRevolver1.png", "res://Assets/Weapons/CattlemanRevolver2.png", "res://Assets/Weapons/CattlemanRevolver3.png", "res://Assets/Weapons/CattlemanRevolver4.png"]},
		{"id": "colt_python", "name": "Colt Python", "sprites": ["res://Assets/Weapons/ColtPythonRevolver.png"]},
		{"id": "44_magnum", "name": "44. Magnum", "sprites": ["res://Assets/Weapons/44MagnumRevolver.png", "res://Assets/Weapons/44MagnumRevolverGreyHandle.png"]},
		{"id": "500_bushwhacker", "name": "500. Bushwhacker", "sprites": ["res://Assets/Weapons/500BushwhackerGreyHandle.png"]},
		{"id": "taurus", "name": "Taurus", "sprites": ["res://Assets/Weapons/TaurusGreyHandle.png"]},
	],
	"rifle": [
		{"id": "winchester_henry", "name": "Winchester Henry", "sprites": ["res://Assets/Weapons/WinchesterHenryRifle.png"]},
		{"id": "repeating_carbine", "name": "Repeating Carbine", "sprites": ["res://Assets/Weapons/RepeatingCarbineRifle.png"]},
		{"id": "winchester_hotchkiss", "name": "Winchester Hotchkiss", "sprites": ["res://Assets/Weapons/WinchesterHotchkissRifle.png"]},
		{"id": "winchester_37", "name": "Winchester 37", "sprites": ["res://Assets/Weapons/Winchester37Rifle.png"]},
		{"id": "hawken", "name": "Hawken", "sprites": ["res://Assets/Weapons/HawkenRifle.png"]},
		{"id": "sharps_1853", "name": "Sharps 1853", "sprites": ["res://Assets/Weapons/Sharps1853SportingRifle.png"]},
		{"id": "remington_rolling_block", "name": "Remington Rolling Block", "sprites": ["res://Assets/Weapons/RemingtonRollingBlockRifle.png"]},
		{"id": "winchester_69", "name": "Winchester 69", "sprites": ["res://Assets/Weapons/Winchester69Rifle.png"]},
		{"id": "sharps_1874", "name": "Sharps 1874", "sprites": ["res://Assets/Weapons/SharpsRifle.png"]},
		{"id": "winchester_wild_west", "name": "Winchester Wild West", "sprites": ["res://Assets/Weapons/WinchesterRifle.png"]},
		{"id": "winchester_under_barrel", "name": "Winchester Under Barrel", "sprites": ["res://Assets/Weapons/WinchesterRifleUnderbarrel.png", "res://Assets/Weapons/WinchesterRifleUnderbarrel2.png", "res://Assets/Weapons/WinchesterRifleUnderbarrel4.png"]},
		{"id": "winchester_trapper", "name": "Winchester Trapper", "sprites": ["res://Assets/Weapons/WinchesterTrapperRifle.png"]},
	],
	"shotgun": [
		{"id": "colt_1839", "name": "Colt 1839", "sprites": ["res://Assets/Weapons/Colt1839Shotgun.png"]},
		{"id": "colt_1855_revolving", "name": "Colt 1855 Revolving", "sprites": ["res://Assets/Weapons/Colt1855RevolvingShotgun.png"]},
		{"id": "ithaca_double_barrel", "name": "Ithaca Double Barrel", "sprites": ["res://Assets/Weapons/IthacaDoubleBarrel.png"]},
		{"id": "ah_fox_double_barrel", "name": "A.H. Fox Double Barrel", "sprites": ["res://Assets/Weapons/AHFoxDoubleBarrelShotgun.png"]},
		{"id": "lc_smith_hammerless", "name": "L.C. Smith Hammerless", "sprites": ["res://Assets/Weapons/LCSmithHammerlessShotgun.png"]},
		{"id": "ww_greener", "name": "W.W. Greener", "sprites": ["res://Assets/Weapons/WWGreenerShotgun.png"]},
		{"id": "ithaca_12_gauge", "name": "Ithaca 12 Gauge", "sprites": ["res://Assets/Weapons/Ithaca12Gauge.png"]},
		{"id": "winchester_1887", "name": "Winchester 1887", "sprites": ["res://Assets/Weapons/Winchester1887Shotgun.png"]},
		{"id": "winchester_1893", "name": "Winchester 1893", "sprites": ["res://Assets/Weapons/Winchester1893Shotgun.png"]},
		{"id": "winchester_1897", "name": "Winchester 1897", "sprites": ["res://Assets/Weapons/Winchester1897Shotgun.png"]},
	],
}

# Authored base value per rollable weapon id. VendorPricing requires an entry
# for every weapon definition; zero/negative values are data errors. Values are
# balance placeholders, not combat stats.
var baseValues = {
	"colt_paterson": 60,
	"pepper_box": 50,
	"colt_walker": 110,
	"colt_1851_navy": 90,
	"remington_army": 95,
	"colt_single_action_army": 130,
	"remington_1875": 125,
	"smith_wesson": 120,
	"bisley": 115,
	"lemat": 150,
	"cattleman": 100,
	"colt_python": 180,
	"44_magnum": 175,
	"500_bushwhacker": 200,
	"taurus": 140,
	"winchester_henry": 200,
	"repeating_carbine": 160,
	"winchester_hotchkiss": 190,
	"winchester_37": 120,
	"hawken": 150,
	"sharps_1853": 170,
	"remington_rolling_block": 155,
	"winchester_69": 145,
	"sharps_1874": 210,
	"winchester_wild_west": 185,
	"winchester_under_barrel": 195,
	"winchester_trapper": 165,
	"colt_1839": 140,
	"colt_1855_revolving": 180,
	"ithaca_double_barrel": 170,
	"ah_fox_double_barrel": 190,
	"lc_smith_hammerless": 185,
	"ww_greener": 210,
	"ithaca_12_gauge": 175,
	"winchester_1887": 200,
	"winchester_1893": 195,
	"winchester_1897": 205,
}
