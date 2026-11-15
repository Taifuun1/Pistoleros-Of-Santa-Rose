extends Node

## Scene-run validation of the Journal Inventory & Equipment tab (Docs/System
## Design/Journal/Inventory and Equipment.md, patch 4). Uses a fake provider so
## commands, states and focus are deterministic. Run as TestInventoryTab.tscn.

const InventoryTabScene = preload("res://UI/Journal/Tabs/InventoryTab.tscn")

var failures := 0
var provider: FakeProvider
var useProvider: FakeUseProvider
var tab


class FakeProvider:
	extends Node

	signal inventoryChanged
	signal equipmentChanged(memberKey: String)

	var available := true
	var snapshot: Dictionary = {}
	var previewResult: Dictionary = {}
	var equipResult: Dictionary = { "success": true, "slot": "duster", "returnedInstanceId": "" }
	var dropResult: Dictionary = { "success": true, "quantity": 1 }
	var previewCalls: Array = []
	var equipCalls: Array = []
	var dropCalls: Array = []
	var snapshotCalls := 0

	func isInventoryDataAvailable() -> bool:
		return available

	func getInventorySnapshot() -> Dictionary:
		snapshotCalls += 1
		return snapshot.duplicate(true)

	func getEquipmentPreview(memberKey: String, instanceId: String) -> Dictionary:
		previewCalls.append([memberKey, instanceId])
		return previewResult.duplicate(true)

	func equipItem(memberKey: String, instanceId: String) -> Dictionary:
		equipCalls.append([memberKey, instanceId])
		return equipResult.duplicate(true)

	func dropItem(instanceId: String, quantity: int) -> Dictionary:
		dropCalls.append([instanceId, quantity])
		return dropResult.duplicate(true)

	func emitInventoryChanged() -> void:
		inventoryChanged.emit()


class FakeUseProvider:
	extends Node

	var previewResult: Dictionary = { "success": true, "reason": "", "mapId": "test_map", "targetNames": ["Gold Run", "Buried cache"] }
	var useResult: Dictionary = { "success": true, "reason": "", "mapId": "test_map", "revealedIds": ["Gold Run", "Buried cache"], "consumed": true }
	var previewCalls: Array = []
	var useCalls: Array = []

	func getMapUsePreview(instanceId: String) -> Dictionary:
		previewCalls.append(instanceId)
		return previewResult.duplicate(true)

	func useMap(instanceId: String) -> Dictionary:
		useCalls.append(instanceId)
		return useResult.duplicate(true)


func _ready() -> void:
	provider = FakeProvider.new()
	provider.snapshot = makeSnapshot()
	useProvider = FakeUseProvider.new()
	add_child(useProvider)
	provider.previewResult = {
		"success": true,
		"reason": "",
		"memberKey": "walker",
		"slot": "duster",
		"beltValid": true,
		"managementAllowed": true,
		"deltas": [
			{ "path": "maxHp", "label": "MxHP", "before": 12, "after": 16, "delta": 4 },
			{ "path": "stats.defense.style", "label": "Style", "before": 2, "after": 4, "delta": 2 },
		],
	}
	tab = InventoryTabScene.instantiate()
	tab.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tab.position = Vector2(40, 60)
	tab.size = Vector2(560, 240)
	tab.inventoryProvider = provider
	tab.itemUseProvider = useProvider
	add_child(tab)
	await get_tree().process_frame
	await get_tree().process_frame

	await testUnavailableAndEmpty()
	await testContentAndSelection()
	await testSelectionFallback()
	await testEquipAndComparison()
	await testDropFlow()
	await testMapUseFlow()
	await testFocusAndLiveUpdates()
	await testLongContentAndLayout()
	await testEquipmentAndMemberPresentation()

	tab.setTabActive(false)
	tab.free()
	useProvider.free()
	provider.free()
	print("\nTestInventoryTab: %d failure(s)" % failures)
	get_tree().quit(failures)


