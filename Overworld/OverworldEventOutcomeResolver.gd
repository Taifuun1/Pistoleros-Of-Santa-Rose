class_name OverworldEventOutcomeResolver
extends RefCounted

## Pure event-choice outcome mapping (Docs/System Design/First Steps
## Implementation Plan.md, commit 2). A choice must carry an explicit `outcome`
## Dictionary; legacy choices with only a `result` string remain unavailable
## instead of executing an accidental no-op.

const EncounterRequestScript = preload("res://Shootout/EncounterRequest.gd")
const EncounterPoolDataScript = preload("res://Data/Shootout/EncounterPoolData.gd")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")
const SUPPORTED_KINDS := ["none", "encounter"]


## UI-facing validation without executing anything.
func canResolve(choice: Dictionary, zoneCatalog = null) -> Dictionary:
	var outcome := _outcomeFor(choice)
	if outcome.is_empty():
		return _failure("missing_outcome")
	var kind := str(outcome.get("kind", ""))
	if !SUPPORTED_KINDS.has(kind):
		return _failure("unsupported_outcome")
	if kind == "encounter":
		var encounterPath := str(outcome.get("encounter", "")).strip_edges()
		var poolZone := str(outcome.get("poolZone", outcome.get("zone", ""))).strip_edges()
		if encounterPath != "":
			if !encounterPath.begins_with("res://") or !ResourceLoader.exists(encounterPath):
				return _failure("missing_encounter")
		elif poolZone == "":
			return _failure("invalid_outcome")
		else:
			if zoneCatalog == null:
				zoneCatalog = ZoneCatalogScript.new()
			if !zoneCatalog.hasZone(poolZone):
				return _failure("invalid_zone")
	return { "success": true, "reason": "", "kind": kind, "outcome": outcome }


## Validates and executes one choice. `context` supplies the current canonical
## zone, origin, Trail state, RNG, and an injected `launchEncounter` Callable.
func resolve(eventName: String, _eventData: Dictionary, choice: Dictionary, context: Dictionary = {}) -> Dictionary:
	var zoneCatalog = context.get("zoneCatalog", null)
	var validation := canResolve(choice, zoneCatalog)
	if !validation.success:
		return validation
	var outcome: Dictionary = validation.outcome
	match validation.kind:
		"none":
			return {
				"success": true,
				"reason": "",
				"kind": "none",
				"request": {},
				"launched": false,
			}
		"encounter":
			return _resolveEncounter(eventName, outcome, context)
	return _failure("unsupported_outcome")


func _resolveEncounter(eventName: String, outcome: Dictionary, context: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = context.get("rng", null)
	var zoneId := str(outcome.get("zoneId", context.get("zoneId", ""))).strip_edges()
	var encounterPath := str(outcome.get("encounter", "")).strip_edges()
	var poolZone := str(outcome.get("poolZone", outcome.get("zone", ""))).strip_edges()
	if encounterPath == "":
		var pools = context.get("encounterPools", null)
		if pools == null:
			pools = EncounterPoolDataScript.new()
			pools.loadProductionPools()
		var selected: Dictionary = pools.selectEncounter(poolZone, rng, context.get("zoneCatalog", null))
		if !selected.success:
			return _failure(str(selected.reason))
		encounterPath = str(selected.encounterPath)
		if zoneId == "":
			zoneId = poolZone
	var launch = context.get("launchEncounter", Callable())
	if !launch.is_valid():
		return _failure("launch_unavailable")
	var request = EncounterRequestScript.make({
		"encounterPath": encounterPath,
		"zoneId": zoneId,
		"source": "overworld_event",
		"sourceId": str(outcome.get("sourceId", eventName)),
		"origin": context.get("origin", {}),
		"progression": context.get("progression", {}),
		"trailState": context.get("trailState", {}),
		"seed": int(outcome.get("seed", -1)),
	}, context.get("zoneCatalog", null), context.get("locations", null))
	if !request.isValid():
		return _failure(request.reason())
	var launched := bool(launch.call(request))
	if !launched:
		return _failure("launch_failed")
	return {
		"success": true,
		"reason": "",
		"kind": "encounter",
		"request": request,
		"launched": true,
	}


func _outcomeFor(choice: Dictionary) -> Dictionary:
	if choice.get("outcome", null) is Dictionary and !choice.outcome.is_empty():
		return choice.outcome.duplicate(true)
	return {}


func _failure(reason: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"kind": "",
		"outcome": {},
		"request": {},
		"launched": false,
	}