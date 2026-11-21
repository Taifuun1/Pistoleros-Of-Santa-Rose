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
	"P": "whispering_pines_reach",
	"R": "rocky_hills",
	"S": "snowy_mountain",
	"A": "prairie",
	"M": "swamp",
	"W": "wild_west",
}

## The drawn Zone map (y = row index, x = character index). Placeholder
## geography carried over from the rectangle bands: snowy_mountain caps the
## northwest across (0,0)-(7,6) around the pine and rocky-hills columns, and
## the chunks the old default-Zone fallback used to answer (the west columns
## and x6-7 below the snowy cap) are written explicitly as pines. Redraw rows
## here to move a boundary; the legend is the only other place to touch.
var zoneMap = [
	"SSPPRRSSWWAA",
	"SSPPRRSSWWAA",
	"SSPPRRSSWWAA",
	"SSPPRRSSWWAA",
	"SSPPRRSSWWAA",
	"SSPPRRSSWWAA",
	"SSPPRRSSWWAA",
	"PPPPRRPPWWAA",
	"PPPPRRPPWWAA",
	"PPPPRRPPWWAA",
	"PPPPRRPPWWAA",
	"PPPPRRPPWWAA",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
	"PPPPRRPPWWMM",
]

var data = {
	"map_width": MAP_WIDTH,
	"map_height": MAP_HEIGHT,
	"legend": MAP_LEGEND,
	"zone_map": zoneMap,
	"zones": [
		# The five progression zones in progression order (commit 20 prep);
		# the non-progression Wild West last. Whispering Pines Reach is the
		# canonical starting zone; the other progression zones keep generic
		# names until they are canonically named.
		{ "zone": "whispering_pines_reach", "displayName": "Whispering Pines Reach" },
		{ "zone": "rocky_hills", "displayName": "Rocky Hills" },
		{ "zone": "snowy_mountain", "displayName": "Snowy Mountain" },
		{ "zone": "prairie", "displayName": "Prairie" },
		{ "zone": "swamp", "displayName": "Swamp" },
		{ "zone": "wild_west", "displayName": "Wild West" },
	],
	"default_zone": "whispering_pines_reach",
}