func refreshTab() -> void:
	tab.setTabActive(true)
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame


func makeSnapshot() -> Dictionary:
	return {
		"capacity": 24,
		"used": 2,
		"managementAllowed": true,
		"items": [
			{
				"instanceId": "p_paregoric", "definitionId": "paregoric", "itemType": "consumable",
				"quantity": 3, "stackLimit": 5, "droppable": true, "name": "Paregoric",
				"category": "supplies", "description": "Restores HP in a Shootout.",
				"sprite": "res://Assets/Items/Paregoric.png",
			},
			{
				"instanceId": "p_duster", "definitionId": "test_duster", "itemType": "equipment",
				"slot": "duster", "quantity": 1, "stackLimit": 1, "droppable": true,
				"name": "Well-Kept Duster", "baseName": "Duster", "rarity": "rare",
				"rarityName": "Well-Kept", "prefix": {}, "suffix": {}, "sprite": "",
				"stats": { "style": 2, "mxHp": 4 },
			},
		],
		"members": [{
			"key": "walker", "actorName": "Walker Langley",
			"equipment": {
				"weapon": { "instanceId": "starter_rifle", "itemType": "weapon", "name": "Rifle", "family": "rifle", "baseDamage": 4, "stats": {} },
				"headwear": null, "bandana": null, "duster": null, "belt": null,
				"trousers": null, "justins": null,
			},
			"fightData": {
				"hp": 12, "maxHp": 12, "beltSpace": 1,
				"stats": { "sixShootin": 3, "highTailin": 6, "taffyin": 2, "defense": { "style": 2, "sand": 1 } },
			},
		}],
	}


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("CHECK FAILED: ", message)
func testUnavailableAndEmpty() -> void:
	print("--- Unavailable, malformed and empty states ---")
	provider.available = false
	await refreshTab()
	check(!tab.contentView.visible and tab.stateView.visible, "unavailable data shows the state view")
	check(tab.stateMessageLabel.get_parsed_text() == "Inventory data unavailable", "unavailable message is explicit")
	check(tab._inventoryButtons.is_empty() and tab.getFocusTarget() == null, "unavailable data leaves no actions or focus target")

	provider.available = true
	provider.snapshot["items"] = "malformed"
	await refreshTab()
	check(tab.stateMessageLabel.get_parsed_text() == "Inventory data unavailable", "malformed snapshot fails closed")

	var broken := Node.new()
	tab.inventoryProvider = broken
	provider.snapshot = makeSnapshot()
	await refreshTab()
	check(tab.stateMessageLabel.get_parsed_text() == "Inventory data unavailable", "provider without the read API fails closed")
	broken.free()
	tab.inventoryProvider = provider

	provider.snapshot = makeSnapshot()
	provider.snapshot["items"] = []
	provider.snapshot["used"] = 0
	await refreshTab()
	check(tab.contentView.visible and tab.emptyInventoryLabel.visible, "valid empty inventory keeps content visible")
	check(tab.memberButtons.get_child_count() == 1 and tab.getFocusTarget() == tab._memberButtons["walker"], "equipment remains inspectable with an empty inventory")
	check(tab.capacityText.get_parsed_text() == "0 / 24", "empty capacity is shown")
	provider.snapshot = makeSnapshot()


