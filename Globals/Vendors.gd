extends Node

## Vendor domain service (Docs/System Design/Location Vendors Implementation.md,
## patch 2): deterministic rolled stock, atomic shop commands, the shared Bank,
## and validated save snapshots. It never renders or edits Party internals; all
## money/inventory changes go through Party commands.

signal vendorChanged(vendorId: String)
signal bankChanged
signal departureStockChanged(departureId: int)

const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const VendorStockGeneratorScript = preload("res://Vendors/VendorStockGenerator.gd")
const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const NewspaperReportBuilderScript = preload("res://Vendors/NewspaperReportBuilder.gd")
const NewspaperDataScript = preload("res://Data/Vendors/NewspaperData.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")

const STATE_FORMAT_VERSION := 1
const MAX_PURCHASE_QUANTITY := 9999

var catalog = null
var party = null
var locations = null
var itemGenerator = null
var discovery = null
var stockGenerator = null
var pricing = null
var itemCatalog = null
var rules = null
## Newspaper projection collaborators (injectable for tests; production resolves
## the authored pools/copy lazily).
var reportBuilder = null
var encounterPools = null
var newspaperData = null

# Run seed. Stock derives per-vendor seeds from this; it is not the global RNG.
var baseSeed := 0

var _stockByVendor := {}
var _bank := []
var _activeDepartureId := 0
var _commandInProgress := false
var _initialized := false
var _connectedLocations = null


func _ready() -> void:
	catalog = VendorCatalogScript.new()
	pricing = VendorPricingScript.new()
	itemCatalog = ItemCatalogScript.new()
	rules = InventoryRulesScript.new()
	party = get_node_or_null("/root/Party")
	locations = get_node_or_null("/root/Locations")
	itemGenerator = get_node_or_null("/root/ItemGeneration")
	stockGenerator = VendorStockGeneratorScript.new(catalog, itemGenerator, pricing)
	if baseSeed == 0:
		baseSeed = randi()
	_activeDepartureId = _currentDepartureId()
	_connectLocations()
	_initialized = true


## Test/headless initialization seam. Installs collaborators, resets stock/Bank,
## and starts at the injected departure id. The newspaper collaborators default
## to null so production resolves the authored pools/copy lazily.
func configure(vendorCatalog = null, partyNode = null, generator = null, pricingRules = null, locationsNode = null, seedValue := 0, discoveryService = null, itemCatalogData = null, projection = null) -> void:
	catalog = vendorCatalog if vendorCatalog != null else VendorCatalogScript.new()
	party = partyNode
	itemGenerator = generator
	pricing = pricingRules if pricingRules != null else VendorPricingScript.new()
	itemCatalog = itemCatalogData if itemCatalogData != null else ItemCatalogScript.new()
	rules = InventoryRulesScript.new()
	stockGenerator = VendorStockGeneratorScript.new(catalog, itemGenerator, pricing)
	locations = locationsNode
	discovery = discoveryService
	if projection is Dictionary:
		reportBuilder = projection.get("reportBuilder", null)
		encounterPools = projection.get("encounterPools", null)
		newspaperData = projection.get("newspaperData", null)
	baseSeed = int(seedValue)
	_stockByVendor = {}
	_bank = []
	_commandInProgress = false
	_connectLocations()
	_activeDepartureId = _currentDepartureId()
	_initialized = true


func _isConfigured() -> bool:
	return _initialized and catalog != null and party != null and pricing != null and rules != null


func _connectLocations() -> void:
	if _connectedLocations == locations:
		return
	if _connectedLocations != null and is_instance_valid(_connectedLocations) and _connectedLocations.has_signal("trailDeparted") and _connectedLocations.is_connected("trailDeparted", _onTrailDeparted):
		_connectedLocations.disconnect("trailDeparted", _onTrailDeparted)
	_connectedLocations = locations
	if _connectedLocations == null:
		return
	if _connectedLocations.has_signal("trailDeparted") and !_connectedLocations.is_connected("trailDeparted", _onTrailDeparted):
		_connectedLocations.connect("trailDeparted", _onTrailDeparted)


func _onTrailDeparted(departureId) -> void:
	_applyDeparture(int(departureId))


