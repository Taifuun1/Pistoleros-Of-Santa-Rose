extends SceneTree

## Headless validation for the authoritative On/Off Trail lifecycle
## (Docs/System Design/First Steps Implementation Plan.md, commit 1).
## Run with: godot --headless --script res://Tests/TestTrailState.gd

const LocationsScript = preload("res://Globals/Locations.gd")

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_testInitialStateAndTownOnlyStart()
	_testTrailGatesAndReentrancy()
	_testTownClassificationAndContext()
	_testSnapshotsAndNewGameReset()
	_testCompatibilityEntryPoints()
	_testProductionTownContent()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _testInitialStateAndTownOnlyStart() -> void:
	print("--- Initial state and Town-only start ---")
	var locations = LocationsScript.new()
	_check(!locations.isOnTrail(), "New Game starts Off Trail")
	_check(!locations.isCurrentLocationTown(), "the default location is not a Town")
	_check(!locations.canAccessLocation(false), "non-town Locations are blocked Off Trail")
	_check(locations.canAccessLocation(true), "Towns remain accessible Off Trail")
	_check(!locations.canApplyAttrition(), "attrition is disabled Off Trail")
	_check(!locations.canGrantLoot(), "loot is disabled Off Trail")

	var refused: Dictionary = locations.startTrail()
	_check(!refused.success and refused.reason == "not_in_town", "a Trail cannot start outside a Town")
	_check(locations.trailDepartureId == 0, "a refused start does not advance the departure id")

	_check(locations.enterTown("").reason == "invalid_location", "an empty Town id is rejected")
	_check(locations.enterTown("  ").reason == "invalid_location", "a whitespace Town id is rejected")
	var town: Dictionary = locations.enterTown("  Lazysprings  ")
	_check(town.success and locations.currentLocation == "Lazysprings", "Town entry trims and records its id")
	_check(locations.lastTownId == "Lazysprings", "the last Town is remembered")
	_check(locations.isCurrentLocationTown(), "entering a Town sets the Town context")
	locations.free()


func _testTrailGatesAndReentrancy() -> void:
	print("\n--- Trail gates, signals and reentrancy ---")
	var locations = LocationsScript.new()
	var departures := []
	var states := []
	locations.trailDeparted.connect(func(departureId): departures.append(departureId))
	locations.trailStateChanged.connect(func(onTrail): states.append(onTrail))
	locations.enterTown("Lazysprings")

	var first: Dictionary = locations.startTrail()
	_check(first.success, "a Town starts a Trail")
	_check(locations.isOnTrail(), "the state becomes On Trail")
	_check(!locations.isCurrentLocationTown(), "leaving for the Trail clears the Town context")
	_check(int(first.departureId) == 1, "the first Trail has departure id 1")
	_check(departures == [1], "starting a Trail emits trailDeparted once")
	_check(states == [true], "starting a Trail emits one state change")
	_check(locations.canAccessLocation(false), "non-town Locations unlock On Trail")
	_check(locations.canApplyAttrition(), "attrition is enabled On Trail")
	_check(locations.canGrantLoot(), "loot is enabled On Trail")

	var repeated: Dictionary = locations.startTrail()
	_check(!repeated.success and repeated.reason == "already_on_trail", "a Trail cannot start twice")
	_check(locations.trailDepartureId == 1 and departures.size() == 1, "a repeated start cannot reset stock")
	_check(locations.enterNonTownLocation("Clearwater Grove").success, "a non-town Location entry is valid On Trail")
	_check(!locations.isCurrentLocationTown() and locations.isOnTrail(), "non-town entry preserves the active Trail")

	var ended: Dictionary = locations.endTrail()
	_check(ended.success and !locations.isOnTrail(), "an active Trail ends explicitly")
	_check(states == [true, false], "ending a Trail emits one state change")
	_check(!locations.canAccessLocation(false), "non-town Locations lock again after ending")
	_check(!locations.canGrantLoot(), "loot locks again after ending")
	_check(locations.endTrail().reason == "not_on_trail", "ending an inactive Trail fails closed")
	_check(departures.size() == 1, "ending a Trail never advances the departure id")

	var second: Dictionary = locations.startTrail()
	_check(second.reason == "not_in_town", "Off Trail cannot restart without re-entering a Town")
	locations.enterTown("Lazysprings")
	var third: Dictionary = locations.startTrail()
	_check(third.success and int(third.departureId) == 2, "a later Town entry starts the next departure")
	_check(departures == [1, 2], "each successful start has one departure id")
	locations.free()

