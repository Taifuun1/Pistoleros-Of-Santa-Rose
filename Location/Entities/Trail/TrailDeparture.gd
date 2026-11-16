extends "res://Nodes/Interaction/LocationInteractable.gd"

## The town's explicit Trail start (Docs/System Design/First Steps
## Implementation Plan.md, commit 1). Only this interaction starts a Trail and
## resets rolled stock; ordinary scene changes never do. Like vendor doors, the
## marker is the tile the floating arrow points at and the activation circle is
## centred on it.

func activate() -> void:
	if !canActivate():
		return
	if Locations == null or !Locations.has_method("startTrail"):
		push_warning("TrailDeparture: the authoritative Trail state is unavailable.")
		return
	var result: Dictionary = Locations.startTrail()
	if !bool(result.get("success", false)):
		push_warning("TrailDeparture: %s" % str(result.get("reason", "start_failed")))
		return
	HelperFunctions.changeScene("overworld")
	activated.emit(self)
