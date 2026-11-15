extends "res://Nodes/Interaction/LocationInteractable.gd"

## Interactive vendor character (Docs/System Design/Location Vendors
## Implementation.md, patches 3-4). The actor itself persists in the room and only
## opens the persistent VendorMenu on interaction.

@export var vendorId := ""
## Optional floating-icon override, matching the exterior door's kind icon.
@export var iconTexture: Texture2D:
	set(value):
		iconTexture = value
		_applyIcon()


func _ready() -> void:
	super()
	_applyIcon()


func activate() -> void:
	if !canActivate():
		return
	if !HelperFunctions.openVendor(vendorId):
		return
	activated.emit(self)


func _applyIcon() -> void:
	if iconTexture == null:
		return
	var floating = get_node_or_null("FloatingIcon")
	if floating != null:
		floating.icon = iconTexture
