extends RefCounted
class_name VendorStockGenerator

## Deterministic rolled vendor stock (Docs/System Design/Location Vendors
## Implementation.md, Stock generation and trail departure). The seed derives
## only from the injected base seed, the departure id and the stable vendor id;
## generation uses a local RandomNumberGenerator and never the global RNG.

var catalog = null
var itemGenerator = null
var pricing = null


func _init(vendorCatalog = null, generator = null, pricingRules = null) -> void:
	catalog = vendorCatalog
	itemGenerator = generator
	pricing = pricingRules


## Returns {success, reason, stockSeed, departureId, itemType, offers}.
func generateStock(vendorId: String, departureId: int, baseSeed: int) -> Dictionary:
	if catalog == null or itemGenerator == null or pricing == null:
		return _failure("data_unavailable")
	var vendor = catalog.getVendor(vendorId)
	if vendor.is_empty():
		return _failure("unknown_vendor")
	var kind = str(vendor.get("kind", ""))
	if kind != "gun" and kind != "equipment":
		return _failure("invalid_vendor")
	var stock = vendor.get("stock", {})
	if !(stock is Dictionary) or str(stock.get("mode", "")) != "rolled":
		return _failure("invalid_stock")
	var itemType = str(stock.get("itemType", ""))
	if itemType != "weapon" and itemType != "equipment":
		return _failure("invalid_stock")
	var expectedKindType = "weapon" if kind == "gun" else "equipment"
	if itemType != expectedKindType:
		return _failure("invalid_stock")
	var count = stock.get("count", null)
	if typeof(count) != TYPE_INT or int(count) <= 0:
		return _failure("invalid_stock")
	var zoneId = str(vendor.get("zoneId", ""))
	if zoneId == "":
		return _failure("invalid_vendor")

	var stockSeed = stockSeedFor(baseSeed, departureId, vendorId)
	var rng = RandomNumberGenerator.new()
	rng.seed = stockSeed
	var offers = []
	for index in int(count):
		var item = itemGenerator.generateItem({
			"itemType": itemType,
			"zone": zoneId,
			"rng": rng,
		})
		if !(item is Dictionary) or item.is_empty():
			return _failure("generation_failed")
		var quote = pricing.quoteGear(item)
		if !quote.success:
			return _failure(str(quote.reason))
		offers.append({
			"offerId": "%s:%d:%d" % [vendorId, departureId, index],
			"item": item,
			"unitPrice": int(quote.buyPrice),
		})
	return {
		"success": true,
		"reason": "",
		"stockSeed": stockSeed,
		"departureId": departureId,
		"itemType": itemType,
		"offers": offers,
	}


## Deterministic 64-bit seed for one vendor/departure pair. Integer arithmetic
## stays within signed-64 range for normal counters and 32-bit base seeds.
func stockSeedFor(baseSeed: int, departureId: int, vendorId: String) -> int:
	return (baseSeed * 73856093) ^ (departureId * 19349663) ^ int(vendorId.hash())


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason, "stockSeed": 0, "departureId": 0, "itemType": "", "offers": [] }
