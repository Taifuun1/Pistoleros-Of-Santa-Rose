extends SceneTree

## Headless validation for map discovery (Docs/System Design/Location Vendors
## Implementation.md, patch 5): atomic map use, duplicate/invalid reveals,
## marker payloads, snapshot isolation and the production reveal data.
## Run with: godot --headless --script res://Tests/TestDiscovery.gd

const DiscoveryScript = preload("res://Globals/Discovery.gd")
const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const PartyScript = preload("res://Globals/Party.gd")

const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Production reveal data ---")
	var production = _makeContext(SecretMapDataScript.new())
	_check(production.discovery.isDiscoveryDataAvailable(), "discovery service is configured")
	var mapItem = _giveMap(production)
	_check(mapItem != "", "the fixture carries a reveal map")
	_check(production.discovery.getRevealedSecretMarkers().is_empty(), "nothing is revealed before the map is used")
	_check(!production.discovery.isRevealed("Gold Run"), "the production secret Location starts hidden")
	_check(!production.discovery.isMapFullyRevealed("canyon_cache_map"), "an unused map is not fully revealed")

	print("\n--- Valid use consumes one map and reveals its targets ---")
	var signalCount = [0]
	production.discovery.discoveryChanged.connect(func(): signalCount[0] += 1)
	var result = production.discovery.useMap(mapItem)
	_check(result.success and result.consumed, "a valid map is consumed")
	_check(result.revealedIds == ["Gold Run"], "the map reveals exactly its authored targets")
	_check(signalCount[0] == 1, "one discovery signal per successful use")
	_check(production.party.inventory.is_empty(), "the consumed map leaves the inventory")
	_check(production.discovery.isRevealed("Gold Run"), "the revealed id is known")
	_check(production.discovery.isMapFullyRevealed("canyon_cache_map"), "the used map is fully revealed")
	var markers = production.discovery.getRevealedSecretMarkers()
	_check(markers.size() == 1 and markers[0].targetId == "Gold Run", "revealed markers list only known ids")
	_check(typeof(markers[0].cell) == TYPE_VECTOR2I, "revealed markers carry a resolved shared cell")
	var manifestEntry = production.mapData.resolveSecretLocation("Gold Run")
	_check(!manifestEntry.is_empty() and markers[0].cell == manifestEntry["cell"], "Location markers resolve from the manifest")

	print("\n--- Duplicate and invalid uses change nothing ---")
	var secondMap = _giveMap(production)
	_check(secondMap != "", "a second map can be carried")
	var before = _state(production)
	result = production.discovery.useMap(secondMap)
	_check(!result.success and result.reason == "already_revealed", "a fully revealed map is rejected")
	_check(_state(production) == before, "a rejected use consumes nothing and reveals nothing")
	_check(production.discovery.useMap("missing_item").reason == "unknown_item", "unknown instances fail closed")
	_check(production.discovery.useMap("").reason == "unknown_item", "empty ids fail closed")
	_check(production.discovery.useMap(mapItem).reason == "unknown_item", "an already consumed map fails closed")

	var nonMap = _makeContext(SecretMapDataScript.new())
	nonMap.party.inventory = [_stackEntry("non_map", "paregoric")]
	_check(nonMap.discovery.useMap("non_map").reason == "wrong_item_type", "non-map items cannot be used as maps")

	var badEffect = _makeContext(SecretMapDataScript.new())
	_carryMap(badEffect, "bad_effect", "")
	_check(badEffect.discovery.useMap("bad_effect").reason == "invalid_map", "a map without a mapId fails closed")

	var unknownMap = _makeContext(SecretMapDataScript.new())
	_carryMap(unknownMap, "unknown_map", "not_a_map")
	_check(unknownMap.discovery.useMap("unknown_map").reason == "invalid_map", "an unknown map definition fails closed")

	_freeContext(production)
	_freeContext(nonMap)
	_freeContext(badEffect)
	_freeContext(unknownMap)

	print("\n--- Malformed targets reject the whole use ---")
	var malformed = _makeContext(_malformedContexts())
	_carryMap(malformed, "bad_target", "bad_target_map")
	var malformedBefore = _state(malformed)
	var malformedResult = malformed.discovery.useMap("bad_target")
	_check(!malformedResult.success and malformedResult.reason == "invalid_target", "a malformed target rejects the whole use")
	_check(_state(malformed) == malformedBefore, "the malformed-map rejection is atomic")

	print("\n--- Secret items project through the shared coordinates ---")
	var secretItem = _makeContext(_secretItemContext())
	_carryMap(secretItem, "cache_map_item", "cache_map")
	result = secretItem.discovery.useMap("cache_map_item")
	_check(result.success, "a map targeting a secret item is usable")
	var itemMarkers = secretItem.discovery.getRevealedSecretMarkers()
	_check(itemMarkers.size() == 1 and str(itemMarkers[0].kind) == "secret_item", "secret items appear in the marker payload")
	_check(typeof(itemMarkers[0].cell) == TYPE_VECTOR2I, "secret-item cells resolve through the shared coordinates")
	_check(itemMarkers[0].chunk == Vector2i(3, 14) and itemMarkers[0].tile == Vector2i(40, 40), "the authored chunk/tile rides along the marker")

	var outOfChunk = _makeContext(_secretItemContext(Vector2i(99, 99)))
	_carryMap(outOfChunk, "cache_map_item", "cache_map")
	result = outOfChunk.discovery.useMap("cache_map_item")
	_check(!result.success and result.reason == "invalid_map", "an out-of-chunk secret item fails closed")
	_check(outOfChunk.party.inventory.size() == 1, "the rejected map stays in the inventory")

	print("\n--- Snapshots ---")
	var exported = _makeContext(SecretMapDataScript.new())
	exported.discovery.importState({ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": ["Gold Run"], "claimedTargetIds": ["Gold Run"] })
	var state = exported.discovery.exportState()
	_check(state.formatVersion == DiscoveryScript.STATE_FORMAT_VERSION and state.revealedIds == ["Gold Run"] and state.claimedTargetIds == ["Gold Run"], "export lists sorted reveals and claims")
	var imported = _makeContext(SecretMapDataScript.new())
	_check(imported.discovery.importState(state).success, "valid state imports")
	_check(imported.discovery.isRevealed("Gold Run") and imported.discovery.isClaimed("Gold Run"), "import restores reveals and claims")
	_check(imported.discovery.exportState() == state, "export/import/export is stable")
	_check(imported.party.inventory.is_empty(), "import grants nothing")
	var legacyImport = _makeContext(SecretMapDataScript.new())
	_check(bool(legacyImport.discovery.importState({ "formatVersion": 1, "revealedIds": ["Gold Run"] }).get("success", false)), "a version 1 snapshot migrates")
	_check(legacyImport.discovery.isRevealed("Gold Run") and !legacyImport.discovery.isClaimed("Gold Run"), "the v1 migration keeps reveals without phantom claims")
	var baseline = imported.discovery.exportState()
	for malformedState in [
		{ "formatVersion": 999, "revealedIds": ["Gold Run"] },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": "Gold Run" },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": ["unknown_target"] },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": [7] },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": ["Gold Run", "Gold Run"] },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": ["Gold Run"], "claimedTargetIds": "Gold Run" },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": ["Gold Run"], "claimedTargetIds": ["unknown_target"] },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": [], "claimedTargetIds": ["Gold Run"] },
		{ "formatVersion": DiscoveryScript.STATE_FORMAT_VERSION, "revealedIds": ["Gold Run"], "claimedTargetIds": ["Gold Run", "Gold Run"] },
	]:
		var importResult = imported.discovery.importState(malformedState)
		_check(!importResult.success and importResult.reason == "invalid_state", "malformed state %s is rejected" % [malformedState])
		_check(imported.discovery.exportState() == baseline, "malformed state leaves reveals unchanged")
	imported.discovery.resetForNewGame()
	_check(imported.discovery.exportState().revealedIds.is_empty() and imported.discovery.exportState().claimedTargetIds.is_empty(), "New Game clears every reveal and claim")

	testSecretClaims()

	_freeContext(malformed)
	_freeContext(secretItem)
	_freeContext(outOfChunk)
	_freeContext(exported)
	_freeContext(imported)

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## Secret reward claims (commit 16): Trail eligibility first, revealed and
## one-shot only, with the all-or-nothing full-inventory refusal in between.
func testSecretClaims() -> void:
	print("\n--- Secret claims (commit 16) ---")
	var claims := _makeContext(SecretMapDataScript.new())
	claims.discovery.locations = FakeLocations.new()
	claims.discovery.locations.onTrail = false
	_check(str(claims.discovery.claimSecretTarget("Gold Run").reason) == "off_trail", "an Off-Trail claim is refused first")
	claims.discovery.locations.onTrail = true
	_check(str(claims.discovery.claimSecretTarget("Gold Run").reason) == "not_revealed", "an unrevealed cache cannot be claimed")
	_check(str(claims.discovery.claimSecretTarget("Mystery Cave").reason) == "unknown_target", "an unknown target fails closed")
	var claimMap = _giveMap(claims)
	_check(bool(claims.discovery.useMap(claimMap).get("success", false)), "the map reveals the cache")

	var filler := 0
	while claims.party.canAddItems([claims.itemCatalog.makeStackable("canyon_cache_map", 1)]) and filler < 40:
		claims.party.addItem(claims.itemCatalog.makeStackable("canyon_cache_map", 1))
		filler += 1
	_check(!claims.party.canAddItems([claims.itemCatalog.makeStackable("gold_nugget", 1)]), "the inventory is full")
	var beforeClaim = _state(claims)
	var refused: Dictionary = claims.discovery.claimSecretTarget("Gold Run")
	_check(!refused.success and refused.reason == "inventory_full", "a full inventory refuses the claim all-or-nothing")
	_check(_state(claims) == beforeClaim, "the refused claim grants nothing and keeps the cache available")
	claims.party.inventory.clear()
	_check(bool(claims.discovery.claimSecretTarget("Gold Run").get("success", false)), "with space free the claim grants the authored reward")
	_check(claims.discovery.isClaimed("Gold Run") and claims.discovery.getClaimedTargetIds() == ["Gold Run"], "the claim is one-shot and recorded")
	var nuggets = claims.party.inventory.filter(func(entry): return entry.definitionId == "gold_nugget")
	_check(nuggets.size() == 1 and int(nuggets[0].quantity) == 1, "exactly one gold nugget was granted")
	var repeat: Dictionary = claims.discovery.claimSecretTarget("Gold Run")
	_check(!repeat.success and repeat.reason == "already_claimed", "a repeat claim is refused")
	_check(claims.party.inventory.size() == 1, "the refused repeat grants nothing")
	_freeContext(claims)


