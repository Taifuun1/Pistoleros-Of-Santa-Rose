extends SceneTree

## Headless validation for vendor transactions, Bank and save snapshots
## (Docs/System Design/Location Vendors Implementation.md, patch 2).
## Run with: godot --headless --script res://Tests/TestVendors.gd

const VendorsScript = preload("res://Globals/Vendors.gd")
const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const PartyScript = preload("res://Globals/Party.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")
const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")

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


class FakeDiscovery:
	extends RefCounted

	var revealed := {}

	func isMapFullyRevealed(mapId: String) -> bool:
		return bool(revealed.get(mapId, false))


class FakeStockGenerator:
	extends RefCounted

	var calls := 0

	func generateStock(_vendorId: String, _departureId: int, _baseSeed: int) -> Dictionary:
		calls += 1
		return { "success": false, "reason": "generator_called" }


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_testGeneralPurchases()
	_testRolledPurchases()
	_testSales()
	_testBank()
	_testDepartureAndSnapshots()
	_testNewspaperBoundary()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _testGeneralPurchases() -> void:
	print("--- General store: fixed stock and atomic purchases ---")
	var context = _makeContext(4242, 200)
	var vendorSignals = []
	context.vendors.vendorChanged.connect(func(vendorId): vendorSignals.append(vendorId))

	var snapshot = context.vendors.getVendorSnapshot("test_general")
	_check(snapshot.success and snapshot.offers.size() == 2, "general snapshot exposes both fixed offers")
	_check(snapshot.money == 200 and snapshot.capacity == 24, "snapshot carries money and capacity")
	var paregoric = _findOffer(snapshot.offers, "paregoric")
	var cacheMap = _findOffer(snapshot.offers, "canyon_cache_map")
	_check(!paregoric.is_empty() and paregoric.available, "Paregoric starts available")
	_check(cacheMap.available, "map starts available")

	var result = context.vendors.buy("test_general", "paregoric", 2)
	_check(result.success and result.totalPrice == 40 and result.money == 160, "two Paregoric cost 40")
	_check(context.party.money == 160, "purchase debits Party money once")
	_check(context.party.inventory.size() == 1 and context.party.inventory[0].quantity == 2, "purchased stack lands in inventory")
	_check(vendorSignals == ["test_general"], "one vendor change signal per purchase")
	var unchanged = _findOffer(context.vendors.getVendorSnapshot("test_general").offers, "paregoric")
	_check(unchanged.available, "fixed offer remains available after purchase")

	result = context.vendors.buy("test_general", "canyon_cache_map", 1)
	_check(result.success and context.party.money == 85, "map purchase debits its price")
	_check(context.party.inventory.size() == 2, "map enters shared inventory")
	var ownedMap = _findOffer(context.vendors.getVendorSnapshot("test_general").offers, "canyon_cache_map")
	_check(!ownedMap.available and ownedMap.reason == "already_owned", "carried unrevealed map blocks another copy")
	var beforeBuy = _state(context)
	result = context.vendors.buy("test_general", "canyon_cache_map", 1)
	_check(!result.success and result.reason == "already_owned", "duplicate map purchase fails")
	_check(_state(context) == beforeBuy, "duplicate map failure is atomic")

	context.discovery.revealed["canyon_cache_map"] = true
	var revealedMap = _findOffer(context.vendors.getVendorSnapshot("test_general").offers, "canyon_cache_map")
	_check(!revealedMap.available and revealedMap.reason == "already_revealed", "revealed map is exhausted")

	context.party.money = 0
	beforeBuy = _state(context)
	result = context.vendors.buy("test_general", "paregoric", 1)
	_check(!result.success and result.reason == "insufficient_money", "insufficient money fails")
	_check(_state(context) == beforeBuy, "failed money check changes nothing")

	context.party.money = 500
	context.party.inventory[0]["quantity"] = 5
	while context.party.inventory.size() < 24:
		context.party.inventory.append({
			"instanceId": "filler_%d" % context.party.inventory.size(),
			"definitionId": "paregoric", "itemType": "consumable", "quantity": 5,
		})
	beforeBuy = _state(context)
	result = context.vendors.buy("test_general", "paregoric", 1)
	_check(!result.success and result.reason == "insufficient_capacity", "full inventory fails the exact purchase")
	_check(_state(context) == beforeBuy, "failed capacity check changes nothing")
	_freeContext(context)


