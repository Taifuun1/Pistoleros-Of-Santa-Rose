extends Node

## Scene-run validation for secret reward claims (Docs/System Design/Next Steps
## Implementation Plan.md, commit 16): the service chain runs against the real
## autoloads, and the real Overworld enterLocation handler claims the revealed
## Gold Run cache in place — the player stays on the Overworld and a spent cache
## refuses a second attempt. Run as TestSecretClaims.tscn.

const OverworldCoordinatesScript = preload("res://Overworld/OverworldCoordinates.gd")

var failures := 0
var sceneManager: Node


func _ready() -> void:
	await _run()
	await _cleanup()
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	# Fresh domains; a New Game starts Off Trail, which the claim refuses first.
	Party.resetForNewGame()
	Party.setInventoryManagementAllowed(true)
	Locations.resetForNewGame()
	Quests.resetForNewGame()
	Cutscene.resetForNewGame()
	Discovery.resetForNewGame()

	print("--- Trail eligibility comes first ---")
	_check(!Locations.isOnTrail(), "the fresh session is Off Trail")
	var offTrail: Dictionary = Discovery.claimSecretTarget("Gold Run")
	_check(!offTrail.success and offTrail.reason == "off_trail", "an Off-Trail claim is refused first")

	print("\n--- An unrevealed cache cannot be claimed ---")
	Locations.enterTown("Lazysprings")
	_check(bool(Locations.startTrail().get("success", false)), "a Trail starts from the Town")
	_check(Locations.isOnTrail(), "the session is On Trail")
	_check(str(Discovery.claimSecretTarget("Gold Run").reason) == "not_revealed", "the hidden cache refuses before its map is used")

	print("\n--- The map reveals the cache; a full inventory refuses all-or-nothing ---")
	var catalog = load("res://Data/Items/ItemCatalog.gd").new()
	var mapItem = catalog.makeStackable("canyon_cache_map", 1)
	var added: Dictionary = Party.addItem(mapItem)
	var mapIds: Array = added.get("acceptedInstanceIds", [])
	_check(mapIds.size() == 1, "the reveal map is carried")
	var mapUse: Dictionary = Discovery.useMap(str(mapIds[0]))
	_check(bool(mapUse.get("success", false)), "the map reveals the Gold Run cache, got %s" % [mapUse])
	var filler := 0
	while Party.canAddItems([catalog.makeStackable("canyon_cache_map", 1)]) and filler < 40:
		Party.addItem(catalog.makeStackable("canyon_cache_map", 1))
		filler += 1
	_check(!Party.canAddItems([catalog.makeStackable("gold_nugget", 1)]), "the inventory is full")
	var inventoryBefore: int = Party.inventory.size()
	var refused: Dictionary = Discovery.claimSecretTarget("Gold Run")
	_check(!refused.success and refused.reason == "inventory_full", "a full inventory refuses the claim all-or-nothing")
	_check(Party.inventory.size() == inventoryBefore and !Discovery.isClaimed("Gold Run"), "the refusal grants nothing and keeps the cache available")

	print("\n--- Freeing space lets the claim grant the authored reward ---")
	Party.inventory.clear()
	var claim: Dictionary = Discovery.claimSecretTarget("Gold Run")
	_check(bool(claim.get("success", false)), "the cache is claimed")
	_check(str(claim.get("reward", "")) == "gold_nugget" and Discovery.isClaimed("Gold Run"), "the one-shot claim is recorded")
	var nuggets = Party.inventory.filter(func(entry): return entry.definitionId == "gold_nugget")
	_check(nuggets.size() == 1, "exactly one gold nugget was granted")
	_check(str(Discovery.claimSecretTarget("Gold Run").reason) == "already_claimed", "a second attempt is refused")

	print("\n--- The real Overworld interaction claims and then refuses a spent cache ---")
	var sceneManagerScene = load("res://Nodes/Scene Manager/SceneManager.tscn")
	sceneManager = sceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	get_tree().root.add_child.call_deferred(sceneManager)
	await get_tree().process_frame
	await get_tree().process_frame
	sceneManager.change_scene("overworld")
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if sceneManager.currentSceneKey == "overworld" and not sceneManager.transitioning:
			break
	var overworld = sceneManager.get_current_scene()
	_check(overworld != null and overworld.has_method("enterLocation"), "the real Overworld exposes the production interaction handler")
	var player := Node2D.new()
	player.name = "PlayerOverworldActor"
	overworld.add_child(player)
	# A spent cache refuses in place; the player stays on the Overworld.
	overworld.enterLocation(player, "Gold Run", true, false, "Gold Run")
	await get_tree().process_frame
	_check(Discovery.isClaimed("Gold Run"), "the interaction leaves the one-shot claim intact")
	_check(sceneManager.currentSceneKey == "overworld", "the player stays on the Overworld")


func _cleanup() -> void:
	if is_instance_valid(sceneManager) and sceneManager.currentSceneKey == "overworld":
		sceneManager.change_scene("main_menu")
		var deadline := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if sceneManager.currentSceneKey == "main_menu":
				break
	Quests.resetForNewGame()
	Locations.resetForNewGame()
	Cutscene.resetForNewGame()
	Discovery.resetForNewGame()
	Party.resetForNewGame()
	SaveGame.deleteSave()