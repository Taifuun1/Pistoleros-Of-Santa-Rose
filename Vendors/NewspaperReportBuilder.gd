extends RefCounted
class_name NewspaperReportBuilder

## Read-only newspaper projection (Docs/System Design/Location Vendors
## Implementation.md, Newspaper reports). It reads exactly one Zone's shared
## encounter pool, resolves each encounter's enemy team against the authored
## actor data, and projects only human-readable combat information. It never
## rolls, never mutates and never falls back to another Zone or the debug
## encounter: unknown or empty data produces an explicit unavailable report.

const ENEMY_SIDE := "enemy team"

## Default actor resolver: the same file layout Shootout.spawnActor() uses, so a
## published report can never describe an actor the fight would not load.
static func defaultActorResolver(actorType: String, actorName: String) -> Dictionary:
	var actorPath := "res://Data/Actors/{actorType}/{actorName}.gd".format({
		"actorType": actorType,
		"actorName": actorName.capitalize().replace(" ", ""),
	})
	return _loadActorData(actorPath)


## Any resolver returning { success, data } works; a bare Dictionary is accepted
## too so fixtures stay small.
static func _loadActorData(actorPath: String) -> Dictionary:
	if !ResourceLoader.exists(actorPath):
		return { "success": false, "reason": "missing_actor" }
	var script = load(actorPath)
	if script == null:
		return { "success": false, "reason": "missing_actor" }
	var holder = script.new()
	if holder == null or !("data" in holder):
		if holder != null:
			holder.free()
		return { "success": false, "reason": "missing_actor" }
	var data: Dictionary = holder.data.duplicate(true)
	holder.free()
	return { "success": true, "data": data }


## zoneId: canonical ZoneData id. encounterPools: EncounterPoolData-compatible
## object. actorResolver: Callable(actorType, actorName) -> { success, data }.
## newspaperData: NewspaperData-compatible object supplying the copy.
## Returns the report view model; every failure carries a stable reason and no
## substitute content.
func buildReport(zoneId: String, encounterPools, actorResolver, newspaperData) -> Dictionary:
	if zoneId == "" or encounterPools == null or newspaperData == null:
		return _failure("data_unavailable", zoneId)
	if !encounterPools.hasZone(zoneId):
		return _failure("no_pool", zoneId)
	var zone = newspaperData.getZone(zoneId)
	if zone.is_empty():
		return _failure("no_copy", zoneId)
	var parties := []
	for entry in encounterPools.getPublicEntries(zoneId):
		var projected := _projectEncounter(str(entry.get("encounter", "")), actorResolver, newspaperData, zoneId)
		if !bool(projected.get("success", false)):
			return _failure(str(projected.get("reason", "malformed_encounter")), zoneId)
		parties.append(projected["party"])
	return {
		"success": true,
		"available": !parties.is_empty(),
		"reason": "",
		"zoneId": zoneId,
		"headline": str(zone.get("headline", "")),
		"editorial": str(zone.get("editorial", "")),
		"parties": parties,
		"generalTips": newspaperData.getGeneralTips(zoneId),
	}


func _projectEncounter(encounterPath: String, actorResolver, newspaperData, zoneId: String) -> Dictionary:
	if encounterPath == "" or !ResourceLoader.exists(encounterPath):
		return { "success": false, "reason": "missing_encounter" }
	var script = load(encounterPath)
	if script == null:
		return { "success": false, "reason": "missing_encounter" }
	var holder = script.new()
	if holder == null or !("data" in holder) or !(holder.data is Dictionary):
		if holder != null:
			holder.free()
		return { "success": false, "reason": "malformed_encounter" }
	var data: Dictionary = holder.data
	var encounterId := encounterPath.get_file().get_basename()
	var teams: Dictionary = data.get("teams", data)
	var enemyTeam = teams.get(ENEMY_SIDE, null)
	if !(enemyTeam is Dictionary):
		holder.free()
		return { "success": false, "reason": "malformed_encounter" }

	# Repeated actor references aggregate into one row per actor, in the order
	# the encounter authors them.
	var composition := []
	var damageTypes := []
	var indexByActor := {}
	for actorType in enemyTeam:
		var actors = enemyTeam[actorType]
		if !(actors is Dictionary):
			holder.free()
			return { "success": false, "reason": "malformed_encounter" }
		for actorName in actors:
			var actorEntry = actors[actorName]
			var positions = actorEntry.get("positions", []) if actorEntry is Dictionary else null
			if !(positions is Array) or positions.is_empty():
				holder.free()
				return { "success": false, "reason": "malformed_encounter" }
			var actorResult = actorResolver.call(str(actorType), str(actorName))
			if !(actorResult is Dictionary) or !bool(actorResult.get("success", false)):
				holder.free()
				return { "success": false, "reason": "missing_actor" }
			var actorData: Dictionary = actorResult.get("data", {})
			var rowKey := str(actorName)
			if !indexByActor.has(rowKey):
				indexByActor[rowKey] = composition.size()
				composition.append({
					"actorName": str(actorData.get("actorName", actorName)),
					"count": 0,
					"characterClass": str(actorData.get("characterClass", "")),
					"actorType": str(actorType),
				})
			var row: Dictionary = composition[int(indexByActor[rowKey])]
			row["count"] = int(row["count"]) + positions.size()
			for damageType in _actorDamageTypes(actorData):
				if !damageTypes.has(damageType):
					damageTypes.append(str(damageType))

	var tips: Array = newspaperData.getEncounterTips(zoneId, encounterId)
	var party := {
		"encounterId": encounterId,
		"name": str(data.get("name", encounterId)),
		"kind": str(data.get("kind", "dustup")),
		"composition": composition,
		"damageTypes": damageTypes,
		"mechanics": tips.duplicate(),
		"tips": tips,
	}
	holder.free()
	return { "success": true, "reason": "", "party": party }


## The damage types an actor actually deals: its weapon's type, plus any
## explicit stats.damage keys the authoring lists.
func _actorDamageTypes(actorData: Dictionary) -> Array:
	var types := []
	var weapon = actorData.get("weapon", {})
	if weapon is Dictionary and str(weapon.get("type", "")) != "":
		types.append(str(weapon.type))
	var stats = actorData.get("stats", {})
	var damage = stats.get("damage", {}) if stats is Dictionary else {}
	if damage is Dictionary:
		for damageType in damage:
			if !types.has(str(damageType)):
				types.append(str(damageType))
	return types


func _failure(reason: String, zoneId: String) -> Dictionary:
	return {
		"success": false,
		"available": false,
		"reason": reason,
		"zoneId": zoneId,
		"headline": "",
		"editorial": "",
		"parties": [],
		"generalTips": [],
	}