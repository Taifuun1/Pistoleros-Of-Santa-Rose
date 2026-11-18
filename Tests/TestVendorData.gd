extends SceneTree

## Headless validation for the Location vendor data foundations (Docs/System
## Design/Location Vendors Implementation.md, patch 1): item/map/Zone/vendor
## schemas, cross-data references and the pricing value model.
## Run with: godot --headless --script res://Tests/TestVendorData.gd

const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")
const NewspaperDataScript = preload("res://Data/Vendors/NewspaperData.gd")

const ROOM_SCENE := "res://UI/Journal/Journal.tscn"
const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var zoneCatalog = ZoneCatalogScript.new()
	var itemCatalog = ItemCatalogScript.new()
	var secretMaps = SecretMapDataScript.new()
	var mapData = load(MAP_MANIFEST)

	print("--- Production data lint ---")
	var catalog = VendorCatalogScript.new()
	_check(catalog.validate({ "zoneCatalog": zoneCatalog, "itemCatalog": itemCatalog, "secretMapData": secretMaps, "mapData": mapData }).is_empty(), "production vendor data validates")
	_testItemCatalog(itemCatalog)
	_testSecretMaps(secretMaps, itemCatalog, mapData)
	_testEncounterPools(zoneCatalog)
	_testNewspaperData(zoneCatalog, _authoredPools())
	_testVendorFixtures(zoneCatalog, itemCatalog, secretMaps, mapData)
	_testPricing()
	_testMapInventory()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _encounterNames() -> Array:
	var names := []
	for fileName in DirAccess.get_files_at("res://Data/Shootout/Encounters"):
		if fileName.ends_with(".gd"):
			names.append(fileName.get_basename())
	return names


func _authoredPools():
	var pools = EncounterPoolDataScript.new()
	pools.loadProductionPools()
	return pools


func _testItemCatalog(itemCatalog) -> void:
	print("\n--- Item catalog functional definitions ---")
	_check(itemCatalog.validate().is_empty(), "item catalog validates: %s" % [itemCatalog.validate()])
	var combatNames = {}
	for fileName in DirAccess.get_files_at("res://Data/Shootout/Items"):
		if !fileName.ends_with(".gd"):
			continue
		var entry = load("res://Data/Shootout/Items/" + fileName).new()
		combatNames[str(entry.data.get("name", ""))] = true
		entry.free()
	for definitionId in itemCatalog.definitions:
		var definition = itemCatalog.getDefinition(definitionId)
		if definition.itemType == "consumable":
			_check(combatNames.has(definition.combatId), "consumable '%s' resolves combat item '%s'" % [definitionId, definition.combatId])
	_check(itemCatalog.getDefinition("multi_heal").combatId == "multiHeal", "Doctor's Kit maps to the MultiHeal combat item")
	_check(itemCatalog.getDefinition("canyon_cache_map").itemType == "map", "map item type is supported")

	var broken = ItemCatalogScript.new()
	broken.definitions["bad_map"] = {
		"definitionId": "bad_map", "itemType": "map", "name": "Bad Map", "category": "maps",
		"description": "Invalid fixture.", "stackLimit": 1, "droppable": true, "sprite": "",
		"effect": { "kind": "reveal_map", "mapId": "" },
	}
	_check(!broken.validate().is_empty(), "map without mapId fails item validation")
	broken = ItemCatalogScript.new()
	broken.definitions["paregoric"]["combatId"] = ""
	_check(!broken.validate().is_empty(), "consumable without combatId fails item validation")