func testContentAndSelection() -> void:
	print("\n--- Content, member and item selection ---")
	await refreshTab()
	check(tab.contentView.visible and !tab.stateView.visible, "valid snapshot shows content")
	check(tab.memberButtons.get_child_count() == 1, "one member button is built")
	check(tab.equipmentGrid.get_child_count() == 7, "all seven equipment slots are built")
	check(tab.inventoryGrid.get_child_count() == 24, "inventory renders occupied plus empty capacity cells")
	check(tab.capacityText.get_parsed_text() == "2 / 24", "capacity counts occupied stacks")
	check(tab.memberStatsLabel.get_parsed_text().contains("HP 12/12") and tab.memberStatsLabel.get_parsed_text().contains("Belt 1"), "member summary renders effective values")
	check(tab.selectionLabel.get_parsed_text() == "Select an item or equipment slot.", "no-selection prompt is explicit")
	check(tab.getFocusTarget() == tab._memberButtons["walker"], "selected member is the tab focus target")

	tab._onInventoryItemPressed("p_paregoric")
	check(tab._selectionSource == "inventory" and tab._selectedInstanceId == "p_paregoric", "inventory click selects by instance id")
	check(tab._itemStats.visible and tab._itemStats.nameLabel.get_parsed_text() == "Paregoric", "stackable details render in ItemStats")
	check(tab.selectionLabel.get_parsed_text().contains("Quantity 3 / 5"), "stack quantity and limit are visible")
	check(tab.equipButton.disabled and tab.feedbackLabel.get_parsed_text() == "Equipment can only be equipped from inventory.", "consumables cannot be equipped")
	check(!tab.dropButton.disabled, "droppable consumable enables Drop")
	check(providerPreviewCalls().is_empty(), "stackables do not request equipment previews")

	tab._onEquipmentSlotPressed("headwear")
	check(tab._selectionSource == "equipment" and _selectionEquipmentSlot() == "headwear", "empty equipment slot is selectable")
	check(tab.selectionLabel.get_parsed_text().contains("Empty Headwear slot."), "empty slot identifies itself")
	check(tab.equipButton.disabled and tab.dropButton.disabled, "empty equipment offers no commands")


func testSelectionFallback() -> void:
	print("\n--- Removed-item selection fallback ---")
	var three = makeSnapshot()
	three["items"].append({
		"instanceId": "p_token", "definitionId": "paregoric", "itemType": "consumable",
		"quantity": 1, "stackLimit": 5, "droppable": true, "name": "Token",
		"category": "supplies", "description": "", "sprite": "",
	})
	provider.snapshot = three
	await refreshTab()
	tab._onInventoryItemPressed("p_duster")
	provider.snapshot["items"].remove_at(1)
	await refreshTab()
	check(tab._selectedInstanceId == "p_token", "removal selects the next occupied cell at the same index")

	provider.snapshot["items"].pop_back()
	await refreshTab()
	check(tab._selectedInstanceId == "p_paregoric", "removal at the end selects the nearest previous cell")

	provider.snapshot["items"] = []
	await refreshTab()
	check(tab._selectedInstanceId == "" and tab.selectionLabel.get_parsed_text() == "Select an item or equipment slot.", "removing every item clears selection without a command")
	check(provider.equipCalls.is_empty() and provider.dropCalls.is_empty(), "selection fallback never invokes a command")
	provider.snapshot = makeSnapshot()


