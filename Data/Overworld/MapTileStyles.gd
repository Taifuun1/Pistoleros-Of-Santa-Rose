extends RefCounted
class_name MapTileStyles

## Authored semantic map styling (Docs/System Design/Journal/Overworld Map.md):
## tile source/atlas identity -> map color/feature/priority. A style describes
## the map representation, not the source texture; walkability and terrain rules
## are never inferred from these colors (or vice versa).
##
## The table is authored from deliberate art direction instead of sampled
## texture colors: the old bottom-band sampling put each isometric tile's dirt
## front face on the map, which made Grasslands read as canyon orange. Every
## tile that exists in the tileset is classified by, in order:
##   1. an explicit per-key override,
##   2. the tileset's own terrain authoring (water / train tracks / powerlines / fences),
##   3. the audited per-source atlas-row table (rock, vegetation, water, structure bands),
##   4. otherwise the source's biome ground color.
## Coverage is complete for tileset tiles, so adding a tile always yields a
## style; genuinely unknown keys keep the magenta development fallback.
##
## Audit the classification with:
##   godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --palette-report

const FEATURE_GROUND := "ground"
const FEATURE_WATER := "water"
const FEATURE_TRACK := "track"
const FEATURE_POWERLINE := "powerline"
const FEATURE_MOUNTAIN := "mountain"
const FEATURE_CLIFF := "cliff"
const FEATURE_FOREST := "forest"
const FEATURE_STRUCTURE := "structure"
const FEATURE_SWAMP := "swamp"

## Conspicuous development fallback for unknown keys.
const UNKNOWN_STYLE := { "color": Color(1, 0, 1), "feature": FEATURE_GROUND, "priority": 0 }

## Deliberate biome ground color per tileset source id.
const SOURCE_GROUND := {
	0: Color("9c8f76"), # Overworld Locations: entrance props
	1: Color("d08a3a"), # Grande Cañón: warm canyon sand
	2: Color("7c8a5e"), # Rocky Hills: grass over rock
	3: Color("86a03a"), # Grasslands: green grass
	4: Color("c9717a"), # Prairie: dusty rose
	5: Color("a89a33"), # Wild West: dry yellow plains
	6: Color("c9dcea"), # Snowy Mountains: snow and ice
}
const FALLBACK_GROUND := Color("6f6a5f")

## Deliberate feature colors shared by every biome, so a river or a road reads
## the same wherever it appears.
const FEATURE_COLORS := {
	FEATURE_WATER: Color("2f6f9f"),
	FEATURE_TRACK: Color("6b5334"),
	FEATURE_POWERLINE: Color("3f4145"),
	FEATURE_MOUNTAIN: Color("8b7f6d"),
	FEATURE_CLIFF: Color("5f574c"),
	FEATURE_FOREST: Color("3f6b38"),
	FEATURE_STRUCTURE: Color("4a4038"),
	FEATURE_SWAMP: Color("3d6b5c"),
}

const FEATURE_PRIORITIES := {
	FEATURE_GROUND: 10,
	FEATURE_FOREST: 20,
	FEATURE_SWAMP: 22,
	FEATURE_WATER: 25,
	FEATURE_TRACK: 30,
	FEATURE_POWERLINE: 30,
	FEATURE_MOUNTAIN: 30,
	FEATURE_CLIFF: 32,
	FEATURE_STRUCTURE: 35,
}

## Tileset terrain-set names -> map feature. Terrain authoring is explicit, so
## it outranks the atlas tables; the generator's survey shares this mapping.
const TERRAIN_FEATURES := {
	"water": FEATURE_WATER,
	"train tracks": FEATURE_TRACK,
	"powerlines grass": FEATURE_POWERLINE,
	"powerlines wild west": FEATURE_POWERLINE,
	"basic fences": FEATURE_STRUCTURE,
	"tall fences": FEATURE_STRUCTURE,
}

