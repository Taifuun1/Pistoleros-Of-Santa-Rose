extends RefCounted
class_name VendorPricing

## Pure integer gear valuation for vendors (Docs/System Design/Location Vendors
## Implementation.md, Pricing). Authored base values live with the item data;
## affix value is derived from each rolled affix's stat kind. Missing or invalid
## value data fails closed instead of inventing a price.

const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")
const EquipmentDataScript = preload("res://Data/Items/EquipmentData.gd")
const LegendaryDataScript = preload("res://Data/Items/LegendaryData.gd")
const AffixDataScript = preload("res://Data/Items/AffixData.gd")
const CombatStatRegistryScript = preload("res://Globals/CombatStatRegistry.gd")

const RARITY_MULTIPLIERS = {
	"common": 1.0,
	"uncommon": 1.5,
	"rare": 2.25,
	"epic": 3.5,
	"legendary": 5.0,
}
# Value per rolled affix point, by AffixData stat kind.
const AFFIX_KIND_POINT_VALUES = {
	"flat": 2,
	"percent": 1,
	"flag": 40,
}

var weaponData
var equipmentData
var legendaryData
var affixData

# Balance knobs. Sell ratio must remain between 0 and 1 so shop gear cannot be
# bought and immediately sold for a profit.
var vendorBuyMarkup := 1.0
var globalSellRatio := 0.25


func _init() -> void:
	weaponData = WeaponDataScript.new()
	equipmentData = EquipmentDataScript.new()
	legendaryData = LegendaryDataScript.new()
	affixData = AffixDataScript.new()


## Prices one complete rolled gear item.
## Returns { "success", "reason", "gearValue", "buyPrice", "sellPrice" }.
func quoteGear(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return _failure("invalid_item")
	var itemType = str(item.get("itemType", ""))
	if itemType != "weapon" and itemType != "equipment":
		return _failure("not_equipment")
	var definitionId = str(item.get("definitionId", ""))
	if definitionId == "":
		return _failure("invalid_item")
	var rarity = str(item.get("rarity", ""))
	if !RARITY_MULTIPLIERS.has(rarity):
		return _failure("unknown_rarity")
	var baseValue = _baseValue(itemType, definitionId, rarity)
	if baseValue <= 0:
		return _failure("missing_base_value")
	var affixValueResult = _affixValue(item)
	if !affixValueResult.success:
		return affixValueResult
	var gearValue = int(round(baseValue * float(RARITY_MULTIPLIERS[rarity]))) + int(affixValueResult.affixValue)
	var buyPrice = maxi(1, int(round(gearValue * vendorBuyMarkup)))
	var sellPrice = maxi(1, int(floor(gearValue * globalSellRatio)))
	sellPrice = mini(sellPrice, buyPrice)
	return {
		"success": true,
		"reason": "",
		"gearValue": gearValue,
		"buyPrice": buyPrice,
		"sellPrice": sellPrice,
	}


## Convenience wrapper for stock generation; -1 means invalid data.
func buyPrice(item: Dictionary) -> int:
	var result = quoteGear(item)
	return int(result.buyPrice) if result.success else -1


## Convenience wrapper for sale quotes; -1 means invalid data.
func sellPrice(item: Dictionary) -> int:
	var result = quoteGear(item)
	return int(result.sellPrice) if result.success else -1


## Data-lint checks: every rollable/legendary definition has a positive base
## value, every affix stat has a valued kind, and the economy knobs are sane.
func validateData() -> Array:
	var errors = []
	if vendorBuyMarkup < 1.0:
		errors.append("vendorBuyMarkup must be at least 1.0")
	if globalSellRatio <= 0.0 or globalSellRatio >= 1.0:
		errors.append("globalSellRatio must be between 0 and 1")
	for rarity in RARITY_MULTIPLIERS:
		if float(RARITY_MULTIPLIERS[rarity]) <= 0.0:
			errors.append("rarity '%s' multiplier must be positive" % rarity)
	for family in weaponData.weaponFamilies:
		for base in weaponData.weaponFamilies[family]:
			errors.append_array(_checkBaseValue("weapon", str(base.get("id", "")), weaponData.baseValues))
	for slot in equipmentData.genericBases:
		errors.append_array(_checkBaseValue("equipment", str(equipmentData.genericBases[slot].get("id", "")), equipmentData.baseValues))
	for zoneId in equipmentData.zones:
		for entry in equipmentData.zones[zoneId]["items"]:
			errors.append_array(_checkBaseValue("equipment", str(entry.get("id", "")), equipmentData.baseValues))
	for legendaryId in legendaryData.legendaries:
		errors.append_array(_checkBaseValue("legendary", legendaryId, legendaryData.baseValues))
	for statKey in affixData.stats:
		var kind = str(affixData.stats[statKey].get("kind", ""))
		if !AFFIX_KIND_POINT_VALUES.has(kind):
			errors.append("affix stat '%s' has unvalued kind '%s'" % [statKey, kind])
	return errors


func _checkBaseValue(kind: String, definitionId: String, values: Dictionary) -> Array:
	var errors = []
	if definitionId == "":
		errors.append("%s definition has an empty id" % kind)
		return errors
	if !values.has(definitionId):
		errors.append("%s '%s' is missing a base value" % [kind, definitionId])
		return errors
	var value = values[definitionId]
	if typeof(value) != TYPE_INT or int(value) <= 0:
		errors.append("%s '%s' base value must be a positive integer" % [kind, definitionId])
	return errors


func _baseValue(itemType: String, definitionId: String, rarity: String) -> int:
	if rarity == "legendary":
		return int(legendaryData.baseValues.get(definitionId, 0))
	if itemType == "weapon":
		return int(weaponData.baseValues.get(definitionId, 0))
	return int(equipmentData.baseValues.get(definitionId, 0))


func _affixValue(item: Dictionary) -> Dictionary:
	var total = 0
	for key in ["prefix", "suffix"]:
		var affix = item.get(key, {})
		if affix == null or (affix is Dictionary and affix.is_empty()):
			continue
		if !(affix is Dictionary):
			return _failure("invalid_affix")
		var statKey = str(affix.get("stat", ""))
		if !affixData.stats.has(statKey):
			return _failure("unknown_affix")
		# Kind comes from the shared registry decision record (commit 12) so
		# pricing cannot value a stat the combat/generation record disagrees
		# about; legacy excluded affixes keep their record and stay sellable.
		var kind = CombatStatRegistryScript.affixKind(statKey)
		if kind == "":
			return _failure("unknown_affix")
		if !AFFIX_KIND_POINT_VALUES.has(kind):
			return _failure("unknown_affix_kind")
		var value = affix.get("value", null)
		if typeof(value) != TYPE_INT:
			return _failure("invalid_affix")
		total += absi(int(value)) * int(AFFIX_KIND_POINT_VALUES[kind])
	return { "success": true, "reason": "", "affixValue": total }


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason, "gearValue": 0, "buyPrice": 0, "sellPrice": 0 }
