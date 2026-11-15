extends SceneTree

## Headless audit of the vendor-domain save seams (Docs/System Design/Location
## Vendors Implementation.md, patch 7): the ordered coordinator contract, a full
## cross-service round-trip, cycle stability, whole-payload rollback and the New
## Game resets. The real save service does not exist yet, so this pins the
## harness contract the future coordinator must satisfy.
## Run with: godot --headless --script res://Tests/TestVendorPersistence.gd

const VendorsScript = preload("res://Globals/Vendors.gd")
const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const DiscoveryScript = preload("res://Globals/Discovery.gd")
const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")
const PartyScript = preload("res://Globals/Party.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")

const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"
const ROOM_SCENE := "res://UI/Journal/Journal.tscn"

var failures = 0


class FakeLocations:
	extends Node

	signal trailDeparted(departureId: int)

	var trailDepartureId := 0

	func departForTrail() -> int:
		trailDepartureId += 1
		trailDeparted.emit(trailDepartureId)
		return trailDepartureId

	func restoreTrailDepartureId(value: int) -> void:
		trailDepartureId = maxi(0, int(value))

	func resetTrailDepartures() -> void:
		trailDepartureId = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- A play session leaves a full domain state ---")
	var session = _makeContext(4321, 500)
	_check(session.vendors.buy("test_general", "paregoric", 2).success, "the session buys a stack")
	var mapPurchase = session.vendors.buy("test_general", "canyon_cache_map", 1)
	_check(mapPurchase.success, "the session buys a reveal map: %s" % str(mapPurchase))
	# A bought map must expose its authored effect through the inventory
	# projection, or the Journal's Use action and discovery could never see it.
	_check(str(_projectedItem(session, "canyon_cache_map").get("effect", {}).get("kind", "")) == "reveal_map", "the inventory projection keeps the map's authored effect")
	var mapUse = session.discovery.useMap(str(mapPurchase.get("acceptedInstanceIds", [""])[0]))
	_check(mapUse.success, "the session uses the map: %s" % str(mapUse))
	var weapon = _carryWeapon(session)
	_check(session.vendors.deposit(weapon).success, "the session stores a rolled weapon in the Bank")
	_check(session.vendors.getVendorSnapshot("test_gunsmith").offers.size() > 0, "the session rolls gunsmith stock")
	session.locations.departForTrail()
	_check(session.vendors.getVendorSnapshot("test_gunsmith").offers.size() > 0, "the new trail cycle rolls fresh stock")
	var payload = exportPayload(session)

	print("\n--- The payload round-trips into a fresh session ---")
	var restored = _makeContext(0, 0)
	_check(restorePayload(restored, payload).success, "the documented coordinator order restores the payload")
	_check(_capture(restored) == _capture(session), "every saved domain value survives the round-trip")
	_check(exportPayload(restored) == payload, "export/import/export is byte-stable")

	print("\n--- Whole-payload validation happens before any commit ---")
	var baseline = _capture(restored)
	var badDiscovery = payload.duplicate(true)
	badDiscovery.discovery.revealedIds = ["Missing Target"]
	var badResult = restorePayload(restored, badDiscovery)
	_check(!badResult.success and badResult.reason == "invalid_state", "a malformed discovery payload is rejected")
	_check(_capture(restored) == baseline, "no service committed when one payload is invalid")
	var badVendors = payload.duplicate(true)
	badVendors.vendors.bank = [{ "instanceId": "broken", "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 }]
	_check(!restorePayload(restored, badVendors).success, "a malformed vendor payload is rejected")
	_check(_capture(restored) == baseline, "no service committed when the vendor payload is invalid")
	var badDeparture = payload.duplicate(true)
	badDeparture.trailDepartureId = "nope"
	_check(!restorePayload(restored, badDeparture).success, "an invalid departure id is rejected")
	_check(_capture(restored) == baseline, "no service committed when the departure id is invalid")

	print("\n--- Partial payloads fail closed ---")
	for missingKey in ["vendors", "discovery", "trailDepartureId", "party"]:
		var partial = payload.duplicate(true)
		partial.erase(missingKey)
		_check(!restorePayload(restored, partial).success, "a payload without '%s' is rejected" % missingKey)
	_check(_capture(restored) == baseline, "partial payloads leave the session untouched")

	print("\n--- New Game resets the vendor-domain state ---")
	restored.vendors.resetForNewGame(4242)
	restored.discovery.resetForNewGame()
	restored.locations.resetTrailDepartures()
	var fresh = _capture(restored)
	_check(fresh.vendorState.stock.is_empty() and fresh.vendorState.bank.is_empty(), "New Game clears rolled stock and the Bank")
	_check(fresh.vendorState.baseSeed == 4242, "New Game installs the injected run seed")
	_check(fresh.discoveryState.revealedIds.is_empty(), "New Game clears every reveal")
	_check(fresh.trailDepartureId == 0, "New Game resets the departure cycle")
	_check(fresh.vendorState.activeDepartureId == 0, "the vendor service synchronizes to the reset cycle")
	# Party persistence/reset belongs to the save service, which does not exist
	# yet: the domain resets must leave Party exactly as they found it.
	_check(restored.party.money == payload.party.money and _gearCount(restored) == _gearCount(session), "the vendor-domain resets never touch Party state")

	_release(session)
	_release(restored)

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## --- The documented save-coordinator contract ---------------------------------
## 1. Validate every payload against a scratch service pair (the services'
##    own importers are the validators; they commit only when they accept).
## 2. Validate the scalar state (departure id) by hand.
## 3. Only then commit: vendor state, discovery state, departure id, Party state.
## A payload that fails any step leaves every live service untouched.

func exportPayload(context: Dictionary) -> Dictionary:
	return {
		"formatVersion": 1,
		"vendors": context.vendors.exportState(),
		"discovery": context.discovery.exportState(),
		"trailDepartureId": int(context.locations.trailDepartureId),
		"party": {
			"money": int(context.party.money),
			"inventory": context.party.inventory.duplicate(true),
		},
	}


func restorePayload(context: Dictionary, payload) -> Dictionary:
	if !(payload is Dictionary):
		return { "success": false, "reason": "invalid_state" }
	if typeof(payload.get("trailDepartureId", null)) != TYPE_INT or int(payload.trailDepartureId) < 0:
		return { "success": false, "reason": "invalid_state" }
	if !(payload.get("vendors", null) is Dictionary) or !(payload.get("discovery", null) is Dictionary):
		return { "success": false, "reason": "invalid_state" }
	if !(payload.get("party", null) is Dictionary):
		return { "success": false, "reason": "invalid_state" }

	# Phase 1: validate on throwaway services that share the real collaborators
	# but are discarded, so a rejected payload cannot half-apply.
	var scratch = _makeContext(0, 0)
	scratch.party.inventory = (payload.party.inventory as Array).duplicate(true)
	var vendorCheck = scratch.vendors.importState(payload.vendors)
	var discoveryCheck = scratch.discovery.importState(payload.discovery)
	_release(scratch)
	if !bool(vendorCheck.get("success", false)) or !bool(discoveryCheck.get("success", false)):
		return { "success": false, "reason": "invalid_state" }

	# Phase 2: commit the Party side, then the services, then the scalar.
	context.party.money = int(payload.party.money)
	context.party.inventory = (payload.party.inventory as Array).duplicate(true)
	if !bool(context.vendors.importState(payload.vendors).get("success", false)):
		return { "success": false, "reason": "invalid_state" }
	if !bool(context.discovery.importState(payload.discovery).get("success", false)):
		return { "success": false, "reason": "invalid_state" }
	context.locations.restoreTrailDepartureId(int(payload.trailDepartureId))
	return { "success": true, "reason": "" }


func _capture(context: Dictionary) -> Dictionary:
	return {
		"vendorState": context.vendors.exportState(),
		"discoveryState": context.discovery.exportState(),
		"trailDepartureId": int(context.locations.trailDepartureId),
		"money": int(context.party.money),
		"inventory": context.party.inventory.duplicate(true),
	}


## A full vendor domain: real Party and item generator, the production reveal
## data/manifest, a fixture shop catalog and a fake Location service.
func _makeContext(seed: int, money: int) -> Dictionary:
	var itemCatalog = ItemCatalogScript.new()
	var party = PartyScript.new()
	party.configureInventory(itemCatalog)
	party.inventory = []
	party._nextInstanceNumber = 1
	party.money = money
	party.setInventoryManagementAllowed(true)
	var coordinates := OverworldCoordinates.makeHeadless()
	var discovery = DiscoveryScript.new()
	discovery.configure(party, SecretMapDataScript.new(), itemCatalog, load(MAP_MANIFEST), coordinates)
	var locations = FakeLocations.new()
	var catalog = VendorCatalogScript.new()
	catalog.vendors = _makeVendors()
	var itemGenerator = ItemGenerationScript.new()
	var vendors = VendorsScript.new()
	vendors.configure(catalog, party, itemGenerator, VendorPricingScript.new(), locations, seed, discovery, itemCatalog)
	return {
		"vendors": vendors,
		"discovery": discovery,
		"party": party,
		"locations": locations,
		"itemGenerator": itemGenerator,
		"coordinates": coordinates,
	}


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


## A complete rolled weapon carried by the Party, returned by instance id.
func _carryWeapon(context: Dictionary) -> String:
	var item = context.itemGenerator.generateWeapon({ "rarity": "common", "family": "revolver" })
	var result = context.party.addItem(item)
	var accepted = result.get("acceptedInstanceIds", []) if result is Dictionary else []
	if !(accepted is Array) or accepted.is_empty():
		return ""
	return str(accepted[0])


func _gearCount(context: Dictionary) -> int:
	var count := 0
	for entry in context.party.inventory:
		if entry is Dictionary and str(entry.get("itemType", "")) in ["weapon", "equipment"]:
			count += 1
	return count


## The projected (snapshot) item of a carried definition, as the Journal and the
## discovery service see it.
func _projectedItem(context: Dictionary, definitionId: String) -> Dictionary:
	for item in context.party.getInventorySnapshot().get("items", []):
		if item is Dictionary and str(item.get("definitionId", "")) == definitionId:
			return item
	return {}


func _release(context: Dictionary) -> void:
	for key in ["vendors", "discovery", "party", "locations", "itemGenerator"]:
		var node = context.get(key, null)
		if node != null and is_instance_valid(node):
			node.free()
	var coordinateService = context.get("coordinates", null)
	if coordinateService != null:
		coordinateService.dispose()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)