func _currentDepartureId() -> int:
	if locations != null:
		var value = locations.get("trailDepartureId")
		if typeof(value) == TYPE_INT:
			return int(value)
	return _activeDepartureId


## Clears rolled stock when the departure cycle changed. Fixed catalogs, money,
## inventory, Bank and discovery are untouched.
func _syncDeparture() -> void:
	var current = _currentDepartureId()
	if current == _activeDepartureId:
		return
	_applyDeparture(current)


func _applyDeparture(departureId: int) -> void:
	_activeDepartureId = departureId
	_stockByVendor.clear()
	departureStockChanged.emit(departureId)


func _beginCommand() -> bool:
	_syncDeparture()
	if _commandInProgress:
		return false
	_commandInProgress = true
	return true


func _endCommand() -> void:
	_commandInProgress = false


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason }


## Catalog lookups used by navigation/room shells without exposing mutable state.
func hasVendor(vendorId: String) -> bool:
	return _isConfigured() and catalog.hasVendor(vendorId)


func getVendorDefinition(vendorId: String) -> Dictionary:
	if !_isConfigured():
		return {}
	return catalog.getVendor(vendorId)


## Deep-copied vendor view. Rolled stock is created lazily exactly once for the
## current departure; repeated snapshots never invoke the generator again.
func getVendorSnapshot(vendorId: String) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	if _commandInProgress:
		return _failure("command_in_progress")
	_syncDeparture()
	var vendor = catalog.getVendor(vendorId)
	if vendor.is_empty():
		return _failure("vendor_unavailable")
	var inventorySnapshot = party.getInventorySnapshot()
	var snapshot = {
		"success": true,
		"reason": "",
		"vendorId": vendorId,
		"kind": str(vendor.get("kind", "")),
		"vendor": vendor,
		"money": int(inventorySnapshot.get("money", party.money)),
		"capacity": int(inventorySnapshot.get("capacity", 0)),
		"used": int(inventorySnapshot.get("used", 0)),
		"offers": [],
		"eligibleSell": [],
		"unavailableSell": [],
	}
	var kind = snapshot.kind
	if kind == "general":
		snapshot["offers"] = _fixedOffers(vendorId, vendor)
	elif kind == "gun" or kind == "equipment":
		var stockResult = _ensureRolledStock(vendorId)
		if !stockResult.success:
			return stockResult
		snapshot["offers"] = stockResult.offers
		_buildSellLists(snapshot, kind, inventorySnapshot.get("items", []))
	return snapshot


func _fixedOffers(_vendorId: String, vendor: Dictionary) -> Array:
	var offers = []
	for catalogOffer in vendor.get("stock", {}).get("offers", []):
		var definitionId = str(catalogOffer.get("definitionId", ""))
		var item = _buildStackable(definitionId, 1)
		var availability = _purchaseAvailability(definitionId, item)
		offers.append({
			"offerId": str(catalogOffer.get("offerId", "")),
			"definitionId": definitionId,
			"item": item,
			"unitPrice": int(catalogOffer.get("unitPrice", 0)),
			"available": bool(availability.available),
			"reason": str(availability.reason),
		})
	return offers


func _ensureRolledStock(vendorId: String) -> Dictionary:
	_syncDeparture()
	if _stockByVendor.has(vendorId):
		var cached = _stockByVendor[vendorId]
		if int(cached.get("departureId", -1)) == _activeDepartureId:
			return {
				"success": true,
				"reason": "",
				"stockSeed": int(cached.get("stockSeed", 0)),
				"departureId": _activeDepartureId,
				"offers": cached.get("offers", []).duplicate(true),
			}
	var generated = stockGenerator.generateStock(vendorId, _activeDepartureId, baseSeed)
	if !generated.success:
		return generated
	_stockByVendor[vendorId] = {
		"departureId": _activeDepartureId,
		"stockSeed": int(generated.stockSeed),
		"offers": generated.offers.duplicate(true),
	}
	return {
		"success": true,
		"reason": "",
		"stockSeed": int(generated.stockSeed),
		"departureId": _activeDepartureId,
		"offers": generated.offers.duplicate(true),
	}