class FakeLocations:
	var onTrail := true

	func isOnTrail() -> bool:
		return onTrail


## A Party with a working inventory plus a Discovery service over the production
## manifest (or a fixture map resource).
func _makeContext(secretMapData, mapDataOverride = null) -> Dictionary:
	var itemCatalog = ItemCatalogScript.new()
	var party = PartyScript.new()
	party.configureInventory(itemCatalog)
	party.inventory = []
	party._nextInstanceNumber = 1
	party.setInventoryManagementAllowed(true)
	var discovery = DiscoveryScript.new()
	var mapData = mapDataOverride if mapDataOverride != null else load(MAP_MANIFEST)
	var coordinates := OverworldCoordinates.makeHeadless()
	discovery.configure(party, secretMapData, itemCatalog, mapData, coordinates)
	return { "discovery": discovery, "party": party, "itemCatalog": itemCatalog, "mapData": mapData, "coordinates": coordinates }


## A map that reveals Gold Run, added as a real carried stack entry.
func _giveMap(context: Dictionary) -> String:
	context["mapCounter"] = int(context.get("mapCounter", 0)) + 1
	var instanceId := "map_%d" % int(context["mapCounter"])
	context.party.inventory.append(_mapEntry(instanceId, "canyon_cache_map"))
	return instanceId