func _testSecretMaps(secretMaps, itemCatalog, mapData) -> void:
	print("\n--- Secret maps ---")
	_check(secretMaps.validate(itemCatalog, mapData).is_empty(), "production secret maps validate: %s" % [secretMaps.validate(itemCatalog, mapData)])
	var targets = secretMaps.getMapTargets("canyon_cache_map")
	_check(!targets.is_empty(), "production map has authored targets")
	for target in targets:
		_check(!mapData.resolveLocation(target.targetId).is_empty(), "map target '%s' resolves in the manifest" % target.targetId)
		# Only manifest Locations authored as secret are revealable.
		var entry: Dictionary = mapData.resolveSecretLocation(target.targetId)
		_check(!entry.is_empty() and str(entry.get("secret_id", "")) == target.targetId, "map target '%s' is authored as a secret Location" % target.targetId)
	var alwaysVisible = SecretMapDataScript.new()
	alwaysVisible.maps["always_map"] = { "mapId": "always_map", "targetIds": ["Lazysprings"] }
	alwaysVisible.targets["Lazysprings"] = { "targetId": "Lazysprings", "kind": "location", "displayName": "Lazysprings", "icon": "secret_location" }
	_check(!alwaysVisible.validate(itemCatalog, mapData).is_empty(), "revealing an always-visible Location fails lint")

	var badMap = SecretMapDataScript.new()
	badMap.maps["broken"] = { "mapId": "broken", "targetIds": ["missing_target"] }
	badMap.maps["dup"] = { "mapId": "dup", "targetIds": ["missing_target", "missing_target"] }
	_check(!badMap.validate(itemCatalog, mapData).is_empty(), "unknown/duplicate targets fail map validation")

	var badItem = ItemCatalogScript.new()
	badItem.definitions["canyon_cache_map"]["effect"]["mapId"] = "does_not_exist"
	_check(!secretMaps.validate(badItem, mapData).is_empty(), "item reveal referencing a missing map fails cross-data lint")

	var secretItem = SecretMapDataScript.new()
	secretItem.targets["cache_one"] = { "targetId": "cache_one", "kind": "secret_item", "displayName": "Cache", "icon": "secret_item", "chunk": Vector2i(3, 14), "tile": Vector2i(40, 40), "reward": "paregoric" }
	secretItem.maps["cache_map"] = { "mapId": "cache_map", "targetIds": ["cache_one"] }
	_check(secretItem.validate(null, null).is_empty(), "valid secret-item target passes schema lint")
	secretItem.targets["cache_one"]["tile"] = Vector2i(99, 99)
	_check(!secretItem.validate(null, null).is_empty(), "out-of-chunk secret-item tile fails lint")


func _testEncounterPools(zoneCatalog) -> void:
	print("\n--- Encounter-pool schema ---")
	var productionPools = EncounterPoolDataScript.new()
	var authoredErrors := productionPools.validateAuthoredPools(zoneCatalog, _encounterNames())
	_check(authoredErrors.is_empty(), "authored Zone pools validate: %s" % [authoredErrors])
	_check(!productionPools.pools.is_empty(), "at least one Zone publishes a pool")
	_check(productionPools.getEntries("swamp").is_empty() and productionPools.getPublicEntries("swamp").is_empty(), "missing pools never fall back to a default encounter")

	var pools = EncounterPoolDataScript.new()
	pools.pools["canyon"] = { "zoneId": "canyon", "entries": [
		{ "encounter": "res://Data/Shootout/Encounters/RatAmbush.gd", "weight": 1 },
		{ "encounter": "res://Data/Shootout/Encounters/RatAmbush.gd", "weight": 2, "newspaperPublic": false },
	] }
	_check(pools.validate(zoneCatalog, ["RatAmbush"]).is_empty(), "valid pool fixture passes lint")
	_check(pools.getPublicEntries("canyon").size() == 1, "newspaperPublic=false entries are excluded from reports")

	var badPools = EncounterPoolDataScript.new()
	badPools.pools["unknown_zone"] = { "zoneId": "unknown_zone", "entries": [{ "encounter": "res://missing.gd", "weight": 0 }] }
	_check(!badPools.validate(zoneCatalog, []).is_empty(), "unknown Zone, missing encounter and zero weight fail lint")


