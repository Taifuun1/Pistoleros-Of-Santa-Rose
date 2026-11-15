extends Button
class_name VendorItemRow

## One selectable vendor list row (Docs/System Design/Location Vendors
## Implementation.md, patch 4). The row carries the stable command id it stands
## for (offerId or instanceId); the menu never uses an array index as identity.

## Stable id of the offer/item this row commands.
var rowId := ""


## `row` is a display-only Dictionary from the menu's snapshot:
## { id, name, detail, price, disabled, reason }.
func displayRow(row: Dictionary) -> void:
	rowId = str(row.get("id", ""))
	var nameLabel: Label = $Layout/Name
	var detailLabel: Label = $Layout/Detail
	var priceLabel: Label = $Layout/Price
	nameLabel.text = str(row.get("name", ""))
	detailLabel.text = str(row.get("detail", ""))
	priceLabel.text = str(row.get("price", ""))
	var reason := str(row.get("reason", ""))
	disabled = bool(row.get("disabled", false))
	tooltip_text = reason if disabled and reason != "" else str(row.get("name", ""))
	var tint := Color(1, 1, 1, 0.5) if disabled else Color(1, 1, 1, 1)
	nameLabel.modulate = tint
	detailLabel.modulate = tint
	priceLabel.modulate = tint