func _buildStackable(definitionId: String, quantity: int) -> Dictionary:
	if itemCatalog == null:
		return {}
	return itemCatalog.makeStackable(definitionId, quantity)


func _purchaseAvailability(definitionId: String, item: Dictionary) -> Dictionary:
	if item.is_empty():
		return { "available": false, "reason": "data_unavailable" }
	if str(item.get("itemType", "")) != "map":
		return { "available": true, "reason": "" }
	var mapId = str(item.get("effect", {}).get("mapId", ""))
	if mapId == "":
		return { "available": false, "reason": "invalid_map" }
	if _isMapFullyRevealed(mapId):
		return { "available": false, "reason": "already_revealed" }
	if _partyOwnsDefinition(definitionId):
		return { "available": false, "reason": "already_owned" }
	return { "available": true, "reason": "" }


func _isMapFullyRevealed(mapId: String) -> bool:
	var service = _discoveryService()
	if service == null or !service.has_method("isMapFullyRevealed"):
		return false
	return bool(service.isMapFullyRevealed(mapId))


## Injected Discovery wins; production resolves the autoload lazily so autoload
## registration order cannot silently disable map availability.
func _discoveryService():
	if discovery != null:
		return discovery
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Discovery")


## --- Newspaper collaborators ---------------------------------------------------

func _reportBuilder():
	if reportBuilder != null:
		return reportBuilder
	return NewspaperReportBuilderScript.new()


## Read-only pools: injected fixtures win, otherwise the authored per-Zone files
## under Data/Shootout/EncounterPools.
func _encounterPools():
	if encounterPools != null:
		return encounterPools
	var pools = EncounterPoolDataScript.new()
	pools.loadProductionPools()
	return pools


func _newspaperData():
	if newspaperData != null:
		return newspaperData
	return NewspaperDataScript.new()


static func _actorResolver() -> Callable:
	return Callable(NewspaperReportBuilderScript, "defaultActorResolver")


func _partyOwnsDefinition(definitionId: String) -> bool:
	for item in party.getInventorySnapshot().get("items", []):
		if str(item.get("definitionId", "")) == definitionId:
			return true
	return false


func _buildSellLists(snapshot: Dictionary, kind: String, items: Array) -> void:
	var expectedType = "weapon" if kind == "gun" else "equipment"
	for itemValue in items:
		if !(itemValue is Dictionary):
			continue
		var item = itemValue.duplicate(true)
		if str(item.get("itemType", "")) != expectedType:
			continue
		var instanceId = str(item.get("instanceId", ""))
		if bool(item.get("sellable", true)) == false:
			snapshot.unavailableSell.append({ "instanceId": instanceId, "item": item, "reason": "not_sellable" })
			continue
		var quote = pricing.quoteGear(item)
		if !quote.success:
			snapshot.unavailableSell.append({ "instanceId": instanceId, "item": item, "reason": str(quote.reason) })
			continue
		snapshot.eligibleSell.append({ "instanceId": instanceId, "item": item, "salePrice": int(quote.sellPrice) })


## Atomic purchase. Quantity is resolved against the vendor's authoritative
## offer; the UI never supplies a price.
func buy(vendorId: String, offerId: String, quantity: int) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	if !_beginCommand():
		return _failure("command_in_progress")
	var result = _buyInternal(vendorId, offerId, quantity)
	_endCommand()
	return result