func testEquipAndComparison() -> void:
	print("\n--- Preview, comparison and equip command ---")
	provider.snapshot = makeSnapshot()
	provider.previewResult = {
		"success": true, "reason": "", "memberKey": "walker", "slot": "duster",
		"beltValid": true, "managementAllowed": true,
		"deltas": [
			{ "path": "maxHp", "label": "MxHP", "before": 12, "after": 16, "delta": 4 },
			{ "path": "stats.defense.style", "label": "Style", "before": 2, "after": 4, "delta": 2 },
		],
	}
	await refreshTab()
	provider.previewCalls.clear()
	tab._onInventoryItemPressed("p_duster")
	check(providerPreviewCalls().size() == 1, "gear selection requests one preview")
	check(!tab.equipButton.disabled, "valid preview enables Equip")
	check(tab.comparisonRows.get_child_count() == 2, "comparison renders each changed stat")
	check(tab.comparisonRows.get_child(0).get_parsed_text().contains("MxHP") and tab.comparisonRows.get_child(0).get_parsed_text().contains("(+4)"), "comparison shows before, after and delta")
	check(tab.feedbackLabel.get_parsed_text() == "", "valid gear has no disabled reason")

	tab._onEquipPressed()
	check(providerEquipCalls().size() == 1 and providerEquipCalls()[0] == ["walker", "p_duster"], "Equip calls one command with stable ids")
	check(tab.feedbackLabel.get_parsed_text() == "Equipped.", "successful equip reports its result")

	provider.snapshot["managementAllowed"] = false
	await refreshTab()
	tab._onInventoryItemPressed("p_duster")
	check(tab.equipButton.disabled and tab.feedbackLabel.get_parsed_text().contains("unavailable"), "management policy disables Equip with a visible reason")
	provider.snapshot = makeSnapshot()

	provider.previewResult = {
		"success": true, "reason": "belt_loadout_too_large", "memberKey": "walker", "slot": "duster",
		"beltValid": false, "managementAllowed": true, "deltas": [],
	}
	await refreshTab()
	tab._onInventoryItemPressed("p_duster")
	check(tab.equipButton.disabled and tab.feedbackLabel.get_parsed_text().contains("belt"), "invalid belt loadout disables Equip")
	provider.previewResult = {
		"success": true, "reason": "", "memberKey": "walker", "slot": "duster",
		"beltValid": true, "managementAllowed": true, "deltas": [],
	}

func testDropFlow() -> void:
	print("\n--- Confirmed quantity drop ---")
	provider.snapshot = makeSnapshot()
	provider.dropResult = { "success": true, "quantity": 2, "definitionId": "paregoric", "instanceId": "p_paregoric" }
	await refreshTab()
	tab._onInventoryItemPressed("p_paregoric")
	tab._onDropPressed()
	check(tab.dropOverlay.visible and !tab.canCloseTab(), "Drop opens a guarded confirmation")
	check(tab.quantityLabel.get_parsed_text() == "1" and tab.decrementButton.disabled, "quantity starts at one")
	tab._onIncrementPressed()
	check(tab.quantityLabel.get_parsed_text() == "2" and !tab.decrementButton.disabled, "increment raises the quantity")
	tab._onAllPressed()
	check(tab.quantityLabel.get_parsed_text() == "3" and tab.allButton.disabled, "All selects the whole stack")
	tab._onDropCancelled()
	await get_tree().process_frame
	check(!tab.dropOverlay.visible and providerDropCalls().is_empty() and tab.canCloseTab(), "cancel mutates nothing")
	check(get_viewport().gui_get_focus_owner() == tab._inventoryButtons["p_paregoric"], "cancel returns focus to the selected item")

	tab._onDropPressed()
	tab._onIncrementPressed()
	tab._onDropConfirmed()
	check(providerDropCalls().size() == 1 and providerDropCalls()[0] == ["p_paregoric", 2], "confirm sends exactly one quantity command")
	check(!tab.dropOverlay.visible and tab.feedbackLabel.get_parsed_text() == "Dropped 2.", "successful drop closes and reports")

	tab._onDropPressed()
	var cancelEvent := InputEventAction.new()
	cancelEvent.action = "ui_cancel"
	cancelEvent.pressed = true
	tab._unhandled_input(cancelEvent)
	check(!tab.dropOverlay.visible and providerDropCalls().size() == 1, "ui_cancel closes without a second command")


