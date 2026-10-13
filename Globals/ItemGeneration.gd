extends Node

## Item generation system: rolls rarity, weapon/equipment bases and affixes,
## and assembles named items.
## Design source: Docs/Weapons and affixes.md
##
## Items are plain dictionaries (project convention), e.g. a rolled weapon:
## {
##   "name": "Well-Kept Deadeye's Cattleman of the Quickdraw",
##   "itemType": "weapon", "family": "revolver"
##   "baseName": "Cattleman", "baseDamage": 7,
##   "rarity": "rare", "rarityName": "Well-Kept",
##   "prefix": { "name": "Deadeye's", "stat": "cylinderIncrease", "value": 2 },
##   "suffix": { "name": "of the Quickdraw", "stat": "highTailin", "value": 3 },
##   "stats": { "cylinderIncrease": 2, "highTailin": 3 },
##   "sprite": "res://Assets/Weapons/CattlemanRevolver.png",
##   "zone": "anywhere",
## }

const AffixDataScript = preload("res://Data/Items/AffixData.gd")
const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")
const EquipmentDataScript = preload("res://Data/Items/EquipmentData.gd")
const LegendaryDataScript = preload("res://Data/Items/LegendaryData.gd")

const RARITIES = {
	"common": { "displayName": "Trail-Worn" },
	"uncommon": { "displayName": "Serviceable" },
	"rare": { "displayName": "Well-Kept" },
	"epic": { "displayName": "Storied" },
}

const LEGENDARY_RARITY_NAME = "Legendary of the West"

var affixData
var weaponData
var equipmentData
var legendaryData


func _loadData() -> void:
	if affixData == null:
		affixData = AffixDataScript.new()
		weaponData = WeaponDataScript.new()
		equipmentData = EquipmentDataScript.new()
		legendaryData = LegendaryDataScript.new()

## Generates a random item. Options (all optional):
## - itemType: "weapon" or "equipment" (default: 50/50 roll)
## - zone: zone key from EquipmentData.gd (equipment only, default "anywhere")
## - family: "revolver"/"rifle"/"shotgun" (weapons only)
## - rarity: "common"/"uncommon"/"rare"/"epic" to force a rarity
func generateItem(options := {}) -> Dictionary:
	_loadData()
	var itemType = options.get("itemType", "")
	if itemType == "":
		itemType = "weapon" if randf() < 0.5 else "equipment"
	if itemType == "weapon":
		return generateWeapon(options)
	return generateEquipment(options)

func generateWeapon(options := {}) -> Dictionary:
	_loadData()
	var weaponFamily = options.get("family", "")
	if weaponFamily == "":
		var familyKeys = weaponData.weaponFamilies.keys()
		weaponFamily = familyKeys[randi() % familyKeys.size()]
	var weaponBases = weaponData.weaponFamilies[weaponFamily]
	var weaponBase = weaponBases[randi() % weaponBases.size()]

	var item = {
		"itemType": "weapon",
		"family": weaponFamily,
		"baseName": weaponBase["name"],
		"familyNoun": weaponFamily.capitalize(),
		"sprite": _rollSprite(weaponBase["sprites"]),
		"stats": {},
		"zone": options.get("zone", "anywhere"),
	}
	_rollRarityAndAffixes(item, options)
	# WeaponData has no per-base damage values yet; roll the base damage from
	# the family's damage range for the rolled rarity (PLACEHOLDER values, see
	# AffixData.gd statValues).
	item["baseDamage"] = _rollAffixValue(weaponFamily + "Damage", item["rarity"])
	_assembleName(item)
	return item

func generateEquipment(options := {}) -> Dictionary:
	_loadData()
	var zone = options.get("zone", "anywhere")
	var pool = []
	if equipmentData.zones.has(zone):
		for entry in equipmentData.zones[zone]["items"]:
			pool.append({ "name": entry["name"], "slot": entry["slot"], "zone": zone })
	for zoneKey in equipmentData.zones:
		for entry in equipmentData.zones[zoneKey]["items"]:
			if entry["dropsAnywhere"]:
				pool.append({ "name": entry["name"], "slot": entry["slot"], "zone": zoneKey })
	for slot in equipmentData.slots:
		var generic = equipmentData.genericBases[slot]
		pool.append({ "name": generic["name"], "slot": slot, "zone": "anywhere" })

	var base = pool[randi() % pool.size()]
	var item = {
		"itemType": "equipment",
		"slot": base["slot"],
		"baseName": base["name"],
		"sprite": _rollSprite(equipmentData.spritePools[base["slot"]]),
		"stats": equipmentData.genericBases[base["slot"]]["baseStats"].duplicate(),
		"zone": base["zone"],
	}
	_rollRarityAndAffixes(item, options)
	_assembleName(item)
	return item

func generateLegendary(legendaryKey: String) -> Dictionary:
	_loadData()
	if not legendaryData.legendaries.has(legendaryKey):
		push_warning("ItemGeneration: unknown legendary '%s'" % legendaryKey)
		return {}
	var item = legendaryData.legendaries[legendaryKey].duplicate(true)
	item["rarity"] = "legendary"
	item["rarityName"] = LEGENDARY_RARITY_NAME
	item["prefix"] = {}
	item["suffix"] = {}
	return item

