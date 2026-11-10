extends NinePatchRect

## Displays a generated item (see Globals/ItemGeneration.gd) on the ItemStats
## scene: the item sprite on the Icon texture rect, the rarity-colored name,
## the weapon family / equipment slot, rolled modifier lines and, for
## legendaries, the unique modifier (lore) line.

const PLACEHOLDER_ICON = "res://Assets/Icons/PlaceholderIcon.png"
const AffixDataScript = preload("res://Data/Items/AffixData.gd")

## Maximum lines the item name may take; longer names are truncated with "..."
## so the name can't push the rest of the panel's content down.
## (Three ASCII periods: the FFF Forward Outline 8px bitmap font only covers
## chars 32-125, so a U+2026 ellipsis would render as an unknown symbol.)
const NAME_MAX_LINES = 2

## Journal details need the complete name visible without hover; list/tooltip
## contexts keep the existing two-line truncation behavior.
var allowNameTruncation := true

var icon
var nameLabel
var familyLabel
var modifierLabels = []
var uniqueModifierLabel
var moveIcon
var tooltip

var affixData = AffixDataScript.new()

var _nameParts = []
var _displayedItem = {}
var _fullName = ""


func _ready() -> void:
	_ensureNodes()
	resized.connect(_onResized)
	# Re-display once in the tree so name truncation can measure real widths
	if not _displayedItem.is_empty():
		displayItem(_displayedItem)


## Resolves the node references. Called from _ready() and defensively from
## displayItem(), so displayItem() also works when called on an instance that
## hasn't entered the scene tree yet.
func _ensureNodes() -> void:
	if icon != null:
		return
	icon = $"MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/IconBox/Icon"
	nameLabel = $"MarginContainer/VBoxContainer/HBoxContainer/MarginContainer2/Name"
	familyLabel = $"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Family"
	modifierLabels = [
		$"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Modifier1",
		$"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Modifier2",
		$"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Modifier3",
		$"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Modifier4",
	]
	uniqueModifierLabel = $"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/UniqueModifier"
	moveIcon = $"MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Move"
	tooltip = $"Tooltip/Tooltip"
	if not nameLabel.mouse_entered.is_connected(_onNameMouseEntered):
		nameLabel.mouse_entered.connect(_onNameMouseEntered)
		nameLabel.mouse_exited.connect(_onNameMouseExited)


## Interior of the card art's icon frame: x 5-32, y 7-30 of the 200x200 texture
## (the frame's highlight border runs x 4-33, y 6-31). The nine-patch keeps that
## corner at 1:1, so this rect lands exactly on the drawn frame.
const ICON_BOX = Vector2(28, 24)

## Item sprites come in 12x12, 24x24 and 28x24. They are drawn at their native
## scale so every sprite keeps even pixel proportions and its authored size (a
## 12x12 hat stays visibly smaller than a 24x24 revolver), and centered inside the
## frame. Scaling each sprite up to fill the frame made 12px art as large as
## 24px art and left no room at the frame's edges.
func _setIcon(texture: Texture2D) -> void:
	icon.texture = texture
	TextureFit.applyTo(icon, ICON_BOX)