func testMapUseFlow() -> void:
	print("\n--- Map use (out-of-combat item effect) ---")
	provider.snapshot = makeSnapshot()
	provider.snapshot["items"].append({
		"instanceId": "p_cache_map", "definitionId": "canyon_cache_map", "itemType": "map",
		"quantity": 1, "stackLimit": 1, "droppable": true, "name": "Canyon Cache Map",
		"category": "maps", "description": "Reveals the hidden Gold Run on the Overworld map.",
		"sprite": "res://Assets/Journal/MapIcon.png",
		"effect": { "kind": "reveal_map", "mapId": "canyon_cache_map" },
	})
	await refreshTab()
	tab._onInventoryItemPressed("p_paregoric")
	check(!tab.useButton.visible, "items without a supported effect show no Use action")
	tab._onInventoryItemPressed("p_cache_map")
	check(tab.useButton.visible and !tab.useButton.disabled, "a map shows an enabled Use action")
	check(tab.canCloseTab(), "the tab is closable while no overlay is open")

	tab._onUsePressed()
	check(tab.useOverlay.visible and !tab.canCloseTab(), "Use opens a guarded confirmation")
	check(tab.useItemLabel.get_parsed_text().contains("Canyon Cache Map"), "the confirmation names the map")
	check(tab.useItemLabel.get_parsed_text().contains("Gold Run"), "the confirmation lists the map's reveals")
	check(tab.useItemLabel.get_parsed_text().contains("One copy will be consumed"), "the confirmation states one copy is spent")
	check(useProvider.previewCalls == ["p_cache_map"], "the preview resolves the selected instance")
	tab._onUseCancelled()
	await get_tree().process_frame
	check(!tab.useOverlay.visible and useProvider.useCalls.is_empty(), "cancel consumes nothing")
	check(tab.canCloseTab(), "cancel clears the modal guard")
	check(get_viewport().gui_get_focus_owner() == tab._inventoryButtons["p_cache_map"], "cancel returns focus to the map")

	tab._onUsePressed()
	tab._onUseConfirmed()
	check(useProvider.useCalls == ["p_cache_map"], "confirm sends exactly one use command")
	check(!tab.useOverlay.visible, "a successful use closes the confirmation")
	check(tab.feedbackLabel.get_parsed_text().contains("2 destinations revealed"), "the result reports the revealed count")

	tab._onUsePressed()
	useProvider.useResult = { "success": false, "reason": "already_revealed" }
	tab._onUseConfirmed()
	check(tab.feedbackLabel.get_parsed_text().contains("already fully revealed"), "domain failures map to readable text")
	check(tab.useOverlay.visible, "a failed use keeps the confirmation open for a retry")
	tab._onUseCancelled()
	useProvider.useResult = { "success": true, "reason": "", "mapId": "test_map", "revealedIds": ["Gold Run"], "consumed": true }
	await get_tree().process_frame

	useProvider.previewResult = { "success": false, "reason": "already_revealed" }
	tab._onUsePressed()
	check(!tab.useOverlay.visible, "an unusable map never opens the confirmation")
	check(tab.feedbackLabel.get_parsed_text().contains("already fully revealed"), "the preview reason is reported")
	useProvider.previewResult = { "success": true, "reason": "", "mapId": "test_map", "targetNames": ["Gold Run", "Buried cache"] }

	# A blocked inventory policy disables the action instead of consuming.
	provider.snapshot["managementAllowed"] = false
	await refreshTab()
	tab._onInventoryItemPressed("p_cache_map")
	check(tab.useButton.disabled, "Use is disabled when inventory changes are blocked")
	tab._onUsePressed()
	check(!tab.useOverlay.visible and useProvider.useCalls.size() == 2, "a blocked Use opens nothing and sends no command")

	provider.snapshot = makeSnapshot()
	provider.snapshot["items"].append({
		"instanceId": "p_cache_map", "definitionId": "canyon_cache_map", "itemType": "map",
		"quantity": 1, "stackLimit": 1, "droppable": true, "name": "Canyon Cache Map",
		"category": "maps", "description": "", "sprite": "",
		"effect": { "kind": "reveal_map", "mapId": "canyon_cache_map" },
	})
	await refreshTab()
	var cancelEvent := InputEventAction.new()
	cancelEvent.action = "ui_cancel"
	cancelEvent.pressed = true
	tab._onInventoryItemPressed("p_cache_map")
	tab._onUsePressed()
	tab._unhandled_input(cancelEvent)
	check(!tab.useOverlay.visible, "ui_cancel closes the confirmation without a command")
	provider.snapshot = makeSnapshot()


