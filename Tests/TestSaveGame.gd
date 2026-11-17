extends SceneTree

## Headless validation for the disk save service (Docs/System Design/First Steps
## Implementation Plan.md, save-service commit; System Coherence.md §8). Covers
## payload assembly, the schema/cross-reference audit, validate-before-commit
## rollback, format migration and atomic replacement.
## Run with: godot --headless --script res://Tests/TestSaveGame.gd

const SaveGameScript = preload("res://Globals/SaveGame.gd")
const PartyScript = preload("res://Globals/Party.gd")
const QuestsScript = preload("res://Globals/Quests.gd")
const CutsceneScript = preload("res://Globals/Cutscene.gd")
const LocationsScript = preload("res://Globals/Locations.gd")
const VendorsScript = preload("res://Globals/Vendors.gd")
const DiscoveryScript = preload("res://Globals/Discovery.gd")
const OverworldScript = preload("res://Globals/Overworld.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")
const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")

const QUEST_ID := "pistoleros_regroup"
const QUEST_CATALOG_PATH := "res://Data/Quests/QuestCatalog.tres"
const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"
const ROOM_SCENE := "res://UI/Journal/Journal.tscn"
const SAVE_PATH := "user://savegame_service_test.json"
const PLAYER_POSITION := Vector2(1200.5, 2400.25)

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	testPayloadAssembly()
	testRoundTrip()
	testMalformedRollback()
	testMigration()
	testAtomicReplacementAndDelete()
	testSaveSlots()

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures)
	quit(failures)


func testPayloadAssembly() -> void:
	print("--- Payload assembly and schema audit ---")
	var context := _makeContext()
	var payload: Dictionary = context.saveGame.exportPayload()
	_check(context.saveGame.validatePayload(payload).success, "a clean session exports a valid payload")
	var expectedKeys := ["cutscene", "discovery", "formatVersion", "locations", "overworld", "party", "quests", "savedAt", "vendors"]
	var actualKeys: Array = payload.keys()
	actualKeys.sort()
	_check(actualKeys == expectedKeys, "the payload carries exactly the domain and metadata keys, got %s" % str(actualKeys))

	var withTransient := payload.duplicate(true)
	withTransient["shootout"] = { "origin": "Lazysprings" }
	_check(context.saveGame.validatePayload(withTransient).reason == "invalid_state", "transient scene context in the payload is rejected")

	var withVector := payload.duplicate(true)
	withVector.overworld.position = Vector2(1, 2)
	_check(context.saveGame.validatePayload(withVector).reason == "invalid_state", "engine types (Vector2) are rejected as not JSON-safe")

	var futureVersion := payload.duplicate(true)
	futureVersion.formatVersion = context.saveGame.SAVE_FORMAT_VERSION + 1
	_check(context.saveGame.validatePayload(futureVersion).reason == "invalid_state", "validatePayload only accepts the current format version")

	var missingDomain := payload.duplicate(true)
	missingDomain.erase("quests")
	_check(context.saveGame.validatePayload(missingDomain).reason == "invalid_state", "a missing required domain is rejected")

	var duplicateIds := payload.duplicate(true)
	duplicateIds.party.inventory.append(duplicateIds.party.inventory[0].duplicate(true))
	_check(context.saveGame.validatePayload(duplicateIds).reason == "invalid_state", "duplicate carried instance ids are rejected")

	var overReserved := payload.duplicate(true)
	overReserved.party.members["Walker Langley"].beltReservations[0].quantity = 99
	_check(context.saveGame.validatePayload(overReserved).reason == "invalid_state", "a belt reservation larger than its stack is rejected")

	var orphanReservation := payload.duplicate(true)
	orphanReservation.party.members["Walker Langley"].beltReservations[0].instanceId = "not_carried"
	_check(context.saveGame.validatePayload(orphanReservation).reason == "invalid_state", "a reservation on an uncarried stack is rejected")

	var bankClash := payload.duplicate(true)
	bankClash.vendors.bank = [payload.party.inventory[0].duplicate(true)]
	_check(context.saveGame.validatePayload(bankClash).reason == "invalid_state", "a Bank entry that duplicates a carried id is rejected")

	var staleCycle := payload.duplicate(true)
	staleCycle.vendors.activeDepartureId = int(staleCycle.locations.trailDepartureId) + 1
	_check(context.saveGame.validatePayload(staleCycle).reason == "invalid_state", "a vendor cycle that disagrees with the Trail departure is rejected")

	var staleStock := payload.duplicate(true)
	staleStock.vendors.stock = { "test_gunsmith": { "departureId": 9, "stockSeed": 1, "offers": [] } }
	_check(context.saveGame.validatePayload(staleStock).reason == "invalid_state", "rolled stock from another departure cycle is rejected")

	var unknownRarity := payload.duplicate(true)
	unknownRarity.quests.currentMainQuestLevel = { "level": 2, "rarity": "mythic" }
	_check(context.saveGame.validatePayload(unknownRarity).reason == "invalid_state", "an unknown progression rarity is rejected")

	var duplicateMoves := payload.duplicate(true)
	duplicateMoves.party.members["Walker Langley"].moves = ["Sharp Shot", "Sharp Shot"]
	_check(context.saveGame.validatePayload(duplicateMoves).reason == "invalid_state", "a duplicate selected Move is rejected")

	var oversizedMoves := payload.duplicate(true)
	oversizedMoves.party.members["Walker Langley"].moves = ["Sharp Shot", "Hold Steady", "Duck Down", "Scratch", "Sharp Shot"]
	_check(context.saveGame.validatePayload(oversizedMoves).reason == "invalid_state", "a selected Move list beyond the cap is rejected")

	_check(payload.party.members["Walker Langley"].moves == ["Sharp Shot", "Hold Steady"], "the payload records the member's selected Move loadout")

	_release(context)


