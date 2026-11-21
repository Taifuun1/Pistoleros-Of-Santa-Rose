extends RefCounted

## Sole authoritative Overworld Zone definition (Docs/System Design/Overworld
## Spawns.md). Zone ids are canonical snake_case ids shared by music, equipment,
## encounters and vendors; displayName is presentation only. Geography is an
## ASCII chunk map: one character per chunk, one fixed-width row per world row.
## Every mapped chunk is explicitly zoned; default_zone only covers lookups
## outside the map, never a region on it.

## Map dimensions. One row per world row, one character per chunk column.
## TestZoneCatalog cross-checks these against WorldData.CHUNK_GRID.
const MAP_WIDTH := 12
const MAP_HEIGHT := 24

# Map legend: character -> canonical Zone id.
const MAP_LEGEND = {
	"P": "kipley_wilds",
	"R": "cassidy_hills",
	"S": "oakley_peak",
	"A": "urie_prairie",
	"M": "tillhill_marsh",
	"W": "wild_west",
}

## The drawn Zone map (y = row index, x = character index). Canonical owner-
## defined boundaries: Oakley Peak caps the north above the Wild West's
## open middle band; Cassidy Hills climb the southwest; Kipley Wilds
## and Tillhill Marsh fill the south. Redraw rows here to move a boundary; the
## legend is the only other place to touch.
var zoneMap = [
	"SSSSSSSSAAAA",
	"SSSSSSSSAAAA",
	"SSSSSSSSAAAA",
	"SSSSSSSSAAAA",
	"SSSSSSSSAAAA",
	"SSSSSSSSAAAA",
	"SSSSSSSSAAAA",
	"WWWWWSSSAAAA",
	"WWWWWWWWWWWW",
	"WWWWWWWWWWWW",
	"WWWWWWWWWWWW",
	"WWWWWWWWWWWW",
	"WWWWWWWWWWWW",
	"RRRRWWWWWWWW",
	"RRRRRWWWWWWW",
	"RRRRRPPPPPPW",
	"RRRRRPPPPPPW",
	"RRRRRPPPPPPP",
	"RRRRRPPPPPPP",
	"RRRRRPPPPPPP",
	"RRRRRPPPMMMM",
	"RRRRRPPPMMMM",
	"RRRRRPPPMMMM",
	"RRRRRPPPMMMM",
]

var data = {
	"map_width": MAP_WIDTH,
	"map_height": MAP_HEIGHT,
	"legend": MAP_LEGEND,
	"zone_map": zoneMap,
	"zones": [
		# The five progression zones in progression order; the
		# non-progression Wild West last. Kipley Wilds is the canonical
		# starting zone.
		{ "zone": "kipley_wilds", "displayName": "Kipley Wilds" },
		{ "zone": "cassidy_hills", "displayName": "Cassidy Hills" },
		{ "zone": "oakley_peak", "displayName": "Oakley Peak" },
		{ "zone": "urie_prairie", "displayName": "Urie Prairie" },
		{ "zone": "tillhill_marsh", "displayName": "Tillhill Marsh" },
		{ "zone": "wild_west", "displayName": "Wild West" },
	],
	"default_zone": "kipley_wilds",
}