func testFocusAndLiveUpdates() -> void:
	print("\n--- Focus restoration and live provider signals ---")
	provider.snapshot = makeSnapshot()
	await refreshTab()
	tab._onMemberPressed("walker")
	tab._memberButtons["walker"].grab_focus()
	await get_tree().process_frame
	await refreshTab()
	check(get_viewport().gui_get_focus_owner() == tab._memberButtons["walker"], "member focus survives a refresh")

	var callsBefore = provider.snapshotCalls
	provider.emitInventoryChanged()
	await get_tree().process_frame
	check(provider.snapshotCalls == callsBefore + 1, "inventoryChanged refreshes the active tab once")
	callsBefore = provider.snapshotCalls
	provider.equipmentChanged.emit("walker")
	await get_tree().process_frame
	check(provider.snapshotCalls == callsBefore + 1, "equipmentChanged also refreshes the active tab")
	tab.setTabActive(false)
	callsBefore = provider.snapshotCalls
	provider.emitInventoryChanged()
	await get_tree().process_frame
	check(provider.snapshotCalls == callsBefore, "hidden tab disconnects from provider signals")
	tab.setTabActive(true)


func testLongContentAndLayout() -> void:
	print("\n--- Long content and layout ---")
	provider.snapshot = makeSnapshot()
	var longItem = provider.snapshot["items"][1]
	longItem["name"] = "Storied Deadeye's Trail-Forged Duster of the Endless Prairie"
	longItem["description"] = "A long description that must wrap without shrinking the shared 12px font or hiding the full name behind a tooltip."
	await refreshTab()
	tab._onInventoryItemPressed("p_duster")
	# Item text lays out asynchronously; the card re-fits for a few frames after.
	for _frame in 6:
		await get_tree().process_frame
	check(tab._itemStats.nameLabel.get_parsed_text() == longItem["name"], "Journal details show the complete untruncated item name")
	check(tab._itemStats.nameLabel.autowrap_mode != TextServer.AUTOWRAP_OFF, "long name wraps")
	check(tab.detailScroll.size.y > 0 and tab.inventoryScroll.size.y > 0, "detail and inventory scroll regions are laid out")
	check(tab.inventoryGrid.get_child(0).size.x >= 39.0 and tab.inventoryGrid.get_child(0).size.y >= 37.0, "slot hit areas remain usable")
	check(tab.get_combined_minimum_size().x <= 570.0, "tab content minimum width fits the 560px Journal panel")
	check(tab.get_combined_minimum_size().y <= 280.0, "tab content minimum height fits the Journal content area")

	# The item card must reflow instead of overlapping: every visible line has to
	# fit the height the card gives it once the wrapped text is measured.
	var card = tab._itemStats
	check(card.size.y + 0.5 >= card.get_combined_minimum_size().y, "item card is at least as tall as its content")
	for labelValue in [card.nameLabel, card.familyLabel, card.modifierLabels[0], card.uniqueModifierLabel]:
		var label = labelValue
		if !label.visible:
			continue
		check(label.get_content_height() <= label.size.y + 0.5,
			"item card text overlaps: content %s > box %s" % [label.get_content_height(), label.size.y])
	# Width changes are the only input that changes the wrapped line count.
	var originalTabSize = tab.size
	tab.size = Vector2(420, 240)
	for _frame in 6:
		await get_tree().process_frame
	check(card.custom_minimum_size.y + 0.5 >= card.get_node("MarginContainer/VBoxContainer").get_combined_minimum_size().y,
		"narrow item card grows to fit the re-wrapped text")
	check(card.nameLabel.get_content_height() <= card.nameLabel.size.y + 0.5,
		"narrow item card still keeps the name inside its box")
	# The card art's icon box must keep its natural size: the sprite is contained
	# by that box, not by the scaled card, so it never spills over the background.
	check(card is NinePatchRect, "item card scales as a nine-patch so its icon box keeps its size")
	var iconRectBefore = card.icon.size
	var iconPatch = Rect2(card.global_position, Vector2(card.patch_margin_left, card.patch_margin_top))
	check(iconPatch.encloses(card.icon.get_global_rect()),
		"item icon stays inside the card's icon box: icon %s in %s" % [card.icon.get_global_rect(), iconPatch])
	# Restore the tab width before touching textures, so the size comparison below
	# can only be explained by the card resize.
	tab.size = originalTabSize
	for _frame in 6:
		await get_tree().process_frame
	check(card.icon.size == iconRectBefore, "the icon box does not scale with the card")
	# Sprites come in 12x12, 24x24 and 28x24. One shared native scale keeps their
	# pixel proportions even and their authored sizes intact: a 12x12 hat must stay
	# visibly smaller than a 24x24 revolver instead of being blown up to match it.
	var drawnSizes = {}
	for spritePath in ["res://Assets/Weapons/ColtPythonRevolver.png", "res://Assets/Weapons/HawkenRifle.png", "res://Assets/Equipment/HatBrown.png"]:
		var sprite = load(spritePath)
		card.icon.texture = sprite
		TextureFit.applyTo(card.icon, card.ICON_BOX)
		var drawn = card.icon.custom_minimum_size
		var factor = drawn / sprite.get_size()
		drawnSizes[spritePath.get_file()] = drawn
		check(is_equal_approx(factor.x, factor.y), "%s keeps its aspect ratio (%s)" % [spritePath.get_file(), factor])
		check(is_equal_approx(factor.x, TextureFit.SCALE), "%s uses the shared sprite scale, got %s" % [spritePath.get_file(), factor])
		check(drawn.x <= card.ICON_BOX.x + 0.5 and drawn.y <= card.ICON_BOX.y + 0.5,
			"%s fits the icon box (%s in %s)" % [spritePath.get_file(), drawn, card.ICON_BOX])
	check(drawnSizes["HatBrown.png"].x < drawnSizes["ColtPythonRevolver.png"].x,
		"small art stays smaller than 24px art (%s vs %s)" % [drawnSizes["HatBrown.png"], drawnSizes["ColtPythonRevolver.png"]])


