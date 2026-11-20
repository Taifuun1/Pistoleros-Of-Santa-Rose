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
	print("\n--- Band resolution and default ---")
	_check(catalog.zoneForChunk(Vector2i(0, 0)) == "grassy_plains", "top-left chunk is grassy plains")
	_check(catalog.zoneForChunk(Vector2i(1, 23)) == "grassy_plains", "grassy plains band includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(2, 0)) == "whispering_pines_reach", "Whispering Pines Reach starts at x=2")
	_check(catalog.zoneForChunk(Vector2i(4, 23)) == "hilly_mining", "hilly mining includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(6, 0)) == "snowy_mountain", "snowy mountain starts at x=6")
	_check(catalog.zoneForChunk(Vector2i(8, 23)) == "canyon", "canyon band includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(10, 1)) == "ghost_town", "earlier ghost town band wins the overlap")
	_check(catalog.zoneForChunk(Vector2i(10, 4)) == "desert_prairie", "desert prairie follows the ghost town band")
	_check(catalog.zoneForChunk(Vector2i(11, 11)) == "desert_prairie", "desert prairie ends at (11,11)")
	_check(catalog.zoneForChunk(Vector2i(10, 12)) == "swamp", "swamp starts at y=12")
	_check(catalog.zoneForChunk(Vector2i(11, 23)) == "swamp", "swamp includes its far corner")
	_check(catalog.zoneForChunk(Vector2i(99, 99)) == "canyon", "chunks outside every band use the default Zone")
	_check(catalog.zoneForChunk(Vector2i(-1, -1)) == "canyon", "negative chunks use the default Zone")
	_check(catalog.zoneIds().size() == 8, "eight declared Zones")
	_check(catalog.hasZone("canyon") and !catalog.hasZone("town"), "hasZone checks canonical ids only")
	_check(catalog.displayName("ghost_town") == "Ghost Town", "display names come from ZoneData")


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
		"zones": [
			{ "zone": "test_zone", "displayName": "Test Zone", "min": Vector2i(0, 0), "max": Vector2i(1, 1) },
		],
		"default_zone": "test_zone",
	})
	_check(injected.loadError == "", "injected data does not load production data")
	_check(injected.zoneForChunk(Vector2i(0, 0)) == "test_zone", "injected band resolves")
	_check(injected.zoneForChunk(Vector2i(99, 99)) == "test_zone", "injected default resolves")
	_check(!injected.hasZone("canyon"), "production Zones are absent from an injected dataset")


func _testMalformedData() -> void:
	print("\n--- Malformed datasets fail lint ---")
	var duplicateOk = ZoneCatalogScript.new({
		"zones": [
			{ "zone": "a", "displayName": "A", "min": Vector2i(0, 0), "max": Vector2i(1, 1) },
			{ "zone": "a", "displayName": "A Copy", "min": Vector2i(2, 0), "max": Vector2i(3, 1) },
		],
		"default_zone": "a",
	})
	_check(duplicateOk.validate().is_empty(), "repeated Zone ids in separate bands are valid")

	var cases = [
		{ "zones": [], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "displayName": "A", "min": Vector2i(2, 0), "max": Vector2i(1, 0) }], "default_zone": "a" },
		{ "zones": [{ "zone": "", "displayName": "A", "min": Vector2i(0, 0), "max": Vector2i(1, 1) }], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "min": Vector2i(0, 0), "max": Vector2i(1, 1) }], "default_zone": "a" },
		{ "zones": [{ "zone": "a", "displayName": "A", "min": Vector2i(0, 0), "max": Vector2i(1, 1) }], "default_zone": "missing" },
	]
	for index in cases.size():
		var catalog = ZoneCatalogScript.new(cases[index])
		_check(!catalog.validate().is_empty(), "malformed dataset %d reports errors" % index)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