func _buyInternal(vendorId: String, offerId: String, quantity: int) -> Dictionary:
	_syncDeparture()
	var vendor = catalog.getVendor(vendorId)
	if vendor.is_empty():
		return _failure("unknown_vendor")
	if typeof(quantity) != TYPE_INT or quantity <= 0 or quantity > MAX_PURCHASE_QUANTITY:
		return _failure("invalid_quantity")
	var kind = str(vendor.get("kind", ""))
	var item = {}
	var unitPrice = 0
	var rolled = false
	if kind == "general":
		var catalogOffer = _findFixedOffer(vendor, offerId)
		if catalogOffer.is_empty():
			return _failure("unknown_offer")
		var definitionId = str(catalogOffer.get("definitionId", ""))
		unitPrice = int(catalogOffer.get("unitPrice", 0))
		item = _buildStackable(definitionId, quantity)
		if item.is_empty():
			return _failure("invalid_item")
		var itemType = str(item.get("itemType", ""))
		if (itemType == "map" or itemType == "weapon" or itemType == "equipment") and quantity != 1:
			return _failure("invalid_quantity")
		var availability = _purchaseAvailability(definitionId, item)
		if !availability.available:
			return _failure(str(availability.reason))
	elif kind == "gun" or kind == "equipment":
		if quantity != 1:
			return _failure("invalid_quantity")
		var stockResult = _ensureRolledStock(vendorId)
		if !stockResult.success:
			return stockResult
		var offer = _findRolledOffer(stockResult.offers, offerId)
		if offer.is_empty():
			return _failure("unknown_offer")
		item = offer.item.duplicate(true)
		unitPrice = int(offer.unitPrice)
		rolled = true
	else:
		return _failure("invalid_vendor")
	if typeof(unitPrice) != TYPE_INT or unitPrice <= 0:
		return _failure("invalid_price")
	var totalPrice = unitPrice * quantity
	if totalPrice < unitPrice:
		return _failure("invalid_price")
	var purchase = party.completePurchase([item], totalPrice)
	if !purchase.success:
		return purchase
	if rolled:
		_removeRolledOffer(vendorId, offerId)
	vendorChanged.emit(vendorId)
	purchase["offerId"] = offerId
	purchase["unitPrice"] = unitPrice
	purchase["totalPrice"] = totalPrice
	return purchase


func _findFixedOffer(vendor: Dictionary, offerId: String) -> Dictionary:
	for offer in vendor.get("stock", {}).get("offers", []):
		if str(offer.get("offerId", "")) == offerId:
			return offer
	return {}


func _findRolledOffer(offers: Array, offerId: String) -> Dictionary:
	for offerValue in offers:
		if offerValue is Dictionary and str(offerValue.get("offerId", "")) == offerId:
			return offerValue
	return {}


func _removeRolledOffer(vendorId: String, offerId: String) -> void:
	if !_stockByVendor.has(vendorId):
		return
	var offers = _stockByVendor[vendorId].get("offers", [])
	for index in offers.size():
		if str(offers[index].get("offerId", "")) == offerId:
			offers.remove_at(index)
			return


## Atomic sale. The specialist category and sellable policy are enforced here;
## Party removes exactly one carried gear instance and credits the quote once.
func sell(vendorId: String, instanceId: String) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	if !_beginCommand():
		return _failure("command_in_progress")
	var result = _sellInternal(vendorId, instanceId)
	_endCommand()
	return result


func _sellInternal(vendorId: String, instanceId: String) -> Dictionary:
	var vendor = catalog.getVendor(vendorId)
	if vendor.is_empty():
		return _failure("unknown_vendor")
	var kind = str(vendor.get("kind", ""))
	if kind != "gun" and kind != "equipment":
		return _failure("invalid_vendor")
	var expectedType = "weapon" if kind == "gun" else "equipment"
	var item = _findCarriedItem(instanceId)
	if item.is_empty():
		return _failure("unknown_item")
	if str(item.get("itemType", "")) != expectedType:
		return _failure("wrong_item_type")
	if bool(item.get("sellable", true)) == false:
		return _failure("not_sellable")
	var quote = pricing.quoteGear(item)
	if !quote.success:
		return _failure(str(quote.reason))
	var sale = party.completeSale(instanceId, int(quote.sellPrice))
	if !sale.success:
		return sale
	vendorChanged.emit(vendorId)
	sale["salePrice"] = int(quote.sellPrice)
	return sale


func _findCarriedItem(instanceId: String) -> Dictionary:
	for item in party.getInventorySnapshot().get("items", []):
		if item is Dictionary and str(item.get("instanceId", "")) == instanceId:
			return item.duplicate(true)
	return {}