func testRoundTrip() -> void:
	print("")
	print("--- Save, mutate and restore a full session ---")
	var context := _makeContext()
	_dirtySession(context)
	_check(context.saveGame.save().success, "a dirty session saves without errors")
	_check(FileAccess.file_exists(SAVE_PATH), "save() writes the payload to the injected path")
	_check(context.saveGame.hasValidSave(), "the written save reads back as valid")
	_check(!FileAccess.file_exists(SAVE_PATH + ".tmp") and !FileAccess.file_exists(SAVE_PATH + ".bak"), "a completed save leaves no temp or backup file")
	var savedCapture := _capture(context)
	_check((savedCapture.party.members["Walker Langley"].moves as Array).size() == 3, "the saved session carries the activated class grant")
	var savedPayload: Dictionary = context.saveGame.exportPayload()
	var skipped: Dictionary = context.saveGame.save()
	_check(bool(skipped.get("skipped", false)), "an unchanged session is not rewritten")

	_resetToNewGame(context)
	context.party.money = 42
	_check(_capture(context) != savedCapture, "the session is dirty before the restore")

	var restored: Dictionary = context.saveGame.loadSave()
	_check(restored.success, "the stored payload restores: %s" % str(restored))
	_check(int(restored.get("migratedFrom", -1)) == context.saveGame.SAVE_FORMAT_VERSION, "a current-format file reports no migration")
	_check(_capture(context) == savedCapture, "every saved domain value survives the restart-shaped round trip")
	_check(JSON.stringify(_withoutSavedAt(context.saveGame.exportPayload())) == JSON.stringify(_withoutSavedAt(savedPayload)), "export/import/export is byte-stable")
	_release(context)


