extends RefCounted
class_name CharacterStatCalculator

## Pure equipment/stat projection (Docs/System Design/Journal/Inventory and
## Equipment.md). It never reads autoloads or mutates the member/equipment it is
## given. Only combat modifiers already supported by the fight pipeline are
## applied; other authored affixes remain item text.

const LEAD_FAMILIES = ["revolver", "rifle", "shotgun"]
const EXPLOSIVE_TYPES = ["gunpowder", "liquid", "shrapnel"]
const EQUIPMENT_SLOTS = [
	"weapon", "headwear", "bandana", "duster", "belt", "trousers", "justins",
]
const STAT_LABELS = {
	"maxHp": "MxHP",
	"sixShootin": "Six Shootin'",
	"highTailin": "High Tailin'",
	"taffyin": "Taffyin'",
	"lasso": "Lasso",
	"style": "Style",
	"sand": "Sand",
	"bleed": "Bleed",
	"poison": "Poison",
}
## Ordered rows for the Journal character sheet. `sentinel` marks the existing
## -1 "unknown stat" value that the UI projects as unavailable rather than -1.
const STAT_ROWS = [
	{ "group": "Vitality", "path": "maxHp", "label": "MxHP", "format": "integer" },
	{ "group": "Core", "path": "stats.sixShootin", "label": "Six Shootin'", "format": "integer", "sentinel": true },
	{ "group": "Core", "path": "stats.highTailin", "label": "High Tailin'", "format": "integer", "sentinel": true },
	{ "group": "Core", "path": "stats.taffyin", "label": "Taffyin'", "format": "integer", "sentinel": true },
	{ "group": "Lead", "path": "stats.damage.lead.revolver", "label": "Revolver", "format": "integer", "sentinel": true },
	{ "group": "Lead", "path": "stats.damage.lead.rifle", "label": "Rifle", "format": "integer", "sentinel": true },
	{ "group": "Lead", "path": "stats.damage.lead.shotgun", "label": "Shotgun", "format": "integer", "sentinel": true },
	{ "group": "Explosive", "path": "stats.damage.explosive.gunpowder", "label": "Gunpowder", "format": "integer", "sentinel": true },
	{ "group": "Explosive", "path": "stats.damage.explosive.liquid", "label": "Liquid", "format": "integer", "sentinel": true },
	{ "group": "Explosive", "path": "stats.damage.explosive.shrapnel", "label": "Shrapnel", "format": "integer", "sentinel": true },
	{ "group": "Offense", "path": "stats.damage.lasso", "label": "Lasso", "format": "integer", "sentinel": true },
	{ "group": "Defense", "path": "stats.defense.style", "label": "Style", "format": "integer" },
	{ "group": "Defense", "path": "stats.defense.sand", "label": "Sand", "format": "integer" },
	{ "group": "Resistances", "path": "stats.resistances.bleed", "label": "Bleed", "format": "percent" },
	{ "group": "Resistances", "path": "stats.resistances.poison", "label": "Poison", "format": "percent" },
	{ "group": "Weapon", "path": "weapon.weapon", "label": "Family", "format": "text" },
	{ "group": "Weapon", "path": "weapon.baseDamage", "label": "Damage", "format": "integer" },
	{ "group": "Loadout", "path": "beltSpace", "label": "Belt space", "format": "integer" },
]