## Audited atlas rows (atlasY -> feature) per source; unlisted rows are ground.
## Sources: 0 Locations, 1 Grande Cañón, 2 Rocky Hills, 3 Grasslands,
## 4 Prairie, 5 Wild West, 6 Snowy Mountains. This mirrors
## Docs/System Design/Journal/Tileset Classification.md, which is the authored
## reference for what each row depicts (rows there are 1-based).
const SOURCE_ROW_FEATURES := {
	0: { 1: FEATURE_MOUNTAIN, 2: FEATURE_WATER, 3: FEATURE_STRUCTURE },
	1: { 1: FEATURE_MOUNTAIN, 2: FEATURE_CLIFF },
	2: { 1: FEATURE_MOUNTAIN, 4: FEATURE_MOUNTAIN, 5: FEATURE_WATER },
	3: {
		1: FEATURE_FOREST, 2: FEATURE_FOREST,
		3: FEATURE_STRUCTURE, 4: FEATURE_STRUCTURE, 5: FEATURE_STRUCTURE, 6: FEATURE_POWERLINE, 7: FEATURE_STRUCTURE,
		8: FEATURE_WATER, 9: FEATURE_SWAMP, 10: FEATURE_WATER,
	},
	4: { 1: FEATURE_MOUNTAIN },
	5: { 1: FEATURE_MOUNTAIN, 3: FEATURE_TRACK, 4: FEATURE_WATER, 5: FEATURE_POWERLINE, 6: FEATURE_WATER },
	6: { 1: FEATURE_MOUNTAIN, 4: FEATURE_WATER },
}

## Rows that mix features within the row: source -> atlasY -> [[firstX, lastX,
## feature], ...]. Ranges are consulted before the whole-row table, so a row can
## be split exactly as the classification doc describes it. Cliff tiles are the
## solid ones in a mixed rock/cliff row; water animation frames share one style.
const SOURCE_RANGE_FEATURES := {
	2: {
		# Row 3: impassable rocks and cliffs; tile 10 is grass.
		2: [[0, 2, FEATURE_MOUNTAIN], [3, 8, FEATURE_CLIFF], [9, 9, FEATURE_GROUND]],
	},
	3: {
		# Row 1: first three tiles grass, the rest forest, the last a cliff.
		0: [[0, 2, FEATURE_GROUND], [3, 10, FEATURE_FOREST], [11, 11, FEATURE_CLIFF]],
	},
	4: {
		# Row 3: forests and impassable cliffs; tile 10 is grass.
		2: [[0, 5, FEATURE_FOREST], [6, 8, FEATURE_CLIFF], [9, 9, FEATURE_GROUND]],
	},
	5: {
		# Row 3: first four grass, next five forests and rocks.
		2: [[0, 3, FEATURE_GROUND], [4, 8, FEATURE_FOREST], [9, 9, FEATURE_GROUND]],
	},
	6: {
		# Row 3: first four tents, next five forest and rocks.
		2: [[0, 3, FEATURE_STRUCTURE], [4, 8, FEATURE_FOREST], [9, 9, FEATURE_GROUND]],
		# Row 4: tiles 1-3 cliffs, tiles 4-5 the two frames of one water tile.
		3: [[0, 2, FEATURE_CLIFF], [3, 4, FEATURE_WATER]],
	},
}

## Explicit exceptions for tiles whose row would misclassify them: Snowy
## Mountains row 2 mixes vegetation tiles with plain ice tiles.
const KEY_FEATURE_OVERRIDES := {
	Vector3i(6, 4, 2): FEATURE_FOREST,
	Vector3i(6, 5, 2): FEATURE_FOREST,
	Vector3i(6, 6, 2): FEATURE_FOREST,
	Vector3i(6, 7, 2): FEATURE_FOREST,
	Vector3i(6, 8, 2): FEATURE_FOREST,
}

## Explicit color exceptions where a tile should keep its biome tone instead of
## the shared feature color (the Grande Cañón rock formation stays terracotta).
const KEY_COLOR_OVERRIDES := {
	Vector3i(1, 7, 1): Color("a8662a"),
	Vector3i(1, 8, 1): Color("a8662a"),
	Vector3i(1, 9, 1): Color("a8662a"),
}



var _ids := {}
var _byId: Array = [UNKNOWN_STYLE]


