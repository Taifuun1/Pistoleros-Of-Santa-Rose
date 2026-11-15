extends SceneTree

## Gate evidence for the vendor plan (Docs/System Design/Location Vendors
## Implementation.md, patch 7 gate): production content must be complete and
## functional. No catalog offer may claim an effect nothing implements, every
## placed vendor must have an authored room with a safe return, and every
## newspaper must name a Zone it can really report on.
## Run with: godot --headless --script res://Tests/TestVendorContent.gd

const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const SecretMapDataScript = preload("res://Data/Overworld/SecretMapData.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const NewspaperDataScript = preload("res://Data/Vendors/NewspaperData.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")

const MAP_MANIFEST := "res://Data/Overworld/OverworldMapData.tres"
const COMBAT_ITEM_DIR := "res://Data/Shootout/Items"
const LOCATION_SCENE_PATTERN := "res://Location/Locations/%s/%s.tscn"
## VendorRoom.tscn authors VendorExit here; VendorExit.tscn activates inside a
## radius-18 circle, so a room spawn closer than that would trap the player.
const EXIT_MARKER := Vector2(0, 48)
const EXIT_ACTIVATION_RADIUS := 18.0

var failures = 0
## Set while running the lint against deliberately broken fixtures.
var expectFailure := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var itemCatalog = ItemCatalogScript.new()
	var secretMapData = SecretMapDataScript.new()
	var zoneCatalog = ZoneCatalogScript.new()
	var mapData = load(MAP_MANIFEST)
	var catalog = VendorCatalogScript.new()

	print("--- The production catalog is structurally complete ---")
	var errors = catalog.validate({ "zoneCatalog": zoneCatalog, "itemCatalog": itemCatalog, "secretMapData": secretMapData, "mapData": mapData })
	_check(errors.is_empty(), "the catalog and its data dependencies validate: %s" % [errors])
	_check(!catalog.vendors.is_empty(), "the production catalog ships authored vendors")

	print("\n--- Every vendor Location is real and every vendor is placed ---")
	var vendorsByParent = _groupByParent(catalog)
	for parentId in vendorsByParent:
		var location = mapData.resolveLocation(parentId)
		_check(!location.is_empty(), "vendor parent Location '%s' resolves through the manifest" % parentId)
		_check(ResourceLoader.exists(_locationScenePath(parentId)), "vendor parent Location '%s' has an authored scene" % parentId)
		_testPlacement(parentId, vendorsByParent[parentId], catalog)

	print("\n--- Every vendor room is authored and returns safely ---")
	for vendorId in catalog.vendors:
		_testRoom(catalog.getVendor(vendorId))

	print("\n--- No offer claims an effect nothing implements ---")
	var combatNames = _combatItemNames()
	_check(!combatNames.is_empty(), "the combat item set is authored")
	for vendorId in catalog.vendors:
		var vendor = catalog.getVendor(vendorId)
		if !VendorCatalogScript.FIXED_KINDS.has(str(vendor.kind)):
			continue
		for offer in catalog.getFixedOffers(vendorId):
			_testFixedOffer(vendorId, offer, itemCatalog, secretMapData, combatNames)
	_testSecretReachability(catalog, itemCatalog, secretMapData, mapData)

	print("\n--- Every newspaper names a Zone it can really report on ---")
	_testReports(catalog, zoneCatalog)

	print("\n--- The gate lint rejects broken content ---")
	_testLintHasTeeth(itemCatalog, secretMapData, combatNames)

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _testPlacement(parentId: String, vendorIds: Array, catalog) -> void:
	var scenePath = _locationScenePath(parentId)
	if !ResourceLoader.exists(scenePath):
		return
	var location = load(scenePath).instantiate()
	var doors = []
	_collectDoors(location, doors)
	_check(!doors.is_empty(), "vendor Location '%s' places at least one vendor door" % parentId)
	var placedIds = []
	for door in doors:
		var doorId = str(door.get("vendorId"))
		placedIds.append(doorId)
		_check(catalog.hasVendor(doorId), "placed door '%s' resolves in the catalog" % doorId)
		if catalog.hasVendor(doorId):
			_check(str(catalog.getVendor(doorId).parentLocationId) == parentId, "placed door '%s' sits in its catalog Location" % doorId)
		_check(door.get_node_or_null("FloatingIcon") != null, "placed door '%s' carries its floating icon" % doorId)
		# Patch 3's return convention: the player comes back on the marker under
		# the icon, and the activation shape is centered on that same marker.
		_check(door.get("returnOffset") == Vector2.ZERO, "placed door '%s' returns the player to the marker" % doorId)
		var shapeNode = door.get_node_or_null("CollisionShape2D")
		_check(shapeNode != null and shapeNode.position == Vector2.ZERO, "placed door '%s' centers activation on the marker" % doorId)
	for vendorId in vendorIds:
		_check(placedIds.count(vendorId) == 1, "catalog vendor '%s' is placed exactly once" % vendorId)
	location.free()


func _testRoom(vendor: Dictionary) -> void:
	var vendorId = str(vendor.vendorId)
	var roomScene = str(vendor.roomScene)
	if !ResourceLoader.exists(roomScene):
		_check(false, "vendor '%s' room scene does not exist" % vendorId)
		return
	var room = load(roomScene).instantiate()
	var actor = _findInteractable(room, vendorId)
	_check(actor != null, "vendor '%s' room contains its vendor actor" % vendorId)
	var spawnNode = _findDescendantNamed(room, "PlayerSpawn")
	_check(spawnNode is Marker2D, "vendor '%s' room authors a player spawn marker" % vendorId)
	if spawnNode is Marker2D:
		var distance = (spawnNode as Marker2D).position.distance_to(EXIT_MARKER)
		_check(distance > EXIT_ACTIVATION_RADIUS + 1.0, "vendor '%s' spawn sits %.0fpx from the exit, outside its activation radius" % [vendorId, distance])
	room.free()


func _testFixedOffer(vendorId: String, offer: Dictionary, itemCatalog, secretMapData, combatNames: Dictionary) -> void:
	var offerId = str(offer.get("offerId", ""))
	var definitionId = str(offer.get("definitionId", ""))
	var label = "vendor '%s' offer '%s'" % [vendorId, offerId]
	var definition = itemCatalog.getDefinition(definitionId)
	if definition.is_empty():
		_check(false, "%s: unknown item definition '%s'" % [label, definitionId])
		return
	# Fixed offers are built from a bare definition id, so only definitions that
	# carry their whole effect can be sold without shipping a fake purchase.
	var itemType = str(definition.get("itemType", ""))
	if itemType == "consumable":
		_check(combatNames.has(str(definition.get("combatId", ""))), "%s: consumable resolves combat item '%s'" % [label, definition.get("combatId", "")])
	elif itemType == "map":
		var effect = definition.get("effect", {})
		_check(str(effect.get("kind", "")) == "reveal_map", "%s: map declares a reveal effect" % label)
		_check(secretMapData.hasMap(str(effect.get("mapId", ""))), "%s: map '%s' has authored reveal data" % [label, effect.get("mapId", "")])
	else:
		_check(false, "%s: fixed offers cannot sell itemType '%s' without a full payload" % [label, itemType])


func _testSecretReachability(catalog, itemCatalog, secretMapData, mapData) -> void:
	var soldMapIds = []
	for vendorId in catalog.vendors:
		if !VendorCatalogScript.FIXED_KINDS.has(str(catalog.getVendor(vendorId).kind)):
			continue
		for offer in catalog.getFixedOffers(vendorId):
			var definition = itemCatalog.getDefinition(str(offer.get("definitionId", "")))
			if str(definition.get("itemType", "")) != "map":
				continue
			var mapId = str(definition.get("effect", {}).get("mapId", ""))
			if !soldMapIds.has(mapId):
				soldMapIds.append(mapId)
	_check(!soldMapIds.is_empty(), "the shops sell at least one reveal map")
	for mapId in soldMapIds:
		var targets = secretMapData.getMapTargets(mapId)
		_check(!targets.is_empty(), "sold map '%s' reveals authored targets" % mapId)
		for target in targets:
			var targetId = str(target.get("targetId", ""))
			if str(target.get("kind", "")) != "location":
				_check(str(target.get("kind", "")) == "secret_item", "map '%s' target '%s' uses a supported kind" % [mapId, targetId])
				continue
			var location = mapData.resolveSecretLocation(targetId)
			_check(!location.is_empty(), "map '%s' target '%s' resolves to a manifest Location" % [mapId, targetId])
			if location.is_empty():
				continue
			_check(mapData.locationVisibility(location) == "secret", "map '%s' target '%s' is authored as secret" % [mapId, targetId])
			_check(ResourceLoader.exists(_locationScenePath(targetId)), "map '%s' target '%s' has a reachable scene" % [mapId, targetId])


func _testReports(catalog, zoneCatalog) -> void:
	var pools = EncounterPoolDataScript.new()
	var poolErrors = pools.loadProductionPools()
	_check(poolErrors.is_empty(), "the production encounter pools validate: %s" % [poolErrors])
	var copy = NewspaperDataScript.new()
	var builder = NewspaperReportBuilder.new()
	var resolver = Callable(NewspaperReportBuilder, "defaultActorResolver")
	var newspaperCount := 0
	for vendorId in catalog.vendors:
		var vendor = catalog.getVendor(vendorId)
		if str(vendor.kind) != "newspaper":
			continue
		newspaperCount += 1
		var zoneId = str(vendor.zoneId)
		_check(zoneCatalog.hasZone(zoneId), "newspaper '%s' Zone '%s' is canonical" % [vendorId, zoneId])
		_check(copy.hasZone(zoneId), "newspaper '%s' has authored copy for Zone '%s'" % [vendorId, zoneId])
		var poolAvailable = pools.hasZone(zoneId)
		_check(poolAvailable, "newspaper '%s' Zone '%s' publishes a production encounter pool" % [vendorId, zoneId])
		if !poolAvailable or !copy.hasZone(zoneId) or !zoneCatalog.hasZone(zoneId):
			continue
		var report = builder.buildReport(zoneId, pools, resolver, copy)
		_check(bool(report.get("success", false)), "newspaper '%s' builds a report (%s)" % [vendorId, str(report.get("reason", ""))])
		_check(str(report.get("zoneId", "")) == zoneId, "newspaper '%s' reports its own Zone '%s'" % [vendorId, zoneId])
		_check(!report.get("parties", []).is_empty(), "newspaper '%s' never ships an empty report" % vendorId)
	_check(newspaperCount > 0, "at least one newspaper is placed")
	# A fallback Zone would silently print another region's news.
	var unpublished = builder.buildReport("unpublished_zone", pools, resolver, copy)
	_check(!bool(unpublished.get("success", true)), "an unpublished Zone never falls back to another Zone")


## Runs the same checks against deliberately broken fixtures: a sold definition
## with no real effect and a room that is not a vendor room must both trip them.
func _testLintHasTeeth(itemCatalog, secretMapData, combatNames: Dictionary) -> void:
	var before = failures
	# A scratch catalog: production definitions are never mutated by a test.
	var scratch = ItemCatalogScript.new()
	scratch.definitions["fake_blade"] = { "definitionId": "fake_blade", "itemType": "weapon", "name": "Fake Blade", "category": "weapons", "stackLimit": 1 }
	scratch.definitions["fake_tonic"] = { "definitionId": "fake_tonic", "itemType": "consumable", "name": "Fake Tonic", "category": "supplies", "combatId": "noSuchCombatItem", "stackLimit": 5 }
	expectFailure = true
	_testFixedOffer("broken_vendor", { "offerId": "fake_blade", "definitionId": "fake_blade", "unitPrice": 10 }, scratch, secretMapData, combatNames)
	_testFixedOffer("broken_vendor", { "offerId": "fake_tonic", "definitionId": "fake_tonic", "unitPrice": 10 }, scratch, secretMapData, combatNames)
	_testFixedOffer("broken_vendor", { "offerId": "ghost", "definitionId": "no_such_item", "unitPrice": 10 }, scratch, secretMapData, combatNames)
	_testRoom({ "vendorId": "broken_vendor", "roomScene": "res://Location/Entities/Vendor/VendorActor.tscn" })
	expectFailure = false
	_check(failures == before, "broken fixtures tripped every checked failure and nothing else")


func _groupByParent(catalog) -> Dictionary:
	var grouped = {}
	for vendorId in catalog.vendors:
		var parentId = str(catalog.getVendor(vendorId).parentLocationId)
		if !grouped.has(parentId):
			grouped[parentId] = []
		grouped[parentId].append(vendorId)
	return grouped


func _locationScenePath(locationId: String) -> String:
	return LOCATION_SCENE_PATTERN % [locationId, locationId]


## Placed vendor doors are the only Area2D nodes carrying a vendorId.
func _collectDoors(node: Node, doors: Array) -> void:
	if node is Area2D and node.get("vendorId") != null:
		doors.append(node)
	for child in node.get_children():
		_collectDoors(child, doors)


func _findInteractable(node: Node, vendorId: String) -> Node:
	if node.get("vendorId") != null and str(node.get("vendorId")) == vendorId:
		return node
	for child in node.get_children():
		var found = _findInteractable(child, vendorId)
		if found != null:
			return found
	return null


func _findDescendantNamed(node: Node, nodeName: String) -> Node:
	if node.name == nodeName:
		return node
	for child in node.get_children():
		var found = _findDescendantNamed(child, nodeName)
		if found != null:
			return found
	return null


func _combatItemNames() -> Dictionary:
	var names = {}
	for fileName in DirAccess.get_files_at(COMBAT_ITEM_DIR):
		if !fileName.ends_with(".gd"):
			continue
		var entry = load(COMBAT_ITEM_DIR + "/" + fileName).new()
		names[str(entry.data.get("name", ""))] = true
		entry.free()
	return names


func _check(condition: bool, message: String) -> void:
	var passed = !condition if expectFailure else condition
	if passed:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)