func testMalformedRollback() -> void:
	print("")
	print("--- Malformed files and rejected domains preserve the session ---")
	var context := _makeContext()
	_check(context.saveGame.save().success, "the baseline session saves")
	_resetToNewGame(context)
	_dirtySession(context)
	var baseline := _capture(context)

	_writeRaw("{ this is not json")
	_check(!context.saveGame.hasValidSave(), "a malformed file reports no valid save")
	_check(context.saveGame.loadSave().reason == "malformed_save", "a malformed file fails with a stable reason")
	_check(_capture(context) == baseline, "a malformed file leaves the session untouched")

	_writeRaw(JSON.stringify({ "formatVersion": context.saveGame.SAVE_FORMAT_VERSION + 1, "party": {} }))
	_check(context.saveGame.readPayload().reason == "unsupported_version", "a newer format version is refused")

	var payload: Dictionary = context.saveGame.exportPayload()
	var sentinel := payload.duplicate(true)
	sentinel.discovery.revealedIds = ["Missing Target"]
	_writeRaw(JSON.stringify(sentinel))
	_check(context.saveGame.loadSave().reason == "invalid_state", "a payload with an unknown reveal id is refused")
	_check(_capture(context) == baseline, "a refused payload never mutates the session")

	# Content drift: the file is schema-valid but an item definition no longer
	# resolves, so the first domain commit rejects it.
	var drifted := payload.duplicate(true)
	drifted.party.inventory.append({ "instanceId": "legacy_item", "definitionId": "retired_relic", "itemType": "consumable", "quantity": 1 })
	var driftedResult: Dictionary = context.saveGame.commitPayload(drifted)
	_check(!driftedResult.success and driftedResult.reason == "invalid_item", "content drift is rejected by the domain importer: %s" % str(driftedResult))
	_check(_capture(context) == baseline, "content drift leaves the session untouched")

	# A later domain rejects its payload after Party committed: the commit is
	# rolled back instead of half-applied.
	var badQuests := payload.duplicate(true)
	badQuests.quests.states[QUEST_ID].current_objective_id = "not_an_objective"
	var badQuestsResult: Dictionary = context.saveGame.commitPayload(badQuests)
	_check(!badQuestsResult.success and badQuestsResult.reason == "invalid_state", "an inconsistent objective chain is rejected")
	_check(_capture(context) == baseline, "a rejected quest payload rolls the committed domains back")

	var badBank := payload.duplicate(true)
	badBank.vendors.bank = [{ "instanceId": "bank_relic", "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 }]
	var badBankResult: Dictionary = context.saveGame.commitPayload(badBank)
	_check(!badBankResult.success and badBankResult.reason == "invalid_state", "an invalid Bank entry is rejected by the vendor importer")
	_check(_capture(context) == baseline, "a rejected vendor payload rolls the committed domains back")

	_writeRaw(JSON.stringify(payload))
	_check(context.saveGame.loadSave().success, "the intact session restores after the rejection cases")
	_release(context)


func testMigration() -> void:
	print("")
	print("--- Legacy payload migration ---")
	var context := _makeContext()
	_writeRaw(JSON.stringify(_legacyPayload()))
	var result: Dictionary = context.saveGame.loadSave()
	_check(result.success, "the legacy vendor-audit payload migrates: %s" % str(result))
	_check(int(result.get("migratedFrom", -1)) == context.saveGame.LEGACY_FORMAT_VERSION, "the load reports the source format version")
	_check(context.party.money == 777, "the migrated Party money is restored")
	_check(context.party.inventory.size() == 2, "the migrated carried stacks are restored")
	_check(int(context.party.inventory[0].quantity) == 2, "the migrated stacks keep their quantities")
	_check(int(context.party.exportState().nextInstanceNumber) == 6, "the instance-id counter is raised past every carried id")
	_check(int(context.locations.trailDepartureId) == 2, "the migrated departure cycle is restored")
	_check(!context.locations.isOnTrail(), "a legacy payload cannot restore an active Trail")
	_check(context.locations.getLastTownId() == "", "a legacy payload records no last Town")
	_check(int(context.vendors.exportState().baseSeed) == 1234, "the migrated vendor seed is restored")
	_check(context.discovery.exportState().revealedIds.is_empty(), "a legacy payload without reveals restores none")
	_check(context.overworld.spawnChunk == OverworldScript.DEFAULT_SPAWN_CHUNK and context.overworld.spawnTile == OverworldScript.DEFAULT_SPAWN_TILE, "a legacy payload keeps the default Overworld entry anchor")
	var belt: Dictionary = context.party.getBeltSnapshot("Walker Langley")
	_check(belt.entries.size() == 1 and belt.entries[0].instanceId == "starter_paregoric", "the starter reservation is reconciled onto a carried stack")

	var emptyInventoryLegacy := _legacyPayload()
	emptyInventoryLegacy.party.inventory = []
	_writeRaw(JSON.stringify(emptyInventoryLegacy))
	_check(context.saveGame.loadSave().success, "a legacy payload with no carried stacks still loads")
	var emptyBelt: Dictionary = context.party.getBeltSnapshot("Walker Langley")
	_check(emptyBelt.entries.is_empty(), "a reservation with no carried stack is dropped by the migration")

	var unresolvable := _legacyPayload()
	unresolvable.vendors.bank = [{ "instanceId": "old_relic", "definitionId": "retired_relic", "itemType": "weapon" }]
	_writeRaw(JSON.stringify(unresolvable))
	_resetToNewGame(context)
	_dirtySession(context)
	var before := _capture(context)
	var refused: Dictionary = context.saveGame.loadSave()
	_check(!refused.success, "a legacy payload with unresolvable content ids is refused: %s" % str(refused))
	_check(_capture(context) == before, "a refused legacy payload leaves the session untouched")

	print("")
	print("--- Pre-loadout payload migration ---")
	_dirtySession(context)
	var stored: Dictionary = context.saveGame.exportPayload()
	stored.formatVersion = 2
	stored.party.formatVersion = 1
	for memberValue in stored.party.members.values():
		memberValue.erase("moves")
	_writeRaw(JSON.stringify(stored))
	_check(!context.saveGame.validatePayload(stored).success, "a pre-loadout payload is not a current payload")
	_resetToNewGame(context)
	var migrated: Dictionary = context.saveGame.loadSave()
	_check(migrated.success, "a pre-loadout payload migrates: %s" % str(migrated))
	_check(int(migrated.get("migratedFrom", -1)) == 2, "the load reports the pre-loadout source version")
	_check(context.party.party["Walker Langley"].moves == ["Sharp Shot", "Hold Steady"], "the migrated loadout defaults to the canonical selection")
	_check(context.party.getMoveLoadoutSnapshot("Walker Langley").active == ["Sharp Shot", "Hold Steady"], "the migrated selection resolves through the loadout projection")
	_check(int(context.saveGame.readPayload().payload.party.formatVersion) == context.party.STATE_FORMAT_VERSION, "the migrated Party payload carries the current domain version")
	_release(context)


func testAtomicReplacementAndDelete() -> void:
	print("")
	print("--- Atomic replacement and delete ---")
	var context := _makeContext()
	_check(context.saveGame.save().success, "the first save writes the file")
	var firstText := _readRaw()
	_dirtySession(context)
	_check(context.saveGame.save().success, "a second save replaces the file")
	_check(_readRaw() != firstText, "the replacement holds the newer payload")
	_check(!FileAccess.file_exists(SAVE_PATH + ".tmp") and !FileAccess.file_exists(SAVE_PATH + ".bak"), "the replacement cleans up its temp and backup files")

	# A crash between the backup rename and the replacement leaves only the
	# backup; the service recovers from it instead of reporting no save.
	DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	_check(!context.saveGame.readPayload(false).success, "the main file is gone before the recovery check")
	_check(context.saveGame.hasValidSave(), "a leftover backup counts as a valid save")
	_check(context.saveGame.loadSave().success, "the leftover backup restores")
	DirAccess.remove_absolute(SAVE_PATH + ".bak")

	_check(context.saveGame.save().success, "a new save writes the file again")
	_check(context.saveGame.deleteSave(), "deleteSave removes the save")
	_check(!FileAccess.file_exists(SAVE_PATH) and !context.saveGame.hasValidSave(), "a deleted save reports no valid save")
	_check(!context.saveGame.deleteSave(), "deleting a missing save is a no-op")
	_release(context)


## Save slots (commit 14): slot files under user://saves with an active-slot
## index; the payload schema is untouched. The slot directory is wiped before
## and after so the shared user:// directory stays clean.
func testSaveSlots() -> void:
	print("")
	print("--- Save slots ---")
	_wipeSlots()
	var context := _makeContext()
	var saveGame = context.saveGame
	_check(saveGame.listSlots().is_empty(), "no slots exist before the first save")
	_check(!saveGame.hasValidSave(), "an empty slot store reports no valid save")

	var created: Dictionary = saveGame.createSlot()
	_check(bool(created.get("success", false)) and str(created.get("activeSlot", "")) == "slot1", "createSlot picks the first free id")
	_check(saveGame.getActivePath().ends_with("saves/slot1.json"), "the active path points into the slot directory")
	_check(saveGame.listSlots().is_empty(), "a created slot appears in listings only after its first save")
	_check(!saveGame.hasValidSave(), "a fresh slot has no valid save yet")
	_check(bool(saveGame.save().get("success", false)), "a checkpoint save writes into the active slot")
	_check(FileAccess.file_exists("user://saves/slot1.json"), "the slot file exists under user://saves")
	var slots: Array = saveGame.listSlots()
	_check(slots.size() == 1 and str(slots[0].id) == "slot1" and bool(slots[0].valid), "the saved slot lists as valid, got %s" % [slots])
	var moneyA: int = context.party.money

	_check(bool(saveGame.createSlot("run B").get("success", false)), "an explicit id with a space is honored")
	_check(saveGame.getActivePath().ends_with("run B.json"), "the explicit slot becomes the active path")
	_dirtySession(context)
	_check(bool(saveGame.save().get("success", false)), "the second slot saves independently")
	slots = saveGame.listSlots()
	_check(slots.size() == 2, "both slots list, got %d" % slots.size())

	_check(str(saveGame.selectSlot("missing_slot").get("reason", "")) == "unknown_slot", "selecting an unknown slot fails closed")
	_check(saveGame.getActivePath().ends_with("run B.json"), "a failed selection keeps the active slot")
	_check(bool(saveGame.selectSlot("slot1").get("success", false)), "selecting slot1 succeeds")
	_check(bool(saveGame.loadSave().get("success", false)), "the selected slot restores")
	_check(context.party.money == moneyA, "the restore matches slot1's session, not slot2's")

	_check(str(saveGame.createSlot("../evil").get("reason", "")) == "invalid_slot_id", "path traversal ids are rejected")
	_check(str(saveGame.createSlot("slot1").get("reason", "")) == "slot_exists", "creating over an existing slot file is rejected")

	var deleted: Dictionary = saveGame.deleteSlot("run B")
	_check(bool(deleted.get("success", false)) and !FileAccess.file_exists("user://saves/run B.json"), "deleting a slot removes its file")
	_check(saveGame.getActivePath().ends_with("slot1.json"), "deleting a non-active slot keeps the selection")
	deleted = saveGame.deleteSlot("slot1")
	_check(bool(deleted.get("success", false)) and str(saveGame.activeSlot) == "", "deleting the active slot clears the selection")
	_check(!saveGame.hasValidSave(), "no slot left means no valid save")

	_check(str(saveGame.migrationNotice("unsupported_version")).contains("newer"), "a future-version slot explains itself")
	_check(str(saveGame.migrationNotice("malformed_save")).contains("damaged"), "a damaged slot explains itself")
	_check(saveGame.migrationNotice("no_save").is_empty(), "a missing slot needs no notice")
	_release(context)

	# Legacy import: a pre-slot save is adopted as slot1 on the first listing.
	var legacy := _makeContext()
	_check(bool(legacy.saveGame.save().get("success", false)), "the legacy single-file save is written")
	var importer := _makeContext()
	var imported: Array = importer.saveGame.listSlots()
	_check(imported.size() == 1 and str(imported[0].id) == "slot1" and bool(imported[0].valid), "the legacy save is imported as slot1, got %s" % [imported])
	_check(str(importer.saveGame.activeSlot) == "slot1", "the imported slot becomes active")
	_check(bool(importer.saveGame.loadSave().get("success", false)), "the imported slot restores")
	_release(importer)
	_release(legacy)
	_wipeSlots()
	_check(!FileAccess.file_exists(SAVE_PATH), "the legacy test file is cleaned up")


func _wipeSlots() -> void:
	if !DirAccess.dir_exists_absolute("user://saves"):
		return
	var directory := DirAccess.open("user://saves")
	if directory == null:
		return
	directory.list_dir_begin()
	var fileName := directory.get_next()
	while fileName != "":
		if !directory.current_is_dir():
			DirAccess.remove_absolute("user://saves/" + fileName)
		fileName = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute("user://saves")



## A full save-domain context: real Party/Quests/Cutscene/Locations/Vendors/
## Discovery/Overworld services wired exactly as production does, the production
## reveal data and manifest, a fixture shop catalog and an isolated save path.
func _makeContext() -> Dictionary:
	var itemCatalog = ItemCatalogScript.new()
	var party = PartyScript.new()
	party.configureInventory(itemCatalog, _loadDataFolder("res://Data/Shootout/Classes"))
	party.configureCharacterData(
		_loadDataFolder("res://Data/Shootout/Classes"),
		_loadDataFolder("res://Data/Shootout/Rodeos"),
		_loadDataFolder("res://Data/Shootout/Moves"))
	party.setInventoryManagementAllowed(true)
	var quests = QuestsScript.new()
	quests.loadCatalog(load(QUEST_CATALOG_PATH))
	var cutscene = CutsceneScript.new()
	var locations = LocationsScript.new()
	var coordinates := OverworldCoordinates.makeHeadless()
	var discovery = DiscoveryScript.new()
	discovery.configure(party, SecretMapDataScript.new(), itemCatalog, load(MAP_MANIFEST), coordinates)
	var catalog = VendorCatalogScript.new()
	catalog.vendors = _makeVendors()
	var itemGenerator = ItemGenerationScript.new()
	var vendors = VendorsScript.new()
	vendors.configure(catalog, party, itemGenerator, VendorPricingScript.new(), locations, 4321, discovery, itemCatalog)
	var overworld = OverworldScript.new()
	var saveGame = SaveGameScript.new()
	saveGame.configure({
		"party": party,
		"quests": quests,
		"cutscene": cutscene,
		"locations": locations,
		"vendors": vendors,
		"discovery": discovery,
		"overworld": overworld,
	}, { "savePath": SAVE_PATH })
	return {
		"party": party,
		"quests": quests,
		"cutscene": cutscene,
		"locations": locations,
		"vendors": vendors,
		"discovery": discovery,
		"overworld": overworld,
		"saveGame": saveGame,
		"itemGenerator": itemGenerator,
		"coordinates": coordinates,
	}


## Authored content loader matching Globals/Shootout.loadDataFolder so the
## context resolves the real class/Move grants.
func _loadDataFolder(folderPath: String) -> Dictionary:
	var data := {}
	for fileName in DirAccess.get_files_at(folderPath):
		if !fileName.ends_with(".gd"):
			continue
		var entry = load(folderPath + "/" + fileName).new()
		var entryData = entry.get("data")
		if entryData != null:
			data[str(entryData.name)] = entryData
		if entry is Node:
			entry.free()
	return data


func _makeVendors() -> Dictionary:
	return {
		"test_general": {
			"vendorId": "test_general", "kind": "general", "displayName": "Test General",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "fixed", "offers": [
				{ "offerId": "paregoric", "definitionId": "paregoric", "unitPrice": 20 },
				{ "offerId": "canyon_cache_map", "definitionId": "canyon_cache_map", "unitPrice": 75 },
			] },
		},
		"test_gunsmith": {
			"vendorId": "test_gunsmith", "kind": "gun", "displayName": "Test Gunsmith",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 3 },
		},
		"test_bank": {
			"vendorId": "test_bank", "kind": "bank", "displayName": "Test Bank",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
		},
	}