## Shared Bank + carried gear view. The Bank is global, not per vendor.
func getBankSnapshot() -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	var inventorySnapshot = party.getInventorySnapshot()
	return {
		"success": true,
		"reason": "",
		"bank": _bank.duplicate(true),
		"carried": _carriedGear(inventorySnapshot.get("items", [])),
		"capacity": int(inventorySnapshot.get("capacity", 0)),
		"used": int(inventorySnapshot.get("used", 0)),
		"money": int(inventorySnapshot.get("money", party.money)),
	}


func _carriedGear(items: Array) -> Array:
	var gear = []
	for itemValue in items:
		if itemValue is Dictionary and rules.isValidGearEntry(itemValue):
			gear.append(itemValue.duplicate(true))
	return gear


## Moves one carried gear instance into the shared Bank, preserving everything.
func deposit(instanceId: String) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	if !_beginCommand():
		return _failure("command_in_progress")
	var result = _depositInternal(instanceId)
	_endCommand()
	return result


func _depositInternal(instanceId: String) -> Dictionary:
	if _bankHasInstance(instanceId):
		return _failure("already_stored")
	var item = _findCarriedItem(instanceId)
	if item.is_empty():
		return _failure("unknown_item")
	if !rules.isValidGearEntry(item):
		return _failure("not_equipment")
	var transfer = party.transferGearOut(instanceId)
	if !transfer.success:
		return transfer
	_bank.append(transfer.item.duplicate(true))
	bankChanged.emit()
	return { "success": true, "reason": "", "instanceId": instanceId, "item": transfer.item.duplicate(true) }


## Moves one stored gear instance back to Party when it fits.
func withdraw(instanceId: String) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	if !_beginCommand():
		return _failure("command_in_progress")
	var result = _withdrawInternal(instanceId)
	_endCommand()
	return result


func _withdrawInternal(instanceId: String) -> Dictionary:
	var index = _bankIndex(instanceId)
	if index < 0:
		return _failure("unknown_item")
	var item = _bank[index]
	if !rules.isValidGearEntry(item):
		return _failure("invalid_item")
	if party.hasInstanceId(instanceId):
		return _failure("duplicate_instance_id")
	var transfer = party.transferGearIn(item)
	if !transfer.success:
		return transfer
	_bank.remove_at(index)
	bankChanged.emit()
	return { "success": true, "reason": "", "instanceId": instanceId, "item": item.duplicate(true) }


func _bankIndex(instanceId: String) -> int:
	for index in _bank.size():
		if str(_bank[index].get("instanceId", "")) == instanceId:
			return index
	return -1


func _bankHasInstance(instanceId: String) -> bool:
	return _bankIndex(instanceId) >= 0


## Newspaper reports arrive in patch 6. The service exposes the call now and
## fails closed until real Zone pools/editorial exist.
func getNewspaperReport(vendorId: String) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	var vendor = catalog.getVendor(vendorId)
	if vendor.is_empty():
		return _failure("unknown_vendor")
	if str(vendor.get("kind", "")) != "newspaper":
		return _failure("invalid_vendor")
	var zoneId := str(vendor.get("zoneId", ""))
	if zoneId == "":
		return _failure("data_unavailable")
	# The report resolves the vendor's own Zone only; there is no fallback Zone.
	var report = _reportBuilder().buildReport(zoneId, _encounterPools(), _actorResolver(), _newspaperData())
	if !(report is Dictionary):
		return _failure("data_unavailable")
	return report.duplicate(true)


## Clears vendor runtime state for New Game. A zero seed chooses a fresh run seed
## so a new game does not repeat the same stock; tests pass an explicit seed.
func resetForNewGame(seedValue := 0) -> void:
	_stockByVendor = {}
	_bank = []
	_activeDepartureId = _currentDepartureId()
	baseSeed = int(seedValue) if int(seedValue) != 0 else randi()
	vendorChanged.emit("")
	bankChanged.emit()
	departureStockChanged.emit(_activeDepartureId)


