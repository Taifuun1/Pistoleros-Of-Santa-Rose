extends "res://Nodes/Interaction/LocationInteractable.gd"

## Vendor room exit (Docs/System Design/Location Vendors Implementation.md,
## patch 3). SceneManager restores the captured parent Location and safe door
## spawn position.

func activate() -> void:
	if !canActivate():
		return
	if !HelperFunctions.exitVendorRoom():
		return
	activated.emit(self)
