extends Node

## Explicit trail-departure lifecycle (Docs/System Design/Location Vendors
## Implementation.md, patch 2). Only the deliberate town departure interaction
## calls departForTrail(); ordinary scene changes must not reset vendor stock.

signal trailDeparted(departureId: int)

var currentLocation = "Clearwater Grove"
var currentQuest = "Pistoleros Regroup"

var actorId = 0

var playerPosition

var trailDepartureId = 0


## Begins a new trail cycle once and returns its id.
func departForTrail() -> int:
	trailDepartureId += 1
	trailDeparted.emit(trailDepartureId)
	return trailDepartureId


## Save-load sink for the departure counter. Does not emit trailDeparted; vendor
## state is imported separately and synchronizes against this value.
func restoreTrailDepartureId(value: int) -> void:
	trailDepartureId = maxi(0, int(value))


func resetTrailDepartures() -> void:
	trailDepartureId = 0

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
