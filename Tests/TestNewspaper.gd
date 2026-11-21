extends SceneTree

## Headless validation for newspaper reports (Docs/System Design/Location
## Vendors Implementation.md, patch 6): exact-Zone resolution, composition
## aggregation, damage/mechanics/tips projection, quest exclusion, empty and
## malformed data, and the production pool/copy lint.
## Run with: godot --headless --script res://Tests/TestNewspaper.gd

const NewspaperReportBuilderScript = preload("res://Vendors/NewspaperReportBuilder.gd")
const NewspaperDataScript = preload("res://Data/Vendors/NewspaperData.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"

const RAT_ENCOUNTER := "res://Data/Shootout/Encounters/CanyonRats.gd"
const QUEST_ENCOUNTER := "res://Data/Shootout/Encounters/CanyonRatNest.gd"

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var zoneCatalog = ZoneCatalogScript.new()
	var builder = NewspaperReportBuilderScript.new()

	print("--- Production pools and copy lint ---")
	var pools = EncounterPoolDataScript.new()
	var poolErrors := pools.validateAuthoredPools(zoneCatalog, _encounterNames())
	_check(poolErrors.is_empty(), "authored pools validate: %s" % [poolErrors])
	_check(!pools.pools.is_empty(), "at least one Zone publishes a pool")
	_check(pools.hasZone("wild_west") and !pools.getPublicEntries("wild_west").is_empty(), "the canyon Zone publishes entries")
	var copy = NewspaperDataScript.new()
	var copyErrors := copy.validate(zoneCatalog, pools)
	_check(copyErrors.is_empty(), "authored newspaper copy validates: %s" % [copyErrors])
	_check(!copy.hasZone("tillhill_marsh"), "Zones without copy stay unauthored")

	print("\n--- Every production report matches its own Zone and pool ---")
	var manifest = load(MAP_MANIFEST)
	var report = builder.buildReport("wild_west", pools, _resolver(), copy)
	_check(report.success and report.available, "the canyon report is available")
	_check(report.zoneId == "wild_west", "the report keeps the requested Zone")
	_check(str(report.headline) == copy.getHeadline("wild_west") and str(report.editorial) == copy.getEditorial("wild_west"), "headline and editorial come from the authored copy")
	_check(report.generalTips == copy.getGeneralTips("wild_west"), "general tips come from the authored copy")
	for party in report.parties:
		var entry := _findPoolEntry(pools, "wild_west", str(party.encounterId))
		_check(!entry.is_empty(), "report party '%s' is published by the Zone pool" % party.encounterId)
		var encounter = _loadEncounter(str(entry.encounter))
		_check(!encounter.is_empty(), "report party '%s' resolves its encounter file" % party.encounterId)
		_check(str(party.name) == str(encounter.get("name", "")), "report party '%s' keeps the encounter name" % party.encounterId)
		_check(str(party.kind) == str(encounter.get("kind", "dustup")), "report party '%s' keeps the encounter kind" % party.encounterId)
		_check(_compositionMatches(party.composition, encounter.get("teams", {})), "report party '%s' composition matches the authored enemy team" % party.encounterId)
		_check(!party.composition.is_empty(), "report party '%s' lists at least one enemy" % party.encounterId)
		_check(party.mechanics == copy.getEncounterTips("wild_west", str(party.encounterId)), "report party '%s' uses the authored tips" % party.encounterId)
		for row in party.composition:
			_check(int(row.count) > 0, "report party '%s' counts every aggregate" % party.encounterId)
		_check(!party.damageTypes.is_empty(), "report party '%s' names its damage types" % party.encounterId)
	_check(!manifest.resolveLocation("Lazysprings").is_empty(), "the vendor Zone id resolves through the shared catalogs")

	var productionPools = EncounterPoolDataScript.new()
	productionPools.loadProductionPools()
	var productionCopy = NewspaperDataScript.new()
	_check(builder.buildReport("tillhill_marsh", productionPools, _resolver(), productionCopy).reason == "no_pool", "an unpublished Zone never falls back to another Zone")
	var productionReport = builder.buildReport("wild_west", productionPools, _resolver(), productionCopy)
	_check(productionReport.parties.size() == productionPools.getPublicEntries("wild_west").size(), "every published entry appears exactly once")
	_check(!productionReport.parties.is_empty(), "a real production report is never empty")
	var names := []
	for party in productionReport.parties:
		names.append(str(party.name))
	_check(!names.has("Testing Encounter"), "the debug RatAmbush encounter is never published as news")

	print("\n--- The second authored Zone projects real news ---")
	var pinesReport = builder.buildReport("kipley_wilds", productionPools, _resolver(), productionCopy)
	_check(pinesReport.success and pinesReport.available, "the Whispering Pines Reach report is available")
	_check(pinesReport.zoneId == "kipley_wilds", "the pines report keeps its Zone")
	_check(str(pinesReport.headline) == productionCopy.getHeadline("kipley_wilds"), "the pines headline comes from the authored copy")
	_check(pinesReport.parties.size() == productionPools.getPublicEntries("kipley_wilds").size(), "every published Whispering Pines Reach entry is projected")
	for party in pinesReport.parties:
		_check(!party.composition.is_empty(), "pines party '%s' lists at least one enemy" % party.encounterId)
		_check(!party.damageTypes.is_empty(), "pines party '%s' names its damage types" % party.encounterId)
		_check(party.mechanics == productionCopy.getEncounterTips("kipley_wilds", str(party.encounterId)) and !party.mechanics.is_empty(), "pines party '%s' carries its authored tips" % party.encounterId)
	var pinesNames := []
	for party in pinesReport.parties:
		pinesNames.append(str(party.encounterId))
	pinesNames.sort()
	_check(pinesNames == ["PinesPatrol", "PinesStandoff", "PinesWaylay"], "the three authored pines encounters are published, got %s" % [pinesNames])

	print("\n--- Aggregation, ordering and exclusions ---")
	var fixturePools = EncounterPoolDataScript.new()
	fixturePools.pools["wild_west"] = { "zoneId": "wild_west", "entries": [
		{ "encounter": RAT_ENCOUNTER, "weight": 1 },
		{ "encounter": QUEST_ENCOUNTER, "weight": 1, "newspaperPublic": false },
	] }
	var fixtureCopy = NewspaperDataScript.new()
	var fixture = builder.buildReport("wild_west", fixturePools, _resolver(), fixtureCopy)
	_check(fixture.success and fixture.available, "a pool with public entries reports")
	_check(fixture.parties.size() == 1, "quest/private entries are excluded from reports")
	_check(str(fixture.parties[0].encounterId) == "CanyonRats", "the remaining party is the public encounter")
	_check(fixture.parties[0].mechanics == fixtureCopy.getEncounterTips("wild_west", "CanyonRats"), "the party carries the authored mechanics")

	var duplicatePools = EncounterPoolDataScript.new()
	duplicatePools.pools["wild_west"] = { "zoneId": "wild_west", "entries": [
		{ "encounter": RAT_ENCOUNTER, "weight": 1 },
		{ "encounter": RAT_ENCOUNTER, "weight": 2 },
	] }
	var duplicated = builder.buildReport("wild_west", duplicatePools, _resolver(), fixtureCopy)
	_check(duplicated.parties.size() == 2, "the same encounter listed twice reports twice (the launcher owns dedupe)")
	_check(duplicated.parties[0].composition == duplicated.parties[1].composition, "repeated entries project identical compositions")

	print("\n--- Deterministic and side-effect free ---")
	var first = builder.buildReport("wild_west", fixturePools, _resolver(), fixtureCopy)
	var second = builder.buildReport("wild_west", fixturePools, _resolver(), fixtureCopy)
	_check(first == second, "two builds of the same data are deep-equal")
	var poolSnapshot = fixturePools.getEntries("wild_west")
	var copySnapshot = fixtureCopy.getZone("wild_west")
	builder.buildReport("wild_west", fixturePools, _resolver(), fixtureCopy)
	_check(fixturePools.getEntries("wild_west") == poolSnapshot and fixtureCopy.getZone("wild_west") == copySnapshot, "building a report mutates neither the pools nor the copy")
	seed(99)
	var expected := randi()
	seed(99)
	builder.buildReport("wild_west", fixturePools, _resolver(), fixtureCopy)
	_check(randi() == expected, "reporting never advances the global RNG")

	print("\n--- Failure states ---")
	_check(builder.buildReport("", fixturePools, _resolver(), fixtureCopy).reason == "data_unavailable", "an empty Zone id fails closed")
	_check(builder.buildReport("wild_west", null, _resolver(), fixtureCopy).reason == "data_unavailable", "missing pools fail closed")
	_check(builder.buildReport("wild_west", fixturePools, _resolver(), null).reason == "data_unavailable", "missing copy fails closed")
	var emptyPools = EncounterPoolDataScript.new()
	emptyPools.pools["wild_west"] = { "zoneId": "wild_west", "entries": [] }
	var empty = builder.buildReport("wild_west", emptyPools, _resolver(), fixtureCopy)
	_check(empty.success and !empty.available, "a valid Zone with no public encounters is available=false")
	_check(str(empty.headline) == fixtureCopy.getHeadline("wild_west"), "an empty report still shows the authored headline")
	_check(empty.parties.is_empty() and empty.generalTips.size() > 0, "an empty report carries no parties but keeps the tips")

	var missingEncounterPools = EncounterPoolDataScript.new()
	missingEncounterPools.pools["wild_west"] = { "zoneId": "wild_west", "entries": [{ "encounter": "res://Data/Shootout/Encounters/DoesNotExist.gd", "weight": 1 }] }
	_check(builder.buildReport("wild_west", missingEncounterPools, _resolver(), fixtureCopy).reason == "missing_encounter", "a missing encounter file fails closed")

	var malformedEncounterPools = EncounterPoolDataScript.new()
	malformedEncounterPools.pools["wild_west"] = { "zoneId": "wild_west", "entries": [{ "encounter": "res://Tests/TestNewspaper.gd", "weight": 1 }] }
	_check(builder.buildReport("wild_west", malformedEncounterPools, _resolver(), fixtureCopy).reason == "malformed_encounter", "an encounter without enemy teams fails closed")

	var missingActorPools = EncounterPoolDataScript.new()
	missingActorPools.pools["wild_west"] = { "zoneId": "wild_west", "entries": [{ "encounter": RAT_ENCOUNTER, "weight": 1 }] }
	_check(builder.buildReport("wild_west", missingActorPools, Callable(self, "_missingActorResolver"), fixtureCopy).reason == "missing_actor", "an unresolvable enemy actor fails closed")

	var noCopy = NewspaperDataScript.new()
	noCopy.zones = {}
	_check(builder.buildReport("wild_west", fixturePools, _resolver(), noCopy).reason == "no_copy", "a Zone without authored copy fails closed")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _resolver() -> Callable:
	return Callable(NewspaperReportBuilderScript, "defaultActorResolver")


func _missingActorResolver(_actorType: String, _actorName: String) -> Dictionary:
	return { "success": false, "reason": "missing_actor" }


## Every encounter basename on disk, so pool lint rejects unknown references.
func _encounterNames() -> Array:
	var names := []
	for fileName in DirAccess.get_files_at("res://Data/Shootout/Encounters"):
		if fileName.ends_with(".gd"):
			names.append(fileName.get_basename())
	return names


func _findPoolEntry(pools, zoneId: String, encounterId: String) -> Dictionary:
	for entry in pools.getEntries(zoneId):
		if str(entry.get("encounter", "")).get_file().get_basename() == encounterId:
			return entry
	return {}


func _loadEncounter(encounterPath: String) -> Dictionary:
	if !ResourceLoader.exists(encounterPath):
		return {}
	var script = load(encounterPath)
	if script == null:
		return {}
	var holder = script.new()
	if holder == null or !("data" in holder):
		if holder != null:
			holder.free()
		return {}
	var data: Dictionary = holder.data.duplicate(true)
	holder.free()
	return data


## True when the projected rows cover exactly the authored enemy team: total
## copies per actor match the authored position counts.
func _compositionMatches(composition: Array, teams: Dictionary) -> bool:
	var enemyTeam = teams.get("enemy team", null)
	if !(enemyTeam is Dictionary):
		return false
	var expected := {}
	for actorType in enemyTeam:
		for actorName in enemyTeam[actorType]:
			var positions = enemyTeam[actorType][actorName].get("positions", [])
			expected[str(actorName)] = int(expected.get(str(actorName), 0)) + positions.size()
	if expected.size() != composition.size():
		return false
	for row in composition:
		var actorName := str(row.get("actorName", "")).capitalize()
		var matched := false
		for key in expected:
			if str(key).capitalize() == actorName:
				matched = int(row.get("count", 0)) == int(expected[key])
		if !matched:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)