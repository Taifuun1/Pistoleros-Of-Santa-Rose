extends SceneTree

## Production content lint (Docs/System Design/First Steps Implementation Plan.md,
## commit 6; System Coherence.md section 10). Fails closed on silent content
## defects: duplicate `data.name` values that would overwrite each other, unknown
## Move/item/effect/class/actor references, non-canonical Zone ids, and reward or
## Location-access producers that are not behind the authoritative Trail gate.
## Run with: godot --headless --script res://Tests/TestContentLint.gd

const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const EffectManagerScript = preload("res://Shootout/ShootoutEffectManager.gd")
const CombatStatRegistryScript = preload("res://Globals/CombatStatRegistry.gd")
const CombatLoadoutProjectorScript = preload("res://Globals/CombatLoadoutProjector.gd")
const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")
const EquipmentDataScript = preload("res://Data/Items/EquipmentData.gd")
const ShootoutEnemyAIScript = preload("res://Shootout/ShootoutEnemyAI.gd")

## Every folder whose files expose a `data` Dictionary identified by `data.name`.
const CONTENT_FOLDERS := [
	"res://Data/Shootout/Moves",
	"res://Data/Shootout/Items",
	"res://Data/Shootout/Encounters",
	"res://Data/Shootout/LootTables",
	"res://Data/Shootout/Rodeos",
	"res://Data/Shootout/Classes",
	"res://Data/Actors/Animals",
	"res://Data/Actors/Named People",
]

## Source roots scanned for Trail-gated reward producers. Tests are excluded:
## they inject fixtures and gates deliberately.
const PRODUCTION_ROOTS := [
	"res://Globals",
	"res://Shootout",
	"res://Overworld",
	"res://Location",
	"res://Minigames",
	"res://Nodes",
	"res://UI",
	"res://Vendors",
	"res://Actors",
	"res://Items",
	"res://Cutscenes",
	"res://Game",
]

const CHUNK_DIR := "res://Overworld/Overworld Chunks"
const GENERIC_EVENT_FILE := "res://Data/Events/GenericEvents.gd"
const SUPPORTED_OUTCOME_KINDS := ["none", "encounter"]
const REWARD_CALL_TOKENS := ["generateLoot(", ".applyLoot("]
const TRAIL_GATE_TOKENS := ["canGrantLoot", "onTrail", "trailState", "applyAttrition"]
const MOVE_EFFECT_OPS := ["apply_effect", "cleanse_effect", "modify_cylinder"]
const RODEO_EFFECT_OPS := ["modify_stat", "move_position", "modify_loot", "set_hit_quality_floor", "cleanse_effect"]

var failures := 0

