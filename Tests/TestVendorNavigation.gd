extends Node

## Scene-run validation of vendor interaction and navigation (Docs/System
## Design/Location Vendors Implementation.md, patch 3): closest-target
## activation, door → room → vendor modal → exit → same-door return for both
## pregenerated and generic Dictionary Locations, and safe failed entries.
## Run as TestVendorNavigation.tscn.

const SceneManagerScene := preload("res://Nodes/Scene Manager/SceneManager.tscn")
const DirectorScene := preload("res://Nodes/Interaction/LocationInteractionDirector.tscn")
const InteractableScript := preload("res://Nodes/Interaction/LocationInteractable.gd")
const PlayerScript := preload("res://Actors/Location/PlayerLocationActor.gd")

var failures := 0
var sceneManager: Node
## The player must return to the doorway itself, not tiles below the entrance.
const ENTRANCE_TOLERANCE := 12.0


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	get_tree().root.add_child.call_deferred(sceneManager)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	_cleanup()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _run() -> void:
	await _testClosestTargetOnly()
	await _testPregeneratedFlow()
	await _testGenericFlow()
	await _testTownContent()
	await _testSafeFailures()


func _testClosestTargetOnly() -> void:
	print("--- Closest target only ---")
	var host := Node2D.new()
	add_child(host)
	var director = DirectorScene.instantiate()
	host.add_child(director)
	var player := CharacterBody2D.new()
	player.add_to_group("location_player")
	player.collision_layer = 2
	player.collision_mask = 0
	var playerShape := CollisionShape2D.new()
	var playerCircle := CircleShape2D.new()
	playerCircle.radius = 2.0
	playerShape.shape = playerCircle
	player.add_child(playerShape)
	host.add_child(player)
	var near = _makeTarget(host, Vector2(12, 0), "Near")
	var far = _makeTarget(host, Vector2(48, 0), "Far")
	var nearCount := [0]
	var farCount := [0]
	near.activated.connect(func(_target): nearCount[0] += 1)
	far.activated.connect(func(_target): farCount[0] += 1)

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(director.getBestTarget() == near, "closest overlapping target wins")
	_check(director.promptLabel.visible and director.promptLabel.text == "Near", "prompt shows the closest target")
	director._unhandled_input(_actionEvent("INTERACT"))
	_check(nearCount[0] == 1 and farCount[0] == 0, "INTERACT activates only the closest target")

	player.global_position = Vector2(40, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(director.getBestTarget() == far, "selection follows the player's nearest target")
	director._unhandled_input(_actionEvent("INTERACT"))
	_check(nearCount[0] == 1 and farCount[0] == 1, "the other target activates after the move")
	host.queue_free()
	await get_tree().process_frame


func _testPregeneratedFlow() -> void:
	print("\n--- Pregenerated Location flow ---")
	sceneManager.change_scene("pregenerated_location", { "location": "Lazysprings" })
	await sceneManager.scene_changed
	_check(sceneManager.currentSceneKey == "pregenerated_location", "Lazysprings loads as a pregenerated Location")
	var location = sceneManager.get_current_scene()
	var player = location.get_node_or_null("Entities/Actors/PlayerActor")
	var door = location.get_node_or_null("Entities/Vendors/GeneralStoreDoor")
	_check(player != null and door != null, "Lazysprings has the player and general-store door")
	_check(door.get_node_or_null("FloatingIcon") != null, "door carries a floating icon node")
	_check(door.vendorId == "lazysprings_general", "door points at the production vendor")
	_check(door.returnPosition().distance_to(door.global_position) <= ENTRANCE_TOLERANCE, "door return spawn sits at the doorway")
	var director = location.get_node_or_null("Entities/InteractionDirector")

	var returnTarget: Vector2 = door.returnPosition()
	player.global_position = door.global_position + Vector2(0, 20)
	await _physicsFrames(6)
	_check(director.getBestTarget() == door, "door is the closest interaction target")
	_check(director.promptLabel.visible and director.promptLabel.text == "Enter General Store", "door prompt names the action")
	director._unhandled_input(_actionEvent("INTERACT"))
	await sceneManager.scene_changed
	_check(sceneManager.currentSceneKey == "vendor_room", "door interaction enters the vendor room")
	_check(!sceneManager.vendorMenu.isOpen, "entering a room does not auto-open the vendor menu")

	var room = sceneManager.get_current_scene()
	_check(room.vendorId == "lazysprings_general" and room.roomReady, "room loads the catalog interior")
	_check(room.get_node("Room").get_child_count() == 1, "authored interior is instanced once")
	var roomPlayer = room.get_node_or_null("Entities/Actors/PlayerActor")
	var actor = room.get_node_or_null("Room/LazyspringsGeneralStore/VendorActor")
	_check(roomPlayer != null and actor != null, "room contains the persistent player and vendor actor")
	_check(actor.vendorId == "lazysprings_general", "vendor actor carries the same vendor id")
	var roomSpawn = room.get_node_or_null("Room/LazyspringsGeneralStore/PlayerSpawn")
	_check(roomSpawn != null, "room interior authors a player spawn")
	await _checkSpawnOutsideActivation(roomPlayer, room.get_node("VendorExit"), "room spawn is outside the exit activation shape")

	roomPlayer.global_position = Vector2(0, -30)
	await _physicsFrames(6)
	director = room.get_node_or_null("LocationInteractionDirector")
	_check(director.getBestTarget() == actor, "vendor actor is the closest target inside the room")
	director._unhandled_input(_actionEvent("INTERACT"))
	_check(sceneManager.vendorMenu.isOpen and get_tree().paused, "vendor interaction opens the modal and pauses")
	_check(sceneManager.vendorMenu.titleLabel.text == "Lazysprings General Store", "modal shows the vendor name")
	sceneManager.closeVendor()
	_check(!sceneManager.vendorMenu.isOpen and !get_tree().paused, "closing the modal restores gameplay")

	roomPlayer.global_position = Vector2(0, 40)
	await _physicsFrames(6)
	_check(director.getBestTarget() == room.get_node("VendorExit"), "exit becomes the closest target")
	director._unhandled_input(_actionEvent("INTERACT"))
	await sceneManager.scene_changed
	_check(sceneManager.currentSceneKey == "pregenerated_location", "exit returns to the parent Location")
	var returned = sceneManager.get_current_scene()
	var returnedPlayer = returned.get_node_or_null("Entities/Actors/PlayerActor")
	var returnedDoor = returned.get_node_or_null("Entities/Vendors/GeneralStoreDoor")
	_check(returnedPlayer != null and returnedPlayer.global_position.distance_to(returnTarget) < 0.001, "return places the player at the door position")
	_check(returnedDoor != null, "return restores the same exterior door")
	_checkSpawnOnMarker(returnedPlayer, returnedDoor, "return places the player on the door marker, under the icon")


func _testGenericFlow() -> void:
	print("
--- Generic Dictionary Location flow ---")
	Locations.currentQuest = ""
	var startPosition := Vector2(40, 0)
	Locations.currentLocation = { "location": "Test/VendorNavigationTest", "playerPosition": startPosition }
	sceneManager.change_scene("location")
	await sceneManager.scene_changed
	await get_tree().process_frame
	_check(sceneManager.currentSceneKey == "location", "generic Location loader reaches the fixture")
	var sceneRoot = sceneManager.get_current_scene()
	var fixture = sceneRoot.get_node_or_null("VendorNavigationTest")
	_check(fixture != null, "generic loader instantiates the fixture scene")
	var player = fixture.get_node_or_null("Entities/Actors/PlayerActor")
	_check(player != null and player.global_position.distance_to(startPosition) < 0.001, "Dictionary playerPosition seeds the generic Location")
	var door = fixture.get_node_or_null("Entities/Vendors/GenericStoreDoor")
	var director = fixture.get_node_or_null("Entities/InteractionDirector")
	_check(door != null and director != null, "generic fixture has its door and director")
	var returnTarget: Vector2 = door.returnPosition()
	_check(returnTarget.distance_to(door.global_position) <= ENTRANCE_TOLERANCE, "generic door return spawn sits at the doorway")

	player.global_position = door.global_position + Vector2(0, 20)
	await _physicsFrames(6)
	_check(director.getBestTarget() == door, "generic door is interactable")
	director._unhandled_input(_actionEvent("INTERACT"))
	await sceneManager.scene_changed
	_check(sceneManager.currentSceneKey == "vendor_room", "generic door enters the shared vendor room")
	var room = sceneManager.get_current_scene()
	var roomPlayer = room.get_node_or_null("Entities/Actors/PlayerActor")
	var actor = room.get_node_or_null("Room/LazyspringsGeneralStore/VendorActor")
	roomPlayer.global_position = Vector2(0, -30)
	await _physicsFrames(6)
	director = room.get_node_or_null("LocationInteractionDirector")
	_check(director.getBestTarget() == actor, "generic room vendor interaction is available")
	director._unhandled_input(_actionEvent("INTERACT"))
	_check(sceneManager.vendorMenu.isOpen, "generic flow opens the vendor modal")
	sceneManager.closeVendor()

	roomPlayer.global_position = Vector2(0, 40)
	await _physicsFrames(6)
	director._unhandled_input(_actionEvent("INTERACT"))
	await sceneManager.scene_changed
	await get_tree().process_frame
	_check(sceneManager.currentSceneKey == "location", "generic exit returns through the Location loader")
	var returnedRoot = sceneManager.get_current_scene()
	var returned = returnedRoot.get_node_or_null("VendorNavigationTest")
	var returnedPlayer = returned.get_node_or_null("Entities/Actors/PlayerActor")
	var returnedDoor = returned.get_node_or_null("Entities/Vendors/GenericStoreDoor")
	_check(returnedPlayer != null and returnedPlayer.global_position.distance_to(returnTarget) < 0.001, "generic return places the player at the door position")
	_check(typeof(Locations.currentLocation) == TYPE_DICTIONARY, "return preserves the Dictionary currentLocation form")
	_check(Locations.currentLocation.get("playerPosition", Vector2.ZERO) == returnTarget, "Dictionary playerPosition is updated to the door spawn")
	_checkSpawnOnMarker(returnedPlayer, returnedDoor, "generic return places the player on the door marker")

func _testTownContent() -> void:
	print("\n--- Lazysprings vendor street ---")
	sceneManager.change_scene("pregenerated_location", { "location": "Lazysprings" })
	await sceneManager.scene_changed
	var location = sceneManager.get_current_scene()
	var vendors = get_node_or_null("/root/Vendors")
	_check(vendors != null, "the Vendors service is available")
	var expected = {
		"GeneralStoreDoor": "lazysprings_general",
		"GunsmithDoor": "lazysprings_gunsmith",
		"OutfitterDoor": "lazysprings_outfitter",
		"BankDoor": "lazysprings_bank",
		"GazetteDoor": "lazysprings_gazette",
	}
	for doorName in expected:
		var door = location.get_node_or_null("Entities/Vendors/" + doorName)
		_check(door != null, "Lazysprings places %s" % doorName)
		if door == null:
			continue
		_check(door.vendorId == expected[doorName], "%s points at its production vendor" % doorName)
		_check(door.returnPosition().distance_to(door.global_position) <= ENTRANCE_TOLERANCE, "%s returns the player to its doorway" % doorName)
		var definition = vendors.getVendorDefinition(door.vendorId)
		_check(!definition.is_empty(), "%s resolves a catalog definition" % doorName)
		if !definition.is_empty():
			_check(ResourceLoader.exists(str(definition.get("roomScene", ""))), "%s has an authored interior" % doorName)
	var departure = location.get_node_or_null("Entities/TrailDeparture")
	_check(departure != null and departure.interactionPrompt == "Leave for the trail", "the town has an explicit trail departure")
	if departure != null:
		var departureShape := departure.get_node("CollisionShape2D") as CollisionShape2D
		var departureIcon := departure.get_node("FloatingIcon") as Node2D
		_check(departureShape.position == Vector2.ZERO and departureShape.shape is CircleShape2D, "the trail departure activation is centred on its marker")
		_check(departureIcon.position.x == 0.0, "the trail departure icon sits straight above its marker")
		await _physicsFrames(4)
		_check(!departure.playerNearby, "the player does not spawn inside the trail departure")

	print("\n--- Stock resets only on the explicit departure ---")
	var first = vendors.getVendorSnapshot("lazysprings_gunsmith")
	_check(bool(first.get("success", false)) and first.offers.size() > 0, "the gunsmith rolls stock for the cycle")
	var reopened = vendors.getVendorSnapshot("lazysprings_gunsmith")
	_check(reopened.offers == first.offers, "reopening the vendor keeps the same stock")
	var bankBefore = vendors.getBankSnapshot().get("bank", []).size()
	Locations.departForTrail()
	var after = vendors.getVendorSnapshot("lazysprings_gunsmith")
	_check(after.offers.size() > 0 and after.offers != first.offers, "the explicit departure rolls new stock once")
	_check(vendors.getBankSnapshot().get("bank", []).size() == bankBefore, "departure leaves the Bank untouched")
	_check(vendors.getVendorSnapshot("lazysprings_general").offers.size() == 2, "departure leaves the fixed store untouched")

	# Walk into one of the new interiors to prove the authored scenes load and
	# return to their own doorway.
	var bankDoor = location.get_node_or_null("Entities/Vendors/BankDoor")
	var director = location.get_node_or_null("Entities/InteractionDirector")
	var bankPlayer = location.get_node_or_null("Entities/Actors/PlayerActor")
	if bankDoor == null or director == null or bankPlayer == null:
		_check(false, "the bank door and director are available")
		return
	var bankReturn: Vector2 = bankDoor.returnPosition()
	bankPlayer.global_position = bankDoor.global_position + Vector2(0, 20)
	await _physicsFrames(6)
	_check(director.getBestTarget() == bankDoor, "the bank door is the closest interaction target")
	director._unhandled_input(_actionEvent("INTERACT"))
	await sceneManager.scene_changed
	var bankRoom = sceneManager.get_current_scene()
	_check(sceneManager.currentSceneKey == "vendor_room" and bankRoom.vendorId == "lazysprings_bank", "the bank room loads its catalog interior")
	var bankRoomPlayer = bankRoom.get_node_or_null("Entities/Actors/PlayerActor")
	var bankActor = bankRoom.get_node_or_null("Room/LazyspringsBank/VendorActor")
	_check(bankRoomPlayer != null and bankActor != null and bankActor.vendorId == "lazysprings_bank", "the bank interior places its vendor actor")
	await _checkSpawnOutsideActivation(bankRoomPlayer, bankRoom.get_node("VendorExit"), "the bank room spawn stays outside the exit activation shape")
	bankRoomPlayer.global_position = Vector2(0, 40)
	await _physicsFrames(6)
	director = bankRoom.get_node_or_null("LocationInteractionDirector")
	director._unhandled_input(_actionEvent("INTERACT"))
	await sceneManager.scene_changed
	var returnedBank = sceneManager.get_current_scene()
	var returnedBankPlayer = returnedBank.get_node_or_null("Entities/Actors/PlayerActor")
	var returnedBankDoor = returnedBank.get_node_or_null("Entities/Vendors/BankDoor")
	_check(returnedBankPlayer != null and returnedBankPlayer.global_position.distance_to(bankReturn) < 0.001, "the bank room returns the player to its doorway")
	_checkSpawnOnMarker(returnedBankPlayer, returnedBankDoor, "the bank return spawn is centred under the door icon")


func _testSafeFailures() -> void:
	print("\n--- Safe failure paths ---")
	sceneManager.currentSceneKey = "pregenerated_location"
	var currentScene = sceneManager.get_current_scene()
	_check(!sceneManager.enterVendorRoom("missing_vendor", Vector2.ZERO), "unknown vendor is rejected")
	_check(!sceneManager.transitioning and sceneManager.get_current_scene() == currentScene, "rejected vendor does not transition")
	_check(!sceneManager.exitVendorRoom(), "exit without a captured return context is rejected")

	var vendors = get_node_or_null("/root/Vendors")
	var savedVendors = vendors.catalog.vendors.duplicate(true)
	vendors.catalog.vendors["broken_room"] = {
		"vendorId": "broken_room", "kind": "general", "displayName": "Broken",
		"parentLocationId": "Lazysprings", "zoneId": "canyon",
		"roomScene": "res://Location/Vendors/Interiors/DoesNotExist.tscn",
		"stock": { "mode": "fixed", "offers": [] },
	}
	_check(!sceneManager.enterVendorRoom("broken_room", Vector2.ZERO), "missing room scene is rejected before transition")
	_check(!sceneManager.transitioning and sceneManager.get_current_scene() == currentScene, "missing room does not disturb the current scene")
	vendors.catalog.vendors = savedVendors

	sceneManager.currentSceneKey = "vendor_room"
	_check(!sceneManager.enterVendorRoom("lazysprings_general", Vector2.ZERO), "nested vendor-room entry is rejected")
	sceneManager.currentSceneKey = "overworld"
	_check(!sceneManager.enterVendorRoom("lazysprings_general", Vector2.ZERO), "Overworld cannot enter a vendor room")

	# A direct scene run never receives initScene(), so the room shell must
	# report the unsupported navigation instead of showing a dead room.
	var directRoom = preload("res://Location/Vendors/VendorRoom.tscn").instantiate()
	add_child(directRoom)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(!directRoom.roomReady and directRoom.loadError != "" and directRoom.fallbackLabel.visible, "a direct vendor-room run reports unsupported navigation")
	directRoom.queue_free()
	await get_tree().process_frame


## Asserts a spawn sits on the entrance marker itself, under the floating icon.
func _checkSpawnOnMarker(player: Node2D, target: Node2D, message: String) -> void:
	var offset := Vector2(INF, INF)
	if player != null and target != null:
		offset = player.global_position - target.global_position
	_check(offset.length() <= ENTRANCE_TOLERANCE, message)


## Asserts a spawn is outside the target's activation shape, so a spawn there
## cannot immediately re-offer that interaction.
func _checkSpawnOutsideActivation(player: Node2D, target: Area2D, message: String) -> void:
	await _physicsFrames(2)
	_check(player != null and target != null and !target.playerNearby, message)


func _physicsFrames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _makeTarget(host: Node2D, position: Vector2, prompt: String) -> Area2D:
	var target := Area2D.new()
	target.set_script(InteractableScript)
	target.collision_layer = 0
	target.collision_mask = 2
	target.monitoring = true
	target.interactionPrompt = prompt
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	target.add_child(shape)
	host.add_child(target)
	target.position = position
	return target


func _actionEvent(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _cleanup() -> void:
	get_tree().paused = false
	Locations.currentQuest = "Pistoleros Regroup"
	Locations.currentLocation = "Clearwater Grove"
	if is_instance_valid(sceneManager):
		sceneManager.queue_free()
	var music = get_node_or_null("/root/MusicPlayer")
	if music != null and music.has_method("shutdown"):
		music.shutdown()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
