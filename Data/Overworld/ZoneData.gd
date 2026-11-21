extends RefCounted

## Sole authoritative Overworld Zone dimensions (Docs/System Design/Overworld
## Spawns.md). Zone ids are canonical snake_case ids shared by music, equipment,
## encounters and vendors; displayName is presentation only. Bands are inclusive
## chunk-coordinate corners and the first match wins.

var data = {
	"zones": [
		# The five progression zones in progression order (commit 20 prep).
		# Whispering Pines Reach is the canonical starting zone; the other
		# progression zones keep generic names until they are canonically
		# named. Wild West is the generic mid-map zone outside the
		# progression. Band boundaries are unchanged; the canonical
		# boundaries are defined separately.
		{ "zone": "whispering_pines_reach", "displayName": "Whispering Pines Reach", "min": Vector2i(2, 0), "max": Vector2i(3, 23) },
		{ "zone": "rocky_hills", "displayName": "Rocky Hills", "min": Vector2i(4, 0), "max": Vector2i(5, 23) },
		{ "zone": "snowy_mountain", "displayName": "Snowy Mountain", "min": Vector2i(6, 0), "max": Vector2i(7, 23) },
		{ "zone": "prairie", "displayName": "Prairie", "min": Vector2i(10, 0), "max": Vector2i(11, 11) },
		{ "zone": "swamp", "displayName": "Swamp", "min": Vector2i(10, 12), "max": Vector2i(11, 23) },
		# Mid-map generic zone, not part of the progression.
		{ "zone": "wild_west", "displayName": "Wild West", "min": Vector2i(8, 0), "max": Vector2i(9, 23) },
	],
	"default_zone": "whispering_pines_reach",
}
