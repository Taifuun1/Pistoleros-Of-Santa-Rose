extends SceneTree

## Headless validation for rewards and loot (Docs/System Design/Shootout/Rewards.md).
## Run with: godot --headless --script res://Tests/TestLoot.gd

const LootGeneratorScript = preload("res://Globals/ItemGeneration.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")

const KNOWN_KINDS = ["consumable", "weapon", "equipment", "resources"]
const KNOWN_RARITIES = ["common", "uncommon", "rare", "epic"]
const KNOWN_BANDS = ["early", "mid", "late"]

var failures = 0


func _init() -> void:
	call_deferred("_run")


func loadFolder(folder: String) -> Dictionary:
	var data = {}
	for fileName in DirAccess.get_files_at(folder):
		if !fileName.ends_with(".gd"):
			continue
		var entry = load("{folder}/{fileName}".format({ "folder": folder, "fileName": fileName })).new()
		var entryData = entry.get("data")
		if entryData != null:
			# Duplicate names would silently overwrite each other in this loader.
			_check(!data.has(str(entryData.name)), "%s: duplicate data.name '%s' in %s" % [folder, entryData.name, fileName])
			data[entryData.name] = entryData
		if entry is Node:
			entry.free()
	return data


func _run() -> void:
	seed(12345)
	var lootGenerator = LootGeneratorScript.new()
	var catalog = ItemCatalogScript.new()
	lootGenerator.itemCatalog = catalog
	var catalogErrors = catalog.validate()
	_check(catalogErrors.is_empty(), "item catalog errors: %s" % [catalogErrors])
	var itemNames = loadFolder("res://Data/Shootout/Items").keys()

	print("--- Loot table files are valid ---")
	var tables = loadFolder("res://Data/Shootout/LootTables")
	_check(!tables.is_empty(), "expected at least one loot table")
	for tableName in tables:
		var table = tables[tableName]
		_check(KNOWN_BANDS.has(table.get("band", "")), "%s: unknown band" % tableName)
		var money = table.get("money", {})
		_check(int(money.get("min", 0)) <= int(money.get("max", 0)), "%s: money min above max" % tableName)
		_check(!table.get("entries", []).is_empty(), "%s: no loot entries" % tableName)
		for entry in table.get("entries", []):
			_check(KNOWN_KINDS.has(entry.get("kind", "")), "%s: unknown kind %s" % [tableName, entry.get("kind", "")])
			_check(int(entry.get("weight", 0)) > 0, "%s: entry weight must be positive" % tableName)
			if entry.get("kind", "") in ["consumable", "resources"]:
				var definitionId = str(entry.get("definitionId", ""))
				_check(catalog.hasDefinition(definitionId), "%s: unknown item definition %s" % [tableName, definitionId])
				if catalog.hasDefinition(definitionId):
					var definition = catalog.getDefinition(definitionId)
					_check(definition.itemType == entry.kind, "%s: definition type mismatch for %s" % [tableName, definitionId])
					if entry.kind == "consumable":
						_check(itemNames.has(definition.combatId), "%s: unknown combat item %s" % [tableName, definition.combatId])
			for rarity in entry.get("rarity", []):
				_check(KNOWN_RARITIES.has(rarity), "%s: unknown rarity %s" % [tableName, rarity])

	print("\n--- Rodeo loot modifiers: flats then multipliers ---")
	var moneyTable = { "name": "T", "rolls": 0, "money": { "min": 5, "max": 5, "chance": 1.0 }, "entries": [] }
	var loot = lootGenerator.generateLoot(moneyTable, { "amounts": { "money": 10 }, "multipliers": { "money": 2.0 } })
	_check(loot.money == 30, "(5 + 10) * 2 = 30, got %d" % loot.money)
	var noMoneyTable = { "name": "T", "rolls": 0, "money": { "min": 5, "max": 5, "chance": 0.0 }, "entries": [] }
	loot = lootGenerator.generateLoot(noMoneyTable, { "amounts": { "money": 10 }, "multipliers": {} })
	_check(loot.money == 10, "flat money applies even when the table roll misses, got %d" % loot.money)

	print("\n--- Money rolls stay in range ---")
	var rangeTable = { "name": "T", "rolls": 0, "money": { "min": 2, "max": 6, "chance": 1.0 }, "entries": [] }
	var inRange = true
	for i in 100:
		var rolled = lootGenerator.generateLoot(rangeTable, {}).money
		if rolled < 2 or rolled > 6:
			inRange = false
	_check(inRange, "100 money rolls all within min/max")

	print("\n--- Unknown stackable definitions are rejected ---")
	var unknownTable = { "name": "T", "rolls": 1, "money": {}, "entries": [
		{ "kind": "resources", "definitionId": "missing_resource", "amount": 1, "weight": 1 }
	] }
	var unknownLoot = lootGenerator.generateLoot(unknownTable, {})
	_check(unknownLoot.items.is_empty(), "unknown resource should not produce loot")

	var testCatalog = ItemCatalogScript.new()
	testCatalog.definitions["test_resource"] = {
		"definitionId": "test_resource",
		"itemType": "resources",
		"name": "Test Resource",
		"category": "loot",
		"description": "Test-only resource.",
		"stackLimit": 20,
		"droppable": true,
		"sprite": "",
	}
	lootGenerator.itemCatalog = testCatalog

	print("\n--- Weighted entries respect their weights ---")
	var weightTable = { "name": "T", "rolls": 300, "money": {}, "entries": [
		{ "kind": "consumable", "definitionId": "paregoric", "weight": 9 },
		{ "kind": "resources", "definitionId": "test_resource", "amount": 1, "weight": 1 }
	] }
	var counts = { "paregoric": 0, "test_resource": 0 }
	var rolls = lootGenerator.generateLoot(weightTable, {}).items
	for item in rolls:
		counts[item.definitionId] += 1
		_check(item.has("quantity") and item.quantity > 0, "stackable loot needs a positive quantity")
	_check(counts.paregoric > counts.test_resource * 4, "9:1 weight leans heavily toward Paregoric, got %s" % [counts])

	print("\n--- Resource loot keeps definition ids and quantities ---")
	var resourceTable = { "name": "T", "rolls": 2, "money": {}, "entries": [
		{ "kind": "resources", "definitionId": "test_resource", "amount": 2, "weight": 1 }
	] }
	var resourceLoot = lootGenerator.generateLoot(resourceTable, { "multipliers": { "resources": 1.5 } })
	_check(resourceLoot.items.size() == 2, "two resource rolls produce two stacks")
	for item in resourceLoot.items:
		_check(item.itemType == "resources" and item.definitionId == "test_resource", "resource identity lost: %s" % [item])
		_check(item.quantity == 3, "resource amount 2 * 1.5 should be 3, got %s" % [item.quantity])

	print("\n--- Weapon entries honor their rarity pool ---")
	var weaponTable = { "name": "T", "rolls": 5, "money": {}, "entries": [
		{ "kind": "weapon", "rarity": ["common"], "weight": 1 }
	] }
	var loot2 = lootGenerator.generateLoot(weaponTable, {})
	_check(loot2.items.size() == 5, "five rolls produce five items")
	for item in loot2.items:
		_check(item.itemType == "weapon" and item.rarity == "common", "rolled weapon is common, got %s" % [item])

	print("\n--- Zone-aware equipment loot ---")
	var zoneTable = { "name": "Z", "rolls": 20, "money": {}, "entries": [
		{ "kind": "equipment", "rarity": ["common"], "weight": 1 }
	] }
	var zoneRng = RandomNumberGenerator.new()
	zoneRng.seed = 4242
	var canyonLoot = lootGenerator.generateLoot(zoneTable, {}, zoneRng, "wild_west")
	_check(canyonLoot.items.size() == 20, "zone-aware generation rolls the requested count")
	var sawCanyon = false
	for item in canyonLoot.items:
		_check(item.zone == "wild_west" or item.zone == "anywhere", "no foreign-zone equipment drops, got %s" % item.zone)
		if item.zone == "wild_west":
			sawCanyon = true
	_check(sawCanyon, "at least one canyon-locked equipment base can drop in canyon")

	var invalidRng = RandomNumberGenerator.new()
	invalidRng.seed = 4242
	var invalidLoot = lootGenerator.generateLoot(zoneTable, {}, invalidRng, "not_a_zone")
	for item in invalidLoot.items:
		_check(item.zone == "anywhere", "an unknown Zone fails closed to anywhere, got %s" % item.zone)

	print("\n--- Empty tables generate nothing ---")
	var empty = lootGenerator.generateLoot({ "name": "T", "rolls": 0, "entries": [] }, {})
	_check(empty.money == 0 and empty.items.is_empty(), "no money config and no rolls means no loot")

	print("\n--- Equipment loot affixes (commit 12) ---")
	var lootStats = lootGenerator.equipmentLootStats([{ "lootGold": 30, "lootItems": 50 }, { "lootGold": 10, "irrelevant": 5 }, "not_a_dict"])
	_check(lootStats.lootGold == 40 and lootStats.lootItems == 50, "equipment loot percents sum across gear, got %s" % [lootStats])
	_check(lootGenerator.equipmentLootStats([{}]).lootGold == 0, "gear without loot affixes adds nothing")
	var merged = lootGenerator.mergeLootModifiers({ "amounts": { "money": 5 }, "multipliers": { "money": 2.0 } }, lootStats)
	_check(is_equal_approx(float(merged.multipliers.money), 2.8), "rodeo multiplier composes with the equipment percent: 2.0 * 1.4, got %f" % float(merged.multipliers.money))
	_check(int(merged.rollsPercent) == 50 and int(merged.amounts.money) == 5, "the roll bonus and rodeo flats ride along")
	var lootGoldTable = { "name": "T", "rolls": 0, "money": { "min": 10, "max": 10, "chance": 1.0 }, "entries": [] }
	_check(lootGenerator.generateLoot(lootGoldTable, merged).money == 42, "(10 + 5) * 2.8 = 42, got %d" % lootGenerator.generateLoot(lootGoldTable, merged).money)
	var rollsTable = { "name": "T", "rolls": 2, "money": { "chance": 0.0 }, "entries": [{ "kind": "consumable", "definitionId": "paregoric", "weight": 1 }] }
	var rngRolls = RandomNumberGenerator.new()
	rngRolls.seed = 777
	var boosted = lootGenerator.generateLoot(rollsTable, merged, rngRolls)
	_check(boosted.items.size() == 3, "rollsPercent adds whole extra rolls: 2 + 50%% = 3, got %d" % boosted.items.size())
	var plainRolls = lootGenerator.generateLoot(rollsTable, {}, rngRolls)
	_check(plainRolls.items.size() == 2, "without the affix the roll count is unchanged")
	var zeroRollTable = { "name": "T", "rolls": 0, "entries": [] }
	_check(lootGenerator.generateLoot(zeroRollTable, merged).items.is_empty(), "no base rolls means no loot-items bonus (nothing to multiply)")

	lootGenerator.free()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
