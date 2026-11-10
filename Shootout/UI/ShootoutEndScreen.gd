extends Control

## Shootout result screen (Docs/System Design/Journal/Inventory and Equipment.md):
## a static scene node owned by ShootoutUI. Showing results only updates its
## text, visibility and focus — it never creates or frees UI nodes.

signal continuePressed

@onready var outcomeText = $CenterContainer/PanelContainer/MarginContainer/Layout/Outcome
@onready var acceptedText = $CenterContainer/PanelContainer/MarginContainer/Layout/LootScroll/LootContent/AcceptedLoot
@onready var overflowText = $CenterContainer/PanelContainer/MarginContainer/Layout/LootScroll/LootContent/OverflowLoot
@onready var continueButton: Button = $CenterContainer/PanelContainer/MarginContainer/Layout/ContinueButton

var acknowledged := false


func _ready() -> void:
	visible = false
	overflowText.visible = false
	continueButton.pressed.connect(_onContinuePressed)


func showResults(results: Dictionary) -> void:
	acknowledged = false
	continueButton.disabled = false
	var loot = results.get("loot", {})
	if !(loot is Dictionary):
		loot = {}
	var lootResult = results.get("lootResult", {})
	if !(lootResult is Dictionary):
		lootResult = {}
	var accepted = lootResult.get("accepted", [])
	if !(accepted is Array):
		accepted = []
	var overflow = lootResult.get("overflow", [])
	if !(overflow is Array):
		overflow = []
	if lootResult.is_empty():
		accepted = loot.get("items", [])
		if !(accepted is Array):
			accepted = []
	var money = int(lootResult.get("money", loot.get("money", 0)))

	outcomeText.setRichTextLabel(str(results.get("outcome", "")).capitalize())
	var acceptedSummary = _lootSummary(accepted, money)
	acceptedText.setRichTextLabel(acceptedSummary if acceptedSummary != "" else "No loot.")
	overflowText.visible = !overflow.is_empty()
	overflowText.setRichTextLabel("Inventory full - left behind: " + _lootSummary(overflow, 0) if !overflow.is_empty() else "")
	continueButton.text = "Leave overflow & continue" if !overflow.is_empty() else "Continue"
	visible = true
	continueButton.grab_focus()


func hideResults() -> void:
	visible = false


func _onContinuePressed() -> void:
	if acknowledged:
		return
	acknowledged = true
	continueButton.disabled = true
	continuePressed.emit()


func _lootSummary(entries: Array, money: int) -> String:
	var parts = []
	if money > 0:
		parts.append("%d cash" % money)
	for entryValue in entries:
		if !(entryValue is Dictionary):
			continue
		var entry = entryValue as Dictionary
		var quantity = int(entry.get("quantity", 1))
		var itemName = str(entry.get("name", entry.get("definitionId", "item")))
		parts.append("%d %s" % [quantity, itemName])
	return String(", ").join(parts)