extends RefCounted
class_name VendorCatalog

## Stable vendor definitions (Docs/System Design/Location Vendors
## Implementation.md, Vendor catalog). Production vendors cover the Lazysprings
## resupply street; later towns add their own entries, and tests inject fixtures.
## Display names are never keys, and stock rules reference only known Zone ids,
## item definitions and room scenes.

const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")

const KINDS = ["general", "gun", "equipment", "bank", "newspaper"]
const FIXED_KINDS = ["general"]
const ROLLED_KINDS = ["gun", "equipment"]
const NO_STOCK_KINDS = ["bank", "newspaper"]
const ROLLED_ITEM_TYPE = { "gun": "weapon", "equipment": "equipment" }

## Production vendors: the Lazysprings resupply street. Each kind maps to its
## authored interior (patch 4); later towns add their own entries.
var vendors = {
	"lazysprings_general": {
		"vendorId": "lazysprings_general",
		"kind": "general",
		"displayName": "Lazysprings General Store",
		"parentLocationId": "Lazysprings",
		"zoneId": "wild_west",
		"roomScene": "res://Location/Vendors/Interiors/LazyspringsGeneralStore.tscn",
		"stock": { "mode": "fixed", "offers": [
			{ "offerId": "paregoric", "definitionId": "paregoric", "unitPrice": 20 },
			{ "offerId": "canyon_cache_map", "definitionId": "canyon_cache_map", "unitPrice": 75 },
		] },
	},
	"lazysprings_gunsmith": {
		"vendorId": "lazysprings_gunsmith",
		"kind": "gun",
		"displayName": "Lazysprings Gunsmith",
		"parentLocationId": "Lazysprings",
		"zoneId": "wild_west",
		"roomScene": "res://Location/Vendors/Interiors/LazyspringsGunsmith.tscn",
		"stock": { "mode": "rolled", "itemType": "weapon", "count": 6 },
	},
	"lazysprings_outfitter": {
		"vendorId": "lazysprings_outfitter",
		"kind": "equipment",
		"displayName": "Lazysprings Outfitter",
		"parentLocationId": "Lazysprings",
		"zoneId": "wild_west",
		"roomScene": "res://Location/Vendors/Interiors/LazyspringsOutfitter.tscn",
		"stock": { "mode": "rolled", "itemType": "equipment", "count": 5 },
	},
	"lazysprings_bank": {
		"vendorId": "lazysprings_bank",
		"kind": "bank",
		"displayName": "Lazysprings Bank",
		"parentLocationId": "Lazysprings",
		"zoneId": "wild_west",
		"roomScene": "res://Location/Vendors/Interiors/LazyspringsBank.tscn",
	},
	"lazysprings_gazette": {
		"vendorId": "lazysprings_gazette",
		"kind": "newspaper",
		"displayName": "Lazysprings Gazette",
		"parentLocationId": "Lazysprings",
		"zoneId": "wild_west",
		"roomScene": "res://Location/Vendors/Interiors/LazyspringsGazette.tscn",
	},
}


func hasVendor(vendorId: String) -> bool:
	return vendors.has(vendorId)


func getVendor(vendorId: String) -> Dictionary:
	if !vendors.has(vendorId):
		return {}
	return vendors[vendorId].duplicate(true)


func getFixedOffers(vendorId: String) -> Array:
	if !vendors.has(vendorId):
		return []
	return vendors[vendorId].get("stock", {}).get("offers", []).duplicate(true)