## Maps an item dictionary onto the labels and texture rects.
func displayItem(item: Dictionary) -> void:
	_ensureNodes()
	if item.is_empty():
		return
	_displayedItem = item

	if item.get("sprite", "") != "":
		_setIcon(load(item["sprite"]))
	else:
		_setIcon(load(PLACEHOLDER_ICON))

	_displayItemName(item)

	var itemType = str(item.get("itemType", ""))
	if itemType == "weapon":
		var familyText = str(item.get("family", "")).capitalize()
		if item.has("familyNoun"):
			familyText = "%s (%s)" % [familyText, item["familyNoun"]]
		familyLabel.setRichTextLabel(familyText)
	elif itemType == "equipment":
		familyLabel.setRichTextLabel(str(item.get("slot", "")).capitalize())
	else:
		familyLabel.setRichTextLabel(str(item.get("category", itemType)).capitalize())

	var modifierLines = []
	if itemType == "weapon":
		modifierLines.append("%s: %d" % [nameLabel.colorize("Damage", "keyword"), item.get("baseDamage", 0)])
	elif itemType not in ["equipment"]:
		var description = str(item.get("description", ""))
		if description != "":
			modifierLines.append(description)
	var itemStats = item.get("stats", {})
	if itemStats is Dictionary:
		for statKey in itemStats:
			modifierLines.append(_formatStatLine(statKey, itemStats[statKey]))
	for i in modifierLabels.size():
		modifierLabels[i].visible = i < modifierLines.size()
		if modifierLabels[i].visible:
			modifierLabels[i].setRichTextLabel(modifierLines[i])

	var lore = item.get("lore", "")
	uniqueModifierLabel.visible = lore != ""
	if uniqueModifierLabel.visible:
		uniqueModifierLabel.setRichTextLabel(uniqueModifierLabel.colorize("Unique:", "unique") + " " + lore)

	# Items don't grant Shootout moves yet (see Docs/Combat.md, equipment moves)
	moveIcon.visible = false

	_fitPanelToContent()


## Builds the item name from individually colored parts: the rarity adjective
## in the rarity color, prefix and suffix in their affix category color, and
## the base name in white. Legendaries show their full name in legendary color.
## The name is capped at NAME_MAX_LINES lines; longer names are truncated with
## an ellipsis by _truncateName() (deferred, needs a laid-out label to measure).
func _displayItemName(item: Dictionary) -> void:
	var rarity = item.get("rarity", "common")
	_nameParts = []
	if !allowNameTruncation:
		_nameParts.append([str(item.get("name", "")), rarity])
	elif item.get("itemType", "") not in ["weapon", "equipment"]:
		_nameParts.append([str(item.get("name", "")), "white"])
	elif rarity == "legendary" or not item.has("rarityName"):
		_nameParts.append([item["name"], rarity])
	else:
		_nameParts.append([item["rarityName"], rarity])
		var prefix = item.get("prefix", {})
		if not prefix.is_empty():
			_nameParts.append([" " + prefix["name"], _affixCategoryColor(prefix["stat"])])
		_nameParts.append([" " + item["baseName"], "white"])
		var suffix = item.get("suffix", {})
		if not suffix.is_empty():
			_nameParts.append([" " + suffix["name"], _affixCategoryColor(suffix["stat"])])
	_renderName(_nameParts)
	# The full, untruncated name for the tooltip (item["name"] for generated
	# items; assembled from the parts as a fallback)
	_fullName = item.get("name", "")
	if _fullName == "":
		for part in _nameParts:
			_fullName += part[0]
		_fullName = _fullName.strip_edges()
	if allowNameTruncation:
		call_deferred("_truncateName")
	else:
		_fitPanelToContent()
	_requestRefit()


## Shows the tooltip with the full item name when hovering the name label.
## This is how the player reads names that were truncated with "...".
func _onNameMouseEntered() -> void:
	if _displayedItem.is_empty():
		return
	tooltip.updateTooltip(_fullName, _tooltipDescription(_displayedItem))
	tooltip.showTooltip()


func _onNameMouseExited() -> void:
	tooltip.hideTooltip()


func _tooltipDescription(item: Dictionary) -> String:
	var description = item.get("rarityName", "")
	if description != "":
		description += " - "
	var itemType = str(item.get("itemType", ""))
	if itemType == "weapon":
		description += str(item.get("family", "")).capitalize()
	elif itemType == "equipment":
		description += str(item.get("slot", "")).capitalize()
	else:
		description += str(item.get("category", itemType)).capitalize()
	return description


