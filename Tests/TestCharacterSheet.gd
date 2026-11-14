extends SceneTree

## Headless validation for the Journal Character tab's read model
## (Docs/System Design/Journal/Character.md, patch 1).
## Run with: godot --headless --script res://Tests/TestCharacterSheet.gd

const CharacterStatCalculatorScript = preload("res://Globals/CharacterStatCalculator.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const PartyScript = preload("res://Globals/Party.gd")

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var calculator = CharacterStatCalculatorScript.new()
	testStatCatalog(calculator)
	testUnavailableValuesAndLegacyWeapon(calculator)
	testInjuriesAndKnockouts(calculator)
	testPartySnapshot()
	testNotifications()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func testStatCatalog(calculator) -> void:
	print("--- Calculator: full ordered catalog and Base/Effective values ---")
	var member = _member()
	var classData = _classes().Gunslinger
	var sheet = calculator.projectCharacter(member, classData)
	var effective = calculator.calculate(member, classData)
	_check(sheet.statRows.size() == 18, "the catalog has exactly 18 rows, got %d" % sheet.statRows.size())
	_check(_groups(sheet) == [
		"Vitality", "Core", "Core", "Core", "Lead", "Lead", "Lead",
		"Explosive", "Explosive", "Explosive", "Offense", "Defense", "Defense",
		"Resistances", "Resistances", "Weapon", "Weapon", "Loadout",
	], "groups follow the documented display order")
	_check(int(sheet.hp) == 12 and int(sheet.maxHp) == 15, "HP stays 12 while effective MxHP is 15")
	_check(int(sheet.maxHp) == int(effective.maxHp), "sheet MxHP matches calculate()")
	_check(_value(sheet, "maxHp", "base") == 12, "Base MxHP is the stored value without gear/injury")
	_check(_value(sheet, "maxHp", "effective") == 15, "Effective MxHP includes gear and injury")
	_check(_value(sheet, "stats.sixShootin", "base") == 3 and _value(sheet, "stats.sixShootin", "effective") == 3, "Six Shootin' stays unchanged")
	_check(_value(sheet, "stats.highTailin", "base") == 6 and _value(sheet, "stats.highTailin", "effective") == 7, "weapon High Tailin' appears only as Effective")
	_check(_value(sheet, "stats.taffyin", "effective") == 2, "Taffyin' projects from member stats")
	_check(_value(sheet, "stats.damage.lead.rifle", "effective") == 1, "Lead family stats are visible")
	_check(_value(sheet, "stats.damage.explosive.shrapnel", "effective") == 1, "Explosive type stats are visible")
	_check(_value(sheet, "stats.damage.lasso", "effective") == 0, "Lasso is part of the catalog")
	_check(_value(sheet, "stats.defense.style", "base") == 2 and _value(sheet, "stats.defense.style", "effective") == 5, "gear Style adds to Effective")
	_check(_value(sheet, "stats.defense.sand", "base") == 1 and _value(sheet, "stats.defense.sand", "effective") == 3, "gear Sand adds to Effective")
	_check(_row(sheet, "stats.resistances.bleed").format == "percent" and _value(sheet, "stats.resistances.bleed", "effective") == 0.0, "resistances use whole-percentage formatting")
	_check(_value(sheet, "weapon.weapon", "base") == "" and _value(sheet, "weapon.weapon", "effective") == "rifle", "canonical members have no Base weapon and an Effective rifle")
	_check(_value(sheet, "weapon.baseDamage", "base") == 0 and _value(sheet, "weapon.baseDamage", "effective") == 9, "weapon damage includes only the matching family affix")
	_check(_value(sheet, "beltSpace", "base") == 1 and _value(sheet, "beltSpace", "effective") == 2, "belt Base/Effective include class plus equipment")

	print("\n--- Calculator: modifier provenance and order ---")
	var kinds = _modifierKinds(sheet)
	_check(kinds == ["injury", "class", "equipment", "equipment", "equipment"], "modifiers are injury, class, then canonical equipment")
	var injury = sheet.modifiers[0]
	_check(injury.effects[0].path == "maxHp" and int(injury.effects[0].amount) == -1, "injury reports the MxHP penalty")
	_check(str(injury.detail).contains("Town entry"), "injury explains recovery without exposing internal rates")
	var classModifier = sheet.modifiers[1]
	_check(classModifier.sourceId == "Gunslinger" and classModifier.effects[0].path == "class.explosiveBase" and int(classModifier.effects[0].amount) == 2, "class explosive base is a separate contribution")
	var weaponModifier = sheet.modifiers[2]
	_check(weaponModifier.slot == "weapon" and weaponModifier.name == "Test Weapon", "weapon modifier carries its slot and name")
	_check(weaponModifier.effects.size() == 2 and weaponModifier.effects[0].path == "stats.highTailin" and int(weaponModifier.effects[0].amount) == 1, "weapon core stat is listed")
	_check(weaponModifier.effects[1].path == "weapon.baseDamage" and int(weaponModifier.effects[1].amount) == 5, "only the matching family damage affix is listed")
	var dusterModifier = sheet.modifiers[3]
	_check(dusterModifier.effects.size() == 3, "duster lists Style, Sand and MxHP only")
	_check(_effectPaths(dusterModifier) == ["stats.defense.style", "stats.defense.sand", "maxHp"], "duster effect order is deterministic")
	_check(!_allEffectPaths(sheet).has("stats.damageTakenReduction") and !_allEffectPaths(sheet).has("damageTakenReduction"), "unsupported affixes are not presented as active")
	_check(sheet.modifiers[4].slot == "belt" and sheet.modifiers[4].effects[0].path == "beltSpace", "belt space is a supported equipment modifier")

	print("\n--- Calculator: purity and no shared mutable state ---")
	var beforeHigh = member.stats.highTailin
	var beforeWeapon = member.equipment.weapon.stats.rifleDamage
	sheet.statRows[0]["base"] = 999
	sheet.modifiers[0].effects[0]["amount"] = 999
	var second = calculator.projectCharacter(member, _classes().Gunslinger)
	_check(_value(second, "maxHp", "base") == 12 and int(second.modifiers[0].effects[0].amount) == -1, "each projection is a fresh deep copy")
	_check(member.stats.highTailin == beforeHigh and member.equipment.weapon.stats.rifleDamage == beforeWeapon, "projection never mutates the source member")

func testUnavailableValuesAndLegacyWeapon(calculator) -> void:
	print("\n--- Calculator: unknown sentinels, empty data and legacy weapons ---")
	var sparse = { "hp": 5, "stats": {}, "equipment": {}, "knockoutDebuffs": [] }
	var sheet = calculator.projectCharacter(sparse, {})
	_check(sheet.statRows.size() == 18, "sparse members still project the full row catalog")
	_check(_value(sheet, "stats.sixShootin", "base") == null and _value(sheet, "stats.sixShootin", "effective") == null, "unknown -1 core stats project as unavailable")
	_check(_value(sheet, "stats.damage.lead.revolver", "effective") == null, "unknown family stats project as unavailable")
	_check(_value(sheet, "stats.damage.lasso", "effective") == 0, "Lasso defaults to a legitimate zero")
	_check(_value(sheet, "stats.defense.style", "base") == 0 and _value(sheet, "stats.resistances.bleed", "base") == 0.0, "missing defaults stay legitimate zeroes")
	_check(_value(sheet, "maxHp", "base") == 5 and _value(sheet, "maxHp", "effective") == 5, "MxHP falls back to stored hp")
	_check(_value(sheet, "weapon.weapon", "base") == "" and _value(sheet, "weapon.baseDamage", "base") == 0, "empty canonical equipment has no weapon values")
	_check(_value(sheet, "beltSpace", "base") == null and _value(sheet, "beltSpace", "effective") == null, "unknown class belt space is unavailable, not unlimited")

	var legacy = {
		"hp": 12, "baseMaxHp": 12, "injuryDamage": 0, "injuryRate": 4,
		"stats": {
			"sixShootin": 3, "highTailin": 6, "taffyin": 2,
			"damage": { "lead": { "revolver": 1, "rifle": 1, "shotgun": 1 } },
			"defense": { "style": 2, "sand": 1 },
		},
		"knockoutDebuffs": [],
		"weapon": { "type": "lead", "weapon": "revolver", "baseDamage": 3 },
	}
	sheet = calculator.projectCharacter(legacy, _classes().Gunslinger)
	_check(_value(sheet, "weapon.weapon", "base") == "revolver" and _value(sheet, "weapon.baseDamage", "base") == 3, "legacy members preserve their Base weapon")
	_check(_value(sheet, "weapon.weapon", "effective") == "revolver" and _value(sheet, "weapon.baseDamage", "effective") == 3, "legacy Effective weapon follows the legacy weapon")
	var canonical = legacy.duplicate(true)
	canonical["equipment"] = {}
	sheet = calculator.projectCharacter(canonical, _classes().Gunslinger)
	_check(_value(sheet, "weapon.weapon", "base") == "" and _value(sheet, "weapon.baseDamage", "base") == 0, "canonical equipment ignores stale legacy Base weapon data")

	print("\n--- Calculator: HP clamping and injury thresholds ---")
	var clamped = _member()
	clamped.hp = 99
	sheet = calculator.projectCharacter(clamped, _classes().Gunslinger)
	_check(int(sheet.hp) == 15 and int(sheet.maxHp) == 15, "current HP clamps to effective MxHP")
	var below = _member()
	below.injuryDamage = 2
	sheet = calculator.projectCharacter(below, _classes().Gunslinger)
	_check(int(sheet.maxHp) == 16 and int(sheet.modifiers[0].effects[0].amount) == 0, "injury below the threshold reports no MxHP loss")
	_check(str(sheet.modifiers[0].detail) == "No MxHP lost yet", "pre-threshold injury has a distinct detail")
	var floored = _member()
	floored.injuryDamage = 200
	_check(int(calculator.projectCharacter(floored, _classes().Gunslinger).maxHp) == 1, "Effective MxHP floors at one")
	var clean = _member()
	clean.injuryDamage = 0
	_check(!_modifierKinds(calculator.projectCharacter(clean, _classes().Gunslinger)).has("injury"), "no injury modifier without journey damage")

func testInjuriesAndKnockouts(calculator) -> void:
	print("\n--- Calculator: knockout grouping and effective stats ---")
	var member = _member()
	member.injuryDamage = 0
	member.knockoutDebuffs = [
		{ "stat": "sixShootin", "amount": -1, "shootoutsLeft": 3 },
		{ "stat": "highTailin", "amount": -2, "shootoutsLeft": 3 },
		{ "stat": "sixShootin", "amount": -1, "shootoutsLeft": 3 },
		{ "stat": "mysteryStat", "amount": -5, "shootoutsLeft": 3 },
	]
	var sheet = calculator.projectCharacter(member, _classes().Gunslinger)
	_check(_value(sheet, "stats.sixShootin", "effective") == 1, "duplicate knockout penalties both apply to Effective stats, got %s" % str(_value(sheet, "stats.sixShootin", "effective")))
	_check(_value(sheet, "stats.highTailin", "effective") == 5, "second knockout penalty applies")
	var knockouts = sheet.modifiers.filter(func(modifier): return modifier.kind == "knockout")
	_check(knockouts.size() == 2, "identical knockout entries group and unsupported stats are skipped")
	_check(int(knockouts[0].shootoutsLeft) == 3 and int(knockouts[1].shootoutsLeft) == 3, "knockout modifiers carry remaining Shootouts")
	_check(knockouts[0].effects[0].path == "stats.sixShootin" and int(knockouts[0].effects[0].amount) == -1, "knockout reports the supported stat penalty")
	_check(_modifierKinds(sheet).slice(0, 2) == ["knockout", "knockout"], "knockouts follow injury and precede class/equipment")

func testPartySnapshot() -> void:
	print("\n--- Party: character availability and snapshot ---")
	var party = _party()
	_check(party.isCharacterDataAvailable(), "configured character data is available")
	_check(!party.isInventoryDataAvailable(), "character availability does not require inventory data")
	var snapshot = party.getCharacterJournalSnapshot()
	_check(int(snapshot.level) == 1 and snapshot.members.size() == 1, "snapshot carries level and members")
	var walker = snapshot.members[0]
	_check(walker.key == "Walker Langley" and walker.actorName == "Walker Langley", "stable member identity is projected")
	_check(walker.characterClass == "Gunslinger" and !walker.downed, "class and downed state are projected")
	_check(int(walker.hp) == 12 and int(walker.maxHp) == 12, "HP and MxHP come from the fight projection")
	_check(walker.statRows.size() == 18, "snapshot includes the full row catalog")
	_check(_modifierKinds(walker) == ["class"], "only supported persistent modifiers are included")
	_check(walker.rodeo != null and walker.rodeo.available and walker.rodeo.name == "Leaders Duck", "mixed-case Rodeo lookup resolves display metadata")
	_check(str(walker.rodeo.description).contains("Every other turn"), "Rodeo description is copied")

	print("\n--- Party: snapshot isolation and read-only registries ---")
	snapshot.members[0].statRows[0]["base"] = 999
	snapshot.members[0].modifiers[0]["effects"][0]["amount"] = 999
	snapshot.members[0].rodeo["name"] = "Mutated"
	var fresh = party.getCharacterJournalSnapshot()
	_check(_value(fresh.members[0], "maxHp", "base") == 12 and int(fresh.members[0].modifiers[0].effects[0].amount) == 2, "mutating a snapshot cannot corrupt later snapshots")
	_check(fresh.members[0].rodeo.name == "Leaders Duck", "Rodeo display metadata is deeply copied")
	party.party["Walker Langley"]["stats"]["sixShootin"] = 99
	_check(_value(fresh.members[0], "stats.sixShootin", "base") == 3, "changing Party after a snapshot cannot mutate that snapshot")

	var classes = _classes()
	var rodeos = _rodeos()
	var isolated = _party()
	isolated.configureCharacterData(classes, rodeos)
	classes.Gunslinger.beltSpace = 99
	rodeos["Leaders Duck"]["name"] = "Changed"
	var isolatedSnapshot = isolated.getCharacterJournalSnapshot()
	_check(_value(isolatedSnapshot.members[0], "beltSpace", "base") == 1, "class definitions are deep-copied during configuration")
	_check(isolatedSnapshot.members[0].rodeo.name == "Leaders Duck", "Rodeo definitions are deep-copied during configuration")
	isolated.free()

	print("\n--- Party: empty, malformed, unknown and no Rodeo states ---")
	var unknownRodeo = _party()
	unknownRodeo.party["Walker Langley"]["rodeo"] = "mystery"
	var unknownSnapshot = unknownRodeo.getCharacterJournalSnapshot()
	_check(!unknownSnapshot.members[0].rodeo.available and unknownSnapshot.members[0].rodeo.name == "mystery", "unknown Rodeo keys remain visible without hiding the sheet")
	unknownRodeo.party["Walker Langley"]["rodeo"] = null
	_check(unknownRodeo.getCharacterJournalSnapshot().members[0].rodeo == null, "empty Rodeo projects as no Rodeo")
	unknownRodeo.free()

	var empty = _party()
	empty.party = {}
	_check(empty.getCharacterJournalSnapshot().members.is_empty(), "a valid empty party returns no members")
	empty.free()

	var malformed = _party()
	malformed.party["Bad"] = null
	malformed.party["Also Bad"] = "not a member"
	var malformedSnapshot = malformed.getCharacterJournalSnapshot()
	_check(malformedSnapshot.members.size() == 1 and malformedSnapshot.members[0].key == "Walker Langley", "malformed members are skipped while valid siblings remain")
	var second = malformed.party["Walker Langley"].duplicate(true)
	second["actorName"] = "Second Member"
	malformed.party["Second Member"] = second
	var ordered = malformed.getCharacterJournalSnapshot()
	_check(ordered.members.size() == 2 and ordered.members[0].key == "Walker Langley" and ordered.members[1].key == "Second Member", "members keep authoritative Dictionary order")
	malformed.free()

	var unconfigured = PartyScript.new()
	_check(!unconfigured.isCharacterDataAvailable(), "character data is unavailable before configuration")
	_check(unconfigured.getCharacterJournalSnapshot().members.is_empty(), "unavailable character data returns no members")
	unconfigured.free()

	var independent = _party()
	var brokenCatalog = ItemCatalogScript.new()
	brokenCatalog.definitions["paregoric"]["stackLimit"] = 0
	independent.configureInventory(brokenCatalog, _classes().Gunslinger)
	_check(!independent.isInventoryDataAvailable() and independent.isCharacterDataAvailable(), "invalid inventory catalog does not disable character data")
	independent.free()
	party.free()

func testNotifications() -> void:
	print("\n--- Party: committed mutation notifications ---")
	var party = _party()
	party.configureInventory(ItemCatalogScript.new(), _classes().Gunslinger)
	party.setInventoryManagementAllowed(true)
	party.inventory = []
	party._nextInstanceNumber = 1
	var signals = []
	party.partyChanged.connect(func(key): signals.append(key))
	var added = party.addItem(_duster("Notify Duster", 4))
	_check(added.success and signals.is_empty(), "inventory-only changes do not emit partyChanged")
	var dusterId = added.acceptedInstanceIds[0]
	var result = party.equipItem("Walker Langley", dusterId)
	_check(result.success and signals == ["Walker Langley"], "successful equip emits one member notification")
	signals.clear()
	party.equipItem("Walker Langley", "missing")
	party.equipItem("Missing Member", dusterId)
	_check(signals.is_empty(), "rejected equip commands emit nothing")
	party.free()

	var fight = _party()
	signals = []
	fight.partyChanged.connect(func(key): signals.append(key))
	fight.applyFightResults({ "party": {}, "fled": false })
	_check(signals.is_empty(), "an empty, unchanged fight result emits nothing")
	fight.applyFightResults({ "party": { "Walker Langley": { "hp": 5, "injuryDamage": 2 } }, "fled": false })
	_check(signals == [""], "one fight result emits one whole-party notification")
	fight.free()

	var ticking = _party()
	ticking.party["Walker Langley"]["knockoutDebuffs"] = [
		{ "stat": "sixShootin", "amount": -1, "shootoutsLeft": 2 },
	]
	signals = []
	ticking.partyChanged.connect(func(key): signals.append(key))
	ticking.applyFightResults({ "party": {}, "fled": false })
	_check(signals == [""] and ticking.party["Walker Langley"].knockoutDebuffs[0].shootoutsLeft == 1, "knockout ticks emit one notification")
	ticking.free()

	var fleeing = _party()
	signals = []
	fleeing.partyChanged.connect(func(key): signals.append(key))
	fleeing.applyFightResults({ "party": { "Walker Langley": { "hp": 5, "injuryDamage": 0 } }, "fled": true })
	_check(signals == [""], "batched flee cost stays inside the single fight notification")
	_check(int(fleeing.party["Walker Langley"].injuryDamage) > 0, "batched flee cost still mutates injury")
	signals.clear()
	fleeing.applyFleeCost("Walker Langley")
	_check(signals == ["Walker Langley"], "standalone flee emits the member key")
	signals.clear()
	fleeing.applyFleeCost("Missing Member")
	_check(signals.is_empty(), "flee for an unknown member emits nothing")
	fleeing.free()

	var condition = _party()
	signals = []
	condition.partyChanged.connect(func(key): signals.append(key))
	condition.resetInjury()
	_check(signals.is_empty(), "a no-op town reset emits nothing")
	condition.party["Walker Langley"]["injuryDamage"] = 8
	condition.resetInjury()
	_check(signals == [""] and int(condition.party["Walker Langley"].injuryDamage) == 0, "town reset emits once after clearing injuries")
	signals.clear()
	condition.party["Walker Langley"]["injuryDamage"] = 10
	condition.reduceInjury(0)
	_check(signals.is_empty(), "non-positive camp reduction emits nothing")
	condition.reduceInjury(3)
	_check(signals == [""] and int(condition.party["Walker Langley"].injuryDamage) == 7, "camp reduction emits once")
	signals.clear()
	condition.reduceInjury(100)
	_check(signals == [""] and int(condition.party["Walker Langley"].injuryDamage) == 0, "camp reduction clamps at zero and emits once")
	signals.clear()
	condition.reduceInjury(1)
	_check(signals.is_empty(), "zero-injury camp reduction emits nothing")
	condition.vamoose()
	_check(signals == [""] and condition.party["Walker Langley"].downed and condition.party["Walker Langley"].knockoutDebuffs.size() == 2, "Vamoose emits one whole-party notification")
	condition.free()

func _party():
	var party = PartyScript.new()
	party.configureCharacterData(_classes(), _rodeos())
	return party


func _classes() -> Dictionary:
	return {
		"Gunslinger": {
			"name": "Gunslinger",
			"beltSpace": 1,
			"explosiveBase": 2,
			"magazine": [1, 0, 1, -1],
		},
	}


func _rodeos() -> Dictionary:
	return {
		"Leaders Duck": {
			"name": "Leaders Duck",
			"description": "Every other turn, at the end of the turn, move one column backward",
			"trigger": "turn_end",
		},
	}


func _member() -> Dictionary:
	return {
		"actorName": "Test Member",
		"characterClass": "Gunslinger",
		"rodeo": "leaders duck",
		"hp": 12,
		"baseMaxHp": 12,
		"injuryDamage": 4,
		"injuryRate": 4,
		"knockoutDebuffs": [],
		"downed": false,
		"stats": {
			"sixShootin": 3, "highTailin": 6, "taffyin": 2,
			"damage": {
				"lead": { "revolver": 1, "rifle": 1, "shotgun": 1 },
				"explosive": { "gunpowder": 1, "liquid": 1, "shrapnel": 1 },
				"lasso": 0,
			},
			"defense": { "style": 2, "sand": 1 },
			"resistances": { "bleed": 0.0, "poison": 0.0 },
		},
		"equipment": {
			"weapon": _weapon("rifle", 4, { "rifleDamage": 5, "revolverDamage": 99, "highTailin": 1 }),
			"headwear": null,
			"bandana": null,
			"duster": _duster("Test Duster", 4, { "style": 3, "sand": 2, "damageTakenReduction": 99 }),
			"belt": _belt(1),
			"trousers": null,
			"justins": null,
		},
	}


func _weapon(family: String, baseDamage: int, stats: Dictionary) -> Dictionary:
	return {
		"instanceId": "test_weapon",
		"definitionId": "test_weapon",
		"quantity": 1,
		"itemType": "weapon",
		"name": "Test Weapon",
		"baseName": "Test Weapon",
		"family": family,
		"baseDamage": baseDamage,
		"stats": stats.duplicate(true),
	}


func _duster(itemName: String, maxHp: int, extraStats := {}) -> Dictionary:
	var stats = { "style": 1, "sand": 1, "mxHp": maxHp }
	for key in extraStats:
		stats[key] = extraStats[key]
	return {
		"instanceId": "test_duster",
		"definitionId": "test_duster",
		"quantity": 1,
		"itemType": "equipment",
		"slot": "duster",
		"name": itemName,
		"baseName": itemName,
		"stats": stats,
	}


func _belt(space: int) -> Dictionary:
	return {
		"instanceId": "test_belt",
		"definitionId": "test_belt",
		"quantity": 1,
		"itemType": "equipment",
		"slot": "belt",
		"name": "Test Belt",
		"baseName": "Test Belt",
		"beltSpace": space,
		"stats": {},
	}


func _row(data: Dictionary, path: String) -> Dictionary:
	for rowValue in data.get("statRows", []):
		if rowValue is Dictionary and str(rowValue.get("path", "")) == path:
			return rowValue
	return {}


func _value(data: Dictionary, path: String, key: String):
	return _row(data, path).get(key, null)


func _groups(sheet: Dictionary) -> Array:
	var groups = []
	for row in sheet.get("statRows", []):
		groups.append(str(row.get("group", "")))
	return groups


func _modifierKinds(data: Dictionary) -> Array:
	var kinds = []
	for modifier in data.get("modifiers", []):
		kinds.append(str(modifier.get("kind", "")))
	return kinds


func _effectPaths(modifier: Dictionary) -> Array:
	var paths = []
	for effect in modifier.get("effects", []):
		paths.append(str(effect.get("path", "")))
	return paths


func _allEffectPaths(data: Dictionary) -> Array:
	var paths = []
	for modifier in data.get("modifiers", []):
		paths.append_array(_effectPaths(modifier))
	return paths


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