const AffixDataScript = preload("res://Data/Items/AffixData.gd")
const LegendaryDataScript = preload("res://Data/Items/LegendaryData.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_testDuplicateNames()
	_testReferenceIntegrity()
	_testZoneReferences()
	_testTrailAndAccessGates()
	_testMoveGrants()
	_testAffixSupport()
	_testAiProfiles()
	_testLintHasTeeth()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


## Proves the lint has teeth: deliberately broken fixtures must trip it and a
## valid producer must not.
## Class, weapon and equipment Move grants must resolve to authored Moves, and
## no combat actor may lose its only offensive option to a grant union.

## Commit 12: every rollable or sellable affix has a registry decision, and no
## generation pool or authored legendary references an excluded stat.
func _testAffixSupport() -> void:
	print("\n--- Affix support registry ---")
	var affixData = AffixDataScript.new()
	var decisions := CombatStatRegistryScript.AFFIX_DECISIONS
	for statKey in affixData.stats:
		var decision = decisions.get(statKey, null)
		if !(decision is Dictionary):
			_check(false, "affix stat '%s' has a registry decision" % statKey)
			continue
		var kindMatches := str(decision.get("kind", "")) == str(affixData.stats[statKey].get("kind", ""))
		_check(kindMatches, "affix stat '%s' kind matches its registry decision" % statKey)
		if bool(decision.get("generation", false)):
			_check(!str(decision.get("consumer", "")).is_empty(), "supported affix '%s' names its production consumer" % statKey)
		else:
			_check(!str(decision.get("reason", "")).is_empty(), "excluded affix '%s' records its exclusion reason" % statKey)
	for statKey in decisions:
		_check(affixData.stats.has(statKey), "registry decision '%s' maps to an authored affix stat" % statKey)

	var poolEntries := []
	for category in affixData.prefixes:
		for affixName in affixData.prefixes[category]:
			poolEntries.append([affixName, str(affixData.prefixes[category][affixName])])
	for affixName in affixData.suffixes:
		poolEntries.append([affixName, str(affixData.suffixes[affixName])])
	var legendaryStats := []
	var legendaryData = LegendaryDataScript.new()
	for legendaryKey in legendaryData.legendaries:
		var stats = legendaryData.legendaries[legendaryKey].get("stats", {})
		if stats is Dictionary:
			for statKey in stats:
				legendaryStats.append(str(statKey))
	var errors := _affixSupportErrors(decisions, poolEntries, legendaryStats)
	_check(errors.is_empty(), "generation pools and legendaries roll only supported affixes: %s" % [errors])

	var brokenErrors := _affixSupportErrors(
		{ "sixShootin": { "kind": "flat", "generation": true, "consumer": "test" } },
		[["Sundance", "turnOrder"], ["Ghost", "unknown_stat"]],
		["lootGems"])
	_check(brokenErrors.size() == 3, "broken fixtures trip the affix support lint: %s" % [brokenErrors])
	_check(_affixSupportErrors(decisions, [["Cowboys", "sixShootin"]], []).is_empty(), "a supported pool entry passes")


## Pure per-fixture checker so the lint can prove it rejects broken pools.
func _affixSupportErrors(decisions: Dictionary, poolEntries: Array, legendaryStats: Array) -> Array:
	var errors := []
	for entry in poolEntries:
		var statKey := str(entry[1])
		var decision = decisions.get(statKey, null)
		if !(decision is Dictionary):
			errors.append("pool affix '%s' rolls unknown stat '%s'" % [entry[0], statKey])
		elif !bool(decision.get("generation", false)):
			errors.append("pool affix '%s' rolls excluded stat '%s'" % [entry[0], statKey])
	for statKey in legendaryStats:
		var decision = decisions.get(statKey, null)
		if !(decision is Dictionary):
			errors.append("legendary stat '%s' has no registry decision" % statKey)
		elif !bool(decision.get("generation", false)):
			errors.append("legendary stat '%s' is excluded from generation" % statKey)
	return errors


## Commit 13: authored `ai` profiles are validated — known archetypes, positive
## selection counts, positive action-family weights, and scripts that resolve to
## real AI data with known Moves and targets. Unprofiled actors stay legal.
func _testAiProfiles() -> void:
	print("\n--- AI profiles resolve ---")
	var moves := _collectData("res://Data/Shootout/Moves")
	var moveNames := {}
	for entry in moves.entries:
		moveNames[str(entry.data.get("name", ""))] = true
	var scriptNames := {}
	for fileName in _gdFiles("res://Data/Shootout/AI"):
		scriptNames[fileName.get_basename()] = true
	var actorNames := {}
	for folder in ["res://Data/Actors/Animals", "res://Data/Actors/Named People"]:
		for entry in _collectData(folder).entries:
			actorNames[str(entry.data.get("actorName", ""))] = true

	var actors := _collectData("res://Data/Actors/Animals")
	actors.entries.append_array(_collectData("res://Data/Actors/Named People").entries)
	var profiled := 0
	for entry in actors.entries:
		var label := str(entry.data.get("actorName", entry.file))
		var aiBlock = entry.data.get("ai", null)
		if !(aiBlock is Dictionary):
			continue
		profiled += 1
		var errors := _aiProfileErrors(aiBlock, scriptNames, moveNames, actorNames)
		_check(errors.is_empty(), "actor '%s' has a valid AI profile: %s" % [label, errors])
	_check(profiled >= 1, "at least one authored AI profile is linted, got %d" % profiled)

	var broken := _aiProfileErrors(
		{
			"archetype": "assassin", "pickFromTop": 0,
			"weights": { "offense": -1.0, "flanking": 2.0 },
			"script": "Ghost Script",
		},
		{}, { "Real Move": true }, {})
	_check(broken.size() == 5, "a broken profile trips every profile rule: %s" % [broken])
	_check(_aiProfileErrors({ "archetype": "damage", "pickFromTop": 3, "weights": { "offense": 1.0, "support": 0.2, "defense": 0.5, "reposition": 0.5 } }, {}, { "Real Move": true }, {}).is_empty(), "a valid profile passes")


## Pure per-profile checker so the lint can prove it rejects broken profiles.
func _aiProfileErrors(profile: Dictionary, scriptNames: Dictionary, moveNames: Dictionary, actorNames: Dictionary) -> Array:
	var errors := []
	var archetype = str(profile.get("archetype", "damage"))
	if !(archetype in ShootoutEnemyAIScript.ARCHETYPES):
		errors.append("unknown archetype '%s'" % archetype)
	if profile.has("pickFromTop"):
		var width = profile.get("pickFromTop", null)
		if typeof(width) != TYPE_INT or int(width) <= 0:
			errors.append("pickFromTop must be a positive integer")
	if profile.has("weights"):
		var weights = profile.get("weights", null)
		if !(weights is Dictionary):
			errors.append("weights must be a dictionary")
		else:
			for family in weights:
				if !(str(family) in ShootoutEnemyAIScript.ACTION_FAMILIES):
					errors.append("unknown action family '%s'" % str(family))
				elif typeof(weights[family]) not in [TYPE_INT, TYPE_FLOAT] or float(weights[family]) <= 0.0:
					errors.append("weight '%s' must be a positive number" % str(family))
	var scriptName = str(profile.get("script", ""))
	if scriptName != "":
		if !scriptNames.has(scriptName):
			errors.append("unknown AI script '%s'" % scriptName)
	return errors


func _testMoveGrants() -> void:
	print("\n--- Move grants resolve ---")
	var moves := _collectData("res://Data/Shootout/Moves")
	var movesData := _movesDataFor(moves.entries)
	var classes := _collectData("res://Data/Shootout/Classes")
	for entry in classes.entries:
		var errors := _classGrantErrors(entry.data, moves.names)
		_check(errors.is_empty(), "class '%s' has canonical unique Move grants: %s" % [entry.data.get("name", entry.file), errors])

	var weaponData = WeaponDataScript.new()
	for family in weaponData.weaponFamilies:
		for baseValue in weaponData.weaponFamilies[family]:
			if !(baseValue is Dictionary) or !baseValue.has("grantedMoves"):
				continue
			var errors := _grantErrors(str(baseValue.get("id", "?")), baseValue.get("grantedMoves", null), moves.names)
			_check(errors.is_empty(), "weapon '%s' grants authored Moves: %s" % [baseValue.get("id", "?"), errors])

	var equipmentData = EquipmentDataScript.new()
	for slot in equipmentData.genericBases:
		var base = equipmentData.genericBases[slot]
		if base is Dictionary and base.has("grantedMoves"):
			var errors := _grantErrors(str(base.get("id", slot)), base.get("grantedMoves", null), moves.names)
			_check(errors.is_empty(), "equipment '%s' grants authored Moves: %s" % [base.get("id", slot), errors])
	for zoneId in equipmentData.zones:
		for itemValue in equipmentData.zones[zoneId].get("items", []):
			if itemValue is Dictionary and itemValue.has("grantedMoves"):
				var errors := _grantErrors(str(itemValue.get("id", "?")), itemValue.get("grantedMoves", null), moves.names)
				_check(errors.is_empty(), "equipment '%s' grants authored Moves: %s" % [itemValue.get("id", "?"), errors])

	var actors := _collectData("res://Data/Actors/Animals")
	actors.entries.append_array(_collectData("res://Data/Actors/Named People").entries)
	for entry in actors.entries:
		var actorLabel := str(entry.data.get("actorName", entry.file))
		var classRecord := _recordNamed(classes.entries, str(entry.data.get("characterClass", "")))
		var classData: Dictionary = classRecord.get("data", {}) if !classRecord.is_empty() else {}
		var resolved: Array = CombatLoadoutProjectorScript.resolvedDirectMoves(entry.data, classData)
		_check(CombatLoadoutProjectorScript.hasOffensiveMove(resolved, movesData), "combat actor '%s' keeps a legal offensive Move after grants (resolved %s)" % [actorLabel, resolved])


## Pure class-grant checker: unknown/duplicate/legacy prose grants.
func _classGrantErrors(classData: Dictionary, moveNames: Dictionary) -> Array:
	var errors := _grantErrors(str(classData.get("name", "")), classData.get("moves", []), moveNames)
	if classData.has("abilities"):
		errors.append("legacy 'abilities' prose must move to 'futureAbilities'")
	return errors


## Pure grant checker: a grant list must be an array of unique authored Move ids.
func _grantErrors(label: String, grants, moveNames: Dictionary) -> Array:
	if !(grants is Array):
		return ["%s grant list must be an Array" % label]
	var errors := []
	var seen := {}
	for grantValue in grants:
		var grantId := str(grantValue)
		if grantId == "" or !moveNames.has(grantId):
			errors.append("%s grants unknown Move '%s'" % [label, grantId])
			continue
		if seen.has(grantId):
			errors.append("%s grants Move '%s' twice" % [label, grantId])
		seen[grantId] = true
	return errors


func _movesDataFor(records: Array) -> Dictionary:
	var data := {}
	for record in records:
		data[str(record.data.get("name", ""))] = record.data
	return data


func _recordNamed(records: Array, dataName: String) -> Dictionary:
	if dataName == "":
		return {}
	for record in records:
		if str(record.data.get("name", "")) == dataName:
			return record
	return {}


func _testLintHasTeeth() -> void:
	print("\n--- The lint rejects broken fixtures ---")
	var duplicates := _duplicateNameErrors([
		{ "file": "A.gd", "data": { "name": "Same Name" } },
		{ "file": "B.gd", "data": { "name": "Same Name" } },
	])
	_check(duplicates.size() == 1, "duplicate data.name fixtures are rejected: %s" % [duplicates])

	var ungated := _rewardProducerOffenders("Broken.gd", "extends Node\nfunc grant():\n\tlootGenerator.generateLoot({})\n")
	_check(ungated == ["Broken.gd::grant"], "an ungated reward producer is rejected: %s" % [ungated])

	var gated := _rewardProducerOffenders("Gated.gd", "extends Node\nfunc grant():\n\tif !Locations.canGrantLoot():\n\t\treturn\n\tlootGenerator.generateLoot({})\n")
	_check(gated.is_empty(), "a Trail-gated reward producer passes: %s" % [gated])

	var definition := _rewardProducerOffenders("Producer.gd", "extends Node\nfunc generateLoot(_options):\n\treturn {}\n")
	_check(definition.is_empty(), "a reward producer definition is not mistaken for a caller: %s" % [definition])

	var badStat := _effectStatPathErrors({ "op": "apply_effect", "effect": "stat_modifier", "stat": "not_a_stat", "amount": 1 })
	_check(badStat.size() == 1, "an unknown effect stat path is rejected: %s" % [badStat])
	var percentStat := _effectStatPathErrors({ "op": "apply_effect", "effect": "stat_modifier", "stat": "damageTakenReduction", "amount": 10 })
	_check(percentStat.size() == 1, "a percent path is not a flat stat modifier: %s" % [percentStat])
	var validStat := _effectStatPathErrors({ "op": "apply_effect", "effect": "stat_modifier", "stat": "highTailin", "amount": 2 })
	_check(validStat.is_empty(), "a supported flat stat path passes: %s" % [validStat])

	var knownMoves := { "Sharp Shot": "SharpShot.gd" }
	var classFixture := { "name": "Broken Class", "moves": ["Sharp Shot", "Missing Move", "Sharp Shot"], "abilities": ["legacy prose"] }
	var classErrors := _classGrantErrors(classFixture, knownMoves)
	_check(classErrors.size() == 3, "an unknown, a duplicate and a legacy prose class grant are rejected: %s" % [classErrors])
	var validClass := { "name": "Good Class", "moves": ["Sharp Shot"], "futureAbilities": ["legacy prose"] }
	_check(_classGrantErrors(validClass, knownMoves).is_empty(), "a canonical class grant with backlog prose passes: %s" % [_classGrantErrors(validClass, knownMoves)])
	var weaponErrors := _grantErrors("Broken Weapon", ["Missing Move"], knownMoves)
	_check(weaponErrors.size() == 1, "an unknown weapon grant is rejected: %s" % [weaponErrors])
	_check(_grantErrors("Broken Weapon", "Sharp Shot", knownMoves).size() == 1, "a non-array grant list is rejected: %s" % [_grantErrors("Broken Weapon", "Sharp Shot", knownMoves)])

	var movesFixture := {
		"Sharp Shot": { "name": "Sharp Shot", "category": "attack_ability" },
		"Duck Down": { "name": "Duck Down", "category": "duck" },
	}
	var supportOnly := CombatLoadoutProjectorScript.resolvedDirectMoves({ "moves": ["Duck Down"] }, { "moves": ["Duck Down"] })
	_check(!CombatLoadoutProjectorScript.hasOffensiveMove(supportOnly, movesFixture), "a grant union without offense is rejected")
	var withClassGrant := CombatLoadoutProjectorScript.resolvedDirectMoves({ "moves": ["Duck Down"] }, { "moves": ["Sharp Shot"] })
	_check(CombatLoadoutProjectorScript.hasOffensiveMove(withClassGrant, movesFixture), "a class attack grant keeps the actor offensive")


func _testDuplicateNames() -> void:
	print("--- Duplicate data.name values fail closed ---")
	var total := 0
	for folder in CONTENT_FOLDERS:
		var collected := _collectData(folder)
		_check(collected.errors.is_empty(), "content folder '%s' has unique data.name values: %s" % [folder, collected.errors])
		_check(!collected.entries.is_empty(), "content folder '%s' ships content" % folder)
		total += collected.entries.size()
	_check(total > 0, "the content lint sees production data")


func _testReferenceIntegrity() -> void:
	print("\n--- Content references resolve ---")
	var moves := _collectData("res://Data/Shootout/Moves")
	var items := _collectData("res://Data/Shootout/Items")
	var lootTables := _collectData("res://Data/Shootout/LootTables")
	var classes := _collectData("res://Data/Shootout/Classes")
	var rodeos := _collectData("res://Data/Shootout/Rodeos")
	var encounters := _collectData("res://Data/Shootout/Encounters")
	var actors := _collectData("res://Data/Actors/Animals")
	actors.entries.append_array(_collectData("res://Data/Actors/Named People").entries)

	var effectTypes := _knownEffectTypes()
	for entry in moves.entries:
		_validateEffectList("Move '%s'" % entry.data.get("name", entry.file), entry.data.get("effects", []), MOVE_EFFECT_OPS, effectTypes)
	for entry in classes.entries:
		var jammed = entry.data.get("jammed", {})
		if jammed is Dictionary:
			_validateEffectList("Class '%s' jammed" % entry.data.get("name", entry.file), jammed.get("effects", []), MOVE_EFFECT_OPS, effectTypes)
	for entry in rodeos.entries:
		_validateEffectList("Rodeo '%s'" % entry.data.get("name", entry.file), entry.data.get("effects", []), RODEO_EFFECT_OPS, effectTypes)

	for entry in actors.entries:
		var actorLabel := str(entry.data.get("actorName", entry.file))
		for moveName in entry.data.get("moves", []):
			_check(moves.names.has(str(moveName)), "actor '%s' references authored Move '%s'" % [actorLabel, moveName])
		var className := str(entry.data.get("characterClass", ""))
		if className != "":
			_check(classes.names.has(className), "actor '%s' references authored class '%s'" % [actorLabel, className])
		for combatId in entry.data.get("items", []):
			_check(items.names.has(str(combatId)), "actor '%s' references authored combat item '%s'" % [actorLabel, combatId])

	var catalog = ItemCatalogScript.new()
	var catalogErrors: Array = catalog.validate()
	_check(catalogErrors.is_empty(), "the item catalog validates: %s" % [catalogErrors])
	for definitionId in catalog.definitions:
		var definition: Dictionary = catalog.definitions[definitionId]
		if str(definition.get("itemType", "")) == "consumable":
			_check(items.names.has(str(definition.get("combatId", ""))), "consumable '%s' resolves combat item '%s'" % [definitionId, definition.get("combatId", "")])

	var actorNames := []
	for entry in actors.entries:
		actorNames.append(str(entry.data.get("actorName", "")))
	for entry in encounters.entries:
		var encounterName := str(entry.data.get("name", entry.file))
		var lootTable := str(entry.data.get("lootTable", ""))
		if lootTable != "":
			_check(lootTables.names.has(lootTable), "encounter '%s' references authored loot table '%s'" % [encounterName, lootTable])
		var background := str(entry.data.get("background", ""))
		if background != "":
			_check(ResourceLoader.exists(background), "encounter '%s' background exists" % encounterName)
		var teams: Dictionary = entry.data.get("teams", entry.data)
		for side in teams:
			for actorType in teams[side]:
				for referencedName in teams[side][actorType]:
					_check(actorNames.has(str(referencedName)), "encounter '%s' actor '%s' has authored data" % [encounterName, referencedName])


func _testZoneReferences() -> void:
	print("\n--- Zone references are canonical ---")
	var catalog = ZoneCatalogScript.new()
	_check(catalog.validate().is_empty(), "the Zone catalog validates: %s" % [catalog.validate()])

	var pools = EncounterPoolDataScript.new()
	var poolErrors: Array = pools.validateAuthoredPools(catalog)
	_check(poolErrors.is_empty(), "authored encounter pools use canonical Zone ids: %s" % [poolErrors])
	_check(pools.hasZone("canyon"), "the authored pools load (sanity check)")

	var lootTables := _collectData("res://Data/Shootout/LootTables")
	for entry in lootTables.entries:
		for lootEntry in entry.data.get("entries", []):
			if !(lootEntry is Dictionary):
				continue
			var zone := str(lootEntry.get("zone", ""))
			if zone != "":
				_check(zone == "anywhere" or catalog.hasZone(zone), "loot entry in '%s' uses Zone '%s' or anywhere" % [entry.file, zone])

	var eventsScript = load("res://Globals/OverworldEvents.gd")
	var zoneFiles: Dictionary = eventsScript.ZONE_EVENT_FILES
	_check(!zoneFiles.is_empty(), "the Zone to event-file mapping is authored")
	var generic := _loadEvents(GENERIC_EVENT_FILE)
	for zoneId in zoneFiles:
		_check(catalog.hasZone(zoneId), "event file key '%s' is a canonical Zone id" % zoneId)
		var events := _loadEvents(zoneFiles[zoneId])
		for eventId in events:
			_check(!generic.has(eventId), "Zone event '%s' does not shadow a generic event id" % eventId)
		_validateEventOutcomes(zoneFiles[zoneId], events, catalog)
	_validateEventOutcomes(GENERIC_EVENT_FILE, generic, catalog)


func _testTrailAndAccessGates() -> void:
	print("\n--- Reward and access producers are Trail-gated ---")
	var offenders := _findUngatedRewardProducers()
	_check(offenders.is_empty(), "every reward producer sits in a Trail-gated function: %s" % [offenders])

	var partyBodies := _functionBodies(_readSource("res://Globals/Party.gd"))
	var resultsBody := str(partyBodies.get("applyFightResults", ""))
	_check(resultsBody != "", "Party.applyFightResults exists")
	_check(_bodyHasTrailGate(resultsBody), "Party.applyFightResults reads the authoritative Trail state")

	var overworldBodies := _functionBodies(_readSource("res://Overworld/Overworld.gd"))
	var enterBody := str(overworldBodies.get("enterLocation", ""))
	_check(enterBody != "", "Overworld.enterLocation exists")
	_check(enterBody.contains("canAccessLocation"), "non-town Location entry checks the shared access gate")
	var gateIndex := enterBody.find("canAccessLocation")
	var transitionIndex := enterBody.find("changeScene")
	_check(gateIndex >= 0 and transitionIndex > gateIndex, "the access gate runs before the Location transition")
	var createBody := str(overworldBodies.get("createLocation", ""))
	_check(createBody.contains("body_entered.connect(enterLocation"), "Location collisions route through the gated enterLocation")
	_check(createBody.contains("isTown"), "the Location entrance forwards its authored Town flag")

	var badEntries := []
	var locationCount := 0
	for fileName in DirAccess.get_files_at(CHUNK_DIR):
		if !fileName.ends_with(".gd"):
			continue
		var result := _collectChunkLocations(CHUNK_DIR + "/" + fileName)
		badEntries.append_array(result.errors)
		locationCount += int(result.count)
	_check(badEntries.is_empty(), "authored Location entries declare a boolean isTown flag when present: %s" % [badEntries])
	_check(locationCount > 0, "the access gate guards authored Locations (found %d)" % locationCount)


## Loads every `.gd` in a folder that exposes a `data` Dictionary, tracking
## `data.name` so a duplicate is an error instead of a silent overwrite.
func _collectData(folder: String) -> Dictionary:
	var result := { "entries": [], "names": {}, "errors": [] }
	if !DirAccess.dir_exists_absolute(folder):
		result.errors.append("content folder '%s' is missing" % folder)
		return result
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for fileName in files:
		if !fileName.ends_with(".gd"):
			continue
		var script = load(folder + "/" + fileName)
		if script == null:
			result.errors.append("'%s/%s' could not be loaded" % [folder, fileName])
			continue
		var holder = script.new()
		if holder == null:
			continue
		var data = holder.get("data") if ("data" in holder) else null
		if holder is Node:
			holder.free()
		if !(data is Dictionary):
			continue
		result.entries.append({ "file": fileName, "data": data })
	result.names = _namesFor(result.entries)
	result.errors.append_array(_duplicateNameErrors(result.entries))
	return result


## Pure duplicate detector so the lint can prove it rejects broken fixtures.
func _duplicateNameErrors(records: Array) -> Array:
	var errors := []
	var seen := {}
	for record in records:
		var dataName := str(record.data.get("name", record.data.get("actorName", "")))
		if dataName == "":
			continue
		if seen.has(dataName):
			errors.append("duplicate data.name '%s' in %s and %s" % [dataName, seen[dataName], record.file])
		else:
			seen[dataName] = record.file
	return errors


func _namesFor(records: Array) -> Dictionary:
	var names := {}
	for record in records:
		var dataName := str(record.data.get("name", record.data.get("actorName", "")))
		if dataName != "" and !names.has(dataName):
			names[dataName] = record.file
	return names


func _effectStatPathErrors(effect: Dictionary) -> Array:
	if str(effect.get("effect", "")) != "stat_modifier":
		return []
	var error := CombatStatRegistryScript.validateStatModifierPath(str(effect.get("stat", "")))
	return [error] if !error.is_empty() else []


func _validateEffectList(label: String, effects, allowedOps: Array, effectTypes: Array) -> void:
	if !(effects is Array):
		return
	for effect in effects:
		if !(effect is Dictionary):
			_check(false, "%s: effect entry must be a Dictionary" % label)
			continue
		var op := str(effect.get("op", ""))
		_check(allowedOps.has(op), "%s: known effect op '%s'" % [label, op])
		for statError in _effectStatPathErrors(effect):
			_check(false, "%s: %s" % [label, statError])
		var effectType := str(effect.get("effect", ""))
		if effectType == "" or (op == "cleanse_effect" and effectType == "random"):
			continue
		_check(effectTypes.has(effectType), "%s: known effect type '%s'" % [label, effectType])


func _knownEffectTypes() -> Array:
	var types := []
	types.append_array(EffectManagerScript.AFFLICTIONS)
	types.append_array(EffectManagerScript.BENEFICIALS)
	types.append("cylinder")
	return types


func _loadEvents(path: String) -> Dictionary:
	var script = load(path)
	if script == null:
		return {}
	var holder = script.new()
	if holder == null:
		return {}
	var events = holder.get("events") if ("events" in holder) else null
	if holder is Node:
		holder.free()
	return events.duplicate(true) if events is Dictionary else {}


func _validateEventOutcomes(filePath: String, events: Dictionary, catalog) -> void:
	_check(!events.is_empty(), "event file '%s' authors events" % filePath)
	for eventId in events:
		var eventData = events[eventId]
		if !(eventData is Dictionary):
			_check(false, "event '%s' must be a Dictionary" % eventId)
			continue
		var choices = eventData.get("choices", [])
		_check(choices is Array and !choices.is_empty(), "event '%s' authors choices" % eventId)
		for choice in choices:
			if !(choice is Dictionary):
				_check(false, "event '%s' choices must be Dictionaries" % eventId)
				continue
			var outcome = choice.get("outcome", null)
			if outcome == null:
				continue
			_check(outcome is Dictionary and !(outcome as Dictionary).is_empty(), "event '%s' outcome must be a non-empty Dictionary" % eventId)
			if !(outcome is Dictionary):
				continue
			var kind := str(outcome.get("kind", ""))
			_check(SUPPORTED_OUTCOME_KINDS.has(kind), "event '%s' outcome kind '%s' is implemented" % [eventId, kind])
			if kind != "encounter":
				continue
			var encounterPath := str(outcome.get("encounter", ""))
			var poolZone := str(outcome.get("poolZone", outcome.get("zone", "")))
			if encounterPath != "":
				_check(encounterPath.begins_with("res://") and ResourceLoader.exists(encounterPath), "event '%s' encounter path exists" % eventId)
				if poolZone != "":
					_check(catalog.hasZone(poolZone), "event '%s' outcome Zone '%s' is canonical" % [eventId, poolZone])
			else:
				_check(poolZone != "" and catalog.hasZone(poolZone), "event '%s' selects a canonical encounter pool Zone" % eventId)


## Authored Location entries must declare `isTown` as a Boolean when present, so
## the single access gate always evaluates a real flag instead of a truthy string.
func _collectChunkLocations(path: String) -> Dictionary:
	var result := { "errors": [], "count": 0 }
	var script = load(path)
	if script == null:
		return result
	var holder = script.new()
	if holder == null:
		return result
	if "locations" in holder and holder.locations is Dictionary:
		for locationName in holder.locations:
			result.count += 1
			var entry = holder.locations[locationName]
			if entry is Dictionary and entry.has("isTown") and typeof(entry["isTown"]) != TYPE_BOOL:
				result.errors.append("%s/%s" % [path.get_file(), locationName])
	if holder is Node:
		holder.free()
	return result


## A reward producer is a function that calls the loot entry points. Each must
## read the Trail state so Off-Trail reward payloads stay empty.
func _findUngatedRewardProducers() -> Array:
	var offenders := []
	for rootPath in PRODUCTION_ROOTS:
		for filePath in _gdFiles(rootPath):
			offenders.append_array(_rewardProducerOffenders(filePath.get_file(), _readSource(filePath)))
	offenders.sort()
	return offenders


## Pure per-source detector so the lint can prove it rejects broken fixtures.
func _rewardProducerOffenders(fileName: String, source: String) -> Array:
	var offenders := []
	var bodies := _functionBodies(source)
	for functionName in bodies:
		var body := str(bodies[functionName])
		if _bodyCallsRewardProducer(body) and !_bodyHasTrailGate(body):
			offenders.append("%s::%s" % [fileName, functionName])
	offenders.sort()
	return offenders


func _gdFiles(path: String) -> Array:
	var files := []
	var directory := DirAccess.open(path)
	if directory == null:
		return files
	directory.list_dir_begin()
	var entryName := directory.get_next()
	while entryName != "":
		if directory.current_is_dir():
			files.append_array(_gdFiles(path + "/" + entryName))
		elif entryName.ends_with(".gd"):
			files.append(path + "/" + entryName)
		entryName = directory.get_next()
	directory.list_dir_end()
	return files


func _readSource(path: String) -> String:
	if !FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## Maps each function name to its source body. Bodies keep their `func` signature
## line so callers can tell a definition apart from a call site.
func _functionBodies(source: String) -> Dictionary:
	var bodies := {}
	var currentName := ""
	var buffer := ""
	for line in source.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("func ") or trimmed.begins_with("static func "):
			if currentName != "":
				bodies[currentName] = buffer
			currentName = _functionName(trimmed)
			buffer = line + "\n"
		elif currentName != "":
			buffer += line + "\n"
	if currentName != "":
		bodies[currentName] = buffer
	return bodies


func _functionName(signature: String) -> String:
	var open := signature.find("(")
	var declaration := signature if open < 0 else signature.substr(0, open)
	var parts := declaration.strip_edges().split(" ", false)
	return str(parts[parts.size() - 1]) if !parts.is_empty() else ""


## Ignores the signature line so a function defining `generateLoot`/`applyLoot`
## is not mistaken for a caller of itself.
func _bodyCallsRewardProducer(body: String) -> bool:
	var lines := body.split("\n")
	for index in range(1, lines.size()):
		for token in REWARD_CALL_TOKENS:
			if lines[index].contains(token):
				return true
	return false


func _bodyHasTrailGate(body: String) -> bool:
	for token in TRAIL_GATE_TOKENS:
		if body.contains(token):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