## A played session: Town purchase, belt reservation, explicit Trail start
## (which rerolls stock), Bank deposit, quest progress, reveal, cutscene flag and
## a walked Overworld position.
func _dirtySession(context: Dictionary) -> void:
	context.party.money = 500
	# One activated class grant: the selected loadout must round-trip and stay
	# resolvable against the real Gunslinger grants.
	context.party.setInventoryManagementAllowed(true)
	var activation: Dictionary = context.party.activateMove("Walker Langley", "Duck Down")
	if !bool(activation.get("success", false)) and str(activation.get("reason", "")) != "already_active":
		push_warning("TestSaveGame: could not activate the class grant: %s" % str(activation))
	var locations = context.locations
	locations.enterTown("Lazysprings")
	locations.startTrail()
	var purchase: Dictionary = context.vendors.buy("test_general", "paregoric", 2)
	if bool(purchase.get("success", false)):
		var stackId := str(context.party.inventory[0].instanceId)
		context.party.reserveBeltItem("Walker Langley", stackId, 1)
	var mapPurchase: Dictionary = context.vendors.buy("test_general", "canyon_cache_map", 1)
	var accepted = mapPurchase.get("acceptedInstanceIds", [])
	if (accepted as Array).size() > 0:
		context.discovery.useMap(str(accepted[0]))
	var weapon = context.itemGenerator.generateWeapon({ "rarity": "common", "family": "revolver" })
	var added: Dictionary = context.party.addItem(weapon)
	var weaponIds = added.get("acceptedInstanceIds", [])
	if (weaponIds as Array).size() > 0:
		context.vendors.deposit(str(weaponIds[0]))
	# The rolled gunsmith stock must exist so the payload carries a real cycle.
	context.vendors.getVendorSnapshot("test_gunsmith")
	context.quests.startQuest(QUEST_ID)
	context.quests.completeCurrentObjective(QUEST_ID, context.quests.getCurrentObjectiveId(QUEST_ID))
	context.cutscene.playedCutscenes["Finch Pond"] = true
	context.cutscene.cutsceneName = "Pine Meadows"
	context.overworld.storeLastKnownPlayerPosition(PLAYER_POSITION)