func _testRolledPurchases() -> void:
	print("\n--- Rolled stock: unique one-shot offers ---")
	var context = _makeContext(7777, 1000)
	var snapshot = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(snapshot.success and snapshot.offers.size() == 4, "rolled stock has the authored count")
	var offer = snapshot.offers[0]
	var unitPrice = int(offer.unitPrice)
	var result = context.vendors.buy("test_gunsmith", offer.offerId, 1)
	_check(result.success and result.totalPrice == unitPrice, "rolled purchase charges the stored price")
	_check(context.party.money == 1000 - unitPrice, "money debited once")
	_check(context.party.inventory.size() == 1 and context.party.inventory[0].itemType == "weapon", "rolled weapon enters inventory")
	var remaining = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(remaining.offers.size() == 3 and _findOffer(remaining.offers, offer.offerId).is_empty(), "purchased offer leaves stock")
	var beforeBuy = _state(context)
	result = context.vendors.buy("test_gunsmith", offer.offerId, 1)
	_check(!result.success and result.reason == "unknown_offer", "stale offer id fails")
	_check(_state(context) == beforeBuy, "stale offer failure is atomic")
	result = context.vendors.buy("test_gunsmith", remaining.offers[0].offerId, 2)
	_check(!result.success and result.reason == "invalid_quantity", "rolled gear quantity must be one")
	_freeContext(context)

	print("\n--- Reentrant and repeated commands cannot duplicate effects ---")
	context = _makeContext(8888, 1000)
	snapshot = context.vendors.getVendorSnapshot("test_gunsmith")
	var firstId = snapshot.offers[0].offerId
	var secondId = snapshot.offers[1].offerId
	var nested = {}
	context.vendors.vendorChanged.connect(func(_vendorId): nested["result"] = context.vendors.buy("test_gunsmith", secondId, 1))
	var signalResult = context.vendors.buy("test_gunsmith", firstId, 1)
	_check(signalResult.success, "outer purchase succeeds")
	_check(nested.result.reason == "command_in_progress", "signal-driven reentrant purchase is rejected")
	_check(context.party.inventory.size() == 1, "only one item was purchased")
	_check(context.vendors.getVendorSnapshot("test_gunsmith").offers.size() == 3, "only the outer offer was removed")
	_freeContext(context)


