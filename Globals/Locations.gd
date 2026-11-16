extends Node

## Authoritative On/Off Trail lifecycle (Docs/System Design/First Steps
## Implementation Plan.md, commit 1). Only a Town entry/command starts or ends a
## Trail; scene presence alone never changes this state. Vendors react to
## trailDeparted so rolled stock resets only on an explicit Trail start.

signal trailDeparted(departureId: int)
signal trailStateChanged(onTrail: bool)

const STATE_FORMAT_VERSION := 1

var currentLocation = "Clearwater Grove"
var currentQuest = "Pistoleros Regroup"
## Whether currentLocation was entered as a Town. Authored per Location entry
## in the Overworld chunk script; not inferred from vendor or scene data.
var currentLocationIsTown := false
var lastTownId := ""
var onTrail := false

var actorId = 0

var playerPosition

var trailDepartureId = 0


func isOnTrail() -> bool:
	return onTrail


func isCurrentLocationTown() -> bool:
	return currentLocationIsTown


## Enters a designated Town through the Overworld entrance. Records the Town and
## ends an active Trail once. Repeated Town entry is idempotent.
func enterTown(locationId: String) -> Dictionary:
	var normalizedId := _normalizedLocationId(locationId)
	if normalizedId == "":
		return _failure("invalid_location")
	currentLocation = normalizedId
	currentLocationIsTown = true
	lastTownId = normalizedId
	var endedTrail := false
	if onTrail:
		onTrail = false
		endedTrail = true
		trailStateChanged.emit(false)
	return {
		"success": true,
		"reason": "",
		"endedTrail": endedTrail,
		"lastTownId": lastTownId,
	}


## Enters a non-town Location through the Overworld entrance. Does not end an
## active Trail.
func enterNonTownLocation(locationId: String) -> Dictionary:
	var normalizedId := _normalizedLocationId(locationId)
	if normalizedId == "":
		return _failure("invalid_location")
	currentLocation = normalizedId
	currentLocationIsTown = false
	return { "success": true, "reason": "" }


## Marks the Overworld as the active context so a stale Town flag cannot start a
## Trail from a scene that has no departure interaction.
func enterOverworld() -> void:
	currentLocationIsTown = false


## Starts a Trail from a Town while Off Trail. Sets the state before emitting,
## so listeners see the correct state when stock resets.
func startTrail() -> Dictionary:
	if onTrail:
		return _failure("already_on_trail")
	if !currentLocationIsTown:
		return _failure("not_in_town")
	onTrail = true
	# The departure interaction leaves the Town immediately; clear the flag so
	# a repeated call cannot start a second Trail while this one is active.
	currentLocationIsTown = false
	trailDepartureId += 1
	trailDeparted.emit(trailDepartureId)
	trailStateChanged.emit(true)
	return {
		"success": true,
		"reason": "",
		"departureId": trailDepartureId,
	}


## Ends an active Trail without recording a Town destination.
func endTrail() -> Dictionary:
	if !onTrail:
		return _failure("not_on_trail")
	onTrail = false
	trailStateChanged.emit(false)
	return { "success": true, "reason": "" }


## Non-town Locations require an active Trail. Town access is always allowed.
func canAccessLocation(isTown: bool) -> bool:
	return isTown or onTrail


func canApplyAttrition() -> bool:
	return onTrail


func canGrantLoot() -> bool:
	return onTrail


## Backward-compatible departure entry point. New production callers use
## startTrail() so failures are visible; this keeps the legacy int contract.
func departForTrail() -> int:
	var result := startTrail()
	if bool(result.get("success", false)):
		return int(result.get("departureId", trailDepartureId))
	return trailDepartureId


## Save-load sink for the departure counter. Does not emit trailDeparted; vendor
## state is imported separately and synchronizes against this value.
func restoreTrailDepartureId(value: int) -> void:
	trailDepartureId = maxi(0, int(value))


func resetTrailDepartures() -> void:
	trailDepartureId = 0


## Versioned snapshot for the later save service. Scene-local location type is
## transient; only the Trail state, departure id and last Town persist.
func exportState() -> Dictionary:
	return {
		"formatVersion": STATE_FORMAT_VERSION,
		"onTrail": onTrail,
		"trailDepartureId": trailDepartureId,
		"lastTownId": lastTownId,
	}


## Validates the whole payload before committing; malformed imports leave the
## current state untouched.
func importState(state) -> Dictionary:
	if !(state is Dictionary):
		return _failure("invalid_state")
	var versionValue = state.get("formatVersion", null)
	if typeof(versionValue) != TYPE_INT or int(versionValue) != STATE_FORMAT_VERSION:
		return _failure("invalid_state")
	var onTrailValue = state.get("onTrail", null)
	if typeof(onTrailValue) != TYPE_BOOL:
		return _failure("invalid_state")
	var departureValue = state.get("trailDepartureId", null)
	if typeof(departureValue) != TYPE_INT or int(departureValue) < 0:
		return _failure("invalid_state")
	var lastTownValue = state.get("lastTownId", null)
	if typeof(lastTownValue) != TYPE_STRING:
		return _failure("invalid_state")

	var changed := onTrail != bool(onTrailValue)
	onTrail = bool(onTrailValue)
	trailDepartureId = int(departureValue)
	lastTownId = str(lastTownValue)
	if changed:
		trailStateChanged.emit(onTrail)
	return { "success": true, "reason": "" }


## New Game starts Off Trail with no departure cycle and no remembered Town.
func resetForNewGame() -> void:
	var changed := onTrail
	onTrail = false
	trailDepartureId = 0
	lastTownId = ""
	currentLocationIsTown = false
	if changed:
		trailStateChanged.emit(false)


func _normalizedLocationId(locationId: String) -> String:
	return locationId.strip_edges()


func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason }


# Points earned from minigames, keyed by minigame name
var minigamePoints = {
	"Dodging": 0,
	"Gathering": 0,
	"Hunting": 0,
	"Mining": 0,
	"Panning": 0,
	"Robbing": 0,
}

# Materials collected during Mining and Robbing that feed into the Panning minigame
var collectedPanningMaterials = {
	"rock": 20,
	"soil": 10,
}