func getLegendaryKeys() -> Array:
	_loadData()
	return legendaryData.legendaries.keys()

func getZoneKeys() -> Array:
	_loadData()
	return equipmentData.zones.keys()

## Returns the rarity for rolled items: the party's current main quest
## progression rarity (Docs/Weapons and affixes.md). Falls back to "common"
## when the Quests autoload is unavailable (e.g. headless test runs).
func rollRarity() -> String:
	if Quests != null:
		return Quests.currentMainQuestLevel.rarity
	return "common"

func _rollRarityAndAffixes(item: Dictionary, options: Dictionary) -> void:
	var rarityKey = options.get("rarity", "")
	if rarityKey == "":
		rarityKey = rollRarity()
	item["rarity"] = rarityKey
	item["rarityName"] = RARITIES[rarityKey]["displayName"]
	# Every item always rolls two affixes: a prefix and a suffix.
	item["prefix"] = _rollAffix("prefix", rarityKey)
	item["suffix"] = _rollAffix("suffix", rarityKey)

	for affix in [item["prefix"], item["suffix"]]:
		item["stats"][affix["stat"]] = item["stats"].get(affix["stat"], 0) + affix["value"]

func _rollAffix(affix: String, rarityKey: String) -> Dictionary:
	var pool = {}
	if affix == "prefix":
		for category in affixData.prefixes:
			for affixName in affixData.prefixes[category]:
				pool[affixName] = affixData.prefixes[category][affixName]
	else:
		pool = affixData.suffixes
	var names = pool.keys()
	var affixName = names[randi() % names.size()]
	var statKey = pool[affixName]
	return {
		"name": affixName,
		"stat": statKey,
		"value": _rollAffixValue(statKey, rarityKey),
	}

func _rollAffixValue(statKey: String, rarityKey: String) -> int:
	var stat = affixData.stats[statKey]
	if stat["kind"] == "flag":
		return 1
	# Roll bounds are either per-rarity ({ "common": {...}, ... }) or a flat
	# { "min", "max" } dict.
	var bounds = stat["value"]
	if bounds.has(rarityKey):
		bounds = bounds[rarityKey]
	return randi_range(bounds["min"], bounds["max"])

func _assembleName(item: Dictionary) -> void:
	var itemName = item["rarityName"] + " "
	if not item["prefix"].is_empty():
		itemName += item["prefix"]["name"] + " "
	itemName += item["baseName"]
	if not item["suffix"].is_empty():
		itemName += " " + item["suffix"]["name"]
	item["name"] = itemName

func _rollSprite(spritePool: Array) -> String:
	if spritePool.is_empty():
		return ""
	return spritePool[randi() % spritePool.size()]


## Loot generation (Docs/System Design/Shootout/Rewards.md): rolls money and
## weighted entries from a loot table, then applies Rodeo loot modifiers
## (flat amounts first, multipliers after).
func generateLoot(table: Dictionary, modifiers := {}) -> Dictionary:
	var loot = { "money": 0, "items": [] }
	var amounts = modifiers.get("amounts", {})
	var multipliers = modifiers.get("multipliers", {})
	var moneyData = table.get("money", {})
	if !moneyData.is_empty() and randf() < float(moneyData.get("chance", 1.0)):
		var money = randi_range(int(moneyData.get("min", 0)), int(moneyData.get("max", 0)))
		money += int(amounts.get("money", 0))
		loot.money = maxi(0, int(round(money * float(multipliers.get("money", 1.0)))))
	else:
		loot.money = maxi(0, int(round(int(amounts.get("money", 0)) * float(multipliers.get("money", 1.0)))))
	for i in int(table.get("rolls", 0)):
		var entry = rollWeightedEntry(table.get("entries", []))
		if entry == null:
			continue
		match entry.get("kind", ""):
			"consumable":
				loot.items.append({ "itemType": "consumable", "id": entry.get("id", ""), "name": entry.get("id", "") })
			"weapon", "equipment":
				var options = { "itemType": entry.kind }
				var rarityPool = entry.get("rarity", [])
				if !rarityPool.is_empty():
					options["rarity"] = rarityPool[randi() % rarityPool.size()]
				loot.items.append(generateItem(options))
			"resources":
				var amount = int(entry.get("amount", 0)) + int(amounts.get("resources", 0))
				loot.items.append({ "itemType": "resources", "amount": maxi(0, int(round(amount * float(multipliers.get("resources", 1.0))))) })
			_:
				push_warning("ItemGeneration: unknown loot entry kind '{kind}'".format({ "kind": entry.get("kind", "") }))
	return loot


func rollWeightedEntry(entries: Array):
	var total = 0
	for entry in entries:
		total += maxi(0, int(entry.get("weight", 0)))
	if total == 0:
		return null
	var pick = randi() % total
	for entry in entries:
		pick -= maxi(0, int(entry.get("weight", 0)))
		if pick < 0:
			return entry
	return null
