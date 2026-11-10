extends RefCounted
class_name CharacterStatCalculator

## Pure equipment/stat projection (Docs/System Design/Journal/Inventory and
## Equipment.md). It never reads autoloads or mutates the member/equipment it is
## given. Only combat modifiers already supported by the fight pipeline are
## applied; other authored affixes remain item text.

const LEAD_FAMILIES = ["revolver", "rifle", "shotgun"]
const EXPLOSIVE_TYPES = ["gunpowder", "liquid", "shrapnel"]


func calculate(member: Dictionary, classData: Dictionary, replacementSlot := "", replacementItem = null) -> Dictionary:
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

	for debuff in result.get("knockoutDebuffs", []):
		var statName = str(debuff.get("stat", ""))
		if stats.has(statName):
			stats[statName] += int(debuff.get("amount", 0))

	var baseMaxHp = maxi(1, int(result.get("baseMaxHp", result.get("maxHp", result.get("hp", 1)))) + maxHpBonus)
	var injuryRate = maxi(1, int(result.get("injuryRate", 4)))
	var maxHp = maxi(1, baseMaxHp - int(floor(float(result.get("injuryDamage", 0)) / injuryRate)))
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
	match path:
		"maxHp":
			return int(data.get("maxHp", 0))
		"stats.sixShootin":
			return int(data.get("stats", {}).get("sixShootin", 0))
		"stats.highTailin":
			return int(data.get("stats", {}).get("highTailin", 0))
		"stats.taffyin":
			return int(data.get("stats", {}).get("taffyin", 0))
		"stats.defense.style":
			return int(data.get("stats", {}).get("defense", {}).get("style", 0))
		"stats.defense.sand":
			return int(data.get("stats", {}).get("defense", {}).get("sand", 0))
		"weapon.baseDamage":
			return int(data.get("weapon", {}).get("baseDamage", 0))
		"weapon.weapon":
			return str(data.get("weapon", {}).get("weapon", ""))
		"beltSpace":
			return int(data.get("beltSpace", -1))
	return null
