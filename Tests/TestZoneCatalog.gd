extends SceneTree

## Headless validation for the shared Overworld Zone catalog
## (Docs/System Design/Overworld Spawns.md and Data/Overworld/ZoneData.gd).
## Run with: godot --headless --script res://Tests/TestZoneCatalog.gd

const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const ZoneDataScript = preload("res://Data/Overworld/ZoneData.gd")
const EquipmentDataScript = preload("res://Data/Items/EquipmentData.gd")
const MusicDataScript = preload("res://Data/Music/MusicData.gd")

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Production Zone dataset ---")
	var catalog = ZoneCatalogScript.new()
	var data = ZoneDataScript.new()
	_check(catalog.validate().is_empty(), "production ZoneData must validate: %s" % [catalog.validate()])
	_check(catalog.data == data.data, "production catalog loads ZoneData.data")
	_testGeography(catalog)
	_testConsumerIds(catalog)
	_testInjectionIsolation()
	_testMalformedData()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _testGeography(catalog) -> void:
	print("\n--- Drawn map resolution and default ---")
	_check(catalog.zoneForChunk(Vector2i(0, 0)) == "snowy_mountain", "the snowy cap covers the northwest corner")
	_check(catalog.zoneForChunk(Vector2i(6, 6)) == "snowy_mountain", "the snowy cap reaches (6,6)")
	_check(catalog.zoneForChunk(Vector2i(6, 7)) == "whispering_pines_reach", "the snowy cap ends above row 7")
	_check(catalog.zoneForChunk(Vector2i(1, 23)) == "whispering_pines_reach", "the west columns are drawn as pines below the cap")
	_check(catalog.zoneForChunk(Vector2i(2, 0)) == "whispering_pines_reach", "Whispering Pines Reach starts at x=2")
	_check(catalog.zoneForChunk(Vector2i(3, 23)) == "whispering_pines_reach", "Whispering Pines Reach includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(4, 23)) == "rocky_hills", "rocky hills includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(8, 23)) == "wild_west", "the Wild West band includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(10, 4)) == "prairie", "the prairie band covers the old ghost town corner")
	_check(catalog.zoneForChunk(Vector2i(11, 11)) == "prairie", "the prairie ends at (11,11)")
	_check(catalog.zoneForChunk(Vector2i(10, 12)) == "swamp", "swamp starts at y=12")
	_check(catalog.zoneForChunk(Vector2i(11, 23)) == "swamp", "swamp includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(99, 99)) == "whispering_pines_reach", "chunks outside the map use the default Zone")
	_check(catalog.zoneForChunk(Vector2i(-1, -1)) == "whispering_pines_reach", "negative chunks use the default Zone")
	_check(catalog.zoneIds().size() == 6, "six declared Zones")
	_check(catalog.hasZone("wild_west") and !catalog.hasZone("town"), "hasZone checks canonical ids only")
	_check(catalog.displayName("rocky_hills") == "Rocky Hills", "display names come from ZoneData")
	var grid := WorldData.CHUNK_GRID
	_check(ZoneDataScript.MAP_WIDTH == grid.size.x and ZoneDataScript.MAP_HEIGHT == grid.size.y, "the zone map matches the WorldData chunk grid")
	_check(catalog.chunkZones.size() == grid.get_area(), "every chunk on the WorldData grid is explicitly zoned")


func _testConsumerIds(catalog) -> void:
	print("\n--- Consumer Zone ids align ---")
	var equipment = EquipmentDataScript.new()
	for zoneId in catalog.zoneIds():
		_check(equipment.zones.has(zoneId), "equipment data has Zone '%s'" % zoneId)
	_check(equipment.zones.keys().size() == catalog.zoneIds().size() + 1, "equipment data has no unexpected Zone beyond 'town'")
	_check(equipment.zones.has("town") and !catalog.hasZone("town"), "the town equipment band is intentionally outside Overworld Zone ids")

	var musicData = MusicDataScript.new().data
	for zoneId in catalog.zoneIds():
		_check(musicData.zone_tracks.has(zoneId), "MusicData has tracks for Zone '%s'" % zoneId)
		_check(musicData.zone_shootout_tracks.has(zoneId), "MusicData has shootout tracks for Zone '%s'" % zoneId)
	_check(musicData.keys().count("zones") == 0 and !musicData.has("default_zone"), "MusicData no longer owns Zone geometry")
	for trackZone in musicData.zone_tracks:
		_check(catalog.hasZone(trackZone), "MusicData zone track key '%s' is a canonical Zone id" % trackZone)
	for fightZone in musicData.zone_shootout_tracks:
		_check(catalog.hasZone(fightZone), "MusicData fight key '%s' is a canonical Zone id" % fightZone)


func _testInjectionIsolation() -> void:
	print("\n--- Injected datasets replace production ---")
	var injected = ZoneCatalogScript.new({
		"map_width": 2,
		"map_height": 2,
		"legend": { "T": "test_zone" },
		"zone_map": ["TT", "TT"],
		"zones": [
			{ "zone": "test_zone", "displayName": "Test Zone" },
		],
		"default_zone": "test_zone",
	})
	_check(injected.loadError == "", "injected data does not load production data")
	_check(injected.validate().is_empty(), "the injected map dataset validates clean")
	_check(injected.zoneForChunk(Vector2i(0, 0)) == "test_zone", "injected map resolves")
	_check(injected.zoneForChunk(Vector2i(99, 99)) == "test_zone", "injected default resolves")
	_check(!injected.hasZone("wild_west"), "production Zones are absent from an injected dataset")


func _testMalformedData() -> void:
	print("\n--- Malformed datasets fail lint ---")
	var cases = [
		{ "zones": [], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "displayName": "A" }], "default_zone": "a" },
		{ "zones": [{ "zone": "", "displayName": "A" }], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "displayName": "A" }, { "zone": "a", "displayName": "A Copy" }], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "min": Vector2i(0, 0), "max": Vector2i(1, 1) }], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "displayName": "A" }], "default_zone": "missing" },
		{
			"zones": [{ "zone": "a", "displayName": "A" }],
			"default_zone": "a",
		},
		{
			"zones": [{ "zone": "a", "displayName": "A" }],
			"legend": { "T": "missing_zone" },
			"zone_map": ["T"], "map_width": 1, "map_height": 1,
			"default_zone": "a",
		},
		{
			"zones": [{ "zone": "a", "displayName": "A" }],
			"legend": {},
			"zone_map": ["T"], "map_width": 1, "map_height": 1,
			"default_zone": "a",
		},
		{
			"zones": [{ "zone": "a", "displayName": "A" }],
			"legend": { "T": "a" },
			"zone_map": ["T"], "map_width": 2, "map_height": 1,
			"default_zone": "a",
		},
		{
			"zones": [{ "zone": "a", "displayName": "A" }],
			"legend": { "T": "a" },
			"zone_map": ["T", "T"], "map_width": 1, "map_height": 1,
			"default_zone": "a",
		},
		{
			"zones": [{ "zone": "a", "displayName": "A" }],
			"legend": { "T": "a" },
			"zone_map": ["TX"], "map_width": 2, "map_height": 1,
			"default_zone": "a",
		},
		{
			"zones": [{ "zone": "a", "displayName": "A" }, { "zone": "b", "displayName": "B" }],
			"legend": { "T": "a" },
			"zone_map": ["TT"], "map_width": 2, "map_height": 1,
			"default_zone": "a",
		},
	]
	for index in cases.size():
		var catalog = ZoneCatalogScript.new(cases[index])
		_check(!catalog.validate().is_empty(), "malformed dataset %d reports errors" % index)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