func _testTownClassificationAndContext() -> void:
	print("\n--- Town classification and scene context ---")
	var locations = LocationsScript.new()
	locations.enterTown("Lazysprings")
	var start: Dictionary = locations.startTrail()
	_check(start.success, "the fixture Trail starts")

	# Entering the Overworld must not end an active Trail or leave a stale Town.
	locations.enterOverworld()
	_check(locations.isOnTrail(), "loading the Overworld does not end an active Trail")
	_check(!locations.isCurrentLocationTown(), "the Overworld clears the Town context")
	_check(locations.startTrail().reason == "already_on_trail", "the Overworld cannot start a second Trail")

	# Entering a Town is the explicit end boundary in this slice.
	var town: Dictionary = locations.enterTown("Lazysprings")
	_check(town.success and town.endedTrail, "Town entry reports that it ended the Trail")
	_check(!locations.isOnTrail() and locations.isCurrentLocationTown(), "Town entry ends the Trail and restores Town context")

	# Re-entering a Town while already Off Trail is idempotent.
	var repeatedTown: Dictionary = locations.enterTown("Lazysprings")
	_check(repeatedTown.success and !repeatedTown.endedTrail, "repeated Town entry does not report a second Trail end")

	locations.enterNonTownLocation("Bandit Camp")
	_check(!locations.isCurrentLocationTown() and !locations.isOnTrail(), "Off-Trail non-town context stays blocked")
	_check(locations.enterNonTownLocation("").reason == "invalid_location", "an empty non-town id is rejected")
	locations.free()


func _testSnapshotsAndNewGameReset() -> void:
	print("\n--- Snapshots and New Game reset ---")
	var source = LocationsScript.new()
	source.enterTown("Lazysprings")
	source.startTrail()
	var state: Dictionary = source.exportState()
	_check(state.formatVersion == LocationsScript.STATE_FORMAT_VERSION, "the snapshot carries its format version")

	var restored = LocationsScript.new()
	_check(restored.importState(state).success, "a valid snapshot imports")
	_check(restored.isOnTrail() and restored.trailDepartureId == 1, "import restores the Trail state and departure id")
	_check(restored.lastTownId == "Lazysprings", "import restores the last Town")

	var target = LocationsScript.new()
	var before: Dictionary = target.exportState()
	var malformed = [
		null,
		{ "formatVersion": 2, "onTrail": false, "trailDepartureId": 0, "lastTownId": "" },
		{ "formatVersion": "1", "onTrail": false, "trailDepartureId": 0, "lastTownId": "" },
		{ "formatVersion": 1.0, "onTrail": false, "trailDepartureId": 0, "lastTownId": "" },
		{ "formatVersion": 1, "onTrail": 1, "trailDepartureId": 0, "lastTownId": "" },
		{ "formatVersion": 1, "onTrail": false, "trailDepartureId": -1, "lastTownId": "" },
		{ "formatVersion": 1, "onTrail": false, "trailDepartureId": "one", "lastTownId": "" },
		{ "formatVersion": 1, "onTrail": false, "trailDepartureId": 0, "lastTownId": 7 },
	]
	for index in malformed.size():
		_check(target.importState(malformed[index]).reason == "invalid_state", "malformed snapshot %d fails closed" % index)
		_check(target.exportState() == before, "malformed snapshot %d leaves state untouched" % index)

	target.importState(state)
	target.resetForNewGame()
	var reset: Dictionary = target.exportState()
	_check(!target.isOnTrail() and reset.onTrail == false, "New Game resets Off Trail")
	_check(target.trailDepartureId == 0, "New Game clears the departure cycle")
	_check(target.lastTownId == "" and !target.isCurrentLocationTown(), "New Game forgets the last Town context")
	source.free()
	restored.free()
	target.free()


func _testCompatibilityEntryPoints() -> void:
	print("\n--- Compatibility entry points ---")
	var locations = LocationsScript.new()
	_check(locations.departForTrail() == 0, "the legacy departure cannot start outside a Town")
	locations.enterTown("Lazysprings")
	_check(locations.departForTrail() == 1 and locations.isOnTrail(), "the legacy departure starts through the same command")
	_check(locations.departForTrail() == 1, "a repeated legacy departure returns the unchanged id")
	locations.restoreTrailDepartureId(7)
	_check(locations.trailDepartureId == 7, "the save-load departure sink still restores the counter")
	locations.resetTrailDepartures()
	_check(locations.trailDepartureId == 0, "the legacy departure reset still clears the counter")
	locations.free()


func _testProductionTownContent() -> void:
	print("\n--- Production Town content ---")
	var chunkScript = load("res://Overworld/Overworld Chunks/#8#17.gd")
	_check(chunkScript != null, "the Lazysprings chunk script loads")
	if chunkScript != null:
		var chunkData = chunkScript.new()
		var lazysprings = chunkData.locations.get("Lazysprings", {})
		_check(bool(lazysprings.get("isTown", false)), "Lazysprings is authored as a Town")
		var banditScript = load("res://Overworld/Overworld Chunks/#1#23.gd")
		if banditScript != null:
			var banditData = banditScript.new()
			for locationName in banditData.locations:
				_check(!bool(banditData.locations[locationName].get("isTown", false)), "non-town chunk content is not marked as a Town")
			banditData.free()
		chunkData.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)