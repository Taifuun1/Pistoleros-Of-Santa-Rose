extends SceneTree

## Headless validation for deterministic vendor stock generation (Docs/System
## Design/Location Vendors Implementation.md, patch 2).
## Run with: godot --headless --script res://Tests/TestVendorStock.gd

const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorStockGeneratorScript = preload("res://Vendors/VendorStockGenerator.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")

const ROOM_SCENE := "res://UI/Journal/Journal.tscn"

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog = _makeCatalog()
	var itemGenerator = ItemGenerationScript.new()
	var generator = VendorStockGeneratorScript.new(catalog, itemGenerator, VendorPricingScript.new())

	print("--- Rolled stock determinism ---")
	var first = generator.generateStock("test_gunsmith", 0, 12345)
	var second = generator.generateStock("test_gunsmith", 0, 12345)
	_check(first.success and second.success, "valid vendor generates stock")
	_check(first == second, "same seed/departure/vendor produces identical stock")
	_check(first.offers.size() == 6, "count controls offer quantity")
	_check(first.stockSeed == generator.stockSeedFor(12345, 0, "test_gunsmith"), "result exposes the derived seed")
	var offerIds = {}
	for offer in first.offers:
		_check(!offerIds.has(offer.offerId), "offer ids are unique")
		offerIds[offer.offerId] = true
		_check(offer.offerId == "test_gunsmith:0:%d" % (offerIds.size() - 1), "offer id is vendor:departure:index")
		_check(offer.item.itemType == "weapon", "gun vendor rolls weapons")
		_check(offer.item.zone == "canyon", "rolled item carries the vendor Zone")
		_check(typeof(offer.unitPrice) == TYPE_INT and offer.unitPrice > 0, "offers are priced")
	var third = generator.generateStock("test_gunsmith", 1, 12345)
	_check(third.success and third != first, "a new departure changes the selection")
	var otherVendor = generator.generateStock("test_equipment", 0, 12345)
	_check(otherVendor.success and otherVendor != first, "a different vendor gets a different selection")
	_check(otherVendor.offers[0].item.itemType == "equipment", "equipment vendor rolls equipment")

	print("\n--- Injected RNG leaves global RNG untouched ---")
	seed(777)
	var expectedGlobal = randi()
	seed(777)
	generator.generateStock("test_gunsmith", 2, 999)
	_check(randi() == expectedGlobal, "stock generation never advances the global RNG")

	print("\n--- Invalid labels fail closed ---")
	_check(!generator.generateStock("missing", 0, 1).success, "unknown vendor fails")
	_check(generator.generateStock("test_general", 0, 1).reason == "invalid_vendor", "fixed vendor cannot roll stock")
	_check(generator.generateStock("bad_count", 0, 1).reason == "invalid_stock", "zero count fails")
	_check(generator.generateStock("bad_type", 0, 1).reason == "invalid_stock", "wrong rolled item type fails")
	var unconfigured = VendorStockGeneratorScript.new()
	_check(unconfigured.generateStock("test_gunsmith", 0, 1).reason == "data_unavailable", "missing collaborators fail closed")

	itemGenerator.free()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _makeCatalog():
	var catalog = VendorCatalogScript.new()
	catalog.vendors = {
		"test_gunsmith": {
			"vendorId": "test_gunsmith", "kind": "gun", "displayName": "Test Gunsmith",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 6 },
		},
		"test_equipment": {
			"vendorId": "test_equipment", "kind": "equipment", "displayName": "Test Outfitter",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "equipment", "count": 4 },
		},
		"test_general": {
			"vendorId": "test_general", "kind": "general", "displayName": "Test General",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "fixed", "offers": [
				{ "offerId": "paregoric", "definitionId": "paregoric", "unitPrice": 20 },
			] },
		},
		"bad_count": {
			"vendorId": "bad_count", "kind": "gun", "displayName": "Bad Count",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 0 },
		},
		"bad_type": {
			"vendorId": "bad_type", "kind": "equipment", "displayName": "Bad Type",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 2 },
		},
	}
	return catalog


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
