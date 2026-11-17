extends Node

## Item generation system: rolls rarity, weapon/equipment bases and affixes,
## and assembles named items.
## Design source: Docs/Weapons and affixes.md
##
## Items are plain dictionaries (project convention), e.g. a rolled weapon:
## {
##   "name": "Well-Kept Deadeye's Cattleman of the Quickdraw",
##   "definitionId": "cattleman", "quantity": 1,
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
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const CombatStatRegistryScript = preload("res://Globals/CombatStatRegistry.gd")

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
var itemCatalog


func _loadData() -> void:
	if itemCatalog == null:
		itemCatalog = ItemCatalogScript.new()
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
## - rng: RandomNumberGenerator for deterministic rolling (default global RNG)
func generateItem(options := {}) -> Dictionary:
	_loadData()
	var itemType = options.get("itemType", "")
	if itemType == "":
		itemType = "weapon" if _randomFloat(_rngFromOptions(options)) < 0.5 else "equipment"
	if itemType == "weapon":
		return generateWeapon(options)
	return generateEquipment(options)

func generateWeapon(options := {}) -> Dictionary:
	_loadData()
	var rng = _rngFromOptions(options)
	var weaponFamily = options.get("family", "")
	if weaponFamily == "":
		var familyKeys = weaponData.weaponFamilies.keys()
		weaponFamily = familyKeys[_randomIndex(rng, familyKeys.size())]
	var weaponBases = weaponData.weaponFamilies[weaponFamily]
	var weaponBase = _findWeaponBase(weaponBases, str(options.get("definitionId", "")))
	if weaponBase.is_empty():
		weaponBase = weaponBases[_randomIndex(rng, weaponBases.size())]

	var item = {
		"definitionId": weaponBase["id"],
		"quantity": 1,
		"itemType": "weapon",
		"family": weaponFamily,
		"baseName": weaponBase["name"],
		"familyNoun": weaponFamily.capitalize(),
		"sprite": _rollSprite(weaponBase["sprites"], rng),
		"stats": {},
		"zone": options.get("zone", "anywhere"),
	}
	_applyGrantedMoves(item, weaponBase)
	_rollRarityAndAffixes(item, options)
	# WeaponData has no per-base damage values yet; roll the base damage from
	# the family's damage range for the rolled rarity (PLACEHOLDER values, see
	# AffixData.gd statValues).
	item["baseDamage"] = _rollAffixValue(weaponFamily + "Damage", item["rarity"], rng)
	_assembleName(item)
	return item


## Authored base lookup for a forced `definitionId` (tests and deterministic
## previews). An unknown id falls back to the normal random pick.
func _findWeaponBase(weaponBases: Array, definitionId: String) -> Dictionary:
	if definitionId == "":
		return {}
	for baseValue in weaponBases:
		if baseValue is Dictionary and str((baseValue as Dictionary).get("id", "")) == definitionId:
			return baseValue as Dictionary
	return {}


## Item-granted Moves are authored on the base definition and copied to the
## instance (Docs/System Design/First Steps Implementation Plan.md, commit 11):
## a rolled item keeps its grants through purchase, loot, Bank and equipment.
func _applyGrantedMoves(item: Dictionary, base: Dictionary) -> void:
	var granted = base.get("grantedMoves", null)
	if granted is Array and !(granted as Array).is_empty():
		item["grantedMoves"] = (granted as Array).duplicate()