func _resetToNewGame(context: Dictionary) -> void:
	context.party.resetForNewGame()
	context.quests.resetForNewGame()
	context.locations.resetForNewGame()
	context.cutscene.resetForNewGame()
	context.discovery.resetForNewGame()
	context.overworld.resetForNewGame()
	context.vendors.resetForNewGame(4242)


## The pinned pre-service payload shape (Tests/TestVendorPersistence.gd): Party
## money/inventory, vendor and discovery states and one scalar departure id.
func _legacyPayload() -> Dictionary:
	return {
		"formatVersion": 1,
		"party": {
			"money": 777,
			"inventory": [
				{ "instanceId": "starter_paregoric", "definitionId": "paregoric", "itemType": "consumable", "quantity": 2 },
				{ "instanceId": "item_5", "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 },
			],
		},
		"vendors": {
			"formatVersion": 1,
			"baseSeed": 1234,
			"activeDepartureId": 2,
			"stock": {},
			"bank": [],
		},
		"discovery": { "formatVersion": 1, "revealedIds": [] },
		"trailDepartureId": 2,
	}


func _capture(context: Dictionary) -> Dictionary:
	return {
		"party": context.party.exportState(),
		"quests": context.quests.exportState(),
		"cutscene": context.cutscene.exportState(),
		"locations": context.locations.exportState(),
		"vendors": context.vendors.exportState(),
		"discovery": context.discovery.exportState(),
		"overworld": context.overworld.exportState(),
	}


## Payload comparison helper: the timestamp is the only value a save changes.
func _withoutSavedAt(payload: Dictionary) -> Dictionary:
	var copy: Dictionary = payload.duplicate(true)
	copy.erase("savedAt")
	return copy


func _writeRaw(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _readRaw() -> String:
	return FileAccess.get_file_as_string(SAVE_PATH)


func _release(context: Dictionary) -> void:
	# Free the provider's lazily-created coordinate service first: these test
	# nodes never enter the tree, so their own _exit_tree never runs.
	var overworld = context.get("overworld", null)
	if overworld != null and is_instance_valid(overworld) and overworld._coordinates != null:
		overworld._coordinates.dispose()
		overworld._coordinates = null
	for keyValue in ["party", "quests", "cutscene", "locations", "vendors", "discovery", "overworld", "saveGame", "itemGenerator"]:
		var node = context.get(keyValue, null)
		if node != null and is_instance_valid(node):
			node.free()
	var coordinateService = context.get("coordinates", null)
	if coordinateService != null:
		coordinateService.dispose()
	_removeSaveFiles()


func _removeSaveFiles() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
