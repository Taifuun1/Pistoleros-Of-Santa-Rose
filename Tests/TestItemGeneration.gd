extends SceneTree

## Headless validation for the item generation system.
## Run with: godot --headless --script res://Tests/TestItemGeneration.gd

var failures = 0


func _init() -> void:
	# Deferred so the scene tree is up and _ready/@onready fire for instanced
	# scenes added below (they don't when adding children during SceneTree._init).
	call_deferred("_run")


func _run() -> void:
	seed(12345)
	var generator = load("res://Globals/ItemGeneration.gd").new()

	print("--- Rarity distribution over 1000 rolls ---")
	var counts = {}
	for i in 1000:
		var rarity = generator.rollRarity()
		counts[rarity] = counts.get(rarity, 0) + 1
	print(counts)

	print("\n--- One weapon per forced rarity ---")
	for rarity in ["common", "uncommon", "rare", "epic"]:
		var item = generator.generateWeapon({ "rarity": rarity })
		print(item["name"], " | baseDamage: ", item["baseDamage"], " | stats: ", item["stats"])
		_checkItem(item, "weapon", rarity)

	print("\n--- One weapon per family ---")
	for family in ["revolver", "rifle", "shotgun"]:
		var item = generator.generateWeapon({ "family": family, "rarity": "rare" })
		print(item["name"])
		_check(item["family"] == family, "family mismatch: %s" % item["name"])

	print("\n--- Equipment per zone ---")
	for zoneKey in generator.getZoneKeys():
		var item = generator.generateEquipment({ "zone": zoneKey, "rarity": "uncommon" })
		print(item["name"], " | slot: ", item["slot"], " | zone: ", item["zone"])
		_checkItem(item, "equipment", "uncommon")

	print("\n--- All legendaries ---")
	for legendaryKey in generator.getLegendaryKeys():
		var item = generator.generateLegendary(legendaryKey)
		print(item["name"], " | ", item["rarityName"], " | stats: ", item["stats"])
		_check(item["rarity"] == "legendary", "legendary rarity wrong: %s" % legendaryKey)
		_check(item["prefix"].is_empty() and item["suffix"].is_empty(), "legendary has affixes: %s" % legendaryKey)
	_check(generator.generateLegendary("does_not_exist").is_empty(), "unknown legendary should return {}")

	print("\n--- Random items (zone 'swamp') ---")
	for i in 5:
		var item = generator.generateItem({ "zone": "swamp" })
		print(item["name"])

	print("\n--- Name format matches doc example shape ---")
	var example = generator.generateWeapon({ "rarity": "rare", "family": "revolver" })
	_check(" " in example["name"], "name should contain spaces")
	if not example["prefix"].is_empty():
		_check(example["name"].begins_with("Well-Kept " + example["prefix"]["name"]), "name should start with rarity + prefix")
	if not example["suffix"].is_empty():
		_check(example["name"].ends_with(example["suffix"]["name"]), "name should end with suffix")
	print(example["name"])

	print("\n--- Sprite rolling ---")
	for i in 10:
		var weapon = generator.generateWeapon({ "rarity": "common" })
		_check(weapon["sprite"] != "" and ResourceLoader.exists(weapon["sprite"]), "weapon sprite missing: %s" % weapon["name"])
	for i in 10:
		var equipment = generator.generateEquipment({ "rarity": "common" })
		if generator.equipmentData.spritePools[equipment["slot"]].is_empty():
			_check(equipment["sprite"] == "", "equipment sprite should be empty for slot %s" % equipment["slot"])
		else:
			_check(equipment["sprite"] != "" and ResourceLoader.exists(equipment["sprite"]), "equipment sprite missing: %s" % equipment["name"])
	for legendaryKey in generator.getLegendaryKeys():
		var legendary = generator.generateLegendary(legendaryKey)
		_check(legendary["sprite"] == "" or ResourceLoader.exists(legendary["sprite"]), "legendary sprite invalid: %s" % legendaryKey)

	print("\n--- Zone equipment names have no possessives ---")
	for zoneKey in generator.getZoneKeys():
		for entry in generator.equipmentData.zones[zoneKey]["items"]:
			_check(not entry["name"].contains("'"), "possessive in zone item name: %s" % entry["name"])

	print("\n--- ItemStats display mapping ---")
	var itemStats = load("res://Nodes/Item Stats/ItemStats.tscn").instantiate()
	var weaponItem = generator.generateWeapon({ "rarity": "rare", "family": "revolver" })
	itemStats.displayItem(weaponItem)
	print(itemStats.nameLabel.get_parsed_text(), " | ", itemStats.familyLabel.get_parsed_text())
	_check(itemStats.nameLabel.get_parsed_text() == weaponItem["name"], "name label mismatch: '%s'" % itemStats.nameLabel.get_parsed_text())
	_check(itemStats.icon.texture != null and itemStats.icon.texture.resource_path == weaponItem["sprite"], "icon texture mismatch")
	_check(itemStats.familyLabel.get_parsed_text().contains(weaponItem["familyNoun"]), "family label mismatch")
	# Rare weapon: Damage line + prefix + suffix = 3 modifier lines
	_check(itemStats.modifierLabels[0].visible and itemStats.modifierLabels[2].visible and not itemStats.modifierLabels[3].visible, "modifier visibility wrong for rare weapon")
	_check(not itemStats.uniqueModifierLabel.visible, "unique modifier should be hidden for a rolled item")

	# Color coding: rarity part, affix category parts, white base name, keywords
	var nameText = itemStats.nameLabel.rawText
	_check(nameText.contains("[color=%s]" % itemStats.nameLabel.colors["rare"]), "rarity color missing in name")
	_check(nameText.contains("[color=%s]" % itemStats.nameLabel.colors["white"]), "base name color missing in name")
	if not weaponItem["prefix"].is_empty():
		var category = generator.affixData.stats[weaponItem["prefix"]["stat"]]["category"]
		_check(nameText.contains("[color=%s]" % itemStats.nameLabel.colors[category]), "prefix category color missing in name")
	if not weaponItem["suffix"].is_empty():
		var category = generator.affixData.stats[weaponItem["suffix"]["stat"]]["category"]
		_check(nameText.contains("[color=%s]" % itemStats.nameLabel.colors[category]), "suffix category color missing in name")
	_check(itemStats.modifierLabels[0].rawText.contains("[color=%s]" % itemStats.nameLabel.colors["keyword"]), "keyword highlight missing in modifier line")

	var legendaryItem = generator.generateLegendary("the_undertakers_coat")
	itemStats.displayItem(legendaryItem)
	_check(itemStats.nameLabel.rawText.contains("[color=%s]" % itemStats.nameLabel.colors["legendary"]), "legendary name color missing")
	_check(itemStats.uniqueModifierLabel.visible and itemStats.uniqueModifierLabel.get_parsed_text().begins_with("Unique: "), "unique prefix missing")
	_check(itemStats.uniqueModifierLabel.get_parsed_text().contains(legendaryItem["lore"]), "legendary lore not shown")
	_check(itemStats.uniqueModifierLabel.rawText.contains("[color=%s]" % itemStats.uniqueModifierLabel.colors["unique"]), "unique color missing")
	_check(itemStats.icon.texture != null and itemStats.icon.texture.resource_path == legendaryItem["sprite"], "legendary icon mismatch")

	var spritelessItem = { "itemType": "equipment", "slot": "bandana", "name": "Trail-Worn Bandana", "rarity": "common", "sprite": "", "stats": {} }
	itemStats.displayItem(spritelessItem)
	_check(itemStats.icon.texture != null and itemStats.icon.texture.resource_path == "res://Assets/Icons/PlaceholderIcon.png", "placeholder icon not used")

	itemStats.free()
	print("\n--- ItemGenerationTest scene ---")
	var testScene = load("res://Nodes/Item Stats/Test/ItemGenerationTest.tscn").instantiate()
	root.add_child(testScene)
	_check(testScene.rarityOption.item_count == 5, "rarity options not populated")
	_check(testScene.typeOption.item_count == 3, "type options not populated")
	_check(testScene.familyOption.item_count == 4, "family options not populated")
	_check(testScene.zoneOption.item_count == 10, "zone options not populated")
	_check(testScene.legendaryOption.item_count == 13, "legendary options not populated")
	_check(testScene.infoLabel.rawText != "", "info label empty after initial generate")

	testScene.typeOption.selected = 1 # Weapon
	testScene.rarityOption.selected = 4 # Storied (epic)
	testScene.familyOption.selected = 1 # Revolver
	testScene._onGeneratePressed()
	_check(testScene.itemStats.nameLabel.get_parsed_text().begins_with("Storied"), "generated item not epic: %s" % testScene.itemStats.nameLabel.get_parsed_text())

	testScene.legendaryOption.selected = 0
	testScene._onGenerateLegendaryPressed()
	_check(testScene.itemStats.uniqueModifierLabel.visible, "legendary not displayed via test scene")

	# Long content must wrap and grow the labels/panel instead of overflowing.
	# Needs the laid-out test scene (real widths), so it runs here.
	var longItem = {
		"itemType": "weapon", "family": "revolver", "familyNoun": "Six-Shooter",
		"baseName": "Colt Single Action Army", "baseDamage": 5,
		"rarity": "epic", "rarityName": "Storied",
		"prefix": { "name": "Silver-Tongued", "stat": "taffyin", "value": 3 },
		"suffix": { "name": "of the Dead Reckoning", "stat": "cylinderIncrease", "value": 2 },
		"stats": { "negativeEffectPotencyReduction": 25, "damageTakenReductionTaunting": 25, "taffyin": 3 },
		"sprite": "res://Assets/Weapons/SingleActionRevolver.png",
		"zone": "anywhere",
	}
	testScene.itemStats.displayItem(longItem)
	for i in 10:
		await process_frame
	var longNameLabel = testScene.itemStats.nameLabel
	_check(longNameLabel.get_line_count() <= 2, "name exceeds 2 lines (%s lines)" % longNameLabel.get_line_count())
	_check(longNameLabel.get_parsed_text().ends_with("..."), "long name not truncated with ellipsis: %s" % longNameLabel.get_parsed_text())
	_check(longNameLabel.get_content_height() <= longNameLabel.size.y + 0.5, "name text still cut off (content %s > height %s)" % [longNameLabel.get_content_height(), longNameLabel.size.y])
	_check(testScene.itemStats.icon.size_flags_vertical == Control.SIZE_SHRINK_BEGIN, "icon not top-anchored")

	# Name tooltip: shows the full, untruncated name on hover
	longNameLabel.mouse_entered.emit()
	_check(testScene.itemStats.get_node("Tooltip").visible, "name tooltip did not show on hover")
	var tooltipTitle = testScene.itemStats.get_node("Tooltip/Tooltip/MarginContainer/VBoxContainer/Title")
	_check(tooltipTitle.get_parsed_text() == "Storied Silver-Tongued Colt Single Action Army of the Dead Reckoning", "tooltip title is not the full name: '%s'" % tooltipTitle.get_parsed_text())
	longNameLabel.mouse_exited.emit()
	_check(not testScene.itemStats.get_node("Tooltip").visible, "name tooltip did not hide on mouse exit")
	var longModifierLabel = testScene.itemStats.modifierLabels[1]
	_check(longModifierLabel.get_content_height() <= longModifierLabel.size.y + 0.5, "modifier text still cut off (content %s > height %s)" % [longModifierLabel.get_content_height(), longModifierLabel.size.y])
	# The panel's minimum height must cover all visible content; its allocated
	# size depends on available window space (the test scene scrolls if needed).
	var contentMinHeight = testScene.itemStats.get_node("MarginContainer/VBoxContainer").get_combined_minimum_size().y
	_check(testScene.itemStats.custom_minimum_size.y >= contentMinHeight - 0.5, "ItemStats panel minimum height (%s) smaller than its content (%s)" % [testScene.itemStats.custom_minimum_size.y, contentMinHeight])
	testScene.free()

	generator.free()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _checkItem(item: Dictionary, itemType: String, rarity: String) -> void:
	_check(item["itemType"] == itemType, "itemType wrong: %s" % item["name"])
	_check(item["rarity"] == rarity, "rarity wrong: %s" % item["name"])
	_check(item.has("name") and item["name"] != "", "missing name")
	var affixCount = int(not item["prefix"].is_empty()) + int(not item["suffix"].is_empty())
	_check(affixCount == 2, "affix count %d != 2 for %s" % [affixCount, rarity])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
