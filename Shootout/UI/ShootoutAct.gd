extends TextureRect

signal actClicked

## Icon states: greyed-out unusable acts, the armed act (a warm gold tint,
## deliberately a different colour from the transient hover lighten so the
## player can see which act is waiting for its target) and the base icon.
const GREYED_MODULATE = Color(0.5, 0.5, 0.5, 0.7)
const SELECTED_MODULATE = Color(1.0, 0.4, 0.85, 1.0)
const BASE_MODULATE = Color(1, 1, 1)

## Slot colours behind the icon: the sprite alone is mostly transparent pixel
## art, so the state only reads once the slot background tints with it too.
## The armed act lights the slot warm; modulate propagation tints the slot
## along with the sprite for the greyed/hover states.
const SLOT_BASE_COLOR = Color(0.14, 0.12, 0.1, 0.85)
const SLOT_SELECTED_COLOR = Color(1.0, 0.95, 0.85, 0.95)
const SLOT_GREYED_COLOR = Color(0.5, 0.5, 0.5, 0.4)

var actName
var actType
var enabled = true
var selected = false
var hovered = false


func init(newActName: String, newActType: String, enabled := true) -> void:
	actName = newActName
	actType = newActType
	self.enabled = enabled
	var iconPath = "res://Assets/{actType}/{actName}.png".format({ "actType": actType, "actName": actName.replace(" ", "") })
	if ResourceLoader.exists(iconPath):
		texture = load(iconPath)
	# Unusable acts are greyed out with the reason (Docs/System Design/Shootout/Shootout UI.md);
	# the tooltip is attached by ShootoutUI through the shared Tooltip node.
	_applyModulate()


## Arms/disarms this icon (ShootoutUI keeps one act armed at a time; greyed
## icons can never be armed because their clicks are ignored).
func setSelected(newSelected: bool) -> void:
	if selected == newSelected:
		return
	selected = newSelected
	_applyModulate()


func setEnabled(newEnabled: bool) -> void:
	if enabled == newEnabled:
		return
	enabled = newEnabled
	_applyModulate()


## State tint with the hover lighten applied on top. Centralized instead of
## the old captured-modulate hover dance so a selection change while hovered
## re-renders both states instead of the exit restoring a stale tint. The
## slot background behind the icon carries the same state — the sprite alone
## is too transparent for the tint to read.
func _applyModulate() -> void:
	var background = get_node_or_null("Background")
	if !enabled:
		modulate = GREYED_MODULATE
	elif selected:
		modulate = SELECTED_MODULATE
	else:
		modulate = BASE_MODULATE
	if hovered:
		modulate = modulate.lightened(0.3)
	if background != null:
		if !enabled:
			background.color = SLOT_GREYED_COLOR
		elif selected:
			background.color = SLOT_SELECTED_COLOR
		else:
			background.color = SLOT_BASE_COLOR


# Clicks are handled as Control GUI input (gui_input), not physics picking:
# the act row sits on Controls that consume the mouse, which would keep an
# Area2D from ever receiving input_event.
func _on_gui_input(event: InputEvent) -> void:
	if modulate.r < 1.0:
		return
	if(
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT and
		not event.is_pressed()
	):
		actClicked.emit()

# Hover feedback brightens the icon (greyed-out icons stay greyed). The old
# Highlight2 sprite showed the same art as the actor turn highlight, which
# looked like the turn marker appearing on the ability icons.
func _on_mouse_entered() -> void:
	hovered = true
	_applyModulate()


func _on_mouse_exited() -> void:
	hovered = false
	_applyModulate()