## Renders the name parts onto the name label, optionally appending an
## ellipsis to the last part.
func _renderName(parts: Array, withEllipsis := false) -> void:
	for i in parts.size():
		var partText = parts[i][0]
		if withEllipsis and i == parts.size() - 1:
			partText += "..."
		if i == 0:
			nameLabel.setRichTextLabel(partText, parts[i][1])
		else:
			nameLabel.appendRichTextLabel(partText, parts[i][1])


## Trims words off the end of the name (suffix first, then base name, etc.)
## until it fits within NAME_MAX_LINES lines, marking it with "...".
func _truncateName() -> void:
	if not allowNameTruncation or not is_inside_tree() or _nameParts.is_empty():
		return
	var truncated = false
	var guard = 0
	while guard < 24:
		_renderName(_nameParts, truncated)
		await get_tree().process_frame
		if nameLabel.get_line_count() <= NAME_MAX_LINES:
			break
		truncated = true
		guard += 1
		var lastPart = _nameParts.back()
		var words = lastPart[0].strip_edges().split(" ")
		if words.size() > 1:
			words.remove_at(words.size() - 1)
			lastPart[0] = " " + " ".join(words)
		elif _nameParts.size() > 1:
			_nameParts.pop_back()
		else:
			var word = lastPart[0].strip_edges()
			lastPart[0] = " " + word.left(maxi(1, word.length() - 4))
	_renderName(_nameParts, truncated)
	_fitPanelToContent()


## Grows (or shrinks) the panel vertically to fit the content. The labels wrap
## and expand (autowrap + fit_content), so the VBox's combined minimum size
## reflects all visible lines; hidden labels take no space.
##
## The wrapped height only holds for the width the panel was given, and the
## panel must never set its own size: it lives in a container that supplies the
## width (the Journal's ItemStatsHost). Only the minimum height is reported, so
## a narrow panel gets taller instead of squeezing its lines on top of each
## other.
const WIDTH_EPSILON = 0.5

var _fittedWidth := -1.0

func _fitPanelToContent() -> void:
	var contentHeight = $"MarginContainer/VBoxContainer".get_combined_minimum_size().y
	_fittedWidth = size.x if is_inside_tree() else -1.0
	if absf(custom_minimum_size.y - contentHeight) > WIDTH_EPSILON:
		custom_minimum_size.y = contentHeight


## Re-fits when the assigned width changes: that is the only input that changes
## how many lines the content wraps into. The width is known a frame before the
## labels finish re-wrapping, so the bounded re-measure below follows it.
func _onResized() -> void:
	if is_equal_approx(size.x, _fittedWidth):
		return
	_fitPanelToContent()
	_requestRefit()


## Text layout resolves a frame or two after the item is rendered, so the first
## measurement can miss the wrapped height. Re-measure for a few frames until
## the height settles; bounded so a layout that never settles cannot spin.
const REFIT_ATTEMPTS = 4
var _refitPending := false

func _requestRefit() -> void:
	if _refitPending or !is_inside_tree():
		return
	_refitPending = true
	for _attempt in REFIT_ATTEMPTS:
		await get_tree().process_frame
		if !is_instance_valid(self) or !is_inside_tree():
			return
		var before = custom_minimum_size.y
		_fitPanelToContent()
		if is_equal_approx(before, custom_minimum_size.y):
			break
	_refitPending = false


func _affixCategoryColor(statKey: String) -> String:
	if affixData.stats.has(statKey):
		return affixData.stats[statKey].get("category", "white")
	return "white"


## Formats a stat line with the keyword highlighted, e.g.
## "+15% [keyword]Revolver damage[/keyword]".
func _formatStatLine(statKey: String, value: int) -> String:
	var displayName = statKey
	var kind = "flat"
	if affixData.stats.has(statKey):
		displayName = affixData.stats[statKey]["displayName"]
		kind = affixData.stats[statKey]["kind"]
	var keyword = nameLabel.colorize(displayName, "keyword")
	match kind:
		"percent":
			return "+%d%% %s" % [value, keyword]
		"flag":
			return keyword
	return "+%d %s" % [value, keyword]
