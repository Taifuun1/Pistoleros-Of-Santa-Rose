extends Node


# Music decisions (Docs/System Design/Music player.md). Track ids are paths
# under Assets/Music without extension. Zone geography and canonical ids live
# in Data/Overworld/ZoneData.gd; this file only maps those Zone ids to tracks.

var data = {
	# Overworld ambience per zone; the lists loop with a fade before each song
	# end blending into the next song.
	"zone_tracks": {
		"rocky_hills": [
			"Overworld/RockyHills1",
			"Overworld/RockyHills2"
		],
		"prairie": [
			"Overworld/Prairie1",
			"Overworld/Prairie2",
			"Overworld/Prairie3"
		],
		"wild_west": [
			"Overworld/WildWest1",
			"Overworld/WildWest2"
		],
		"whispering_pines_reach": [
			"Thematic/Mysterious/Dust at Dawn",
			"Thematic/Chill/Birdsong Window"
		],
		"snowy_mountain": [
			"Thematic/Somber/Rockside Echo",
			"Thematic/Chill/Chill1",
			"Thematic/Chill/Chill2"
		],
		"swamp": [
			"Thematic/Mysterious/Dust at Dawn",
			"Thematic/Mysterious/Dust on the Cartridge"
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
			"Shootout/Last Bullet Canyon",
			"Shootout/Pixel Duel",
			"Shootout/Dusty Cartridge Duel",
			"Shootout/Shootout1",
			"Shootout/Duel de Chiptune",
			"Shootout/Dusty Showdown",
		],
	},
	# Fights tied to an Overworld zone (encounter data "zone"). Zone ids match
	# Data/Overworld/ZoneData.gd.
	"zone_shootout_tracks": {
		"rocky_hills": ["Shootout/Dusty Cartridge Duel"],
		"prairie": ["Shootout/Clash on Beat One"],
		"snowy_mountain": ["Shootout/Wily Core"],
		"whispering_pines_reach": ["Shootout/Pixel Duel"],
		"swamp": ["Shootout/Last Bullet Canyon"],
		"wild_west": ["Shootout/Steel Cannon Run"],
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