func _testNewspaperData(zoneCatalog, encounterPools) -> void:
	print("\n--- Newspaper copy ---")
	var copy = NewspaperDataScript.new()
	var errors := copy.validate(zoneCatalog, encounterPools)
	_check(errors.is_empty(), "authored newspaper copy validates: %s" % [errors])
	_check(copy.hasZone("canyon") and copy.getHeadline("canyon") != "" and copy.getEditorial("canyon") != "", "the canyon Zone has a headline and editorial")
	_check(!copy.getGeneralTips("canyon").is_empty(), "the canyon Zone has general tips")
	for entry in encounterPools.getPublicEntries("canyon"):
		var encounterId := str(entry.get("encounter", "")).get_file().get_basename()
		_check(!copy.getEncounterTips("canyon", encounterId).is_empty(), "published encounter '%s' has authored tips" % encounterId)

	var badCopy = NewspaperDataScript.new()
	badCopy.zones["missing_zone"] = { "zoneId": "missing_zone", "headline": "H", "editorial": "E" }
	_check(!badCopy.validate(zoneCatalog, null).is_empty(), "an unknown Zone fails copy lint")
	badCopy = NewspaperDataScript.new()
	badCopy.zones["canyon"]["headline"] = ""
	_check(!badCopy.validate(zoneCatalog, null).is_empty(), "a missing headline fails copy lint")
	badCopy = NewspaperDataScript.new()
	badCopy.zones["canyon"]["generalTips"] = [""]
	_check(!badCopy.validate(zoneCatalog, null).is_empty(), "an empty tip fails copy lint")
	badCopy = NewspaperDataScript.new()
	badCopy.zones["canyon"]["encounterTips"] = { "DoesNotExist": ["tip"] }
	_check(!badCopy.validate(zoneCatalog, encounterPools).is_empty(), "tips for an unpublished encounter fail copy lint")


func _testVendorFixtures(zoneCatalog, itemCatalog, secretMaps, mapData) -> void:
	print("\n--- Vendor catalog fixtures ---")
	var fixture = _validVendors()
	var catalog = VendorCatalogScript.new()
	catalog.vendors = fixture
	var dependencies = { "zoneCatalog": zoneCatalog, "itemCatalog": itemCatalog, "secretMapData": secretMaps, "mapData": mapData }
	_check(catalog.validate(dependencies).is_empty(), "valid vendor fixtures pass lint: %s" % [catalog.validate(dependencies)])
	_check(catalog.getFixedOffers("test_general").size() == 2, "fixed offers expose authored order")

	var mutations = [
		["unknown_zone", func(v): v["test_general"]["zoneId"] = "missing_zone"],
		["missing_room", func(v): v["test_general"]["roomScene"] = "res://missing.tscn"],
		["general_rolled", func(v): v["test_general"]["stock"]["mode"] = "rolled"],
		["gun_fixed", func(v): v["test_gunsmith"]["stock"]["mode"] = "fixed"],
		["gun_wrong_type", func(v): v["test_gunsmith"]["stock"]["itemType"] = "equipment"],
		["bad_count", func(v): v["test_gunsmith"]["stock"]["count"] = 0],
		["bad_price", func(v): v["test_general"]["stock"]["offers"][0]["unitPrice"] = 0],
		["duplicate_offer", func(v): v["test_general"]["stock"]["offers"][1]["offerId"] = "paregoric"],
		["unknown_item", func(v): v["test_general"]["stock"]["offers"][0]["definitionId"] = "missing_item"],
		["bank_stock", func(v): v["test_bank"]["stock"] = { "mode": "fixed", "offers": [] }],
	]
	for entry in mutations:
		var mutated = fixture.duplicate(true)
		entry[1].call(mutated)
		var mutatedCatalog = VendorCatalogScript.new()
		mutatedCatalog.vendors = mutated
		_check(!mutatedCatalog.validate(dependencies).is_empty(), "vendor mutation '%s' fails lint" % entry[0])

	var emptyMaps = SecretMapDataScript.new()
	emptyMaps.maps = {}
	emptyMaps.targets = {}
	var mapOfferCatalog = VendorCatalogScript.new()
	mapOfferCatalog.vendors = { "test_general": {
		"vendorId": "test_general", "kind": "general", "displayName": "General", "parentLocationId": "Lazysprings",
		"zoneId": "canyon", "roomScene": ROOM_SCENE,
		"stock": { "mode": "fixed", "offers": [{ "offerId": "map", "definitionId": "canyon_cache_map", "unitPrice": 75 }] },
	}}
	_check(!mapOfferCatalog.validate({ "zoneCatalog": zoneCatalog, "itemCatalog": itemCatalog, "secretMapData": emptyMaps }).is_empty(), "map offer without reveal data fails lint")


