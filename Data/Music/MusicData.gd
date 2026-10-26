extends Node


# Music decisions (Docs/System Design/Music player.md). Track ids are paths
# under Assets/Music without extension. The zone set unifies with
# Docs/Weapons and affixes.md ("Zone-Tied Items"); the chunk bands over the
# 12x24 chunk grid (x 0-11, y 0-23) are a provisional allocation — reshape
# the "zones" list when the real geography is decided.

var data = {
	# Overworld zones by inclusive chunk-coordinate corners. First match wins,
	# so more specific bands go first.
	"zones": [
		{ "zone": "ghost town", "min": Vector2i(10, 0), "max": Vector2i(10, 3) },
		{ "zone": "grassy plains", "min": Vector2i(0, 0), "max": Vector2i(1, 23) },
		{ "zone": "pine forest", "min": Vector2i(2, 0), "max": Vector2i(3, 23) },
		{ "zone": "hilly mining area", "min": Vector2i(4, 0), "max": Vector2i(5, 23) },
		{ "zone": "snowy mountain", "min": Vector2i(6, 0), "max": Vector2i(7, 23) },
		{ "zone": "canyon", "min": Vector2i(8, 0), "max": Vector2i(9, 23) },
		{ "zone": "desert prairie", "min": Vector2i(10, 0), "max": Vector2i(11, 11) },
		{ "zone": "swamp", "min": Vector2i(10, 12), "max": Vector2i(11, 23) },
	],
	# Zone for chunks outside every band (and while no chunk is known).
	"default_zone": "canyon",
	# Overworld ambience per zone; the lists loop with a fade before each song
	# end blending into the next song.
	"zone_tracks": {
		"grassy plains": [
			"Overworld/Grasslands1",
			"Overworld/Grasslands2",
			"Overworld/Grasslands3"
		],
		"hilly mining area": [
			"Overworld/RockyHills1",
			"Overworld/RockyHills2"
		],
		"desert prairie": [
			"Overworld/Prairie1",
			"Overworld/Prairie2",
			"Overworld/Prairie3"
		],
		"canyon": [
			"Overworld/WildWest1",
			"Overworld/WildWest2"
		],
		"pine forest": [
			"Thematic/Mysterious/Dust at Dawn",
			"Thematic/Chill/Birdsong Window"
		],
		"snowy mountain": [
			"Thematic/Somber/Rockside Echo",
			"Thematic/Chill/Chill1",
			"Thematic/Chill/Chill2"
		],
		"swamp": [
			"Thematic/Mysterious/Dust at Dawn",
			"Thematic/Mysterious/Dust on the Cartridge"
		],
		"ghost town": [
			"Thematic/Somber/Dusty Cartridge",
			"Thematic/Somber/Rain Over Dusty Trail",
			"Thematic/Somber/Rainy Saloon Loop"
		],
	},
	# Town / location music by location name.
	"location_tracks": {
		"Clearwater Grove": ["Location/Clearwater Grove"],
		"Lazysprings": ["Town/Lazysprings1", "Town/Lazysprings2"],
		"Silverton": ["Town/Silverton1", "Town/Silverton2", "Town/Silverton3", "Town/Silverton4"],
		"Copper Branch": ["Town/Copper Branch1", "Town/Copper Branch2", "Town/Copper Branch3", "Town/Copper Branch4"],
		"Fairpeaks": ["Town/Fairpeaks1", "Town/Fairpeaks2", "Town/Fairpeaks3", "Town/Fairpeaks4"],
		"Lantern Landing": ["Town/Lantern Landing1", "Town/Lantern Landing2", "Town/Lantern Landing3", "Town/Lantern Landing4"],
		"Twin Creek": ["Town/Twin Creek"],
	},
	# Main menu / title.
	"menu_tracks": [
		"Title Screen etc/Dust On The Cartridge1",
		"Title Screen etc/Dust on the Cartridge2",
		"Title Screen etc/Dust on the Cartridge3"
	],
	# Shop and event popup fallback (popups may override with their own track
	# through their event data "music" field).
	"shop_tracks": [
		"Town/ShopTunes1"
	],
	# Default shootout list for fights with no more specific music.
	"shootout_tracks": [
		"Shootout/Duel de Chiptune",
		"Shootout/Dusty Showdown",
		"Shootout/Last Bullet Canyon",
		"Shootout/Pixel Duel",
		"Shootout/Dusty Cartridge Duel"
	],
	# Unique encounters (by encounter data "name").
	"shootout_encounter_tracks": {
		"Testing Encounter": [
			"Shootout/Dusty Showdown",
			"Shootout/Last Bullet Canyon",
			"Shootout/Pixel Duel",
			"Shootout/Dusty Cartridge Duel",
			"Shootout/Shootout1",
			"Shootout/Duel de Chiptune",
		],
	},
	# Fights tied to an Overworld zone (encounter data "zone"). Zone names match
	# the zone set above / Docs/Weapons and affixes.md.
	"zone_shootout_tracks": {
		"grassy plains": ["Shootout/Dusty Hex Duel"],
		"hilly mining area": ["Shootout/Dusty Cartridge Duel"],
		"desert prairie": ["Shootout/Clash on Beat One"],
		"snowy mountain": ["Shootout/Wily Core"],
		"pine forest": ["Shootout/Pixel Duel"],
		"swamp": ["Shootout/Last Bullet Canyon"],
		"canyon": ["Shootout/Steel Cannon Run"],
		"ghost town": ["Shootout/Shootout2"],
	},
	# End-of-fight stingers for the Shootout end screen, keyed by the fight
	# outcome. The victory jingle settles into a warm afterglow while the
	# results are read; feel free to swap any of these picks.
	"shootout_outcome_tracks": {
		"victory": [
			"Thematic/Generic/Flat Note Win",
			"Thematic/Heroic/Frontier Afterglow"
		],
		"fled": [
			"Thematic/Generic/Dusty Goodbye",
			"Thematic/Somber/Lo-Fi Shuffle"
		],
		"vamoose": [
			"Thematic/Sad/Dusty Game Over"
		],
		"defeat": [
			"Thematic/Sad/Dusty Save File"
		],
	},
}