## Stable save payload. Stock is stored explicitly and loading never regenerates
## it. Offer and Bank order is preserved.
func exportState() -> Dictionary:
	_syncDeparture()
	var stock = {}
	var vendorIds = _stockByVendor.keys()
	vendorIds.sort()
	for vendorIdValue in vendorIds:
		var vendorId = str(vendorIdValue)
		var entry = _stockByVendor[vendorId]
		stock[vendorId] = {
			"departureId": int(entry.get("departureId", 0)),
			"stockSeed": int(entry.get("stockSeed", 0)),
			"offers": entry.get("offers", []).duplicate(true),
		}
	return {
		"formatVersion": STATE_FORMAT_VERSION,
		"baseSeed": baseSeed,
		"activeDepartureId": _currentDepartureId(),
		"stock": stock,
		"bank": _bank.duplicate(true),
	}


## Validates the whole payload before committing anything. Malformed state
## leaves current stock, Bank, seed and departure untouched.
func importState(state) -> Dictionary:
	if !_isConfigured():
		return _failure("data_unavailable")
	if !(state is Dictionary):
		return _failure("invalid_state")
	if int(state.get("formatVersion", -1)) != STATE_FORMAT_VERSION:
		return _failure("invalid_state")
	var newBaseSeed = state.get("baseSeed", null)
	var newDepartureId = state.get("activeDepartureId", null)
	var stockValue = state.get("stock", null)
	var bankValue = state.get("bank", null)
	if typeof(newBaseSeed) != TYPE_INT or typeof(newDepartureId) != TYPE_INT or int(newDepartureId) < 0:
		return _failure("invalid_state")
	if !(stockValue is Dictionary) or !(bankValue is Array):
		return _failure("invalid_state")

	var validatedStock = {}
	for vendorIdValue in stockValue:
		var vendorId = str(vendorIdValue)
		var vendor = catalog.getVendor(vendorId)
		if vendor.is_empty() or !catalog.ROLLED_KINDS.has(str(vendor.get("kind", ""))):
			return _failure("invalid_state")
		var entry = stockValue[vendorIdValue]
		if !(entry is Dictionary):
			return _failure("invalid_state")
		var departureId = entry.get("departureId", null)
		var stockSeed = entry.get("stockSeed", null)
		var offersValue = entry.get("offers", null)
		if typeof(departureId) != TYPE_INT or int(departureId) < 0 or typeof(stockSeed) != TYPE_INT or !(offersValue is Array):
			return _failure("invalid_state")
		var expectedType = str(vendor.get("stock", {}).get("itemType", ""))
		var seenOffers = {}
		var validatedOffers = []
		for offerValue in offersValue:
			if !(offerValue is Dictionary):
				return _failure("invalid_state")
			var offerId = str(offerValue.get("offerId", ""))
			var unitPrice = offerValue.get("unitPrice", null)
			var item = offerValue.get("item", null)
			if offerId == "" or seenOffers.has(offerId):
				return _failure("invalid_state")
			seenOffers[offerId] = true
			if typeof(unitPrice) != TYPE_INT or int(unitPrice) <= 0:
				return _failure("invalid_state")
			if !rules.isValidGear(item) or str(item.get("itemType", "")) != expectedType:
				return _failure("invalid_state")
			validatedOffers.append({
				"offerId": offerId,
				"item": (item as Dictionary).duplicate(true),
				"unitPrice": int(unitPrice),
			})
		validatedStock[vendorId] = {
			"departureId": int(departureId),
			"stockSeed": int(stockSeed),
			"offers": validatedOffers,
		}

	var validatedBank = []
	var seenBankIds = {}
	for itemValue in bankValue:
		if !rules.isValidGearEntry(itemValue):
			return _failure("invalid_state")
		var instanceId = str((itemValue as Dictionary).get("instanceId", ""))
		if seenBankIds.has(instanceId) or party.hasInstanceId(instanceId):
			return _failure("invalid_state")
		seenBankIds[instanceId] = true
		validatedBank.append((itemValue as Dictionary).duplicate(true))

	baseSeed = int(newBaseSeed)
	_stockByVendor = validatedStock
	_bank = validatedBank
	if locations != null and locations.has_method("restoreTrailDepartureId"):
		locations.restoreTrailDepartureId(int(newDepartureId))
	_activeDepartureId = int(newDepartureId)
	vendorChanged.emit("")
	bankChanged.emit()
	departureStockChanged.emit(_activeDepartureId)
	return { "success": true, "reason": "" }
