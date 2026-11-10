extends Button
class_name ItemSlotButton

## Focusable inventory/equipment cell used by the Inventory tab. The slot stores
## presentation metadata only; commands use stable ids/slots from the tab.

const PLACEHOLDER_ICON = preload("res://Assets/Icons/PlaceholderIcon.png")

## Empty equipment cells show the greyed-out slot art (the same icons the
## Shootout HUD uses) instead of a text label: the labels never fit the small
## cells, and the icons read at a glance without eating two rows of the panel.
const EMPTY_ICON_MODULATE = Color(1, 1, 1, 0.5)

@onready var iconRect: TextureRect = $Icon
@onready var emptyLabel: CenterContainer = $EmptyLabel
@onready var emptyText: RichTextLabel = $EmptyLabel/EmptyText
@onready var quantityLabel: RichTextLabel = $Quantity

var item: Dictionary = {}


func _ready() -> void:
	_refreshNodes()


## Icon area of a cell (see ItemSlotButton.tscn), kept inside the cell border:
## the 12x12, 24x24 and 28x24 sprites all fit at an integer scale (2x / 1x / 1x).
const ICON_BOX = Vector2(28, 26)

## `emptyIcon` renders a dimmed placeholder instead of `emptyTextValue`; the
## text still feeds the tooltip.
func displayItem(value: Dictionary, emptyTextValue := "", emptyIcon: Texture2D = null) -> void:
	_refreshNodes()
	item = value.duplicate(true)
	if item.is_empty():
		if emptyIcon != null:
			iconRect.texture = emptyIcon
			iconRect.modulate = EMPTY_ICON_MODULATE
			iconRect.visible = true
			emptyText.setRichTextLabel("")
			emptyLabel.visible = false
		else:
			iconRect.texture = null
			iconRect.visible = false
			emptyText.setRichTextLabel(emptyTextValue)
			emptyLabel.visible = emptyTextValue != ""
		quantityLabel.visible = false
		tooltip_text = emptyTextValue
		_applyIconFit()
		return
	var sprite = item.get("sprite", "")
	iconRect.texture = load(sprite) if sprite != "" and ResourceLoader.exists(sprite) else PLACEHOLDER_ICON
	iconRect.modulate = Color(1, 1, 1, 1)
	iconRect.visible = true
	_applyIconFit()


## Draws the sprite at an integer scale (TextureFit) and keeps it centred: the
## cell's Icon is anchored, not laid out by a container, so its rect follows the
## fitted size instead of always filling the 24x24 box.
func _applyIconFit() -> void:
	TextureFit.applyTo(iconRect, ICON_BOX)
	var fitted = iconRect.custom_minimum_size
	iconRect.anchor_left = 0.5
	iconRect.anchor_top = 0.5
	iconRect.anchor_right = 0.5
	iconRect.anchor_bottom = 0.5
	iconRect.offset_left = -fitted.x * 0.5
	iconRect.offset_top = -fitted.y * 0.5
	iconRect.offset_right = fitted.x * 0.5
	iconRect.offset_bottom = fitted.y * 0.5
	emptyLabel.visible = false
	var itemName = str(item.get("name", item.get("definitionId", "Item")))
	var quantity = int(item.get("quantity", 1))
	quantityLabel.setRichTextLabel(str(quantity))
	quantityLabel.visible = quantity > 1
	tooltip_text = itemName if quantity <= 1 else "%s x%d" % [itemName, quantity]


func _refreshNodes() -> void:
	if iconRect == null:
		iconRect = $Icon
		emptyLabel = $EmptyLabel
		emptyText = $EmptyLabel/EmptyText
		quantityLabel = $Quantity
