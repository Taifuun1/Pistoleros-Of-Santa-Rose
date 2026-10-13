extends SceneTree

## Headless validation for rewards and loot (Docs/System Design/Shootout/Rewards.md).
## Run with: godot --headless --script res://Tests/TestLoot.gd

const LootGeneratorScript = preload("res://Globals/ItemGeneration.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")

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
			data[entryData.name] = entryData
	return data


func _run() -> void:
	seed(12345)
	var lootGenerator = LootGeneratorScript.new()
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
			if entry.get("kind", "") == "consumable":
				_check(itemNames.has(entry.get("id", "")), "%s: unknown consumable %s" % [tableName, entry.get("id", "")])
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

	print("\n--- Weighted entries respect their weights ---")
	var weightTable = { "name": "T", "rolls": 300, "money": {}, "entries": [
		{ "kind": "consumable", "id": "Paregoric", "weight": 9 },
		{ "kind": "resources", "amount": 1, "weight": 1 }
	] }
	var counts = { "Paregoric": 0, "resources": 0 }
	for i in 1:
		var rolls = lootGenerator.generateLoot(weightTable, {}).items
		for item in rolls:
			if item.itemType == "consumable":
				counts.Paregoric += 1
			else:
				counts.resources += 1
	_check(counts.Paregoric > counts.resources * 4, "9:1 weight leans heavily toward Paregoric, got %s" % [counts])

	print("\n--- Weapon entries honor their rarity pool ---")
	var weaponTable = { "name": "T", "rolls": 5, "money": {}, "entries": [
		{ "kind": "weapon", "rarity": ["common"], "weight": 1 }
	] }
	var loot2 = lootGenerator.generateLoot(weaponTable, {})
	_check(loot2.items.size() == 5, "five rolls produce five items")
	for item in loot2.items:
		_check(item.itemType == "weapon" and item.rarity == "common", "rolled weapon is common, got %s" % [item])

	print("\n--- Empty tables generate nothing ---")
	var empty = lootGenerator.generateLoot({ "name": "T", "rolls": 0, "entries": [] }, {})
	_check(empty.money == 0 and empty.items.is_empty(), "no money config and no rolls means no loot")

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
