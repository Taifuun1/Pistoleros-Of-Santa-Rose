extends Node

## Local QA helper for the Trail/encounter vertical slice.
##
## Register temporarily as the `VerticalSliceQA` autoload and run the normal
## game. Do not register this singleton for a release build.
##
## F8: print authoritative state
## Ctrl+Shift+E: force the authored Canyon event
## Ctrl+Shift+G: debug-launch CanyonRats through the real SceneManager
## Ctrl+Shift+T: start a Trail from a Town
## Ctrl+Shift+I: fill carried inventory to capacity
## Ctrl+Shift+Backspace: drop all carried stacks and clear belt reservations
## Ctrl+Shift+M: return to the main menu without restarting the process

const CANYON_EVENT := "Canyon Cache Raiders"
const CANYON_RATS := "res://Data/Shootout/Encounters/CanyonRats.gd"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _shortcut_input(event: InputEvent) -> void:
	if !OS.is_debug_build():
		return
	if !(event is InputEventKey) or !event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_O:
		print_state()
		get_viewport().set_input_as_handled()
		return
	if !event.ctrl_pressed or !event.shift_pressed:
		return
	match key:
		KEY_E:
			force_canyon_event()
		KEY_G:
			launch_debug_canyon()
		KEY_T:
			start_trail_from_town()
		KEY_I:
			fill_inventory()
		KEY_BACKSPACE:
			clear_inventory()
		KEY_M:
			return_to_main_menu()
		_:
			return
	get_viewport().set_input_as_handled()


func print_state() -> void:
	var locations = _singleton("Locations")
	var party = _singleton("Party")
	var events = _singleton("OverworldEvents")
	var music = _singleton("MusicPlayer")
	var overworld = _singleton("Overworld")
	var discovery = _singleton("Discovery")
	var vendors = _singleton("Vendors")
	var shootoutGlobals = _singleton("Shootout")
	var manager := get_tree().root.get_node_or_null("SceneManager")
	var origin := {}
	var pendingShootout := false
	if manager != null:
		origin = manager.get("_shootoutContext").get("origin", {})
		pendingShootout = bool(manager.call("hasPendingShootout"))
		if manager.has_method("get_current_scene"):
			var scene = manager.call("get_current_scene")
			if scene != null and scene.get("encounterName") != null:
				print("[VerticalSliceQA] shootout=", scene.get("encounterName"), " zone=", scene.get("encounterZoneId"), " lootEnabled=", scene.get("encounterLootEnabled"), " consumed=", scene.get("consumedBeltItems"))
	print("[VerticalSliceQA] locations=", locations.exportState(), " townContext=", locations.isCurrentLocationTown())
	print("[VerticalSliceQA] party money=", party.money, " inventory=", party.inventory)
	print("[VerticalSliceQA] belt=", party.getBeltSnapshot("Walker Langley"))
	print("[VerticalSliceQA] events active=", events.event_active, " distance=", events.distance_since_last_event)
	print("[VerticalSliceQA] music track=", music.currentTrackId, " zone=", music.currentZone, " stack=", music.musicStack)
	print("[VerticalSliceQA] overworld position=", overworld.getOverworldMapPosition())
	print("[VerticalSliceQA] discovery=", discovery.exportState(), " vendors=", vendors.exportState())
	print("[VerticalSliceQA] pendingRequest=", shootoutGlobals.get("pendingRequest"))
	print("[VerticalSliceQA] pendingShootout=", pendingShootout, " origin=", origin)


func force_canyon_event() -> void:
	var events = _singleton("OverworldEvents")
	var pool: Dictionary = events.call("get_event_pool_for_zone", "canyon")
	if !pool.has(CANYON_EVENT):
		push_warning("VerticalSliceQA: the Canyon event is not present in the Zone pool.")
		return
	events.distance_since_last_event = 0.0
	events.event_active = true
	events.event_triggered.emit(CANYON_EVENT, pool[CANYON_EVENT])


func launch_debug_canyon() -> void:
	var manager := get_tree().root.get_node_or_null("SceneManager")
	if manager == null or !manager.has_method("launchShootout"):
		push_warning("VerticalSliceQA: SceneManager is unavailable.")
		return
	var launched: bool = manager.call("launchShootout", {
		"encounterPath": CANYON_RATS,
		"zoneId": "canyon",
		"source": "debug",
		"sourceId": "vertical-slice-qa",
		"progression": { "band": "early" },
	})
	if !launched:
		push_warning("VerticalSliceQA: SceneManager rejected the debug Canyon launch.")


func start_trail_from_town() -> void:
	var locations = _singleton("Locations")
	var helper = _singleton("HelperFunctions")
	var result: Dictionary = locations.call("startTrail")
	if bool(result.get("success", false)):
		helper.call("changeScene", "overworld")
	else:
		push_warning("VerticalSliceQA: Trail start rejected (%s)." % str(result.get("reason", "unknown")))


func fill_inventory() -> void:
	var party = _singleton("Party")
	var generator = _singleton("ItemGeneration")
	var snapshotForCapacity: Dictionary = party.call("getInventorySnapshot")
	var capacity := int(snapshotForCapacity.get("capacity", 24))
	var allowed := bool(party.inventoryManagementAllowed)
	party.call("setInventoryManagementAllowed", true)
	var guard := 0
	while party.inventory.size() < capacity and guard < 100:
		var item: Dictionary = generator.call("generateItem", {
			"itemType": "equipment",
			"rarity": "common",
			"zone": "anywhere",
		})
		if item.is_empty():
			break
		var result: Dictionary = party.call("addItems", [item])
		if !bool(result.get("success", false)) or (result.get("accepted", []) as Array).is_empty():
			push_warning("VerticalSliceQA: inventory fill stopped at %s." % str(result.get("reason", "no_acceptance")))
			break
		guard += 1
	party.call("setInventoryManagementAllowed", allowed)


func clear_inventory() -> void:
	var party = _singleton("Party")
	var snapshot: Dictionary = party.call("getInventorySnapshot")
	var allowed := bool(party.inventoryManagementAllowed)
	party.call("setInventoryManagementAllowed", true)
	for memberValue in snapshot.get("members", []):
		if !(memberValue is Dictionary):
			continue
		var memberKey := str(memberValue.get("key", ""))
		for entryValue in memberValue.get("belt", {}).get("entries", []):
			if entryValue is Dictionary:
				party.call("unreserveBeltItem", memberKey, str(entryValue.get("instanceId", "")))
	for itemValue in snapshot.get("items", []):
		if itemValue is Dictionary:
			party.call("dropItem", str(itemValue.get("instanceId", "")), int(itemValue.get("quantity", 0)))
	party.call("setInventoryManagementAllowed", allowed)


func return_to_main_menu() -> void:
	var manager := get_tree().root.get_node_or_null("SceneManager")
	if manager == null or !manager.has_method("change_scene"):
		push_warning("VerticalSliceQA: SceneManager is unavailable; cannot return to the main menu.")
		return
	manager.call("change_scene", "main_menu")


func _singleton(singletonName: String) -> Node:
	return get_tree().root.get_node_or_null(singletonName)