func calculate(member: Dictionary, classData: Dictionary, replacementSlot := "", replacementItem = null, context := {}) -> Dictionary:
	var result = member.duplicate(true)
	var stats = _normalizedStats(result.get("stats", {}))
	result["stats"] = stats
	var equipment = _equipmentWithReplacement(result.get("equipment", {}), replacementSlot, replacementItem)
	result["equipment"] = equipment.duplicate(true)

	var maxHpBonus = 0
	for slot in equipment:
		var item = equipment[slot]
		if !(item is Dictionary):
			continue
		var itemStats = item.get("stats", {})
		if !(itemStats is Dictionary):
			continue
		stats["sixShootin"] += int(itemStats.get("sixShootin", 0))
		stats["highTailin"] += int(itemStats.get("highTailin", 0))
		stats["taffyin"] += int(itemStats.get("taffyin", 0))
		stats.defense.style += int(itemStats.get("style", 0))
		stats.defense.sand += int(itemStats.get("sand", 0))
		maxHpBonus += int(itemStats.get("mxHp", 0))

	# Attrition is injected: Off Trail ignores accumulated journey injury for
	# the effective MxHP projection. The calculator never reads Locations.
	var injuryDamage = int(result.get("injuryDamage", 0)) if bool(context.get("applyAttrition", true)) else 0
	var baseMaxHp = maxi(1, int(result.get("baseMaxHp", result.get("maxHp", result.get("hp", 1)))) + maxHpBonus)
	var injuryRate = maxi(1, int(result.get("injuryRate", 4)))
	var maxHp = maxi(1, baseMaxHp - int(floor(float(injuryDamage) / injuryRate)))
	result["baseMaxHp"] = baseMaxHp
	result["maxHp"] = maxHp
	result["hp"] = mini(int(result.get("hp", maxHp)), maxHp)

	var weaponItem = equipment.get("weapon", null)
	if weaponItem is Dictionary:
		var family = str(weaponItem.get("family", ""))
		var weaponStats = weaponItem.get("stats", {})
		var familyDamage = int(weaponStats.get(family + "Damage", 0)) if weaponStats is Dictionary else 0
		result["weapon"] = {
			"type": "lead",
			"weapon": family,
			"baseDamage": int(weaponItem.get("baseDamage", 0)) + familyDamage,
		}
	elif !result.has("weapon"):
		result["weapon"] = { "type": null, "weapon": null, "baseDamage": 0 }

	var classBeltSpace = int(classData.get("beltSpace", -1))
	if classBeltSpace < 0:
		result["beltSpace"] = -1
	else:
		var belt = equipment.get("belt", null)
		var beltBonus = int(belt.get("beltSpace", 0)) if belt is Dictionary else 0
		result["beltSpace"] = classBeltSpace + beltBonus
	return result


## Pure Journal character-sheet projection. It uses the same calculate() result
## as fight setup, reports persisted Base values, and never mutates its inputs.
func projectCharacter(member: Dictionary, classData: Dictionary, context := {}) -> Dictionary:
	var effective = calculate(member, classData, "", null, context)
	var baseStats = _normalizedStats(member.get("stats", {}))
	var baseWeapon = _baseWeapon(member)
	var rows = []
	for specValue in STAT_ROWS:
		var spec = specValue as Dictionary
		var path = str(spec.get("path", ""))
		var baseValue = null
		var effectiveValue = null
		match path:
			"maxHp":
				baseValue = _storedBaseMaxHp(member)
				effectiveValue = _intValue(effective.get("maxHp", 0))
			"weapon.weapon":
				baseValue = str(baseWeapon.get("weapon", ""))
				effectiveValue = str(_effectiveWeapon(effective).get("weapon", ""))
			"weapon.baseDamage":
				baseValue = _intValue(baseWeapon.get("baseDamage", 0))
				effectiveValue = _intValue(_effectiveWeapon(effective).get("baseDamage", 0))
			"beltSpace":
				baseValue = _baseBeltSpace(classData)
				var effectiveBelt = _intValue(effective.get("beltSpace", -1))
				effectiveValue = effectiveBelt if effectiveBelt >= 0 else null
			_:
				baseValue = _projectStatValue(_valueAt({"stats": baseStats}, path), spec)
				effectiveValue = _projectStatValue(_valueAt(effective, path), spec)
		rows.append({
			"group": str(spec.get("group", "")),
			"path": path,
			"label": str(spec.get("label", "")),
			"base": baseValue,
			"effective": effectiveValue,
			"format": str(spec.get("format", "integer")),
		})
	return {
		"hp": _intValue(effective.get("hp", 0)),
		"maxHp": _intValue(effective.get("maxHp", 0)),
		"statRows": rows,
		"modifiers": _projectModifiers(member, classData, effective),
	}