func generateEquipment(options := {}) -> Dictionary:
	_loadData()
	var rng = _rngFromOptions(options)
	var zone = options.get("zone", "anywhere")
	var pool = []
	if equipmentData.zones.has(zone):
		for entry in equipmentData.zones[zone]["items"]:
			var zoneEntry = {
				"definitionId": entry["id"],
				"name": entry["name"],
				"slot": entry["slot"],
				"zone": zone,
			}
			if entry.has("beltSpace"):
				zoneEntry["beltSpace"] = int(entry["beltSpace"])
			_applyGrantedMoves(zoneEntry, entry)
			pool.append(zoneEntry)
	for zoneKey in equipmentData.zones:
		for entry in equipmentData.zones[zoneKey]["items"]:
			if entry["dropsAnywhere"]:
				var anywhereEntry = {
					"definitionId": entry["id"],
					"name": entry["name"],
					"slot": entry["slot"],
					"zone": zoneKey,
				}
				if entry.has("beltSpace"):
					anywhereEntry["beltSpace"] = int(entry["beltSpace"])
				_applyGrantedMoves(anywhereEntry, entry)
				pool.append(anywhereEntry)
	for slot in equipmentData.slots:
		var generic = equipmentData.genericBases[slot]
		var genericEntry = {
			"definitionId": generic["id"],
			"name": generic["name"],
			"slot": slot,
			"zone": "anywhere",
		}
		if generic.has("beltSpace"):
			genericEntry["beltSpace"] = int(generic["beltSpace"])
		_applyGrantedMoves(genericEntry, generic)
		pool.append(genericEntry)

	var base = pool[_randomIndex(rng, pool.size())]
	var item = {
		"definitionId": base["definitionId"],
		"quantity": 1,
		"itemType": "equipment",
		"slot": base["slot"],
		"baseName": base["name"],
		"sprite": _rollSprite(equipmentData.spritePools[base["slot"]], rng),
		"stats": equipmentData.genericBases[base["slot"]]["baseStats"].duplicate(),
		"zone": base["zone"],
	}
	if base.has("beltSpace"):
		item["beltSpace"] = base["beltSpace"]
	_applyGrantedMoves(item, base)
	_rollRarityAndAffixes(item, options)
	_assembleName(item)
	return item

func generateLegendary(legendaryKey: String) -> Dictionary:
	_loadData()
	if not legendaryData.legendaries.has(legendaryKey):
		push_warning("ItemGeneration: unknown legendary '%s'" % legendaryKey)
		return {}
	var item = legendaryData.legendaries[legendaryKey].duplicate(true)
	item["definitionId"] = legendaryKey
	item["quantity"] = 1
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
	var quests = _questsAutoload()
	if quests != null:
		return quests.currentMainQuestLevel.rarity
	return "common"

## Resolved through the tree instead of the Quests autoload identifier (same
## pattern as the Shootout managers) so the script compiles when a headless
## test preloads it before the autoloads register.
func _questsAutoload():
	var mainLoop = Engine.get_main_loop()
	if mainLoop is SceneTree and mainLoop.root != null:
		return mainLoop.root.get_node_or_null("Quests")
	return null

func _rollRarityAndAffixes(item: Dictionary, options: Dictionary) -> void:
	var rng = _rngFromOptions(options)
	var rarityKey = options.get("rarity", "")
	if rarityKey == "":
		rarityKey = rollRarity()
	item["rarity"] = rarityKey
	item["rarityName"] = RARITIES[rarityKey]["displayName"]
	# Every item always rolls two affixes: a prefix and a suffix.
	item["prefix"] = _rollAffix("prefix", rarityKey, rng)
	item["suffix"] = _rollAffix("suffix", rarityKey, rng)

	for affix in [item["prefix"], item["suffix"]]:
		item["stats"][affix["stat"]] = item["stats"].get(affix["stat"], 0) + affix["value"]

