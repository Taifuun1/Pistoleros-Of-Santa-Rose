extends RefCounted

## Sole authoritative Overworld Zone dimensions (Docs/System Design/Overworld
## Spawns.md). Zone ids are canonical snake_case ids shared by music, equipment,
## encounters and vendors; displayName is presentation only. Bands are inclusive
## chunk-coordinate corners and the first match wins.

var data = {
	"zones": [
		{ "zone": "ghost_town", "displayName": "Ghost Town", "min": Vector2i(10, 0), "max": Vector2i(10, 3) },
		{ "zone": "grassy_plains", "displayName": "Grassy Plains", "min": Vector2i(0, 0), "max": Vector2i(1, 23) },
		{ "zone": "pine_forest", "displayName": "Pine Forest", "min": Vector2i(2, 0), "max": Vector2i(3, 23) },
		{ "zone": "hilly_mining", "displayName": "Hilly Mining Area", "min": Vector2i(4, 0), "max": Vector2i(5, 23) },
		{ "zone": "snowy_mountain", "displayName": "Snowy Mountain", "min": Vector2i(6, 0), "max": Vector2i(7, 23) },
		{ "zone": "canyon", "displayName": "Canyon", "min": Vector2i(8, 0), "max": Vector2i(9, 23) },
		{ "zone": "desert_prairie", "displayName": "Desert Prairie", "min": Vector2i(10, 0), "max": Vector2i(11, 11) },
		{ "zone": "swamp", "displayName": "Swamp", "min": Vector2i(10, 12), "max": Vector2i(11, 23) },
	],
	"default_zone": "canyon",
}