## Fixture maps are definitions, not corrupted entries: the inventory stores
## canonical stackable entries and the projection resolves the effect from the
## catalog, so a malformed map is a malformed definition.
func _carryMap(context: Dictionary, instanceId: String, mapId: String) -> void:
	var definitionId := "fixture_map_%s" % mapId
	context.itemCatalog.definitions[definitionId] = {
		"definitionId": definitionId, "itemType": "map", "name": "Fixture Map", "category": "maps",
		"stackLimit": 1, "effect": { "kind": "reveal_map", "mapId": mapId },
	}
	context.party.inventory.append(_mapEntry(instanceId, definitionId))


func _mapEntry(instanceId: String, definitionId: String) -> Dictionary:
	return { "definitionId": definitionId, "itemType": "map", "quantity": 1, "instanceId": instanceId }


func _stackEntry(instanceId: String, definitionId: String) -> Dictionary:
	var entry := ItemCatalogScript.new().makeStackable(definitionId, 1)
	entry["instanceId"] = instanceId
	return entry


func _state(context: Dictionary) -> Dictionary:
	return {
		"inventory": context.party.inventory.duplicate(true),
		"revealed": context.discovery.exportState(),
	}


## A map whose second target is unknown, so the whole use must be rejected.
func _malformedContexts():
	var data = SecretMapDataScript.new()
	data.targets["Gold Run"] = {
		"targetId": "Gold Run", "kind": "location", "displayName": "Gold Run", "icon": "secret_location",
	}
	data.maps["bad_target_map"] = { "mapId": "bad_target_map", "targetIds": ["Gold Run", "missing_target"] }
	return data


## A secret-item target resolved through the shared chunk/tile coordinates.
func _secretItemContext(tile := Vector2i(40, 40)):
	var data = SecretMapDataScript.new()
	data.targets["cache_one"] = {
		"targetId": "cache_one", "kind": "secret_item", "displayName": "Buried cache",
		"icon": "secret_item", "chunk": Vector2i(3, 14), "tile": tile,
	}
	data.maps["cache_map"] = { "mapId": "cache_map", "targetIds": ["cache_one"] }
	return data


func _freeContext(context: Dictionary) -> void:
	for key in ["discovery", "party"]:
		var node = context.get(key, null)
		if node != null and is_instance_valid(node):
			node.free()
	var coordinateService = context.get("coordinates", null)
	if coordinateService != null:
		coordinateService.dispose()
	context.clear()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)