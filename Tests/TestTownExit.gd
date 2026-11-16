extends Node

## Scene-run validation for the Off-Trail Town exit (Docs/System Design/System
## Coherence.md, Trail lifecycle): the production Lazysprings gate leaves the
## Town without starting a Trail, keeps the departure counter and vendor stock
## untouched, returns to the Town's Overworld entrance tile, does not bounce
## straight back into the Town, and only the TrailDeparture still starts a Trail.
## Run as TestTownExit.tscn.

const SceneManagerScene = preload("res://Nodes/Scene Manager/SceneManager.tscn")
const TownExitScene = preload("res://Location/Entities/Town/TownExit.tscn")
const CoordinatesScript = preload("res://Overworld/OverworldCoordinates.gd")

const LAZYSPRINGS := "res://Location/Locations/Lazysprings/Lazysprings.tscn"
const LAZYSPRINGS_CHUNK := Vector2i(8, 17)
const LAZYSPRINGS_TILE := Vector2i(22, 38)

var failures := 0
var sceneManager: Node


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	get_tree().root.add_child.call_deferred(sceneManager)
	await get_tree().process_frame
	await get_tree().process_frame
	await _testEntityContract()
	await _testTownExitRouting()
	await _testTrailDepartureStillStartsTrail()
	await _cleanup()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


## Entity contract: group membership, prompt, proximity gate and the non-Town
## guard (a Town-only door must not transition from a non-Town context).
func _testEntityContract() -> void:
	print("--- Town exit entity contract ---")
	var exit = TownExitScene.instantiate()
	add_child(exit)
	await get_tree().process_frame
	_check(exit.is_in_group("location_interactables"), "the gate joins the shared interaction group")
	_check(exit.interactionPrompt == "Leave town", "the gate prompt reads 'Leave town'")
	_check(!exit.canActivate(), "the gate cannot activate without proximity")
	exit.playerNearby = true
	_check(exit.canActivate(), "the gate activates with proximity")

	# Non-Town guard: no scene change may be requested from outside a Town.
	Locations.resetForNewGame()
	_check(!Locations.isCurrentLocationTown(), "the fixture starts outside a Town")
	var changes := []
	var listener := func(key): changes.append(key)
	sceneManager.scene_changed.connect(listener)
	exit.playerNearby = true
	exit.activate()
	await get_tree().process_frame
	_check(changes.is_empty(), "the gate refuses to transition from a non-Town context")
	sceneManager.scene_changed.disconnect(listener)
	exit.queue_free()
	await get_tree().process_frame


## Real routing: Overworld → Lazysprings interior → gate → Overworld.
func _testTownExitRouting() -> void:
	print("\n--- Lazysprings gate leaves the Town Off Trail ---")
	Party.resetForNewGame()
	Locations.resetForNewGame()
	Overworld.resetForNewGame()
	Party.money = 100
	# The party arrives at the Town from the Overworld gate tile.
	Overworld.setSpawn(LAZYSPRINGS_CHUNK, LAZYSPRINGS_TILE)
	sceneManager.change_scene("overworld")
	_check(await _awaitSceneKey("overworld"), "the Overworld loads for the town-exit test")
	await get_tree().process_frame
	await get_tree().process_frame

	Locations.enterTown("Lazysprings")
	sceneManager.change_scene("pregenerated_location", { "location": "Lazysprings" })
	_check(await _awaitSceneKey("pregenerated_location"), "the Lazysprings interior loads")
	await get_tree().process_frame
	await get_tree().process_frame

	var interior = sceneManager.get_current_scene()
	var exit = interior.get_node_or_null("Entities/TownExit")
	var departure = interior.get_node_or_null("Entities/TrailDeparture")
	_check(exit != null, "the production Lazysprings scene contains the town gate")
	_check(departure != null, "the production Lazysprings scene keeps its trail departure")
	if exit == null or departure == null:
		return
	_check(exit.position.distance_to(departure.position) > 36.0, "the gate and the trail marker do not share an activation area")

	var departureBefore: int = Locations.trailDepartureId
	var towns := []
	var listener := func(locationId): towns.append(locationId)
	Locations.townEntered.connect(listener)
	exit.playerNearby = true
	exit.activate()
	_check(await _awaitSceneKey("overworld"), "the gate returns to the Overworld")
	_check(!Locations.isOnTrail(), "leaving through the gate does not start a Trail")
	_check(Locations.trailDepartureId == departureBefore, "the gate does not advance the departure counter (no stock reroll)")
	_check(!Locations.isCurrentLocationTown(), "the gate clears the Town context")
	_check(Party.money == 100, "the gate does not change Party state")

	# The player lands on the Town's Overworld entrance and is not pulled back in.
	for _frame in 90:
		await get_tree().physics_frame
	_check(sceneManager.currentSceneKey == "overworld", "the party stays on the Overworld after leaving")
	_check(towns.is_empty(), "leaving does not immediately re-enter the Town")
	Locations.townEntered.disconnect(listener)
	var player = sceneManager.get_current_scene().get_node_or_null("Actors/PlayerOverworldActor")
	var coordinates = CoordinatesScript.makeHeadless()
	var expected: Vector2 = coordinates.chunkTileToWorld(LAZYSPRINGS_CHUNK, LAZYSPRINGS_TILE)
	coordinates.dispose()
	_check(player != null and player.global_position.distance_to(expected) < 0.01, "the party returns to the Town's Overworld entrance tile")


## Only the explicit trail head still starts a Trail from the Town.
func _testTrailDepartureStillStartsTrail() -> void:
	print("\n--- The trail head still starts a Trail ---")
	Locations.enterTown("Lazysprings")
	sceneManager.change_scene("pregenerated_location", { "location": "Lazysprings" })
	_check(await _awaitSceneKey("pregenerated_location"), "the Lazysprings interior reloads")
	await get_tree().process_frame
	var departure = sceneManager.get_current_scene().get_node_or_null("Entities/TrailDeparture")
	_check(departure != null, "the trail departure is present")
	if departure == null:
		return
	var departureBefore: int = Locations.trailDepartureId
	departure.playerNearby = true
	departure.activate()
	_check(await _awaitSceneKey("overworld"), "the trail head returns to the Overworld")
	_check(Locations.isOnTrail(), "the trail head starts a Trail")
	_check(Locations.trailDepartureId == departureBefore + 1, "the trail head advances the departure counter exactly once")


func _awaitSceneKey(sceneKey: String, maxFrames := 900) -> bool:
	for _index in maxFrames:
		if sceneManager.currentSceneKey == sceneKey and !sceneManager.transitioning:
			return true
		await get_tree().process_frame
	return false


func _cleanup() -> void:
	Locations.resetForNewGame()
	Overworld.resetForNewGame()
	Party.resetForNewGame()
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
