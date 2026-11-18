extends Node

## Versioned disk save service (Docs/System Design/First Steps Implementation
## Plan.md, save-service commit; System Coherence.md §8).
##
## One JSON payload assembles every persistent domain snapshot, a schema and
## cross-reference audit runs before any live mutation, and the commit is rolled
## back from captured snapshots when a domain rejects its payload. The file is
## replaced atomically through a temp file plus a one-generation backup, so a
## crash or a rejected load can never lose the previous valid session.
##
## Transient state (live actor nodes, pending encounters, modals, pause/music
## stacks, loaders) is deliberately absent from the schema: the strict key audit
## rejects a payload that carries it.
##
## Saving is only requested at Overworld boundaries (SceneManager checkpoints),
## which is what makes the recorded position exact and Continue's single
## Overworld resume route truthful.

const PartyScript = preload("res://Globals/Party.gd")
const QuestsScript = preload("res://Globals/Quests.gd")
const CutsceneScript = preload("res://Globals/Cutscene.gd")
const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")
const CombatLoadoutProjectorScript = preload("res://Globals/CombatLoadoutProjector.gd")

## Current file/domain format. Version 1 is the pre-service payload the vendor
## persistence audit pinned (Party money/inventory, vendor and discovery states
## and one scalar departure id); version 2 is the coordinated save; version 3
## adds the per-member active Move loadout.
const SAVE_FORMAT_VERSION := 3
const LEGACY_FORMAT_VERSION := 1
## Migration steps by source version. Every step returns the next full payload
## (or an empty Dictionary when the payload cannot be migrated).
const MIGRATION_STEPS := {
	LEGACY_FORMAT_VERSION: "migrateLegacyVendorAudit",
	2: "migrateMoveLoadouts",
}
const DEFAULT_SAVE_PATH := "user://savegame.json"
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"
## Slot storage (commit 14): one JSON file per slot under `SLOT_DIRECTORY` plus
## an index file carrying the active slot id. An empty `activeSlot` keeps the
## legacy single-file behavior (`savePath`) so existing saves and call sites
## are untouched until a slot is created or selected.
const SLOT_DIRECTORY := "user://saves"
const SLOT_INDEX_PATH := "user://saves/index.json"
## Required domain keys; also the commit order. Party commits first because the
## vendor Bank validation reads the restored carried ids.
const COMMIT_ORDER := ["party", "quests", "locations", "cutscene", "vendors", "discovery", "overworld"]
const DOMAIN_NODES := {
	"party": "Party",
	"quests": "Quests",
	"locations": "Locations",
	"cutscene": "Cutscene",
	"vendors": "Vendors",
	"discovery": "Discovery",
	"overworld": "Overworld",
}
## Payload keys allowed next to the domain payloads.
const META_KEYS := ["formatVersion", "savedAt"]

var savePath := DEFAULT_SAVE_PATH

## The selected save slot id, or "" for the legacy single-file path.
var activeSlot := ""

var _injectedDomains := {}
var _lastWrittenJson := ""
var _lastError := ""


## Test/headless seam: injects the domain services and an isolated save path.
## Unknown keys are ignored; missing domains fall back to the production
## autoloads, so a caller only injects what it owns.
func configure(domains: Dictionary = {}, options: Dictionary = {}) -> void:
	_injectedDomains = {}
	for key in domains:
		if domains[key] != null:
			_injectedDomains[str(key)] = domains[key]
	savePath = str(options.get("savePath", savePath))
	activeSlot = str(options.get("activeSlot", ""))
	_lastWrittenJson = ""
	_lastError = ""


func getSavePath() -> String:
	return savePath


## The file the next save/load touches: the active slot when one is selected,
## otherwise the legacy single-file path.
func getActivePath() -> String:
	return _slotPath(activeSlot) if _isValidSlotId(activeSlot) else savePath


## Stable reason of the last failed save/load, or "" when it succeeded.
func getLastError() -> String:
	return _lastError


## True when a readable, migratable and schema-valid save exists. The Main Menu
## uses this to enable Continue; nothing is restored by asking.
func hasValidSave() -> bool:
	return bool(readPayload(true).get("success", false))


## Full export -> audit -> atomic write. The payload is validated first, so an
## un-restorable file is never written.
func save() -> Dictionary:
	var payload := exportPayload()
	if payload.is_empty():
		return _fail("domain_unavailable")
	var check := validatePayload(payload)
	if !bool(check.get("success", false)):
		return _fail(str(check.get("reason", "invalid_state")))
	var json := JSON.stringify(payload, "", true, true)
	if json.is_empty():
		return _fail("invalid_state")
	if json == _lastWrittenJson and FileAccess.file_exists(getActivePath()):
		return { "success": true, "reason": "", "path": getActivePath(), "skipped": true }
	var written := _writeAtomically(json)
	if !bool(written.get("success", false)):
		return written
	_lastWrittenJson = json
	return { "success": true, "reason": "", "path": getActivePath() }


