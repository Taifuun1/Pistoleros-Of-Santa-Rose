extends "res://Nodes/Interaction/LocationInteractable.gd"

## The town's explicit departure point (Docs/System Design/Location Vendors
## Implementation.md, patch 4). Only this interaction begins a new trail cycle;
## ordinary scene changes never reset vendor stock. Like vendor doors, the
## marker is the tile the floating arrow points at and the activation circle is
## centred on it.

func activate() -> void:
	if !canActivate():
		return
	if Locations != null and Locations.has_method("departForTrail"):
		Locations.departForTrail()
	HelperFunctions.changeScene("overworld")
	activated.emit(self)