## Validates the catalog and its injected data dependencies. Recognized
## dependency keys: zoneCatalog, itemCatalog, secretMapData, mapData.
func validate(dependencies := {}) -> Array:
	var errors = []
	var zoneCatalog = dependencies.get("zoneCatalog", null)
	if zoneCatalog == null:
		zoneCatalog = ZoneCatalogScript.new()
	var itemCatalog = dependencies.get("itemCatalog", null)
	if itemCatalog == null:
		itemCatalog = ItemCatalogScript.new()
	var secretMapData = dependencies.get("secretMapData", null)
	if secretMapData == null:
		secretMapData = SecretMapDataScript.new()
	var mapData = dependencies.get("mapData", null)

	errors.append_array(zoneCatalog.validate())
	errors.append_array(itemCatalog.validate())
	errors.append_array(secretMapData.validate(itemCatalog, mapData))

	for vendorId in vendors:
		var vendor = vendors[vendorId]
		if !(vendor is Dictionary):
			errors.append("vendor '%s' must be a Dictionary" % vendorId)
			continue
		if str(vendor.get("vendorId", "")) != vendorId:
			errors.append("vendor '%s': vendorId must match its key" % vendorId)
		var kind = str(vendor.get("kind", ""))
		if !KINDS.has(kind):
			errors.append("vendor '%s': unknown kind '%s'" % [vendorId, kind])
		if str(vendor.get("displayName", "")) == "":
			errors.append("vendor '%s': missing displayName" % vendorId)
		if str(vendor.get("parentLocationId", "")) == "":
			errors.append("vendor '%s': missing parentLocationId" % vendorId)
		var zoneId = str(vendor.get("zoneId", ""))
		if !zoneCatalog.hasZone(zoneId):
			errors.append("vendor '%s': unknown Zone id '%s'" % [vendorId, zoneId])
		var roomScene = str(vendor.get("roomScene", ""))
		if !roomScene.begins_with("res://") or !ResourceLoader.exists(roomScene):
			errors.append("vendor '%s': room scene does not exist" % vendorId)
		errors.append_array(_validateStock(vendorId, kind, vendor.get("stock", null), itemCatalog, secretMapData))
	return errors


func _validateStock(vendorId: String, kind: String, stock, itemCatalog, secretMapData) -> Array:
	var errors = []
	var prefix = "vendor '%s' stock" % vendorId
	if NO_STOCK_KINDS.has(kind):
		if stock != null:
			errors.append("%s: %s vendors must not declare stock" % [prefix, kind])
		return errors
	if !(stock is Dictionary):
		errors.append("%s: must be a Dictionary" % prefix)
		return errors
	var mode = str(stock.get("mode", ""))
	if FIXED_KINDS.has(kind):
		if mode != "fixed":
			errors.append("%s: %s vendors require mode 'fixed'" % [prefix, kind])
			return errors
		errors.append_array(_validateFixedOffers(prefix, stock, itemCatalog, secretMapData))
		return errors
	if ROLLED_KINDS.has(kind):
		if mode != "rolled":
			errors.append("%s: %s vendors require mode 'rolled'" % [prefix, kind])
			return errors
		var expectedType = ROLLED_ITEM_TYPE[kind]
		var itemType = str(stock.get("itemType", ""))
		if itemType != expectedType:
			errors.append("%s: %s vendors require itemType '%s'" % [prefix, kind, expectedType])
		var count = stock.get("count", null)
		if typeof(count) != TYPE_INT or int(count) <= 0:
			errors.append("%s: count must be a positive integer" % prefix)
		return errors
	errors.append("%s: unsupported vendor kind '%s'" % [prefix, kind])
	return errors


func _validateFixedOffers(prefix: String, stock: Dictionary, itemCatalog, secretMapData) -> Array:
	var errors = []
	var offers = stock.get("offers", null)
	if !(offers is Array) or offers.is_empty():
		errors.append("%s: fixed stock requires a non-empty offers Array" % prefix)
		return errors
	var seenOffers = {}
	for index in offers.size():
		var offer = offers[index]
		if !(offer is Dictionary):
			errors.append("%s offer %d: must be a Dictionary" % [prefix, index])
			continue
		var offerId = str(offer.get("offerId", ""))
		if offerId == "":
			errors.append("%s offer %d: missing offerId" % [prefix, index])
		elif seenOffers.has(offerId):
			errors.append("%s: duplicate offerId '%s'" % [prefix, offerId])
		seenOffers[offerId] = true
		var definitionId = str(offer.get("definitionId", ""))
		if definitionId == "" or !itemCatalog.hasDefinition(definitionId):
			errors.append("%s offer '%s': unknown item definition" % [prefix, offerId])
		elif itemCatalog.getDefinition(definitionId).get("itemType", "") == "map":
			var mapId = str(itemCatalog.getDefinition(definitionId).get("effect", {}).get("mapId", ""))
			if !secretMapData.hasMap(mapId):
				errors.append("%s offer '%s': map definition '%s' has no reveal data" % [prefix, offerId, mapId])
		var unitPrice = offer.get("unitPrice", null)
		if typeof(unitPrice) != TYPE_INT or int(unitPrice) <= 0:
			errors.append("%s offer '%s': unitPrice must be a positive integer" % [prefix, offerId])
	return errors
