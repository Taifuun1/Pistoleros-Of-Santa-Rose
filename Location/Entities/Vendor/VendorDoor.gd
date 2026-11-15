extends "res://Nodes/Interaction/LocationInteractable.gd"

## Enterable building door (Docs/System Design/Location Vendors
## Implementation.md, patches 3-4). The marker sits on the entrance tile the
## floating icon points at, and the activation circle is centred on it, so
## returning from the room puts the player exactly under the indicator. Because
## that spawn is inside the activation area the prompt reappears at once;
## activation is still a fresh INTERACT press, never a held input, so returning
## cannot re-enter the room by itself.

@export var vendorId := ""
## Safe exterior return position relative to the marker. Vector2.ZERO stands the
## player on the entrance tile, centred under the icon.
@export var returnOffset := Vector2.ZERO
## Optional floating-icon override (VendorCatalog kinds use distinct icons).
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
	if !HelperFunctions.enterVendorRoom(vendorId, returnPosition()):
		return
	activated.emit(self)


func returnPosition() -> Vector2:
	return global_position + returnOffset


func _applyIcon() -> void:
	if iconTexture == null:
		return
	var floating = get_node_or_null("FloatingIcon")
	if floating != null:
		floating.icon = iconTexture
