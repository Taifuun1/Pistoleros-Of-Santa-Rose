extends Node

## Scene-run validation for the encounter request/launch/return router
## (Docs/System Design/First Steps Implementation Plan.md, commit 2): typed
## requests, deterministic pool selection, canonical Zone event dispatch, real
## Overworld → canyon Shootout → same-position return, and one-shot cleanup.
## Run as TestEncounterFlow.tscn.

const SceneManagerScene = preload("res://Nodes/Scene Manager/SceneManager.tscn")
const RequestScript = preload("res://Shootout/EncounterRequest.gd")
const PoolScript = preload("res://Data/Shootout/EncounterPoolData.gd")
const ResolverScript = preload("res://Overworld/OverworldEventOutcomeResolver.gd")
const CanyonEventsScript = preload("res://Data/Events/CanyonEvents.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const CoordinatesScript = preload("res://Overworld/OverworldCoordinates.gd")

const CANYON_RATS := "res://Data/Shootout/Encounters/CanyonRats.gd"
const CANYON_RAT_NEST := "res://Data/Shootout/Encounters/CanyonRatNest.gd"
const LITTLEHILL_APPROACH := "res://Data/Shootout/Encounters/LittlehillApproach.gd"
const PRODUCTION_QUEST_CATALOG := "res://Data/Quests/QuestCatalog.tres"
const QUEST_ID := "pistoleros_regroup"

var failures := 0
var sceneManager: Node


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	sceneManager.autosaveEnabled = false
	get_tree().root.add_child.call_deferred(sceneManager)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	await _cleanup()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _run() -> void:
	_testRequestValidation()
	_testPoolSelection()
	_testEventOutcomeDispatch()
	await _testSceneRouter()
	await _testQuestEncounterProgression()


func _testRequestValidation() -> void:
	print("--- Encounter request validation ---")
	var validOptions := {
		"encounterPath": CANYON_RATS,
		"zoneId": "canyon",
		"source": "overworld_event",
		"sourceId": "fight_cache_rats",
		"origin": { "sceneKey": "overworld" },
		"progression": { "band": "early" },
		"trailState": Locations.exportState(),
		"seed": 7,
	}
	var catalog = ZoneCatalogScript.new()
	var request = RequestScript.make(validOptions, catalog, Locations)
	_check(request.isValid(), "a complete request validates")
	_check(request.reason() == "", "a valid request has no failure reason")
	var dictionary: Dictionary = request.toDictionary()
	_check(dictionary.encounterPath == CANYON_RATS and dictionary.zoneId == "canyon", "the snapshot keeps the encounter and Zone")
	_check(dictionary.source == "overworld_event" and dictionary.seed == 7, "the snapshot keeps source and seed")

	var badPath = validOptions.duplicate(true)
	badPath.encounterPath = "res://Data/Shootout/Encounters/DoesNotExist.gd"
	_check(RequestScript.make(badPath, catalog, Locations).reason() == "invalid_encounter", "a missing encounter is rejected")

	var noData = validOptions.duplicate(true)
	noData.encounterPath = "res://Tests/TestTrailState.gd"
	_check(RequestScript.make(noData, catalog, Locations).reason() == "missing_encounter_data", "a script without data is rejected")

	var badZone = validOptions.duplicate(true)
	badZone.zoneId = "not_a_zone"
	_check(RequestScript.make(badZone, catalog, Locations).reason() == "invalid_zone", "a non-canonical Zone is rejected")

	var badSource = validOptions.duplicate(true)
	badSource.source = "telepathy"
	_check(RequestScript.make(badSource, catalog, Locations).reason() == "invalid_source", "an unknown source is rejected")

	var badTrail = validOptions.duplicate(true)
	badTrail.trailState = { "onTrail": "yes", "trailDepartureId": 0, "lastTownId": "" }
	_check(RequestScript.make(badTrail, catalog, Locations).reason() == "invalid_trail_state", "a malformed Trail snapshot is rejected")

	var badSeed = validOptions.duplicate(true)
	badSeed.seed = -2
	_check(RequestScript.make(badSeed, catalog, Locations).reason() == "invalid_seed", "a negative seed is rejected")

	var noTrail = validOptions.duplicate(true)
	noTrail.erase("trailState")
	_check(RequestScript.make(noTrail, catalog, Locations).isValid(), "the Locations snapshot is captured when omitted")


func _testPoolSelection() -> void:
	print("\n--- Deterministic canyon pool selection ---")
	var pools = PoolScript.new()
	_check(pools.loadProductionPools().is_empty(), "production pools load without errors")
	_check(pools.hasZone("canyon"), "the canyon pool is authored")
	var catalog = ZoneCatalogScript.new()

	var firstRng := RandomNumberGenerator.new()
	firstRng.seed = 12345
	var secondRng := RandomNumberGenerator.new()
	secondRng.seed = 12345
	var first: Dictionary = pools.selectEncounter("canyon", firstRng, catalog)
	var second: Dictionary = pools.selectEncounter("canyon", secondRng, catalog)
	_check(first.success and second.success, "valid pools select an encounter")
	_check(first.encounterPath == second.encounterPath, "the same seed selects the same encounter")
	_check(first.encounterPath in [CANYON_RATS, CANYON_RAT_NEST], "selection returns an authored canyon encounter")

	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for index in 40:
		var selected: Dictionary = pools.selectEncounter("canyon", rng, catalog)
		_check(selected.success, "random selection %d succeeds" % index)
		seen[selected.encounterPath] = true
	_check(seen.size() == 2, "both weighted canyon encounters can be selected")

	_check(pools.selectEncounter("ghost_town", rng, catalog).reason == "no_pool", "a canonical Zone without a pool fails closed")
	_check(pools.selectEncounter("not_a_zone", rng, catalog).reason == "invalid_zone", "a non-canonical Zone fails closed")
	_check(pools.selectEncounter("canyon", null, catalog).reason == "invalid_rng", "selection requires an injected RNG")

func _testEventOutcomeDispatch() -> void:
	print("\n--- Canonical Zone pools and event outcomes ---")
	var catalog = ZoneCatalogScript.new()
	_check(OverworldEvents.get_zone_for_chunk(Vector2i(8, 12)) == "canyon", "the spawn chunk resolves through the shared Zone catalog")
	var canyonPool: Dictionary = OverworldEvents.get_event_pool_for_zone("canyon")
	_check(canyonPool.has("Canyon Cache Raiders"), "the canyon event pool includes its authored event")
	_check(canyonPool.has("Rattlesnake"), "generic events are merged into every Zone pool")
	var swampPool: Dictionary = OverworldEvents.get_event_pool_for_zone("swamp")
	_check(swampPool.has("Quicksand"), "the swamp pool includes its authored event")
	_check(!swampPool.has("Canyon Cache Raiders"), "a Zone never receives another Zone's event")

	var canyonData = CanyonEventsScript.new()
	var eventData: Dictionary = canyonData.events["Canyon Cache Raiders"]
	var fightChoice: Dictionary = eventData.choices[0]
	var leaveChoice: Dictionary = eventData.choices[1]
	var resolver = ResolverScript.new()
	_check(resolver.canResolve(fightChoice, catalog).success, "the encounter choice validates")
	_check(resolver.canResolve(leaveChoice, catalog).success, "the flavor-only choice validates")
	_check(OverworldEvents.can_resolve_choice(fightChoice).success, "the popup can enable the encounter choice")
	_check(!resolver.canResolve({ "label": "Legacy", "result": "legacy_result" }, catalog).success, "legacy result-only choices stay unavailable")

	var pools = PoolScript.new()
	pools.loadProductionPools()
	var launches := []
	var context := {
		"zoneId": "canyon",
		"zoneCatalog": catalog,
		"origin": { "sceneKey": "overworld" },
		"trailState": Locations.exportState(),
		"progression": {},
		"rng": _seededRng(4321),
		"encounterPools": pools,
		"launchEncounter": func(request): launches.append(request); return true,
	}
	var fightResult: Dictionary = resolver.resolve("Canyon Cache Raiders", eventData, fightChoice, context)
	_check(fightResult.success and fightResult.launched, "the encounter choice launches")
	_check(launches.size() == 1, "exactly one request is launched")
	var launched = launches[0]
	_check(launched.isValid(), "the launched request is valid")
	_check(launched.encounterPath in [CANYON_RATS, CANYON_RAT_NEST], "the request resolves through the canyon pool")
	_check(launched.zoneId == "canyon" and launched.source == "overworld_event", "the request keeps Zone and source")
	_check(launched.sourceId == "Canyon Cache Raiders", "the request keeps the event identity")
	_check(launched.trailState.onTrail == false, "the request captures the Off-Trail state")

	var noneResult: Dictionary = resolver.resolve("Canyon Cache Raiders", eventData, leaveChoice, context)
	_check(noneResult.success and !noneResult.launched, "the flavor choice closes without launching")
	_check(launches.size() == 1, "the flavor choice adds no request")

	var failingContext = context.duplicate(true)
	failingContext.launchEncounter = func(_request): return false
	_check(resolver.resolve("Canyon Cache Raiders", eventData, fightChoice, failingContext).reason == "launch_failed", "a refused launch reports failure")

	# Exercise the autoload path used by the popup with an injected launcher.
	var autoloadLaunches := []
	OverworldEvents.encounterLauncher = func(request): autoloadLaunches.append(request); return true
	OverworldEvents.resetEventState()
	var autoloadResult: Dictionary = OverworldEvents.resolve_event_choice("Canyon Cache Raiders", eventData, fightChoice)
	_check(autoloadResult.success and autoloadLaunches.size() == 1, "the production popup path launches through the dispatcher")
	OverworldEvents.encounterLauncher = Callable()
	canyonData.free()


func _testSceneRouter() -> void:
	print("\n--- SceneManager encounter launch and return ---")
	var catalog = ZoneCatalogScript.new()
	var invalid = RequestScript.make({
		"encounterPath": "res://Data/Shootout/Encounters/DoesNotExist.gd",
		"zoneId": "canyon",
		"source": "overworld_event",
	}, catalog, Locations)
	_check(!sceneManager.launchShootout(invalid), "an invalid request never transitions")
	_check(!sceneManager.hasPendingShootout(), "an invalid request leaves no pending context")

	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads for the launch test")
	await get_tree().process_frame
	await get_tree().process_frame
	var overworld = sceneManager.get_current_scene()
	var originPlayer = overworld.get_node_or_null("Actors/PlayerOverworldActor")
	_check(originPlayer != null, "the Overworld player exists")
	var originPosition: Vector2 = originPlayer.global_position if originPlayer != null else Vector2.ZERO

	var request = RequestScript.make({
		"encounterPath": CANYON_RATS,
		"zoneId": "canyon",
		"source": "overworld_event",
		"sourceId": "fight_cache_rats",
		"progression": { "band": "early" },
		"trailState": Locations.exportState(),
		"seed": 2468,
	}, catalog, Locations)
	_check(request.isValid(), "the production request validates")
	_check(sceneManager.launchShootout(request), "the router accepts the request")
	_check(sceneManager.hasPendingShootout(), "the router keeps a pending return context")
	var repeated = RequestScript.make({
		"encounterPath": CANYON_RATS, "zoneId": "canyon", "source": "overworld_event",
	}, catalog, Locations)
	_check(!sceneManager.launchShootout(repeated), "a second launch during transition is rejected")

	_check(await _awaitSceneKey("shootout"), "the Shootout scene loads")
	var shootout = sceneManager.get_current_scene()
	_check(shootout.encounterName == "Canyon Rats", "the selected encounter initializes instead of the debug fallback")
	_check(shootout.encounterRequest != null and shootout.encounterRequest.encounterPath == CANYON_RATS, "the Shootout consumes the request once")
	_check(shootout.encounterZoneId == "canyon" and shootout.encounterSourceId == "fight_cache_rats", "the Shootout keeps request context")
	_check(shootout.encounterSeed == 2468 and shootout.combatRng.seed == 2468, "the request seed drives the combat RNG")
	_check(Shootout.pendingRequest == null, "the global pending request is cleared after consumption")

	# Simulate the acknowledged end screen; the router owns the return.
	shootout.battleOver = true
	shootout.presentFightResults({
		"winningSide": Shootout.TEAM_PLAYER,
		"fled": false,
		"outcome": "victory",
		"party": {},
		"rodeoLoot": {},
		"loot": { "money": 0, "items": [] },
	})
	shootout._on_end_screen_continue_pressed()
	_check(await _awaitSceneKey("overworld"), "the result returns to the launch origin")
	_check(!sceneManager.hasPendingShootout(), "the return context is consumed once")
	_check(Shootout.pendingRequest == null, "no pending request survives the return")

	await get_tree().process_frame
	await get_tree().process_frame
	var returned = sceneManager.get_current_scene().get_node_or_null("Actors/PlayerOverworldActor")
	var coordinates = CoordinatesScript.makeHeadless()
	var originChunkTile: Dictionary = coordinates.cellToChunkTile(coordinates.worldToCell(originPosition))
	var expectedPosition: Vector2 = coordinates.chunkTileToWorld(originChunkTile["chunk"], originChunkTile["tile"])
	coordinates.dispose()
	_check(returned != null and returned.global_position.distance_to(expectedPosition) < 0.01, "the player returns to the exact originating tile center")

	# A duplicate late result cannot trigger a second return.
	sceneManager._on_shootout_ended("", {})
	await get_tree().process_frame
	_check(sceneManager.currentSceneKey == "overworld", "a duplicate result is ignored")

	# The failed-launch path clears the request and context.
	var globals = get_node_or_null("/root/Shootout")
	globals.setPendingRequest(request)
	sceneManager._shootoutContext = { "request": request, "origin": {}, "handled": false, "scene": null }
	await sceneManager._abortTransition("shootout")
	_check(globals.pendingRequest == null and !sceneManager.hasPendingShootout(), "a failed Shootout load clears request and context")


func _testQuestEncounterProgression() -> void:
	print("\n--- Quest encounter launch and objective progression ---")
	var catalog = load(PRODUCTION_QUEST_CATALOG)
	_check(catalog != null, "the production quest catalog loads")
	_check(Quests.loadCatalog(catalog), "the production quest catalog is valid")
	Quests.resetForNewGame()
	_check(Quests.startQuest(QUEST_ID), "the prologue quest starts")
	for objectiveId in ["find_gwyneth", "find_aiyana", "find_manuel"]:
		_check(Quests.completeCurrentObjective(QUEST_ID, objectiveId), "%s advances the quest" % objectiveId)
	_check(Quests.isCurrentObjective(QUEST_ID, "find_morrison"), "the Shootout objective is current")

	var progression := {
		"questId": QUEST_ID,
		"objectiveId": "find_morrison",
		"band": "early",
	}
	var requestOptions := {
		"encounterPath": LITTLEHILL_APPROACH,
		"zoneId": "whispering_pines_reach",
		"source": "quest",
		"sourceId": "%s:find_morrison" % QUEST_ID,
		"origin": { "sceneKey": "overworld" },
		"progression": progression,
		"trailState": Locations.exportState(),
		"seed": 357,
	}
	var trigger = load("res://Location/Entities/Quest/QuestEncounterTrigger.tscn").instantiate()
	add_child(trigger)
	trigger.playerNearby = true
	_check(trigger.canActivate(), "the production trigger is active for its exact current objective")

	var questRequest = RequestScript.make(requestOptions, ZoneCatalogScript.new(), Locations)
	_check(questRequest.isValid(), "the quest encounter request validates")

	sceneManager._applyQuestEncounterResult(questRequest, {
		"winningSide": Shootout.TEAM_ENEMY, "fled": false, "outcome": "defeat", "party": {},
	})
	_check(Quests.isCurrentObjective(QUEST_ID, "find_morrison"), "a defeat leaves the objective current")
	sceneManager._applyQuestEncounterResult(questRequest, {
		"winningSide": Shootout.TEAM_PLAYER, "fled": true, "outcome": "fled", "party": {},
	})
	_check(Quests.isCurrentObjective(QUEST_ID, "find_morrison"), "a flight leaves the objective current")

	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads for the quest launch")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(sceneManager.launchShootout(questRequest), "SceneManager launches the quest encounter")
	_check(await _awaitSceneKey("shootout"), "the quest encounter scene loads")
	var shootout = sceneManager.get_current_scene()
	_check(shootout.encounterName == "Littlehill Approach", "the authored quest encounter initializes")
	_check(shootout.encounterSource == "quest", "the Shootout keeps its quest source")
	shootout.battleOver = true
	shootout.presentFightResults({
		"winningSide": Shootout.TEAM_PLAYER,
		"fled": false,
		"outcome": "victory",
		"party": {},
		"rodeoLoot": {},
		"loot": { "money": 0, "items": [] },
	})
	shootout._on_end_screen_continue_pressed()
	_check(await _awaitSceneKey("overworld"), "the quest result returns to the Overworld")
	_check(Quests.getCurrentObjectiveId(QUEST_ID) == "regroup_pistoleros_of_santa_rose", "the acknowledged victory completes the quest objective")
	_check(!Quests.isCurrentObjective(QUEST_ID, "find_morrison"), "the completed objective does not remain current")

	# A repeated command is idempotent even when it bypasses the one-shot router.
	Quests.completeCurrentObjective(QUEST_ID, "find_morrison")
	_check(Quests.getCurrentObjectiveId(QUEST_ID) == "regroup_pistoleros_of_santa_rose", "a repeated quest-encounter result cannot regress progression")
	_check(!trigger.canActivate(), "the completed quest trigger no longer activates")
	trigger.free()


func _seededRng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _awaitSceneKey(sceneKey: String, maxFrames := 900) -> bool:
	for _index in maxFrames:
		if sceneManager.currentSceneKey == sceneKey && !sceneManager.transitioning:
			return true
		await get_tree().process_frame
	return false


func _cleanup() -> void:
	OverworldEvents.encounterLauncher = Callable()
	OverworldEvents.overworldProvider = null
	OverworldEvents.resetEventState()
	Locations.resetForNewGame()
	Quests.resetForNewGame()
	if is_instance_valid(sceneManager):
		var manager = sceneManager
		manager.queue_free()
		if manager.is_inside_tree():
			await manager.tree_exited
	await get_tree().process_frame
	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
	if Overworld._coordinates != null:
		Overworld._coordinates.dispose()
		Overworld._coordinates = null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)