func _testSales() -> void:
	print("\n--- Specialised sales and atomic Party commands ---")
	var context = _makeContext(3333, 100)
	var snap = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(snap.eligibleSell.is_empty(), "empty gear inventory has no sale rows")
	var soldWeapon = _addWeapon(context)
	var instanceId = soldWeapon.instanceId
	snap = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(snap.eligibleSell.size() == 1 and snap.eligibleSell[0].instanceId == instanceId, "carried weapon is sellable at the gun store")
	var salePrice = int(snap.eligibleSell[0].salePrice)
	_check(salePrice > 0, "sale quote is positive")

	var beforeSell = _state(context)
	var result = context.vendors.sell("test_outfitter", instanceId)
	_check(!result.success and result.reason == "wrong_item_type", "weapon cannot be sold to the equipment store")
	_check(_state(context) == beforeSell, "wrong-store sale changes nothing")
	result = context.vendors.sell("test_gunsmith", "starter_walker_rifle")
	_check(!result.success and result.reason == "unknown_item", "equipped gear is not in carried inventory")

	result = context.vendors.sell("test_gunsmith", instanceId)
	_check(result.success and result.salePrice == salePrice and result.money == 100 + salePrice, "sale credits the quoted price once")
	_check(context.party.inventory.is_empty(), "sold gear leaves inventory")
	_check(context.vendors.getVendorSnapshot("test_gunsmith").offers.size() == 4, "sales do not change random stock")

	var protectedWeapon = _addWeapon(context, false)
	var protectedId = protectedWeapon.instanceId
	snap = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(snap.eligibleSell.is_empty(), "unsellable gear is not eligible")
	_check(snap.unavailableSell.size() == 1 and snap.unavailableSell[0].reason == "not_sellable", "unsellable gear reports its reason")
	beforeSell = _state(context)
	result = context.vendors.sell("test_gunsmith", protectedId)
	_check(!result.success and result.reason == "not_sellable", "unsellable sale fails")
	_check(_state(context) == beforeSell, "unsellable failure is atomic")

	print("\n--- Party commerce command failure modes ---")
	var catalog = ItemCatalogScript.new()
	var bareParty = PartyScript.new()
	bareParty.configureInventory(catalog)
	bareParty.inventory = []
	bareParty.money = 10
	_check(bareParty.completePurchase([{ "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 }], 5).reason == "management_unavailable", "purchase fails closed without management")
	bareParty.setInventoryManagementAllowed(true)
	_check(bareParty.completePurchase([], 0).reason == "invalid_item", "empty purchase is invalid")
	_check(bareParty.completePurchase([{ "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 }], -1).reason == "invalid_price", "negative price is invalid")
	var purchase = bareParty.completePurchase([{ "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 }], 10)
	_check(purchase.success and bareParty.money == 0, "exact funds succeed")
	_check(bareParty.completePurchase([{ "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 }], 1).reason == "insufficient_money", "insufficient money fails before planning")
	var stack = bareParty.inventory[0]
	_check(bareParty.consumeItem(str(stack.instanceId), "map").reason == "wrong_item_type", "wrong consume type fails")
	var consume = bareParty.consumeItem(str(stack.instanceId), "consumable")
	_check(consume.success and bareParty.inventory.is_empty(), "consume removes exactly the last unit")
	_check(bareParty.completeSale("missing", 1).reason == "unknown_item", "unknown sale item fails")
	_check(bareParty.completeSale("missing", 0).reason == "invalid_price", "nonpositive sale price fails")
	bareParty.free()
	_freeContext(context)


func _testBank() -> void:
	print("\n--- Shared Bank: deposits, withdrawals and identity ---")
	var context = _makeContext(5555, 10)
	var weapon = _addWeapon(context)
	var instanceId = weapon.instanceId
	var bankSignals = []
	context.vendors.bankChanged.connect(func(): bankSignals.append(true))

	var result = context.vendors.deposit(instanceId)
	_check(result.success and result.item.instanceId == instanceId, "deposit preserves the instance id")
	_check(context.party.inventory.is_empty(), "deposit frees carried space")
	var bank = context.vendors.getBankSnapshot()
	_check(bank.bank.size() == 1 and bank.carried.is_empty(), "Bank snapshot shows the stored gear")
	_check(bank.bank[0] == weapon.item, "deposit preserves the complete rolled item")
	_check(bankSignals.size() == 1, "deposit emits one Bank signal")

	result = context.vendors.deposit(instanceId)
	_check(!result.success and result.reason == "already_stored", "stored id cannot be deposited twice")

	result = context.vendors.withdraw(instanceId)
	_check(result.success and context.party.inventory.size() == 1, "withdrawal returns gear to Party")
	_check(str(context.party.inventory[0].instanceId) == instanceId, "withdrawal preserves the id")
	_check(context.party.inventory[0] == weapon.item, "withdrawal preserves all rolled fields")
	_check(context.vendors.getBankSnapshot().bank.is_empty(), "withdrawal empties the Bank row")

	print("\n--- Bank: full inventory and invalid collections ---")
	result = context.vendors.deposit(instanceId)
	_check(result.success, "re-deposit for the full-inventory case succeeds")
	while context.party.inventory.size() < 24:
		context.party.inventory.append({
			"instanceId": "fill_%d" % context.party.inventory.size(),
			"definitionId": "paregoric", "itemType": "consumable", "quantity": 5,
		})
	var bankBefore = context.vendors.getBankSnapshot()
	result = context.vendors.withdraw(instanceId)
	_check(!result.success and result.reason == "insufficient_capacity", "full inventory blocks withdrawal")
	_check(context.vendors.getBankSnapshot() == bankBefore, "blocked withdrawal leaves the Bank unchanged")
	context.party.inventory = []
	result = context.vendors.withdraw(instanceId)
	_check(result.success, "withdrawal succeeds once space is available")

	var stack = context.party.addItem({ "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 })
	var stackId = str(stack.acceptedInstanceIds[0])
	result = context.vendors.deposit(stackId)
	_check(!result.success and result.reason == "not_equipment", "non-gear cannot be deposited")
	_check(context.party.inventory.size() == 2, "failed deposit leaves carried items unchanged")

	# A Bank row that collides with Party state is rejected before Party mutates.
	var colliding = _generateWeapon(context)
	context.party.transferGearIn(colliding)
	context.vendors._bank = [colliding.duplicate(true)]
	var collisionBefore = context.vendors.getBankSnapshot()
	result = context.vendors.withdraw(str(colliding.instanceId))
	_check(!result.success and result.reason == "duplicate_instance_id", "withdrawal rejects a duplicate carried id")
	_check(context.vendors.getBankSnapshot() == collisionBefore, "duplicate-id withdrawal leaves both collections unchanged")

	var snapshotCopy = context.vendors.getBankSnapshot()
	snapshotCopy.bank[0]["name"] = "Mutated"
	_check(context.vendors.getBankSnapshot().bank[0].name != "Mutated", "Bank snapshot is a deep copy")
	_freeContext(context)


func _testDepartureAndSnapshots() -> void:
	print("\n--- Departure reset and stock snapshots ---")
	var context = _makeContext(2468, 500)
	var first = context.vendors.getVendorSnapshot("test_gunsmith")
	var repeated = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(first.offers == repeated.offers, "repeated snapshots return the same stored offers")
	_check(context.vendors.getVendorSnapshot("test_general").offers.size() == 2, "fixed catalog is available before departure")
	var departureSignals = []
	context.vendors.departureStockChanged.connect(func(departureId): departureSignals.append(departureId))
	context.locations.departForTrail()
	_check(departureSignals == [1], "explicit departure emits one stock-change signal")
	var next = context.vendors.getVendorSnapshot("test_gunsmith")
	_check(next.offers != first.offers, "new departure produces a new selection")
	for offer in next.offers:
		_check(offer.offerId.begins_with("test_gunsmith:1:"), "new offers belong to the new departure")
	_check(context.vendors.getVendorSnapshot("test_general").offers.size() == 2, "fixed offers do not reset with departure")

	print("\n--- Export/import without regeneration ---")
	var weapon = _addWeapon(context)
	context.vendors.deposit(weapon.instanceId)
	var exported = context.vendors.exportState()
	var importedContext = _makeContext(1111, 500)
	var importResult = importedContext.vendors.importState(exported)
	_check(importResult.success, "valid exported state imports")
	var fakeGenerator = FakeStockGenerator.new()
	importedContext.vendors.stockGenerator = fakeGenerator
	var imported = importedContext.vendors.getVendorSnapshot("test_gunsmith")
	_check(imported.offers == next.offers, "imported offers are returned without regeneration")
	_check(fakeGenerator.calls == 0, "snapshot after import never calls the stock generator")
	_check(importedContext.vendors.getBankSnapshot().bank == context.vendors.getBankSnapshot().bank, "Bank state round-trips completely")
	_check(importedContext.vendors.exportState() == exported, "export/import/export is stable")

	var baseline = importedContext.vendors.exportState()
	var malformedStates = []
	var wrongVersion = exported.duplicate(true)
	wrongVersion["formatVersion"] = 999
	malformedStates.append(["wrong version", wrongVersion])
	var badOffer = exported.duplicate(true)
	badOffer.stock["test_gunsmith"].offers[0].item["itemType"] = "consumable"
	malformedStates.append(["wrong offer item type", badOffer])
	var badPrice = exported.duplicate(true)
	badPrice.stock["test_gunsmith"].offers[0]["unitPrice"] = 0
	malformedStates.append(["nonpositive offer price", badPrice])
	var unknownVendor = exported.duplicate(true)
	unknownVendor.stock["missing_vendor"] = { "departureId": 1, "stockSeed": 1, "offers": [] }
	malformedStates.append(["unknown stock vendor", unknownVendor])
	var badBank = exported.duplicate(true)
	badBank.bank.append({ "instanceId": "bad", "definitionId": "paregoric", "itemType": "consumable", "quantity": 1 })
	malformedStates.append(["non-gear Bank row", badBank])
	var duplicateBank = exported.duplicate(true)
	duplicateBank.bank.append(duplicateBank.bank[0].duplicate(true))
	malformedStates.append(["duplicate Bank ids", duplicateBank])
	var missingBank = exported.duplicate(true)
	missingBank.erase("bank")
	malformedStates.append(["missing Bank collection", missingBank])
	for entry in malformedStates:
		var result = importedContext.vendors.importState(entry[1])
		_check(!result.success and result.reason == "invalid_state", "malformed state '%s' is rejected" % entry[0])
		_check(importedContext.vendors.exportState() == baseline, "malformed state '%s' leaves live state unchanged" % entry[0])

	var collisionContext = _makeContext(2222, 500)
	var collisionItem = exported.bank[0].duplicate(true)
	collisionContext.party.transferGearIn(collisionItem)
	_check(!collisionContext.vendors.importState(exported.duplicate(true)).success, "Bank id colliding with Party rejects import")
	collisionContext.party.inventory = []

	var resetContext = _makeContext(3333, 500)
	resetContext.vendors.getVendorSnapshot("test_gunsmith")
	resetContext.vendors.deposit(_addWeapon(resetContext).instanceId)
	resetContext.vendors.resetForNewGame(424242)
	var resetState = resetContext.vendors.exportState()
	_check(resetState.stock.is_empty() and resetState.bank.is_empty(), "New Game reset clears stock and Bank")
	_check(resetState.baseSeed == 424242, "New Game reset installs the injected seed")

	_freeContext(context)
	_freeContext(importedContext)
	_freeContext(collisionContext)
	_freeContext(resetContext)


func _testNewspaperBoundary() -> void:
	print("\n--- Newspaper reports through the vendor service ---")
	var context = _makeContext(4321, 0)
	var report = context.vendors.getNewspaperReport("test_news")
	_check(report.success and report.available, "a Zone with a published pool reports")
	_check(report.zoneId == "canyon" and report.parties.size() > 0, "the report resolves the vendor's own Zone")
	_check(report.generalTips.size() > 0 and str(report.headline) != "", "the report carries the authored copy")
	_check(context.party.inventory.is_empty() and context.party.money == 0, "reading a report mutates nothing")
	_check(context.vendors.getNewspaperReport("test_news_remote").reason == "no_pool", "a Zone without a pool reports unavailable, never another Zone")
	_check(context.vendors.getNewspaperReport("test_bank").reason == "invalid_vendor", "non-newspaper vendor rejects report request")
	_check(context.vendors.getNewspaperReport("missing").reason == "unknown_vendor", "unknown vendor rejects report request")
	_freeContext(context)


func _makeContext(seed: int, money: int) -> Dictionary:
	var itemCatalog = ItemCatalogScript.new()
	var party = PartyScript.new()
	party.configureInventory(itemCatalog)
	party.inventory = []
	party._nextInstanceNumber = 1
	party.money = money
	party.setInventoryManagementAllowed(true)
	var itemGenerator = ItemGenerationScript.new()
	var locations = FakeLocations.new()
	var discovery = FakeDiscovery.new()
	var vendors = VendorsScript.new()
	vendors.configure(_makeCatalog(), party, itemGenerator, VendorPricingScript.new(), locations, seed, discovery, itemCatalog)
	return {
		"vendors": vendors,
		"party": party,
		"itemGenerator": itemGenerator,
		"locations": locations,
		"discovery": discovery,
		"gearCounter": 0,
	}


func _makeCatalog():
	var catalog = VendorCatalogScript.new()
	catalog.vendors = {
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
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 4 },
		},
		"test_outfitter": {
			"vendorId": "test_outfitter", "kind": "equipment", "displayName": "Test Outfitter",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "equipment", "count": 3 },
		},
		"test_bank": {
			"vendorId": "test_bank", "kind": "bank", "displayName": "Test Bank",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
		},
		"test_news": {
			"vendorId": "test_news", "kind": "newspaper", "displayName": "Test Newspaper",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
		},
		# A Zone with no published pool: the report must stay unavailable.
		"test_news_remote": {
			"vendorId": "test_news_remote", "kind": "newspaper", "displayName": "Test Remote Newspaper",
			"parentLocationId": "Lazysprings", "zoneId": "swamp", "roomScene": ROOM_SCENE,
		},
	}
	return catalog


func _findOffer(offers: Array, offerOrDefinitionId: String) -> Dictionary:
	for offer in offers:
		if str(offer.get("offerId", "")) == offerOrDefinitionId or str(offer.get("definitionId", "")) == offerOrDefinitionId:
			return offer
	return {}


func _generateWeapon(context: Dictionary) -> Dictionary:
	context.gearCounter += 1
	var rng = RandomNumberGenerator.new()
	rng.seed = int(context.gearCounter) * 7919
	var item = context.itemGenerator.generateWeapon({ "rarity": "common", "family": "revolver", "rng": rng })
	item["instanceId"] = "test_gear_%d" % int(context.gearCounter)
	return item


func _addWeapon(context: Dictionary, sellable := true) -> Dictionary:
	var item = _generateWeapon(context)
	item["sellable"] = sellable
	var result = context.party.addItem(item)
	var instanceId = str(result.acceptedInstanceIds[0])
	var rules = InventoryRulesScript.new()
	var index = rules.inventoryIndex(context.party.inventory, instanceId)
	return { "instanceId": instanceId, "item": context.party.inventory[index].duplicate(true) }


func _state(context: Dictionary) -> Dictionary:
	return {
		"money": context.party.money,
		"inventory": context.party.inventory.duplicate(true),
		"bank": context.vendors._bank.duplicate(true),
		"stock": context.vendors._stockByVendor.duplicate(true),
		"departureId": context.vendors._activeDepartureId,
	}


func _freeContext(context: Dictionary) -> void:
	context.vendors.free()
	context.locations.free()
	context.itemGenerator.free()
	context.party.free()


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