func _projectStatValue(value, spec: Dictionary):
	if value == null:
		return null
	var format = str(spec.get("format", "integer"))
	if format == "percent":
		return float(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else null
	if format == "text":
		return str(value)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return null
	var number = int(value)
	if bool(spec.get("sentinel", false)) and number == -1:
		return null
	return number


func _storedBaseMaxHp(member: Dictionary):
	for key in ["baseMaxHp", "maxHp", "hp"]:
		var value = member.get(key, null)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return int(value)
	return null


## Canonical equipment has no unequipped Base weapon; legacy members without an
## equipment Dictionary keep their existing weapon for compatibility.
func _baseWeapon(member: Dictionary) -> Dictionary:
	if member.get("equipment", null) is Dictionary:
		return {}
	var weapon = member.get("weapon", null)
	return weapon if weapon is Dictionary else {}


func _effectiveWeapon(effective: Dictionary) -> Dictionary:
	var weapon = effective.get("weapon", {})
	return weapon if weapon is Dictionary else {}


func _baseBeltSpace(classData: Dictionary):
	var value = classData.get("beltSpace", null)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return null
	var space = int(value)
	return space if space >= 0 else null


func _intValue(value, fallback := 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


## Fixed-row comparison in display order. Unchanged rows are omitted so this is
## the "changed stats" list; current summaries render the full projection.
func compare(current: Dictionary, projected: Dictionary) -> Array:
	var rows = []
	for spec in [
		{ "path": "maxHp", "label": "MxHP" },
		{ "path": "stats.sixShootin", "label": "Six Shootin'" },
		{ "path": "stats.highTailin", "label": "High Tailin'" },
		{ "path": "stats.taffyin", "label": "Taffyin'" },
		{ "path": "stats.defense.style", "label": "Style" },
		{ "path": "stats.defense.sand", "label": "Sand" },
		{ "path": "weapon.baseDamage", "label": "Damage" },
		{ "path": "beltSpace", "label": "Belt space" },
	]:
		var before = _valueAt(current, spec.path)
		var after = _valueAt(projected, spec.path)
		if before == after:
			continue
		rows.append({ "path": spec.path, "label": spec.label, "before": before, "after": after, "delta": after - before })
	var beforeFamily = str(_valueAt(current, "weapon.weapon"))
	var afterFamily = str(_valueAt(projected, "weapon.weapon"))
	if beforeFamily != afterFamily:
		rows.append({
			"path": "weapon.weapon",
			"label": "Weapon family",
			"before": beforeFamily,
			"after": afterFamily,
			"delta": 0,
		})
	return rows


func _projectModifiers(member: Dictionary, classData: Dictionary, effective: Dictionary) -> Array:
	var modifiers = []
	var injury = _injuryModifier(member, effective)
	if !injury.is_empty():
		modifiers.append(injury)
	var classModifier = _classModifier(member, classData)
	if !classModifier.is_empty():
		modifiers.append(classModifier)
	modifiers.append_array(_equipmentModifiers(member))
	return modifiers


func _injuryModifier(member: Dictionary, effective: Dictionary) -> Dictionary:
	if _intValue(member.get("injuryDamage", 0)) <= 0:
		return {}
	var maxHp = _intValue(effective.get("maxHp", 0))
	var gearBase = _intValue(effective.get("baseMaxHp", maxHp))
	var amount = maxHp - gearBase
	var detail = "No MxHP lost yet" if amount == 0 else "Town entry resets journey injuries; camp items reduce them."
	return _makeModifier(
		"injury", "injury", "Journey injury", "",
		[_effect("maxHp", STAT_LABELS["maxHp"], amount)], 0, detail
	)


func _classModifier(member: Dictionary, classData: Dictionary) -> Dictionary:
	var amount = _intValue(classData.get("explosiveBase", 0))
	if amount == 0:
		return {}
	var className = str(classData.get("name", member.get("characterClass", "")))
	if className.is_empty():
		className = "Class"
	return _makeModifier(
		"class", className, className, "",
		[_effect("class.explosiveBase", "Explosive base", amount)], 0, ""
	)


func _equipmentModifiers(member: Dictionary) -> Array:
	var modifiers = []
	var equipment = member.get("equipment", {})
	if !(equipment is Dictionary):
		return modifiers
	for slot in EQUIPMENT_SLOTS:
		var item = equipment.get(slot, null)
		if !(item is Dictionary):
			continue
		var effects = _itemEffects(slot, item as Dictionary)
		if effects.is_empty():
			continue
		var sourceId = str(item.get("instanceId", item.get("definitionId", "")))
		var itemName = str(item.get("name", item.get("baseName", slot.capitalize())))
		if itemName.is_empty():
			itemName = slot.capitalize()
		modifiers.append(_makeModifier("equipment", sourceId, itemName, slot, effects, 0, ""))
	return modifiers


## Supported equipment effects only, in the same order calculate() applies them.
func _itemEffects(slot: String, item: Dictionary) -> Array:
	var effects = []
	var stats = item.get("stats", {})
	if stats is Dictionary:
		_appendEffect(effects, "stats.sixShootin", STAT_LABELS["sixShootin"], _intValue(stats.get("sixShootin", 0)))
		_appendEffect(effects, "stats.highTailin", STAT_LABELS["highTailin"], _intValue(stats.get("highTailin", 0)))
		_appendEffect(effects, "stats.taffyin", STAT_LABELS["taffyin"], _intValue(stats.get("taffyin", 0)))
		_appendEffect(effects, "stats.defense.style", STAT_LABELS["style"], _intValue(stats.get("style", 0)))
		_appendEffect(effects, "stats.defense.sand", STAT_LABELS["sand"], _intValue(stats.get("sand", 0)))
		_appendEffect(effects, "maxHp", STAT_LABELS["maxHp"], _intValue(stats.get("mxHp", 0)))
		if slot == "weapon":
			var family = str(item.get("family", ""))
			if !family.is_empty():
				_appendEffect(effects, "weapon.baseDamage", "Damage", _intValue(stats.get(family + "Damage", 0)))
	if slot == "belt":
		_appendEffect(effects, "beltSpace", "Belt space", _intValue(item.get("beltSpace", 0)))
	return effects


func _appendEffect(effects: Array, path: String, label: String, amount: int) -> void:
	if amount == 0:
		return
	effects.append(_effect(path, label, amount))


func _statPath(stat: String) -> String:
	return "maxHp" if stat == "maxHp" else "stats.%s" % stat


func _effect(path: String, label: String, amount) -> Dictionary:
	return { "path": path, "label": label, "amount": amount, "format": "integer" }


func _makeModifier(kind: String, sourceId: String, name: String, slot: String, effects: Array, shootoutsLeft: int, detail: String) -> Dictionary:
	return {
		"kind": kind,
		"sourceId": sourceId,
		"name": name,
		"slot": slot,
		"effects": effects.duplicate(true),
		"shootoutsLeft": shootoutsLeft,
		"detail": detail,
	}


func _equipmentWithReplacement(equipmentValue, replacementSlot: String, replacementItem) -> Dictionary:
	var equipment = equipmentValue.duplicate(true) if equipmentValue is Dictionary else {}
	if replacementSlot != "":
		equipment[replacementSlot] = replacementItem.duplicate(true) if replacementItem is Dictionary else null
	return equipment


func _normalizedStats(statsValue) -> Dictionary:
	var stats = statsValue.duplicate(true) if statsValue is Dictionary else {}
	stats["sixShootin"] = int(stats.get("sixShootin", -1))
	stats["highTailin"] = int(stats.get("highTailin", -1))
	stats["taffyin"] = int(stats.get("taffyin", -1))
	var damage = stats.get("damage", {})
	if !(damage is Dictionary):
		damage = {}
	damage = damage.duplicate(true)
	var lead = damage.get("lead", {})
	if !(lead is Dictionary):
		lead = {}
	for family in LEAD_FAMILIES:
		lead[family] = int(lead.get(family, -1))
	damage["lead"] = lead
	var explosive = damage.get("explosive", {})
	if !(explosive is Dictionary):
		explosive = {}
	for damageType in EXPLOSIVE_TYPES:
		explosive[damageType] = int(explosive.get(damageType, -1))
	damage["explosive"] = explosive
	damage["lasso"] = int(damage.get("lasso", 0))
	stats["damage"] = damage
	var defense = stats.get("defense", {})
	if !(defense is Dictionary):
		defense = {}
	stats["defense"] = {
		"style": int(defense.get("style", 0)),
		"sand": int(defense.get("sand", 0)),
	}
	var resistances = stats.get("resistances", {})
	if !(resistances is Dictionary):
		resistances = {}
	stats["resistances"] = {
		"bleed": float(resistances.get("bleed", 0.0)),
		"poison": float(resistances.get("poison", 0.0)),
	}
	return stats


func _valueAt(data: Dictionary, path: String):
	var current = data
	for part in path.split("."):
		if !(current is Dictionary):
			return null
		current = current.get(part, null)
		if current == null:
			return null
	return current