## Read -> migrate -> audit -> commit. A failure at any step leaves the live
## session exactly as it was.
func loadSave() -> Dictionary:
	var read := readPayload(true)
	if !bool(read.get("success", false)):
		_lastError = str(read.get("reason", "invalid_state"))
		return read
	var restored := commitPayload(read.payload)
	if !bool(restored.get("success", false)):
		_lastError = str(restored.get("reason", "invalid_state"))
		return restored
	return {
		"success": true,
		"reason": "",
		"path": getActivePath(),
		"migratedFrom": int(read.get("migratedFrom", SAVE_FORMAT_VERSION)),
	}


## Reads, parses, migrates and audits the file without touching live state.
## Returns { success, reason, payload, migratedFrom }. When the main file is
## missing, a leftover backup from an interrupted replacement is used.
func readPayload(includeBackup := true) -> Dictionary:
	var activePath := getActivePath()
	var read := _readFile(activePath)
	if !bool(read.get("success", false)) and includeBackup and str(read.get("reason", "")) == "no_save":
		var backupPath := activePath + BACKUP_SUFFIX
		if FileAccess.file_exists(backupPath):
			read = _readFile(backupPath)
	return read


## Removes the save and its leftover temp/backup files. New Game does not call
## this: a New Game session is independent of any stored save.
func deleteSave() -> bool:
	var removed := false
	for path in [getActivePath(), getActivePath() + TEMP_SUFFIX, getActivePath() + BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			removed = DirAccess.remove_absolute(path) == OK or removed
	_lastWrittenJson = ""
	return removed


## --- Save slots (commit 14) -------------------------------------------------
##
## Slots are plain payload files under `SLOT_DIRECTORY`; the index file carries
## only the active slot id. No payload schema changes: every slot is a complete
## versioned save validated by the same audit, and an empty `activeSlot` keeps
## the legacy single-file path fully functional.

func _ready() -> void:
	_restoreSlotIndex()


func _isValidSlotId(slotId: String) -> bool:
	if slotId.is_empty() or slotId.length() > 64:
		return false
	# Letters, digits, underscore, dash and space only: no path separators or
	# control characters can reach the filesystem through a slot id.
	for character in slotId:
		var code := character.unicode_at(0)
		var letterOrDigit := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if !letterOrDigit and character != "-" and character != "_" and character != " ":
			return false
	return true


func _slotPath(slotId: String) -> String:
	return SLOT_DIRECTORY + "/" + slotId + ".json"


## One entry per slot file: { id, savedAt, formatVersion, valid, notice }.
## Newest first. The legacy single-file save is imported as "slot1" on the
## first listing so existing players keep their save.
func listSlots() -> Array:
	_ensureLegacyImported()
	var slots := []
	if !DirAccess.dir_exists_absolute(SLOT_DIRECTORY):
		return slots
	var directory := DirAccess.open(SLOT_DIRECTORY)
	if directory == null:
		return slots
	directory.list_dir_begin()
	var fileName := directory.get_next()
	while fileName != "":
		if !directory.current_is_dir() and fileName.ends_with(".json") and fileName != "index.json":
			slots.append(_slotEntry(slotIdFromFileName(fileName)))
		fileName = directory.get_next()
	directory.list_dir_end()
	slots.sort_custom(func(a, b): return int(a.savedAt) > int(b.savedAt))
	return slots


func slotIdFromFileName(fileName: String) -> String:
	return fileName.trim_suffix(".json")


func _slotEntry(slotId: String) -> Dictionary:
	var entry := { "id": slotId, "savedAt": 0, "formatVersion": 0, "valid": false, "notice": "" }
	# _readFile parses, migrates and audits: a successful read is a valid slot
	# (older payloads migrate in memory, never on disk during a listing).
	var read := _readFile(_slotPath(slotId))
	entry.valid = bool(read.get("success", false))
	if entry.valid:
		var payload: Dictionary = read.get("payload", {})
		entry.savedAt = int(payload.get("savedAt", 0))
		entry.formatVersion = int(payload.get("formatVersion", 0))
	else:
		entry.notice = migrationNotice(str(read.get("reason", "invalid_state")))
	return entry


## Makes an existing slot file the save/load target. Unknown ids fail closed.
func selectSlot(slotId: String) -> Dictionary:
	_ensureLegacyImported()
	if !_isValidSlotId(slotId) or !FileAccess.file_exists(_slotPath(slotId)):
		return _fail("unknown_slot")
	activeSlot = slotId
	_lastWrittenJson = ""
	_persistSlotIndex()
	return { "success": true, "reason": "", "activeSlot": activeSlot }


## Selects a fresh slot id without a file; the slot appears in listings only
## after its first checkpoint save. An empty id takes the first free number.
func createSlot(slotId := "") -> Dictionary:
	_ensureLegacyImported()
	var newId := slotId.strip_edges()
	if newId == "":
		var counter := 1
		while FileAccess.file_exists(_slotPath("slot%d" % counter)):
			counter += 1
		newId = "slot%d" % counter
	if !_isValidSlotId(newId):
		return _fail("invalid_slot_id")
	if FileAccess.file_exists(_slotPath(newId)):
		return _fail("slot_exists")
	activeSlot = newId
	_lastWrittenJson = ""
	_persistSlotIndex()
	return { "success": true, "reason": "", "activeSlot": activeSlot }


## Removes a slot file and its temp/backup siblings. Deleting the active slot
## clears the selection (Continue falls back to disabled until another slot is
## chosen); the legacy path is never touched by this.
func deleteSlot(slotId: String) -> Dictionary:
	if !_isValidSlotId(slotId) or !FileAccess.file_exists(_slotPath(slotId)):
		return _fail("unknown_slot")
	var removed := false
	for path in [_slotPath(slotId), _slotPath(slotId) + TEMP_SUFFIX, _slotPath(slotId) + BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			removed = DirAccess.remove_absolute(path) == OK or removed
	if activeSlot == slotId:
		activeSlot = ""
		_lastWrittenJson = ""
		_persistSlotIndex()
	return { "success": removed, "reason": "" if removed else "nothing_removed", "activeSlot": activeSlot }


## Human-readable text for a slot that cannot be loaded, by failure reason.
func migrationNotice(reason: String) -> String:
	match reason:
		"unsupported_version":
			return "This save was written by a newer version of the game."
		"no_save":
			return ""
		_:
			return "This save is damaged and cannot be loaded."


func _restoreSlotIndex() -> void:
	if !FileAccess.file_exists(SLOT_INDEX_PATH):
		return
	var file := FileAccess.open(SLOT_INDEX_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var stored = (parsed as Dictionary).get("activeSlot", "")
		if _isValidSlotId(str(stored)):
			activeSlot = str(stored)


func _persistSlotIndex() -> void:
	if !DirAccess.dir_exists_absolute(SLOT_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY)
	var file := FileAccess.open(SLOT_INDEX_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({ "activeSlot": activeSlot }, "  "))
	file.close()


## One-time import of the pre-slot save so existing players do not lose it.
func _ensureLegacyImported() -> void:
	if activeSlot != "":
		return
	if !DirAccess.dir_exists_absolute(SLOT_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY)
	var directory := DirAccess.open(SLOT_DIRECTORY)
	if directory == null:
		return
	directory.list_dir_begin()
	var fileName := directory.get_next()
	var hasSlots := false
	while fileName != "":
		if !directory.current_is_dir() and fileName.ends_with(".json") and fileName != "index.json":
			hasSlots = true
		fileName = directory.get_next()
	directory.list_dir_end()
	if hasSlots or !FileAccess.file_exists(savePath):
		return
	if DirAccess.copy_absolute(savePath, _slotPath("slot1")) == OK:
		activeSlot = "slot1"
		_persistSlotIndex()


## Assembled payload from every live domain. Metadata keys are added first so
## the serialized key order is stable.
func exportPayload() -> Dictionary:
	var payload := {
		"formatVersion": SAVE_FORMAT_VERSION,
		"savedAt": int(Time.get_unix_time_from_system()),
	}
	for domainKey in COMMIT_ORDER:
		var domain := _domain(domainKey)
		if domain == null or !domain.has_method("exportState"):
			_lastError = "domain_unavailable"
			return {}
		payload[domainKey] = domain.exportState()
	return payload


## Pure audit of a complete payload: required keys and versions, JSON-safe
## values only, and every cross-reference that must resolve together (carried
## ids, belt reservations, Bank, departure/stock cycle, quest progression,
## reveals, cutscene flags and the recorded position). Nothing is mutated here.
func validatePayload(payload) -> Dictionary:
	if !(payload is Dictionary):
		return _fail("invalid_state")
	if int(payload.get("formatVersion", -1)) != SAVE_FORMAT_VERSION:
		return _fail("invalid_state")
	for keyValue in payload:
		var key := str(keyValue)
		if !META_KEYS.has(key) and !COMMIT_ORDER.has(key):
			return _fail("invalid_state")
	for domainKey in COMMIT_ORDER:
		if !(payload.get(domainKey, null) is Dictionary):
			return _fail("invalid_state")
	if typeof(payload.get("savedAt", 0)) != TYPE_INT:
		return _fail("invalid_state")
	var safe := _auditJsonSafe(payload)
	if !bool(safe.get("success", false)):
		return safe

	var partyAudit := _auditParty(payload.party)
	if !bool(partyAudit.get("success", false)):
		return partyAudit
	var vendorAudit := _auditVendors(payload.vendors, partyAudit)
	if !bool(vendorAudit.get("success", false)):
		return vendorAudit
	var questAudit := _auditQuestProgression(payload.quests)
	if !bool(questAudit.get("success", false)):
		return questAudit
	var locationAudit := _auditLocations(payload.locations, payload.vendors)
	if !bool(locationAudit.get("success", false)):
		return locationAudit
	var cutsceneAudit := _auditCutscene(payload.cutscene)
	if !bool(cutsceneAudit.get("success", false)):
		return cutsceneAudit
	var discoveryAudit := _auditDiscovery(payload.discovery)
	if !bool(discoveryAudit.get("success", false)):
		return discoveryAudit
	var overworldAudit := _auditOverworld(payload.overworld)
	if !bool(overworldAudit.get("success", false)):
		return overworldAudit
	return { "success": true, "reason": "" }


## Commits a validated payload in dependency order. Every domain snapshot is
## captured first; if a domain rejects its payload (content drift, a replaced
## catalog entry, a stale reference), the already-committed domains are restored
## from those snapshots, so the previous valid session survives.
func commitPayload(payload) -> Dictionary:
	var check := validatePayload(payload)
	if !bool(check.get("success", false)):
		return check

	var snapshots := {}
	for domainKey in COMMIT_ORDER:
		var domain := _domain(domainKey)
		if domain == null or !domain.has_method("importState"):
			return _fail("domain_unavailable")
		snapshots[domainKey] = domain.exportState()

	var committed: Array[String] = []
	for domainKey in COMMIT_ORDER:
		var result: Dictionary = _domain(domainKey).importState(payload[domainKey])
		if bool(result.get("success", false)):
			committed.append(domainKey)
			continue
		var reason := str(result.get("reason", "invalid_state"))
		if !_rollback(committed, snapshots):
			push_error("SaveGame: failed to roll back after rejecting '%s'." % domainKey)
			return _fail("rollback_failed")
		return _fail(reason)
	_lastError = ""
	return { "success": true, "reason": "" }


## Restores the domains a failed commit already applied, newest first so a
## domain that re-applies a shared value (Vendors writes the departure cycle
## back to Locations) is itself rolled back afterwards.
func _rollback(committed: Array[String], snapshots: Dictionary) -> bool:
	for index in range(committed.size() - 1, -1, -1):
		var domainKey := committed[index]
		var domain := _domain(domainKey)
		var result = domain.importState(snapshots[domainKey])
		if !(result is Dictionary) or !bool(result.get("success", false)):
			return false
	return true


## Carried stacks, equipment and belt reservations must resolve together: unique
## ids, reservations that reference a carried consumable, quantities that fit the
## stack they reserve, and the same member set as the live Party (a payload that
## omitted a member would leave that member's stale state in place).
func _auditParty(partyState: Dictionary) -> Dictionary:
	var inventoryValue = partyState.get("inventory", null)
	if !(inventoryValue is Array):
		return _fail("invalid_state")
	var carried := {}
	for entryValue in inventoryValue:
		if !(entryValue is Dictionary):
			return _fail("invalid_state")
		var instanceId := str((entryValue as Dictionary).get("instanceId", ""))
		var quantity = (entryValue as Dictionary).get("quantity", null)
		if instanceId.is_empty() or carried.has(instanceId):
			return _fail("invalid_state")
		if typeof(quantity) != TYPE_INT or int(quantity) <= 0:
			return _fail("invalid_state")
		carried[instanceId] = int(quantity)
	var membersValue = partyState.get("members", null)
	if !(membersValue is Dictionary) or (membersValue as Dictionary).is_empty():
		return _fail("invalid_state")
	var liveParty := _domain("party")
	if liveParty != null and "party" in liveParty:
		var liveKeys := {}
		for keyValue in liveParty.party:
			liveKeys[str(keyValue)] = true
		var payloadKeys := {}
		for keyValue in membersValue:
			payloadKeys[str(keyValue)] = true
		if liveKeys != payloadKeys:
			return _fail("invalid_state")

	var usedIds := carried.keys()
	var used := {}
	for instanceId in usedIds:
		used[str(instanceId)] = true
	for memberValue in membersValue.values():
		if !(memberValue is Dictionary):
			return _fail("invalid_state")
		var equipmentValue = memberValue.get("equipment", null)
		if equipmentValue != null and !(equipmentValue is Dictionary):
			return _fail("invalid_state")
		if equipmentValue is Dictionary:
			for itemValue in (equipmentValue as Dictionary).values():
				if itemValue == null:
					continue
				if !(itemValue is Dictionary):
					return _fail("invalid_state")
				var itemId := str((itemValue as Dictionary).get("instanceId", ""))
				if itemId.is_empty() or used.has(itemId):
					return _fail("invalid_state")
				used[itemId] = true
		var reservationsValue = memberValue.get("beltReservations", null)
		if !(reservationsValue is Array):
			return _fail("invalid_state")
		# Selected active Moves: unique non-empty strings within the cap. The
		# Party importer resolves them against real class/equipment grants.
		var movesValue = memberValue.get("moves", null)
		if !(movesValue is Array):
			return _fail("invalid_state")
		var memberMoves := {}
		for moveValue in movesValue:
			if typeof(moveValue) != TYPE_STRING:
				return _fail("invalid_state")
			var moveName := str(moveValue)
			if moveName.is_empty() or memberMoves.has(moveName) or memberMoves.size() >= int(CombatLoadoutProjectorScript.MOVE_CAP):
				return _fail("invalid_state")
			memberMoves[moveName] = true
		var memberReserved := {}
		for reservationValue in reservationsValue:
			if !(reservationValue is Dictionary):
				return _fail("invalid_state")
			var reservation: Dictionary = reservationValue
			var instanceId := str(reservation.get("instanceId", ""))
			var quantity = reservation.get("quantity", null)
			if instanceId.is_empty() or memberReserved.has(instanceId):
				return _fail("invalid_state")
			if !carried.has(instanceId):
				return _fail("invalid_state")
			if str(reservation.get("combatId", "")).is_empty():
				return _fail("invalid_state")
			if typeof(quantity) != TYPE_INT or int(quantity) <= 0:
				return _fail("invalid_state")
			if int(quantity) > int(carried[instanceId]):
				return _fail("invalid_state")
			memberReserved[instanceId] = true
			used[instanceId] = true
	return { "success": true, "reason": "", "carried": carried, "usedIds": used }




## Bank ids must not collide with any Party id, and every rolled stock entry must
## belong to the same departure cycle the save records: a restored shop may never
## mix cycles or duplicate an instance.
func _auditVendors(vendorsState: Dictionary, partyAudit: Dictionary) -> Dictionary:
	if typeof(vendorsState.get("baseSeed", null)) != TYPE_INT:
		return _fail("invalid_state")
	var departureValue = vendorsState.get("activeDepartureId", null)
	if typeof(departureValue) != TYPE_INT or int(departureValue) < 0:
		return _fail("invalid_state")
	var activeDepartureId := int(departureValue)
	var bankValue = vendorsState.get("bank", null)
	if !(bankValue is Array):
		return _fail("invalid_state")
	var usedIds: Dictionary = partyAudit.get("usedIds", {})
	var bankIds := {}
	for entryValue in bankValue:
		if !(entryValue is Dictionary):
			return _fail("invalid_state")
		var instanceId := str((entryValue as Dictionary).get("instanceId", ""))
		if instanceId.is_empty() or usedIds.has(instanceId) or bankIds.has(instanceId):
			return _fail("invalid_state")
		bankIds[instanceId] = true
	var stockValue = vendorsState.get("stock", null)
	if !(stockValue is Dictionary):
		return _fail("invalid_state")
	for entryValue in (stockValue as Dictionary).values():
		if !(entryValue is Dictionary):
			return _fail("invalid_state")
		var entry: Dictionary = entryValue
		if typeof(entry.get("stockSeed", null)) != TYPE_INT:
			return _fail("invalid_state")
		if typeof(entry.get("departureId", null)) != TYPE_INT or int(entry.departureId) != activeDepartureId:
			return _fail("invalid_state")
		var offersValue = entry.get("offers", null)
		if !(offersValue is Array):
			return _fail("invalid_state")
		var offerIds := {}
		for offerValue in offersValue:
			if !(offerValue is Dictionary):
				return _fail("invalid_state")
			var offerId := str((offerValue as Dictionary).get("offerId", ""))
			if offerId.is_empty() or offerIds.has(offerId):
				return _fail("invalid_state")
			offerIds[offerId] = true
	return { "success": true, "reason": "" }


## Trail state and the departure cycle must agree with the vendor domain, or a
## restored shop would roll against a cycle the world is not in.
func _auditLocations(locationsState: Dictionary, vendorsState: Dictionary) -> Dictionary:
	if typeof(locationsState.get("onTrail", null)) != TYPE_BOOL:
		return _fail("invalid_state")
	var departureValue = locationsState.get("trailDepartureId", null)
	if typeof(departureValue) != TYPE_INT or int(departureValue) < 0:
		return _fail("invalid_state")
	if typeof(locationsState.get("lastTownId", null)) != TYPE_STRING:
		return _fail("invalid_state")
	if int(departureValue) != int(vendorsState.get("activeDepartureId", -1)):
		return _fail("invalid_state")
	return { "success": true, "reason": "" }


## Progression inputs must stay inside the authored rarity vocabulary. The
## objective chain itself is validated by Quests.importState(), which rejects
## and rolls the commit back rather than restoring an inconsistent story.
func _auditQuestProgression(questsState: Dictionary) -> Dictionary:
	var levelValue = questsState.get("currentMainQuestLevel", null)
	if !(levelValue is Dictionary):
		return _fail("invalid_state")
	var level = (levelValue as Dictionary).get("level", null)
	var rarity = (levelValue as Dictionary).get("rarity", null)
	if typeof(level) != TYPE_INT or int(level) < 1:
		return _fail("invalid_state")
	if typeof(rarity) != TYPE_STRING or !ItemGenerationScript.RARITIES.has(str(rarity)):
		return _fail("invalid_state")
	var statesValue = questsState.get("states", null)
	if !(statesValue is Dictionary):
		return _fail("invalid_state")
	for questIdValue in statesValue:
		if str(questIdValue).is_empty() or !(statesValue[questIdValue] is Dictionary):
			return _fail("invalid_state")
	return { "success": true, "reason": "" }


func _auditCutscene(cutsceneState: Dictionary) -> Dictionary:
	var arc = cutsceneState.get("cutsceneArc", null)
	var name = cutsceneState.get("cutsceneName", null)
	if typeof(arc) != TYPE_STRING or typeof(name) != TYPE_STRING:
		return _fail("invalid_state")
	if str(arc).is_empty() or str(name).is_empty():
		return _fail("invalid_state")
	var playedValue = cutsceneState.get("playedCutscenes", null)
	if !(playedValue is Dictionary):
		return _fail("invalid_state")
	for keyValue in playedValue:
		if str(keyValue).is_empty() or typeof(playedValue[keyValue]) != TYPE_BOOL:
			return _fail("invalid_state")
	return { "success": true, "reason": "" }


func _auditDiscovery(discoveryState: Dictionary) -> Dictionary:
	var idsValue = discoveryState.get("revealedIds", null)
	if !(idsValue is Array):
		return _fail("invalid_state")
	var seen := {}
	for idValue in idsValue:
		if typeof(idValue) != TYPE_STRING:
			return _fail("invalid_state")
		var targetId := str(idValue)
		if targetId.is_empty() or seen.has(targetId):
			return _fail("invalid_state")
		seen[targetId] = true
	# Commit 16: the optional one-shot claim list must be unique non-empty
	# strings; the semantic reveal/known-target checks happen in the Discovery
	# import, where content drift rolls back the whole commit.
	var claimedValue = discoveryState.get("claimedTargetIds", [])
	if !(claimedValue is Array):
		return _fail("invalid_state")
	var claimedSeen := {}
	for idValue in claimedValue:
		if typeof(idValue) != TYPE_STRING:
			return _fail("invalid_state")
		var targetId := str(idValue)
		if targetId.is_empty() or claimedSeen.has(targetId):
			return _fail("invalid_state")
		claimedSeen[targetId] = true
	return { "success": true, "reason": "" }


## A null position is the legacy "no exact position recorded" case.
func _auditOverworld(overworldState: Dictionary) -> Dictionary:
	var positionValue = overworldState.get("position", null)
	if positionValue == null:
		return { "success": true, "reason": "" }
	if !(positionValue is Dictionary):
		return _fail("invalid_state")
	var x = (positionValue as Dictionary).get("x", null)
	var y = (positionValue as Dictionary).get("y", null)
	if !_isNumber(x) or !_isNumber(y):
		return _fail("invalid_state")
	if !is_finite(float(x)) or !is_finite(float(y)):
		return _fail("invalid_state")
	return { "success": true, "reason": "" }


## The payload must be plain JSON data: no engine types (Vector2, Object,
## Resource) and no non-String keys, so transient scene state cannot be written
## and the file cannot smuggle a constructible value back in.
func _auditJsonSafe(value, path := "payload") -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return { "success": true, "reason": "" }
		TYPE_FLOAT:
			if is_finite(value):
				return { "success": true, "reason": "" }
			push_warning("SaveGame: %s is not a finite number." % path)
			return _fail("invalid_state")
		TYPE_ARRAY:
			for index in value.size():
				var entryCheck := _auditJsonSafe(value[index], "%s[%d]" % [path, index])
				if !bool(entryCheck.get("success", false)):
					return entryCheck
			return { "success": true, "reason": "" }
		TYPE_DICTIONARY:
			for keyValue in value:
				if typeof(keyValue) != TYPE_STRING:
					push_warning("SaveGame: %s has a non-string key." % path)
					return _fail("invalid_state")
				var entryCheck := _auditJsonSafe(value[keyValue], "%s.%s" % [path, str(keyValue)])
				if !bool(entryCheck.get("success", false)):
					return entryCheck
			return { "success": true, "reason": "" }
	push_warning("SaveGame: %s holds unsupported type %d." % [path, typeof(value)])
	return _fail("invalid_state")



## Upgrades an older payload to the current format by walking the documented
## migration steps, or fails when no step exists. Content ids are never guessed:
## an item definition that no longer resolves is rejected by the domain importers
## (and the commit is rolled back) instead of being silently re-mapped.
func migratePayload(payload) -> Dictionary:
	if !(payload is Dictionary):
		return _fail("invalid_state")
	var versionValue = payload.get("formatVersion", null)
	if typeof(versionValue) != TYPE_INT:
		return _fail("invalid_state")
	var version := int(versionValue)
	if version == SAVE_FORMAT_VERSION:
		return { "success": true, "reason": "", "payload": (payload as Dictionary).duplicate(true), "migratedFrom": version }
	if version > SAVE_FORMAT_VERSION:
		return _fail("unsupported_version")
	var migratedFrom := version
	var working: Dictionary = (payload as Dictionary).duplicate(true)
	while version < SAVE_FORMAT_VERSION:
		var stepName := str(MIGRATION_STEPS.get(version, ""))
		if stepName.is_empty():
			return _fail("unsupported_version")
		var stepResult = call(stepName, working)
		if !(stepResult is Dictionary) or (stepResult as Dictionary).is_empty():
			return _fail("migration_failed")
		working = stepResult
		var nextVersion := int(working.get("formatVersion", -1))
		if nextVersion <= version:
			# A step that does not advance the version would loop forever.
			return _fail("migration_failed")
		version = nextVersion
	return { "success": true, "reason": "", "payload": working, "migratedFrom": migratedFrom }


## Version 2 -> 3. Version 2 saved Party money/inventory/equipment/reservations
## but no selected Move loadout, so each member defaults to its canonical New
## Game selection. Grants are never invented; the domain importer then resolves
## the selection against the real class and equipment.
func migrateMoveLoadouts(payload: Dictionary) -> Dictionary:
	var partyValue = payload.get("party", null)
	if !(partyValue is Dictionary):
		return {}
	var partyState: Dictionary = (partyValue as Dictionary).duplicate(true)
	var membersValue = partyState.get("members", null)
	if !(membersValue is Dictionary):
		return {}
	var canonical := _canonicalPartySnapshot()
	var canonicalMembers = canonical.get("members", {}) if canonical is Dictionary else {}
	for memberKeyValue in membersValue:
		var memberValue = membersValue[memberKeyValue]
		if !(memberValue is Dictionary):
			return {}
		var member: Dictionary = memberValue
		if member.has("moves"):
			continue
		var canonicalMember = canonicalMembers.get(str(memberKeyValue), null)
		member["moves"] = (canonicalMember as Dictionary).get("moves", []).duplicate() if canonicalMember is Dictionary else []
	partyState["formatVersion"] = int(PartyScript.STATE_FORMAT_VERSION)
	var migrated: Dictionary = payload.duplicate(true)
	migrated["party"] = partyState
	migrated["formatVersion"] = SAVE_FORMAT_VERSION
	return migrated


## Version 1 (the pre-service vendor-audit payload) -> current. It carried Party
## money/inventory, vendor and discovery states and one scalar departure id, and
## no quest, cutscene, Trail or position data. Missing domains come from the
## canonical New Game snapshot; belt reservations that no longer reference a
## carried stack are dropped and the instance-id counter is raised past every
## carried id.
func migrateLegacyVendorAudit(legacy: Dictionary) -> Dictionary:
	var partyPayload = legacy.get("party", null)
	if !(partyPayload is Dictionary):
		return {}
	var inventory = (partyPayload as Dictionary).get("inventory", null)
	if !(inventory is Array):
		return {}
	var money = (partyPayload as Dictionary).get("money", null)
	if typeof(money) != TYPE_INT or int(money) < 0:
		return {}
	var departureValue = legacy.get("trailDepartureId", null)
	if typeof(departureValue) != TYPE_INT or int(departureValue) < 0:
		return {}
	var departureId := int(departureValue)

	var partyState := _canonicalPartySnapshot()
	if partyState.is_empty():
		return {}
	partyState["money"] = int(money)
	partyState["inventory"] = (inventory as Array).duplicate(true)
	partyState["nextInstanceNumber"] = _nextInstanceNumberFor(partyState.inventory, int(partyState.get("nextInstanceNumber", 1)))
	var carried := {}
	for entryValue in partyState.inventory:
		if entryValue is Dictionary:
			carried[str((entryValue as Dictionary).get("instanceId", ""))] = int((entryValue as Dictionary).get("quantity", 0))
	for memberValue in (partyState.members as Dictionary).values():
		var kept := []
		for reservationValue in memberValue.get("beltReservations", []):
			if !(reservationValue is Dictionary):
				continue
			var instanceId := str((reservationValue as Dictionary).get("instanceId", ""))
			if !carried.has(instanceId):
				continue
			var quantity := mini(int((reservationValue as Dictionary).get("quantity", 1)), int(carried[instanceId]))
			if quantity <= 0:
				continue
			var reservation: Dictionary = (reservationValue as Dictionary).duplicate(true)
			reservation["quantity"] = quantity
			kept.append(reservation)
		memberValue["beltReservations"] = kept

	var vendorsState := {}
	if legacy.get("vendors", null) is Dictionary:
		vendorsState = (legacy.vendors as Dictionary).duplicate(true)
	else:
		vendorsState = { "formatVersion": 1, "baseSeed": 0, "activeDepartureId": departureId, "stock": {}, "bank": [] }
	var discoveryState := {}
	if legacy.get("discovery", null) is Dictionary:
		discoveryState = (legacy.discovery as Dictionary).duplicate(true)
	else:
		discoveryState = { "formatVersion": 1, "revealedIds": [] }

	return {
		"formatVersion": SAVE_FORMAT_VERSION,
		"party": partyState,
		"quests": _canonicalQuestsSnapshot(),
		"locations": { "formatVersion": 1, "onTrail": false, "trailDepartureId": departureId, "lastTownId": "" },
		"cutscene": _canonicalCutsceneSnapshot(),
		"vendors": vendorsState,
		"discovery": discoveryState,
		"overworld": { "formatVersion": 1, "position": null },
	}

## Canonical New Game snapshots for domains a legacy payload did not carry. The
## owning script's own export is used, never a hand-written shape.
func _canonicalPartySnapshot() -> Dictionary:
	var canonical = PartyScript.new()
	var snapshot: Dictionary = canonical.exportState()
	canonical.free()
	return snapshot


func _canonicalQuestsSnapshot() -> Dictionary:
	var canonical = QuestsScript.new()
	var snapshot: Dictionary = canonical.exportState()
	canonical.free()
	return snapshot


func _canonicalCutsceneSnapshot() -> Dictionary:
	var canonical = CutsceneScript.new()
	var snapshot: Dictionary = canonical.exportState()
	canonical.free()
	return snapshot


## Raised past every already-allocated generated id so a migrated save cannot
## hand a new item an id the file already uses.
func _nextInstanceNumberFor(inventory: Array, base: int) -> int:
	var rules = InventoryRulesScript.new()
	var next := maxi(1, int(base))
	for entryValue in inventory:
		if entryValue is Dictionary:
			next = rules.nextInstanceNumberAfter(str((entryValue as Dictionary).get("instanceId", "")), next)
	return next


## Parses, migrates and audits one file. Never mutates live state. JSON cannot
## express the int/float distinction, so integral numbers are normalized back to
## ints (the shape every domain schema writes) before validation.
func _readFile(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return _fail("no_save")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("unreadable_save")
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("malformed_save")
	return _preparePayload(_coerceIntegralNumbers(json.data))


## A parsed payload states counts, ids and quantities as ints; the file states
## them as numbers. Values that are integral stay exact as ints, and genuinely
## fractional values (the recorded Overworld position) stay floats.
func _coerceIntegralNumbers(value):
	match typeof(value):
		TYPE_FLOAT:
			if is_finite(value) and value == floor(value) and absf(value) <= 9007199254740992.0:
				return int(value)
			return value
		TYPE_ARRAY:
			for index in value.size():
				value[index] = _coerceIntegralNumbers(value[index])
			return value
		TYPE_DICTIONARY:
			for keyValue in value:
				value[keyValue] = _coerceIntegralNumbers(value[keyValue])
			return value
	return value


func _preparePayload(parsed) -> Dictionary:
	if !(parsed is Dictionary):
		return _fail("malformed_save")
	var versionValue = (parsed as Dictionary).get("formatVersion", null)
	if typeof(versionValue) != TYPE_INT:
		return _fail("invalid_state")
	var version := int(versionValue)
	if version > SAVE_FORMAT_VERSION:
		return _fail("unsupported_version")
	var payload: Dictionary = parsed
	var migratedFrom := version
	if version < SAVE_FORMAT_VERSION:
		var migrated := migratePayload(parsed)
		if !bool(migrated.get("success", false)):
			return migrated
		payload = migrated.payload
	var check := validatePayload(payload)
	if !bool(check.get("success", false)):
		return check
	return { "success": true, "reason": "", "payload": payload, "migratedFrom": migratedFrom }


## Temp file -> verified read-back -> backup -> replacement. The previous file is
## only removed after the new one is in place, so a crash mid-write leaves either
## the old save or its backup readable.
func _writeAtomically(json: String) -> Dictionary:
	var targetPath := getActivePath()
	var directory := targetPath.get_base_dir()
	if !directory.is_empty() and !DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var tempPath := targetPath + TEMP_SUFFIX
	var backupPath := targetPath + BACKUP_SUFFIX
	var file := FileAccess.open(tempPath, FileAccess.WRITE)
	if file == null:
		return _fail("write_failed")
	file.store_string(json)
	file.close()
	var verify := FileAccess.open(tempPath, FileAccess.READ)
	if verify == null or verify.get_as_text() != json:
		if verify != null:
			verify.close()
		DirAccess.remove_absolute(tempPath)
		return _fail("write_verify_failed")
	verify.close()

	var hadPrevious := FileAccess.file_exists(targetPath)
	if hadPrevious:
		if FileAccess.file_exists(backupPath):
			DirAccess.remove_absolute(backupPath)
		if DirAccess.rename_absolute(targetPath, backupPath) != OK:
			DirAccess.remove_absolute(tempPath)
			return _fail("write_failed")
	if DirAccess.rename_absolute(tempPath, targetPath) != OK:
		if hadPrevious:
			DirAccess.rename_absolute(backupPath, targetPath)
		DirAccess.remove_absolute(tempPath)
		return _fail("write_failed")
	if hadPrevious:
		DirAccess.remove_absolute(backupPath)
	return { "success": true, "reason": "", "path": getActivePath() }


func _domain(domainKey: String) -> Node:
	if _injectedDomains.has(domainKey):
		var injected = _injectedDomains[domainKey]
		return injected if is_instance_valid(injected) else null
	var mainLoop = Engine.get_main_loop()
	if mainLoop is SceneTree and mainLoop.root != null:
		return mainLoop.root.get_node_or_null(str(DOMAIN_NODES.get(domainKey, "")))
	return null


func _isNumber(value) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


func _fail(reason: String) -> Dictionary:
	_lastError = reason
	return { "success": false, "reason": reason }