func testEquipmentAndMemberPresentation() -> void:
	print("\n--- Equipment and member presentation ---")
	provider.snapshot = makeSnapshot()
	await refreshTab()
	check(tab.equipmentGrid.columns == 7, "equipment slots render in a single row")
	check(tab.equipmentGrid.get_child_count() == 7, "all seven equipment slots are rendered")
	var filled = 0
	for slot in tab._equipmentButtons:
		var button = tab._equipmentButtons[slot]
		check(button.size.y <= 28.5, "equipment cell stays compact: %s is %s tall" % [slot, button.size.y])
		if button.item.is_empty():
			check(button.iconRect.texture == tab.SLOT_ICONS[slot], "empty %s slot shows its greyed icon" % slot)
			check(!button.emptyLabel.visible, "empty %s slot does not rely on a text label" % slot)
		else:
			filled += 1
			check(button.iconRect.modulate.a == 1.0, "filled %s slot shows the item at full opacity" % slot)
	check(filled == 1, "the equipped item is still shown, got %d" % filled)
	var memberButton = tab._memberButtons["walker"]
	check(memberButton.icon != null and memberButton.text == "", "party member buttons use an icon instead of text")
	check(memberButton.tooltip_text == "Walker Langley", "party member icon keeps the name as tooltip")
	check(memberButton.custom_minimum_size.x <= 28.0, "party member button stays compact")


func providerPreviewCalls() -> Array:
	return provider.previewCalls


func providerEquipCalls() -> Array:
	return provider.equipCalls


func providerDropCalls() -> Array:
	return provider.dropCalls


func _selectionEquipmentSlot() -> String:
	return tab._selectedEquipmentSlot

