extends Control



func _on_mouse_entered(title: String, text: String) -> void:
	$Tooltip/Tooltip.updateTooltip(title, text)
	$Tooltip/Tooltip.showTooltip()

func _on_mouse_exited() -> void:
	$Tooltip/Tooltip.hideTooltip()