func _validVendors() -> Dictionary:
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
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 6 },
		},
		"test_bank": {
			"vendorId": "test_bank", "kind": "bank", "displayName": "Test Bank",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
		},
	}


func _testPricing() -> void:
	print("\n--- Vendor pricing ---")
	var pricing = VendorPricingScript.new()
	_check(pricing.validateData().is_empty(), "pricing data validates: %s" % [pricing.validateData()])
	var generator = ItemGenerationScript.new()
	for rarity in ["common", "uncommon", "rare", "epic"]:
		var weapon = generator.generateWeapon({ "rarity": rarity, "family": "revolver" })
		var weaponQuote = pricing.quoteGear(weapon)
		_check(weaponQuote.success, "weapon '%s' quotes" % rarity)
		_check(weaponQuote.buyPrice >= 1 and weaponQuote.sellPrice >= 1, "prices are positive for %s" % rarity)
		_check(weaponQuote.sellPrice <= weaponQuote.buyPrice, "sale never exceeds purchase for %s" % rarity)
		if weaponQuote.buyPrice > 1:
			_check(weaponQuote.sellPrice < weaponQuote.buyPrice, "no arbitrage when purchase is above 1 for %s" % rarity)
		var equipment = generator.generateEquipment({ "rarity": rarity })
		_check(pricing.quoteGear(equipment).success, "equipment '%s' quotes" % rarity)
	var legendary = generator.generateLegendary("widowmaker")
	_check(pricing.quoteGear(legendary).success, "legendary quotes from its base value")

	var missing = generator.generateWeapon({ "rarity": "common", "family": "revolver" })
	missing["definitionId"] = "missing_weapon"
	var missingQuote = pricing.quoteGear(missing)
	_check(!missingQuote.success and missingQuote.reason == "missing_base_value", "missing base value fails closed")
	var badAffix = generator.generateWeapon({ "rarity": "common", "family": "revolver" })
	badAffix["prefix"]["stat"] = "missing_stat"
	_check(pricing.quoteGear(badAffix).reason == "unknown_affix", "unknown affix stat fails closed")
	var legacy = generator.generateWeapon({ "rarity": "common", "family": "revolver" })
	legacy["prefix"] = { "name": "Rattlesnake's", "stat": "poisonAffliction", "value": 5 }
	var legacyQuote = pricing.quoteGear(legacy)
	_check(legacyQuote.success, "a legacy excluded affix keeps its record and stays sellable, got reason '%s'" % str(legacyQuote.reason))

	var brokenPricing = VendorPricingScript.new()
	brokenPricing.weaponData.baseValues.erase("cattleman")
	_check(!brokenPricing.validateData().is_empty(), "missing authored value fails pricing lint")
	brokenPricing = VendorPricingScript.new()
	brokenPricing.globalSellRatio = 1.0
	_check(!brokenPricing.validateData().is_empty(), "sell ratio at/above 1 fails pricing lint")
	generator.free()


func _testMapInventory() -> void:
	print("\n--- Map inventory support ---")
	var catalog = ItemCatalogScript.new()
	var rules = InventoryRulesScript.new()
	var plan = rules.planAdd([], [catalog.makeStackable("canyon_cache_map", 1)], 2, catalog, 1)
	_check(plan.success and plan.inventory.size() == 1, "map items are valid stackable inventory entries")
	_check(plan.inventory[0].itemType == "map", "map item identity survives planning")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