func _rollAffix(affix: String, rarityKey: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var pool = {}
	if affix == "prefix":
		for category in affixData.prefixes:
			for affixName in affixData.prefixes[category]:
				pool[affixName] = affixData.prefixes[category][affixName]
	else:
		pool = affixData.suffixes
	# Defense in depth: the content lint rejects non-eligible pool entries; this
	# filter keeps a reintroduced one out of the rolls anyway (commit 12).
	for affixName in pool.keys():
		if not CombatStatRegistryScript.isGenerationEligible(str(pool[affixName])):
			pool.erase(affixName)
	var names = pool.keys()
	var affixName = names[_randomIndex(rng, names.size())]
	var statKey = pool[affixName]
	return {
		"name": affixName,
		"stat": statKey,
		"value": _rollAffixValue(statKey, rarityKey, rng),
	}

func _rollAffixValue(statKey: String, rarityKey: String, rng: RandomNumberGenerator = null) -> int:
	var stat = affixData.stats[statKey]
	if stat["kind"] == "flag":
		return 1
	# Roll bounds are either per-rarity ({ "common": {...}, ... }) or a flat
	# { "min", "max" } dict.
	var bounds = stat["value"]
	if bounds.has(rarityKey):
		bounds = bounds[rarityKey]
	return _randomIntRange(rng, int(bounds["min"]), int(bounds["max"]))

func _assembleName(item: Dictionary) -> void:
	var itemName = item["rarityName"] + " "
	if not item["prefix"].is_empty():
		itemName += item["prefix"]["name"] + " "
	itemName += item["baseName"]
	if not item["suffix"].is_empty():
		itemName += " " + item["suffix"]["name"]
	item["name"] = itemName

func _rollSprite(spritePool: Array, rng: RandomNumberGenerator = null) -> String:
	if spritePool.is_empty():
		return ""
	return spritePool[_randomIndex(rng, spritePool.size())]


## Accepted deterministic-RNG seam: options may carry
## "rng": RandomNumberGenerator. Null keeps the existing global-RNG behavior.
func _rngFromOptions(options: Dictionary) -> RandomNumberGenerator:
	var rng = options.get("rng", null)
	return rng if rng is RandomNumberGenerator else null


## Canonical Zone validation for generation context. An unknown id fails closed
## to "anywhere" with a warning rather than silently selecting no equipment.
func _resolvedGenerationZone(zoneId: String) -> String:
	var zone = str(zoneId).strip_edges()
	if zone == "" or zone == "anywhere":
		return "anywhere"
	if ZoneCatalogScript.new().hasZone(zone):
		return zone
	push_warning("ItemGeneration: unknown Zone '%s'; falling back to anywhere." % zone)
	return "anywhere"


func _randomFloat(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()


func _randomIndex(rng: RandomNumberGenerator, size: int) -> int:
	if size <= 0:
		return 0
	return rng.randi_range(0, size - 1) if rng != null else randi() % size


func _randomIntRange(rng: RandomNumberGenerator, from: int, to: int) -> int:
	if from > to:
		return from
	return rng.randi_range(from, to) if rng != null else randi_range(from, to)


## Equipment loot bonuses (commit 12): sums the supported percent loot affixes
## across the party's equipped item stats. Pure; no autoloads or member writes.
## Returns { "lootGold", "lootItems" } as integer percents.
static func equipmentLootStats(itemStatsList: Array) -> Dictionary:
	var lootGold := 0
	var lootItems := 0
	for statsValue in itemStatsList:
		if !(statsValue is Dictionary):
			continue
		lootGold += int((statsValue as Dictionary).get("lootGold", 0))
		lootItems += int((statsValue as Dictionary).get("lootItems", 0))
	return { "lootGold": maxi(0, lootGold), "lootItems": maxi(0, lootItems) }


## Merges equipment loot affixes into a generateLoot modifier payload (fight
## loot only — Off-Trail rewards never reach generateLoot with these). Rodeo
## multipliers compose multiplicatively; percent affixes add first:
## multiplier = rodeo * (1 + percent/100). `rollsPercent` adds whole extra
## weighted rolls only (never fractional or negative).
static func mergeLootModifiers(base: Dictionary, lootStats: Dictionary) -> Dictionary:
	var merged = base.duplicate(true)
	var multipliers = merged.get("multipliers", {})
	if !(multipliers is Dictionary):
		multipliers = {}
	var lootGold = maxi(0, int(lootStats.get("lootGold", 0)))
	if lootGold > 0:
		multipliers["money"] = float(multipliers.get("money", 1.0)) * (1.0 + float(lootGold) / 100.0)
	merged["multipliers"] = multipliers
	var lootItems = maxi(0, int(lootStats.get("lootItems", 0)))
	if lootItems > 0:
		merged["rollsPercent"] = int(merged.get("rollsPercent", 0)) + lootItems
	return merged


## Loot generation (Docs/System Design/Shootout/Rewards.md): rolls money and
## weighted entries from a loot table, then applies Rodeo loot modifiers
## (flat amounts first, multipliers after). An optional rng makes the whole
## roll deterministic; null preserves the existing global-RNG behavior.
## `zoneId` propagates the encounter's canonical Zone into generated equipment
## so `dropsAnywhere: false` behaves as it does for vendor stock.
func generateLoot(table: Dictionary, modifiers := {}, rng: RandomNumberGenerator = null, zoneId := "") -> Dictionary:
	_loadData()
	var loot = { "money": 0, "items": [] }
	var amounts = modifiers.get("amounts", {})
	var multipliers = modifiers.get("multipliers", {})
	var moneyData = table.get("money", {})
	if !moneyData.is_empty() and _randomFloat(rng) < float(moneyData.get("chance", 1.0)):
		var money = _randomIntRange(rng, int(moneyData.get("min", 0)), int(moneyData.get("max", 0)))
		money += int(amounts.get("money", 0))
		loot.money = maxi(0, int(round(money * float(multipliers.get("money", 1.0)))))
	else:
		loot.money = maxi(0, int(round(int(amounts.get("money", 0)) * float(multipliers.get("money", 1.0)))))
	var rolls = int(table.get("rolls", 0))
	# Equipment loot affixes (commit 12): whole extra weighted rolls only.
	var rollsPercent = maxi(0, int(modifiers.get("rollsPercent", 0)))
	if rolls > 0 and rollsPercent > 0:
		rolls += int(floor(float(rolls) * float(rollsPercent) / 100.0))
	for i in rolls:
		var entry = rollWeightedEntry(table.get("entries", []), rng)
		if entry == null:
			continue
		match entry.get("kind", ""):
			"consumable":
				var consumableId = str(entry.get("definitionId", ""))
				var consumable = itemCatalog.getDefinition(consumableId)
				if consumable.is_empty() or consumable.get("itemType", "") != "consumable":
					push_warning("ItemGeneration: unknown consumable definition '{definitionId}'".format({ "definitionId": consumableId }))
					continue
				loot.items.append(itemCatalog.makeStackable(consumableId, 1))
			"weapon", "equipment":
				var options = { "itemType": entry.kind, "zone": _resolvedGenerationZone(zoneId) }
				if rng != null:
					options["rng"] = rng
				var rarityPool = entry.get("rarity", [])
				if !rarityPool.is_empty():
					options["rarity"] = rarityPool[_randomIndex(rng, rarityPool.size())]
				loot.items.append(generateItem(options))
			"resources":
				var resourceId = str(entry.get("definitionId", ""))
				var resource = itemCatalog.getDefinition(resourceId)
				if resource.is_empty() or resource.get("itemType", "") != "resources":
					push_warning("ItemGeneration: unknown resource definition '{definitionId}'".format({ "definitionId": resourceId }))
					continue
				var amount = int(entry.get("amount", 0)) + int(amounts.get("resources", 0))
				amount = maxi(0, int(round(amount * float(multipliers.get("resources", 1.0)))))
				if amount > 0:
					loot.items.append(itemCatalog.makeStackable(resourceId, amount))
			_:
				push_warning("ItemGeneration: unknown loot entry kind '{kind}'".format({ "kind": entry.get("kind", "") }))
	return loot


func rollWeightedEntry(entries: Array, rng: RandomNumberGenerator = null):
	var total = 0
	for entry in entries:
		total += maxi(0, int(entry.get("weight", 0)))
	if total == 0:
		return null
	var pick = (_randomIntRange(rng, 0, total - 1) if rng != null else randi() % total)
	for entry in entries:
		pick -= maxi(0, int(entry.get("weight", 0)))
		if pick < 0:
			return entry
	return null
