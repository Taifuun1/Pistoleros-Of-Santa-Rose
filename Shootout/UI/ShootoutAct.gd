extends TextureRect

signal actClicked

var actName
var actType


func init(newActName: String, newActType: String, enabled := true) -> void:
	actName = newActName
	actType = newActType
	var iconPath = "res://Assets/{actType}/{actName}.png".format({ "actType": actType, "actName": actName.replace(" ", "") })
	if ResourceLoader.exists(iconPath):
		texture = load(iconPath)
	# Unusable acts are greyed out with the reason (Docs/System Design/Shootout/Shootout UI.md);
	# the tooltip is attached by ShootoutUI through the shared Tooltip node.
	if !enabled:
		modulate = Color(0.5, 0.5, 0.5, 0.7)


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
var hoverModulate = null


func _on_mouse_entered() -> void:
	hoverModulate = modulate
	modulate = modulate.lightened(0.3)

func _on_mouse_exited() -> void:
	if hoverModulate != null:
		modulate = hoverModulate
		hoverModulate = null