## A custom table (tests, experiments) overrides the authored classification.
func _init(styles: Dictionary = {}) -> void:
	var table := styles if !styles.is_empty() else buildAuthoredStyles()
	var keys: Array = table.keys()
	keys.sort_custom(func(a, b):
		if a.x != b.x:
			return a.x < b.x
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z
	)
	for key in keys:
		var id := _byId.size()
		_ids[key] = id
		_byId.append(table[key])


## Complete key -> style table for every tile in the shared tileset.
static func buildAuthoredStyles() -> Dictionary:
	var tileSet: TileSet = load(WorldData.TEMPLATE_TILESET_PATH)
	var terrainNames := _terrainNames(tileSet)
	var table := {}
	for sourceIndex in tileSet.get_source_count():
		var sourceId: int = tileSet.get_source_id(sourceIndex)
		var source: TileSetAtlasSource = tileSet.get_source(sourceId)
		var grid: Vector2i = source.get_atlas_grid_size()
		for atlasY in grid.y:
			for atlasX in grid.x:
				var atlasCoords := Vector2i(atlasX, atlasY)
				if !source.has_tile(atlasCoords):
					continue
				var key := Vector3i(sourceId, atlasX, atlasY)
				var tileData: TileData = source.get_tile_data(atlasCoords, 0)
				var terrainName: String = terrainNames.get([tileData.get_terrain_set(), tileData.get_terrain()], "")
				var feature := featureForKey(key, terrainName)
				var color: Color = SOURCE_GROUND.get(sourceId, FALLBACK_GROUND)
				if feature != FEATURE_GROUND:
					color = FEATURE_COLORS.get(feature, color)
				color = KEY_COLOR_OVERRIDES.get(key, color)
				table[key] = {
					"color": color,
					"feature": feature,
					"priority": FEATURE_PRIORITIES.get(feature, FEATURE_PRIORITIES[FEATURE_GROUND]),
				}
	return table


## Classification for one key: explicit override, then tileset terrain
## authoring, then the audited atlas-row table, then biome ground.
static func featureForKey(key: Vector3i, terrainName: String) -> String:
	if KEY_FEATURE_OVERRIDES.has(key):
		return KEY_FEATURE_OVERRIDES[key]
	var terrainFeature := featureForTerrainName(terrainName)
	if terrainFeature != "":
		return terrainFeature
	var ranges: Dictionary = SOURCE_RANGE_FEATURES.get(key.x, {})
	if ranges.has(key.z):
		for entry in ranges[key.z]:
			if key.y >= int(entry[0]) and key.y <= int(entry[1]):
				return entry[2]
	var rows: Dictionary = SOURCE_ROW_FEATURES.get(key.x, {})
	return rows.get(key.z, FEATURE_GROUND)


## Shared terrain-name -> feature mapping; "" when the terrain has no map
## meaning (unassigned variants included).
static func featureForTerrainName(terrainName: String) -> String:
	return TERRAIN_FEATURES.get(terrainName.to_lower(), "")


static func _terrainNames(tileSet: TileSet) -> Dictionary:
	var names := {}
	for setIndex in tileSet.get_terrain_sets_count():
		for terrainIndex in range(32):
			var terrainName = tileSet.get("terrain_set_{set}/terrain_{terrain}/name".format({
				"set": setIndex, "terrain": terrainIndex,
			}))
			if terrainName == null:
				break
			names[[setIndex, terrainIndex]] = String(terrainName).to_lower()
	return names


## Stable style id for the typed bake grid; 0 = unknown key.
func styleIdFor(sourceId: int, atlasX: int, atlasY: int) -> int:
	return _ids.get(Vector3i(sourceId, atlasX, atlasY), 0)


## Style dictionary for a bake-grid id; id 0 is the unknown fallback.
func styleForId(styleId: int) -> Dictionary:
	if styleId < 0 or styleId >= _byId.size():
		return UNKNOWN_STYLE
	return _byId[styleId]


func styleCount() -> int:
	return _byId.size() - 1


func hasStyle(sourceId: int, atlasX: int, atlasY: int) -> bool:
	return _ids.has(Vector3i(sourceId, atlasX, atlasY))
