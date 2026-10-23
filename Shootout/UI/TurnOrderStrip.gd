extends HBoxContainer

## Full Round order strip (Docs/System Design/Shootout/Shootout UI.md): one
## portrait icon per living actor, the current actor highlighted.

const CURRENT_MODULATE = Color(1.0, 1.0, 1.0)
const OTHER_MODULATE = Color(1.0, 1.0, 1.0, 0.5)
const PLACEHOLDER_ICON = preload("res://Assets/Icons/PlaceholderIcon.png")
const PORTRAIT_SIZE = Vector2(24, 24)

## The shared Tooltip node of the Shootout UI (this strip renders inside the
## ShootoutUI scene); standalone uses have no tooltip.
var tooltip = null


func _ready() -> void:
	if owner != null:
		tooltip = owner.get_node_or_null("Tooltip/Tooltip")
	# The strip reserves the widest possible row (8 portraits) so rebuilding
	# per turn (the order shrinks as actors act) never changes the container's
	# minimum size: shrinking minimums + the stat panels' label churn trip a
	# Godot layout oscillation that overflows the message queue and hard-crashes
	# the engine (see ShootoutUI.showEffects for the same pattern).
	custom_minimum_size = Vector2(248, 26)


func setTurnOrder(actorNames: Array) -> void:
	for child in get_children():
		# Queue while still parented (safe deletion) and detach immediately so
		# the strip rebuilds within the same frame instead of keeping stale rows.
		child.queue_free()
		remove_child(child)
	for i in actorNames.size():
		var portrait = TextureRect.new()
		portrait.name = "Portrait{index}".format({ "index": i })
		portrait.texture = _iconFor(actorNames[i])
		portrait.custom_minimum_size = PORTRAIT_SIZE
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.modulate = CURRENT_MODULATE if i == 0 else OTHER_MODULATE
		_attachTooltip(portrait, str(actorNames[i]))
		add_child(portrait)


## Portrait icons show the actor name through the shared Tooltip node.
func _attachTooltip(portrait: Control, actorName: String) -> void:
	if tooltip == null:
		return
	portrait.mouse_entered.connect(func():
		tooltip.updateTooltip(actorName)
		tooltip.showTooltip())
	portrait.mouse_exited.connect(tooltip.hideTooltip)


## Portrait icons follow the animation naming: the actor name without the turn
## index, capitalized without spaces, plus "Icon" (ShootoutActor.gd derives
## animation paths the same way). Actors without portrait art fall back to the
## placeholder icon.
func _iconFor(actorName: String) -> Texture2D:
	var iconPath = "res://Assets/Icons/{actorName}Icon.png".format({
		"actorName": str(actorName).rstrip("0123456789").capitalize().replace(" ", "")
	})
	if ResourceLoader.exists(iconPath):
		return load(iconPath)
	return PLACEHOLDER_ICON
