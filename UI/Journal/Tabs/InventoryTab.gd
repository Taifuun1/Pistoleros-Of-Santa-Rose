extends JournalTab

## Journal Inventory & Equipment tab (Docs/System Design/Journal/Inventory and
## Equipment.md, patch 4). Reads authoritative snapshots through an injectable
## provider and mutates only through equip/drop commands. It never reads Party
## internals or other tabs through node paths.

const ItemSlotScene = preload("res://UI/Journal/ItemSlotButton.tscn")
const ItemStatsScene = preload("res://Nodes/Item Stats/ItemStats.tscn")
const TextScene = preload("res://UI/RichTextLabel Extended 8px/RichTextLabelExtended8px.tscn")
const PartyMemberArtScript = preload("res://UI/Journal/PartyMemberArt.gd")

const STATE_UNAVAILABLE := "Inventory data unavailable"
const STATE_NO_MEMBERS := "No party members"
const STATE_SELECT_PROMPT := "Select an item or equipment slot."
const STATE_EMPTY_SLOT := "Empty %s slot."
const STATE_EQUIPMENT_ONLY := "Equipment can only be equipped from inventory."
const STATE_EQUIPPED_NO_DROP := "Equipped items cannot be dropped."

const EQUIPMENT_SLOTS = ["weapon", "headwear", "bandana", "duster", "belt", "trousers", "justins"]
const SLOT_LABELS = {
	"weapon": "Weapon", "headwear": "Headwear", "bandana": "Bandana",
	"duster": "Duster", "belt": "Belt", "trousers": "Trousers", "justins": "Justins",
}
## Empty equipment cells show the greyed slot art the Shootout HUD uses
## (Docs/System Design/Shootout/Shootout UI.md). There is no bandana art yet, so
## that slot falls back to the placeholder icon.
const SLOT_ICONS = {
	"weapon": preload("res://Assets/Icons/RevolverIconGrey.png"),
	"headwear": preload("res://Assets/Icons/HatIconGrey.png"),
	"bandana": preload("res://Assets/Icons/PlaceholderIcon.png"),
	"duster": preload("res://Assets/Icons/JacketIconGrey.png"),
	"belt": preload("res://Assets/Icons/BeltIconGrey.png"),
	"trousers": preload("res://Assets/Icons/TrousersIconGrey.png"),
	"justins": preload("res://Assets/Icons/BootsIconGrey.png"),
}
## One row of small cells: seven slots fit the panel width, which leaves the
## inventory grid the height the seven text slots used to take in two rows. The
## cell is 30x28 so a 28x24 weapon sprite still fits at its native scale (a 26px
## cell clipped the widest art).
const EQUIPMENT_SLOT_SIZE = Vector2(30, 28)
const MEMBER_BUTTON_SIZE = Vector2(28, 28)
const REASON_TEXT = {
	"data_unavailable": STATE_UNAVAILABLE,
	"management_unavailable": "Inventory management is unavailable here.",
	"unknown_member": "That party member is unavailable.",
	"unknown_item": "That item is no longer in the inventory.",
	"not_equipment": STATE_EQUIPMENT_ONLY,
	"invalid_quantity": "Choose a valid quantity.",
	"not_droppable": "That item cannot be dropped.",
	"belt_loadout_too_large": "That belt cannot hold the current belt loadout.",
	"move_grant_lost": "That swap would remove an active equipped Move.",
	"belt_full": "That belt is full.",
	"not_consumable": "Only consumables can go on a belt.",
	"exceeds_owned": "Not enough of that item is carried.",
	"unknown_reservation": "That item is not assigned to this belt.",
	"already_revealed": "This map is already fully revealed.",
	"already_owned": "You already carry an unused copy of this map.",
	"invalid_map": "This map cannot be used.",
	"invalid_target": "This map's destination is unavailable.",
	"wrong_item_type": "That item cannot be used here.",
	"command_in_progress": "Another action is already running.",
}

const SUPPORTED_USE_ITEM_TYPE := "map"
const SUPPORTED_USE_EFFECT := "reveal_map"
const STATE_USE_UNAVAILABLE := "That item has no use outside combat."

## Provider Node contract: isInventoryDataAvailable(), getInventorySnapshot(),
## getEquipmentPreview(memberKey, instanceId), equipItem(...), dropItem(...),
## getBeltSnapshot(memberKey), reserveBeltItem(...), unreserveBeltItem(...),
## inventoryChanged and equipmentChanged(memberKey). Null resolves /root/Party.
var inventoryProvider: Node = null
## Out-of-combat item use (map reveals). Null resolves /root/Discovery; a later
## general item-use service can replace it without moving reveal state here.
var itemUseProvider: Node = null

var _snapshot: Dictionary = {}
var _membersByKey: Dictionary = {}
var _itemsById: Dictionary = {}
var _itemOrder: Array = []
var _previousItemOrder: Array = []
var _selectedMemberKey := ""
var _selectedInstanceId := ""
var _selectedEquipmentSlot := ""
var _selectionSource := ""
var _connectedProvider: Node = null
var _inventoryButtons: Dictionary = {}
var _equipmentButtons: Dictionary = {}
var _memberButtons: Dictionary = {}
var _itemStats: NinePatchRect = null
var _dropInstanceId := ""
var _dropQuantity := 0
var _dropMaximum := 0
var _dropInFlight := false
var _useInstanceId := ""
var _useInFlight := false
var _commandInProgress := false
var _focusWasInside := false
var _focusKind := ""
var _focusAction := ""
var _inventoryScrollValue := 0
var _detailScrollValue := 0

@onready var contentView: Control = $ContentView
@onready var memberScroll: ScrollContainer = $ContentView/LeftPanel/LeftMargin/LeftLayout/MemberScroll
@onready var memberButtons: Control = $ContentView/LeftPanel/LeftMargin/LeftLayout/MemberScroll/MemberButtons
@onready var equipmentGrid: GridContainer = $ContentView/LeftPanel/LeftMargin/LeftLayout/EquipmentGrid
@onready var capacityText = $ContentView/LeftPanel/LeftMargin/LeftLayout/InventoryHeader/CapacityText
@onready var inventoryScroll: ScrollContainer = $ContentView/LeftPanel/LeftMargin/LeftLayout/InventoryScroll
@onready var inventoryGrid: GridContainer = $ContentView/LeftPanel/LeftMargin/LeftLayout/InventoryScroll/InventoryGrid
@onready var emptyInventoryLabel = $ContentView/LeftPanel/LeftMargin/LeftLayout/EmptyInventoryLabel
@onready var memberStatsLabel = $ContentView/RightPanel/RightMargin/RightLayout/MemberStatsLabel
@onready var detailScroll: ScrollContainer = $ContentView/RightPanel/RightMargin/RightLayout/DetailScroll
@onready var itemStatsHost: Control = $ContentView/RightPanel/RightMargin/RightLayout/DetailScroll/DetailContent/ItemStatsHost
@onready var selectionLabel = $ContentView/RightPanel/RightMargin/RightLayout/DetailScroll/DetailContent/SelectionLabel
@onready var comparisonRows: Control = $ContentView/RightPanel/RightMargin/RightLayout/DetailScroll/DetailContent/ComparisonRows
@onready var feedbackLabel = $ContentView/RightPanel/RightMargin/RightLayout/FeedbackLabel
@onready var equipButton: Button = $ContentView/RightPanel/RightMargin/RightLayout/Actions/EquipButton
@onready var useButton: Button = $ContentView/RightPanel/RightMargin/RightLayout/Actions/UseButton
@onready var beltButton: Button = $ContentView/RightPanel/RightMargin/RightLayout/Actions/BeltButton
@onready var dropButton: Button = $ContentView/RightPanel/RightMargin/RightLayout/Actions/DropButton
@onready var dropOverlay: Control = $DropOverlay
@onready var dropItemLabel = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/DropItemLabel
@onready var decrementButton: Button = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/QuantityRow/DecrementButton
@onready var quantityLabel = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/QuantityRow/QuantityLabel
@onready var incrementButton: Button = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/QuantityRow/IncrementButton
@onready var allButton: Button = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/QuantityRow/AllButton
@onready var cancelDropButton: Button = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/DropActions/CancelButton
@onready var confirmDropButton: Button = $DropOverlay/DropCenter/DropPanel/DropMargin/DropLayout/DropActions/ConfirmButton
@onready var useOverlay: Control = $UseOverlay
@onready var useItemLabel = $UseOverlay/UseCenter/UsePanel/UseMargin/UseLayout/UseItemLabel
@onready var cancelUseButton: Button = $UseOverlay/UseCenter/UsePanel/UseMargin/UseLayout/UseActions/CancelUseButton
@onready var confirmUseButton: Button = $UseOverlay/UseCenter/UsePanel/UseMargin/UseLayout/UseActions/ConfirmUseButton
@onready var stateView: Control = $StateView
@onready var stateTabSprite: TabSprite = $StateView/StateLayout/StateTabSprite
@onready var stateMessageLabel = $StateView/StateLayout/StateMessageLabel


func _ready() -> void:
	stateTabSprite.tabIcon = tabIcon
	# Shared label scenes carry their own placeholder text ("ABOBA!"); every label
	# that starts empty is cleared here so it cannot show through before the tab
	# writes real content.
	for label in [capacityText, emptyInventoryLabel, memberStatsLabel, selectionLabel, feedbackLabel, dropItemLabel, quantityLabel, useItemLabel]:
		label.setRichTextLabel("")
	_itemStats = ItemStatsScene.instantiate()
	_itemStats.allowNameTruncation = false
	# The card holds the placeholder too and only shows real item details.
	_itemStats.visible = false
	itemStatsHost.add_child(_itemStats)
	equipButton.pressed.connect(_onEquipPressed)
	useButton.pressed.connect(_onUsePressed)
	beltButton.pressed.connect(_onBeltPressed)
	dropButton.pressed.connect(_onDropPressed)
	decrementButton.pressed.connect(_onDecrementPressed)
	incrementButton.pressed.connect(_onIncrementPressed)
	allButton.pressed.connect(_onAllPressed)
	cancelDropButton.pressed.connect(_onDropCancelled)
	confirmDropButton.pressed.connect(_onDropConfirmed)
	cancelUseButton.pressed.connect(_onUseCancelled)
	confirmUseButton.pressed.connect(_onUseConfirmed)
	_showStateMessage(STATE_UNAVAILABLE)


func refreshTab() -> void:
	_captureViewState()
	var provider := _resolveInventoryProvider()
	if active:
		_connectProvider(provider)
	else:
		_disconnectProvider()
	if !_providerCanRead(provider):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	if !bool(provider.isInventoryDataAvailable()):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	var snapshotValue = provider.getInventorySnapshot()
	if !(snapshotValue is Dictionary) or !_normalizeSnapshot(snapshotValue):
		_clearView()
		_showStateMessage(STATE_UNAVAILABLE)
		return
	_rebuildViews()
	_showContent()
	_restoreViewState()


func setTabActive(tabActive: bool) -> void:
	super.setTabActive(tabActive)
	if tabActive:
		_connectProvider(_resolveInventoryProvider())
	else:
		_closeDropOverlay(false)
		closeUseOverlayIfVisible()
		_disconnectProvider()


func getFocusTarget() -> Control:
	var memberButton: Button = _memberButtons.get(_selectedMemberKey, null)
	if memberButton != null and memberButton.is_visible_in_tree():
		return memberButton
	for instanceId in _inventoryButtons:
		var inventoryButton: Button = _inventoryButtons[instanceId]
		if inventoryButton.is_visible_in_tree() and !inventoryButton.disabled:
			return inventoryButton
	for slot in EQUIPMENT_SLOTS:
		var equipmentButton: Button = _equipmentButtons.get(slot, null)
		if equipmentButton != null and equipmentButton.is_visible_in_tree():
			return equipmentButton
	return null


func canCloseTab() -> bool:
	return !dropOverlay.visible and !useOverlay.visible


func _exit_tree() -> void:
	_disconnectProvider()

func _resolveInventoryProvider() -> Node:
	if inventoryProvider != null:
		return inventoryProvider
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Party")


func _providerCanRead(provider: Node) -> bool:
	return provider != null and provider.has_method("isInventoryDataAvailable") and provider.has_method("getInventorySnapshot")


func _connectProvider(provider: Node) -> void:
	if _connectedProvider == provider:
		return
	_disconnectProvider()
	if provider == null:
		return
	for signalName in ["inventoryChanged", "equipmentChanged"]:
		if provider.has_signal(signalName):
			var callback := Callable(self, "_onProviderChanged")
			if !provider.is_connected(signalName, callback):
				provider.connect(signalName, callback)
	_connectedProvider = provider


func _disconnectProvider() -> void:
	if _connectedProvider == null:
		return
	for signalName in ["inventoryChanged", "equipmentChanged"]:
		var callback := Callable(self, "_onProviderChanged")
		if _connectedProvider.has_signal(signalName) and _connectedProvider.is_connected(signalName, callback):
			_connectedProvider.disconnect(signalName, callback)
	_connectedProvider = null


func _onProviderChanged(_value = null) -> void:
	if active and !_commandInProgress:
		refreshTab()


func _normalizeSnapshot(value: Dictionary) -> bool:
	if !(value.get("items", null) is Array) or !(value.get("members", null) is Array):
		return false
	if int(value.get("capacity", 0)) <= 0:
		return false
	_snapshot = value.duplicate(true)
	_previousItemOrder = _itemOrder.duplicate()
	_membersByKey = {}
	_itemsById = {}
	_itemOrder = []
	for memberValue in _snapshot.members:
		if !(memberValue is Dictionary):
			push_warning("Inventory tab: ignored a non-Dictionary member.")
			continue
		var member = memberValue as Dictionary
		var memberKey = str(member.get("key", ""))
		if memberKey == "":
			continue
		if !(member.get("equipment", {}) is Dictionary):
			member["equipment"] = {}
		if !(member.get("fightData", {}) is Dictionary):
			member["fightData"] = {}
		if !(member.get("belt", {}) is Dictionary):
			member["belt"] = { "entries": [] }
		if !(member.belt.get("entries", null) is Array):
			member.belt["entries"] = []
		_membersByKey[memberKey] = member
	for itemValue in _snapshot.items:
		if !(itemValue is Dictionary):
			push_warning("Inventory tab: ignored a non-Dictionary item.")
			continue
		var item = itemValue as Dictionary
		var instanceId = str(item.get("instanceId", ""))
		if instanceId == "":
			continue
		_itemsById[instanceId] = item
		_itemOrder.append(instanceId)
	_snapshot["members"] = _membersByKey.values()
	_snapshot["items"] = _itemsById.values()
	return true


func _rebuildViews() -> void:
	_reconcileMemberSelection()
	_reconcileItemSelection()
	_buildMemberButtons()
	_buildEquipmentSlots()
	_buildInventorySlots()
	_renderMemberSummary()
	_renderDetail()


func _reconcileMemberSelection() -> void:
	if _membersByKey.is_empty():
		_selectedMemberKey = ""
		return
	if !_membersByKey.has(_selectedMemberKey):
		_selectedMemberKey = str(_membersByKey.keys()[0])


func _reconcileItemSelection() -> void:
	if _selectionSource == "inventory":
		if _itemsById.has(_selectedInstanceId):
			return
		var previousIndex = _previousItemOrder.find(_selectedInstanceId)
		_selectionSource = ""
		_selectedInstanceId = ""
		if previousIndex < 0 or _itemOrder.is_empty():
			return
		# Nearest remaining occupied cell: the same index, else the one before it.
		var fallbackIndex = mini(previousIndex, _itemOrder.size() - 1)
		_selectionSource = "inventory"
		_selectedInstanceId = _itemOrder[fallbackIndex]
	elif _selectionSource == "equipment":
		var equipment = _selectedMember().get("equipment", {})
		if equipment is Dictionary and equipment.get(_selectedEquipmentSlot, null) is Dictionary:
			return
		_selectionSource = ""
		_selectedEquipmentSlot = ""
	else:
		_selectedInstanceId = ""
		_selectedEquipmentSlot = ""



func _selectedMember() -> Dictionary:
	return _membersByKey.get(_selectedMemberKey, {})


func _buildMemberButtons() -> void:
	_clearChildren(memberButtons)
	_memberButtons = {}
	var group := ButtonGroup.new()
	for memberKey in _membersByKey:
		var member = _membersByKey[memberKey]
		var actorName = str(member.get("actorName", memberKey))
		var button := Button.new()
		button.custom_minimum_size = MEMBER_BUTTON_SIZE
		button.icon = _memberIcon(actorName)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.button_pressed = memberKey == _selectedMemberKey
		button.tooltip_text = actorName
		button.pressed.connect(_onMemberPressed.bind(str(memberKey)))
		memberButtons.add_child(button)
		_memberButtons[str(memberKey)] = button


## Portrait lookup is shared with the Character tab (PartyMemberArt.gd).
func _memberIcon(actorName: String) -> Texture2D:
	return PartyMemberArtScript.textureForActorName(actorName)


func _buildEquipmentSlots() -> void:
	_clearChildren(equipmentGrid)
	_equipmentButtons = {}
	if _selectedMemberKey == "":
		return
	var equipment = _selectedMember().get("equipment", {})
	if !(equipment is Dictionary):
		equipment = {}
	var group := ButtonGroup.new()
	for slot in EQUIPMENT_SLOTS:
		var button: ItemSlotButton = ItemSlotScene.instantiate()
		var item = equipment.get(slot, null)
		button.custom_minimum_size = EQUIPMENT_SLOT_SIZE
		button.displayItem(item if item is Dictionary else {}, SLOT_LABELS[slot], SLOT_ICONS.get(slot, null))
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("slot", slot)
		button.tooltip_text = SLOT_LABELS[slot] if !(item is Dictionary) else "%s: %s" % [SLOT_LABELS[slot], str(item.get("name", ""))]
		button.pressed.connect(_onEquipmentSlotPressed.bind(slot))
		equipmentGrid.add_child(button)
		_equipmentButtons[slot] = button
		if _selectionSource == "equipment" and _selectedEquipmentSlot == slot:
			button.button_pressed = true


func _buildInventorySlots() -> void:
	_clearChildren(inventoryGrid)
	_inventoryButtons = {}
	var group := ButtonGroup.new()
	var items: Array = _snapshot.get("items", [])
	for itemValue in items:
		var item = itemValue as Dictionary
		var instanceId = str(item.get("instanceId", ""))
		var button: ItemSlotButton = ItemSlotScene.instantiate()
		button.displayItem(item)
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("instanceId", instanceId)
		button.pressed.connect(_onInventoryItemPressed.bind(instanceId))
		inventoryGrid.add_child(button)
		_inventoryButtons[instanceId] = button
		if _selectionSource == "inventory" and _selectedInstanceId == instanceId:
			button.button_pressed = true
	var capacity = int(_snapshot.get("capacity", 0))
	for index in maxi(0, capacity - items.size()):
		var empty: ItemSlotButton = ItemSlotScene.instantiate()
		empty.displayItem({}, "")
		empty.disabled = true
		empty.focus_mode = Control.FOCUS_NONE
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventoryGrid.add_child(empty)
	capacityText.setRichTextLabel("%d / %d" % [items.size(), capacity])
	emptyInventoryLabel.visible = items.is_empty()
	_wireFocusNeighbours()


func _renderMemberSummary() -> void:
	if _selectedMemberKey == "":
		memberStatsLabel.setRichTextLabel(STATE_NO_MEMBERS)
		return
	var fightData = _selectedMember().get("fightData", {})
	if !(fightData is Dictionary) or fightData.is_empty():
		memberStatsLabel.setRichTextLabel("Stats unavailable")
		return
	var stats = fightData.get("stats", {})
	var defense = stats.get("defense", {}) if stats is Dictionary else {}
	var beltSpace = int(fightData.get("beltSpace", -1))
	var beltText = "unlimited" if beltSpace < 0 else str(beltSpace)
	var beltUsed = int(_selectedMember().get("belt", {}).get("used", 0))
	memberStatsLabel.setRichTextLabel("HP %d/%d | Six %d | High %d | Taffy %d | Style %d | Sand %d | Belt %d/%s" % [
		int(fightData.get("hp", 0)), int(fightData.get("maxHp", 0)),
		int(stats.get("sixShootin", 0)) if stats is Dictionary else 0,
		int(stats.get("highTailin", 0)) if stats is Dictionary else 0,
		int(stats.get("taffyin", 0)) if stats is Dictionary else 0,
		int(defense.get("style", 0)) if defense is Dictionary else 0,
		int(defense.get("sand", 0)) if defense is Dictionary else 0,
		beltUsed,
		beltText,
	])


func _renderDetail() -> void:
	_clearChildren(comparisonRows)
	_itemStats.visible = false
	equipButton.disabled = true
	dropButton.disabled = true
	useButton.visible = false
	useButton.disabled = true
	beltButton.visible = false
	beltButton.disabled = true
	equipButton.tooltip_text = ""
	dropButton.tooltip_text = ""
	useButton.tooltip_text = ""
	beltButton.tooltip_text = ""
	if _selectedMemberKey == "":
		selectionLabel.setRichTextLabel(STATE_NO_MEMBERS)
		return
	if _selectionSource == "equipment":
		_renderEquipmentDetail()
		return
	if _selectionSource == "inventory" and _itemsById.has(_selectedInstanceId):
		_renderInventoryDetail(_itemsById[_selectedInstanceId])
		return
	selectionLabel.setRichTextLabel(STATE_SELECT_PROMPT)

func _renderInventoryDetail(item: Dictionary) -> void:
	_showItemDetails(item)
	var itemType = str(item.get("itemType", ""))
	var isGear = itemType in ["weapon", "equipment"]
	# Use appears only for items with a supported out-of-combat effect.
	var useSupported := _isUseSupported(item)
	useButton.visible = useSupported
	useButton.disabled = !useSupported or !bool(_snapshot.get("managementAllowed", false))
	useButton.tooltip_text = ("Use %s" % str(item.get("name", ""))) if useSupported else ""
	var stackLimit = int(item.get("stackLimit", 1))
	var quantity = int(item.get("quantity", 1))
	if quantity > 1 or stackLimit > 1:
		selectionLabel.appendRichTextLabel("\nQuantity %d / %d" % [quantity, stackLimit])
	var managementAllowed = bool(_snapshot.get("managementAllowed", false))
	dropButton.disabled = !managementAllowed or !bool(item.get("droppable", false))
	dropButton.tooltip_text = "" if !dropButton.disabled else (
		REASON_TEXT["management_unavailable"] if !managementAllowed else REASON_TEXT["not_droppable"]
	)
	_renderBeltAction(item, managementAllowed)
	if !isGear:
		selectionLabel.appendRichTextLabel("\n" + STATE_EQUIPMENT_ONLY)
		equipButton.tooltip_text = STATE_EQUIPMENT_ONLY
		feedbackLabel.setRichTextLabel(STATE_EQUIPMENT_ONLY)
		return
	var provider := _resolveInventoryProvider()
	if provider == null or !provider.has_method("getEquipmentPreview"):
		feedbackLabel.setRichTextLabel(STATE_UNAVAILABLE)
		return
	var previewValue = provider.getEquipmentPreview(_selectedMemberKey, _selectedInstanceId)
	if !(previewValue is Dictionary) or !bool(previewValue.get("success", false)):
		var reason = str(previewValue.get("reason", "data_unavailable")) if previewValue is Dictionary else "data_unavailable"
		equipButton.tooltip_text = _reasonText(reason)
		feedbackLabel.setRichTextLabel(_reasonText(reason))
		return
	_renderComparison(previewValue.get("deltas", []))
	var beltValid = bool(previewValue.get("beltValid", false))
	var moveValid = bool(previewValue.get("moveValid", true))
	equipButton.disabled = !managementAllowed or !beltValid or !moveValid
	if !managementAllowed:
		equipButton.tooltip_text = REASON_TEXT["management_unavailable"]
		feedbackLabel.setRichTextLabel(REASON_TEXT["management_unavailable"])
	elif !beltValid:
		equipButton.tooltip_text = REASON_TEXT["belt_loadout_too_large"]
		feedbackLabel.setRichTextLabel(REASON_TEXT["belt_loadout_too_large"])
	elif !moveValid:
		equipButton.tooltip_text = REASON_TEXT["move_grant_lost"]
		feedbackLabel.setRichTextLabel(REASON_TEXT["move_grant_lost"])
	else:
		equipButton.tooltip_text = "Equip to %s" % _selectedMember().get("actorName", _selectedMemberKey)
		feedbackLabel.setRichTextLabel("")


## Minimal belt assignment (commit 3): one button assigns/removes the selected
## consumable for the selected member. Belt space and quantity validation stay in
## the Party command.
func _renderBeltAction(item: Dictionary, managementAllowed: bool) -> void:
	if str(item.get("itemType", "")) != "consumable" or str(item.get("combatId", "")) == "":
		return
	beltButton.visible = true
	var entry := _beltEntryFor(_selectedInstanceId)
	if entry.is_empty():
		beltButton.text = "To Belt"
		beltButton.tooltip_text = "Assign %s to this member's belt." % str(item.get("name", ""))
	else:
		beltButton.text = "From Belt"
		beltButton.tooltip_text = "%d reserved. Remove %s from this belt." % [
			int(entry.get("quantity", 0)), str(item.get("name", ""))
		]
		selectionLabel.appendRichTextLabel("\nBelt: %d reserved." % int(entry.get("quantity", 0)))
	beltButton.disabled = !managementAllowed
	if !managementAllowed:
		beltButton.tooltip_text = REASON_TEXT["management_unavailable"]


func _beltEntryFor(instanceId: String) -> Dictionary:
	var belt = _selectedMember().get("belt", {})
	if !(belt is Dictionary):
		return {}
	for entryValue in belt.get("entries", []):
		if entryValue is Dictionary and str(entryValue.get("instanceId", "")) == instanceId:
			return entryValue
	return {}


func _onBeltPressed() -> void:
	if _selectionSource != "inventory" or !_itemsById.has(_selectedInstanceId):
		return
	var provider := _resolveInventoryProvider()
	if provider == null or !provider.has_method("reserveBeltItem") or !provider.has_method("unreserveBeltItem"):
		feedbackLabel.setRichTextLabel(STATE_UNAVAILABLE)
		return
	_commandInProgress = true
	var result = {}
	if _beltEntryFor(_selectedInstanceId).is_empty():
		result = provider.reserveBeltItem(_selectedMemberKey, _selectedInstanceId, 1)
	else:
		result = provider.unreserveBeltItem(_selectedMemberKey, _selectedInstanceId)
	_commandInProgress = false
	if result is Dictionary and bool(result.get("success", false)):
		refreshTab()
		feedbackLabel.setRichTextLabel("Removed from belt." if _beltEntryFor(_selectedInstanceId).is_empty() else "Assigned to belt.")
	else:
		var reason = str(result.get("reason", "data_unavailable")) if result is Dictionary else "data_unavailable"
		feedbackLabel.setRichTextLabel(_reasonText(reason))


func _renderEquipmentDetail() -> void:
	var equipment = _selectedMember().get("equipment", {})
	var item = equipment.get(_selectedEquipmentSlot, null) if equipment is Dictionary else null
	if !(item is Dictionary):
		selectionLabel.setRichTextLabel(STATE_EMPTY_SLOT % SLOT_LABELS.get(_selectedEquipmentSlot, _selectedEquipmentSlot))
		equipButton.tooltip_text = "Select equipment in inventory."
		dropButton.tooltip_text = STATE_EQUIPPED_NO_DROP
		feedbackLabel.setRichTextLabel(STATE_EQUIPPED_NO_DROP)
		return
	_showItemDetails(item)
	selectionLabel.appendRichTextLabel("\nEquipped in %s." % SLOT_LABELS.get(_selectedEquipmentSlot, _selectedEquipmentSlot))
	equipButton.tooltip_text = "Select equipment in inventory."
	dropButton.tooltip_text = STATE_EQUIPPED_NO_DROP
	feedbackLabel.setRichTextLabel(STATE_EQUIPPED_NO_DROP)


func _showItemDetails(item: Dictionary) -> void:
	itemStatsHost.visible = true
	_itemStats.visible = true
	_itemStats.displayItem(item)
	# The card already shows the full name, so this line carries only the
	# category plus whatever the caller appends (quantity, equipped slot).
	var category = str(item.get("category", item.get("itemType", ""))).capitalize()
	selectionLabel.setRichTextLabel(category)


func _renderComparison(deltas: Array) -> void:
	_clearChildren(comparisonRows)
	if deltas.is_empty():
		var unchanged = TextScene.instantiate()
		unchanged.setRichTextLabel("No supported stat changes.")
		unchanged.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comparisonRows.add_child(unchanged)
		return
	for rowValue in deltas:
		if !(rowValue is Dictionary):
			continue
		var row = rowValue as Dictionary
		var line = TextScene.instantiate()
		if str(row.get("path", "")) == "weapon.weapon":
			line.setRichTextLabel("%s: %s -> %s" % [row.label, row.before, row.after])
		else:
			line.setRichTextLabel("%s: %s -> %s (%+d)" % [row.label, row.before, row.after, int(row.get("delta", 0))])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comparisonRows.add_child(line)


func _onEquipPressed() -> void:
	if _selectionSource != "inventory" or _selectedInstanceId == "":
		return
	var provider := _resolveInventoryProvider()
	if provider == null or !provider.has_method("equipItem"):
		feedbackLabel.setRichTextLabel(STATE_UNAVAILABLE)
		return
	_commandInProgress = true
	var result = provider.equipItem(_selectedMemberKey, _selectedInstanceId)
	_commandInProgress = false
	if result is Dictionary and bool(result.get("success", false)):
		_selectionSource = "equipment"
		_selectedEquipmentSlot = str(result.get("slot", ""))
		_selectedInstanceId = ""
		refreshTab()
		feedbackLabel.setRichTextLabel("Equipped.")
	else:
		var reason = str(result.get("reason", "data_unavailable")) if result is Dictionary else "data_unavailable"
		feedbackLabel.setRichTextLabel(_reasonText(reason))

func _onDropPressed() -> void:
	if _selectionSource != "inventory" or !_itemsById.has(_selectedInstanceId):
		return
	var item = _itemsById[_selectedInstanceId]
	if !bool(_snapshot.get("managementAllowed", false)):
		feedbackLabel.setRichTextLabel(REASON_TEXT["management_unavailable"])
		return
	if !bool(item.get("droppable", false)):
		feedbackLabel.setRichTextLabel(REASON_TEXT["not_droppable"])
		return
	_dropInstanceId = _selectedInstanceId
	_dropMaximum = int(item.get("quantity", 1))
	_dropQuantity = 1
	_dropInFlight = false
	dropItemLabel.setRichTextLabel("%s x%d" % [str(item.get("name", "")), _dropMaximum])
	dropOverlay.visible = true
	_updateDropQuantity()
	cancelDropButton.grab_focus()


func _onDecrementPressed() -> void:
	_dropQuantity = maxi(1, _dropQuantity - 1)
	_updateDropQuantity()


func _onIncrementPressed() -> void:
	_dropQuantity = mini(_dropMaximum, _dropQuantity + 1)
	_updateDropQuantity()


func _onAllPressed() -> void:
	_dropQuantity = _dropMaximum
	_updateDropQuantity()


func _updateDropQuantity() -> void:
	quantityLabel.setRichTextLabel(str(_dropQuantity))
	decrementButton.disabled = _dropQuantity <= 1
	incrementButton.disabled = _dropQuantity >= _dropMaximum
	allButton.disabled = _dropQuantity >= _dropMaximum


func _onDropConfirmed() -> void:
	if _dropInFlight or _dropInstanceId == "":
		return
	_dropInFlight = true
	var provider := _resolveInventoryProvider()
	if provider == null or !provider.has_method("dropItem"):
		feedbackLabel.setRichTextLabel(STATE_UNAVAILABLE)
		_closeDropOverlay(true)
		return
	var droppedQuantity = _dropQuantity
	var result = provider.dropItem(_dropInstanceId, _dropQuantity)
	if result is Dictionary and bool(result.get("success", false)):
		_closeDropOverlay(true)
		feedbackLabel.setRichTextLabel("Dropped %d." % int(result.get("quantity", droppedQuantity)))
	else:
		var reason = str(result.get("reason", "data_unavailable")) if result is Dictionary else "data_unavailable"
		feedbackLabel.setRichTextLabel(_reasonText(reason))
		_dropInFlight = false


func _onDropCancelled() -> void:
	_closeDropOverlay(true)


func _unhandled_input(event: InputEvent) -> void:
	if useOverlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_onUseCancelled()
		return
	if dropOverlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_onDropCancelled()


func _closeDropOverlay(restoreFocus: bool) -> void:
	var returnInstanceId = _dropInstanceId
	dropOverlay.visible = false
	_dropInFlight = false
	_dropInstanceId = ""
	_dropQuantity = 0
	_dropMaximum = 0
	if restoreFocus and is_inside_tree():
		if _itemsById.has(returnInstanceId):
			_selectionSource = "inventory"
			_selectedInstanceId = returnInstanceId
			_focusKind = "inventory"
			_focusWasInside = true
		call_deferred("_restoreFocus")


func _onMemberPressed(memberKey: String) -> void:
	if !_membersByKey.has(memberKey):
		return
	_selectedMemberKey = memberKey
	_selectedInstanceId = ""
	_selectedEquipmentSlot = ""
	_selectionSource = ""
	feedbackLabel.setRichTextLabel("")
	_buildEquipmentSlots()
	_buildInventorySlots()
	_renderMemberSummary()
	_renderDetail()


func _onEquipmentSlotPressed(slot: String) -> void:
	_selectionSource = "equipment"
	_selectedEquipmentSlot = slot
	_selectedInstanceId = ""
	feedbackLabel.setRichTextLabel("")
	_renderDetail()


func _onInventoryItemPressed(instanceId: String) -> void:
	if !_itemsById.has(instanceId):
		return
	_selectionSource = "inventory"
	_selectedInstanceId = instanceId
	_selectedEquipmentSlot = ""
	feedbackLabel.setRichTextLabel("")
	_renderDetail()


func _reasonText(reason: String) -> String:
	return str(REASON_TEXT.get(reason, "That action could not be completed."))


## An item is usable when it carries a supported out-of-combat effect; nothing
## else in the catalog qualifies yet.
func _isUseSupported(item: Dictionary) -> bool:
	if str(item.get("itemType", "")) != SUPPORTED_USE_ITEM_TYPE:
		return false
	var effect = item.get("effect", null)
	return effect is Dictionary and str(effect.get("kind", "")) == SUPPORTED_USE_EFFECT


func _resolveItemUseProvider() -> Node:
	if itemUseProvider != null:
		return itemUseProvider
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Discovery")


## The confirmation names the map's reveals and states that one copy is spent.
func _onUsePressed() -> void:
	if _selectionSource != "inventory" or !_itemsById.has(_selectedInstanceId):
		return
	var item = _itemsById[_selectedInstanceId]
	if !_isUseSupported(item):
		feedbackLabel.setRichTextLabel(STATE_USE_UNAVAILABLE)
		return
	if !bool(_snapshot.get("managementAllowed", false)):
		feedbackLabel.setRichTextLabel(REASON_TEXT["management_unavailable"])
		return
	var provider := _resolveItemUseProvider()
	if provider == null or !provider.has_method("useMap"):
		feedbackLabel.setRichTextLabel(STATE_UNAVAILABLE)
		return
	var preview = provider.getMapUsePreview(_selectedInstanceId) if provider.has_method("getMapUsePreview") else null
	if !(preview is Dictionary) or !bool(preview.get("success", false)):
		feedbackLabel.setRichTextLabel(_reasonText(str(preview.get("reason", "data_unavailable")) if preview is Dictionary else "data_unavailable"))
		return
	_useInstanceId = _selectedInstanceId
	_useInFlight = false
	useItemLabel.setRichTextLabel("%s\nReveals: %s\nOne copy will be consumed." % [
		str(item.get("name", "")),
		", ".join(_stringList(preview.get("targetNames", []))),
	])
	useOverlay.visible = true
	cancelUseButton.grab_focus()


func _stringList(values) -> Array:
	var strings := []
	if values is Array:
		for value in values:
			strings.append(str(value))
	return strings


func _onUseConfirmed() -> void:
	if _useInFlight or _useInstanceId == "":
		return
	_useInFlight = true
	var provider := _resolveItemUseProvider()
	if provider == null or !provider.has_method("useMap"):
		feedbackLabel.setRichTextLabel(STATE_UNAVAILABLE)
		_closeUseOverlay(true)
		return
	var result = provider.useMap(_useInstanceId)
	if result is Dictionary and bool(result.get("success", false)):
		var revealed := _stringList(result.get("revealedIds", [])).size()
		_closeUseOverlay(true)
		feedbackLabel.setRichTextLabel("Map used: %d destination%s revealed." % [revealed, "" if revealed == 1 else "s"])
	else:
		var reason = str(result.get("reason", "data_unavailable")) if result is Dictionary else "data_unavailable"
		feedbackLabel.setRichTextLabel(_reasonText(reason))
		_useInFlight = false


func _onUseCancelled() -> void:
	_closeUseOverlay(true)


func _closeUseOverlay(restoreFocus: bool) -> void:
	useOverlay.visible = false
	_useInFlight = false
	_useInstanceId = ""
	if restoreFocus and is_inside_tree():
		if _itemsById.has(_selectedInstanceId):
			_selectionSource = "inventory"
			_focusKind = "inventory"
			_focusWasInside = true
		call_deferred("_restoreFocus")


func closeUseOverlayIfVisible() -> void:
	if useOverlay.visible:
		_closeUseOverlay(false)

func _wireFocusNeighbours() -> void:
	var equipmentControls: Array = []
	for slot in EQUIPMENT_SLOTS:
		if _equipmentButtons.has(slot):
			equipmentControls.append(_equipmentButtons[slot])
	var inventoryControls: Array = []
	for instanceId in _inventoryButtons:
		inventoryControls.append(_inventoryButtons[instanceId])
	for equipmentControl in equipmentControls:
		if !inventoryControls.is_empty():
			equipmentControl.focus_neighbor_bottom = equipmentControl.get_path_to(inventoryControls[0])
	for memberKey in _memberButtons:
		var memberButton: Button = _memberButtons[memberKey]
		var downTarget: Control = equipmentControls[0] if !equipmentControls.is_empty() else (inventoryControls[0] if !inventoryControls.is_empty() else null)
		if downTarget != null:
			memberButton.focus_neighbor_bottom = memberButton.get_path_to(downTarget)
			downTarget.focus_neighbor_top = downTarget.get_path_to(memberButton)
	for index in inventoryControls.size():
		var button: Button = inventoryControls[index]
		if index - 6 >= 0:
			button.focus_neighbor_top = button.get_path_to(inventoryControls[index - 6])
		elif !equipmentControls.is_empty():
			button.focus_neighbor_top = button.get_path_to(equipmentControls[0])
		if index + 6 < inventoryControls.size():
			button.focus_neighbor_bottom = button.get_path_to(inventoryControls[index + 6])
		else:
			button.focus_neighbor_bottom = button.get_path_to(equipButton)
		if index % 6 > 0:
			button.focus_neighbor_left = button.get_path_to(inventoryControls[index - 1])
		if index % 6 < 5 and index + 1 < inventoryControls.size():
			button.focus_neighbor_right = button.get_path_to(inventoryControls[index + 1])
	equipButton.focus_neighbor_top = equipButton.get_path_to(detailScroll)
	useButton.focus_neighbor_top = useButton.get_path_to(detailScroll)
	dropButton.focus_neighbor_top = dropButton.get_path_to(detailScroll)
	# The action row's horizontal order depends on whether Use is shown for the
	# current selection.
	var actions: Array = []
	if useButton.visible:
		actions.append(useButton)
	if equipButton.visible:
		actions.append(equipButton)
	actions.append(dropButton)
	for index in actions.size():
		var action: Button = actions[index]
		action.focus_neighbor_left = action.get_path_to(actions[index - 1] if index > 0 else actions[actions.size() - 1])
		action.focus_neighbor_right = action.get_path_to(actions[index + 1] if index + 1 < actions.size() else actions[0])


func _captureViewState() -> void:
	_inventoryScrollValue = int(inventoryScroll.scroll_vertical)
	_detailScrollValue = int(detailScroll.scroll_vertical)
	_focusWasInside = _focusIsInsideTab()
	_focusKind = ""
	_focusAction = ""
	if !_focusWasInside:
		return
	var focusOwner := get_viewport().gui_get_focus_owner()
	if focusOwner == null:
		return
	for memberKey in _memberButtons:
		if _memberButtons[memberKey] == focusOwner:
			_focusKind = "member"
			return
	for slot in _equipmentButtons:
		if _equipmentButtons[slot] == focusOwner:
			_focusKind = "equipment"
			return
	for instanceId in _inventoryButtons:
		if _inventoryButtons[instanceId] == focusOwner:
			_focusKind = "inventory"
			return
	if focusOwner == equipButton or focusOwner == dropButton:
		_focusKind = "action"
		_focusAction = "equip" if focusOwner == equipButton else "drop"
	elif focusOwner == detailScroll or detailScroll.is_ancestor_of(focusOwner):
		_focusKind = "detail"


func _restoreViewState() -> void:
	inventoryScroll.scroll_vertical = _inventoryScrollValue
	detailScroll.scroll_vertical = _detailScrollValue
	call_deferred("_applyPendingViewState")


func _applyPendingViewState() -> void:
	inventoryScroll.scroll_vertical = _inventoryScrollValue
	detailScroll.scroll_vertical = _detailScrollValue
	if _focusWasInside and !dropOverlay.visible:
		_restoreFocus()
	_focusWasInside = false


func _restoreFocus() -> void:
	if !active or !is_inside_tree() or dropOverlay.visible:
		return
	match _focusKind:
		"member":
			var memberButton: Button = _memberButtons.get(_selectedMemberKey, null)
			if memberButton != null:
				memberButton.grab_focus()
				return
		"equipment":
			var equipmentButton: Button = _equipmentButtons.get(_selectedEquipmentSlot, null)
			if equipmentButton != null:
				equipmentButton.grab_focus()
				return
		"inventory":
			var inventoryButton: Button = _inventoryButtons.get(_selectedInstanceId, null)
			if inventoryButton != null:
				inventoryButton.grab_focus()
				return
		"action":
			var actionButton := equipButton if _focusAction == "equip" else dropButton
			if !actionButton.disabled:
				actionButton.grab_focus()
				return
		"detail":
			detailScroll.grab_focus()
			return
	var target := getFocusTarget()
	if target != null:
		target.grab_focus()


func _focusIsInsideTab() -> bool:
	if !is_inside_tree():
		return false
	var focusOwner := get_viewport().gui_get_focus_owner()
	return focusOwner != null and is_ancestor_of(focusOwner)


func _showStateMessage(message: String) -> void:
	contentView.visible = false
	stateView.visible = true
	stateMessageLabel.setRichTextLabel(message)
	stateTabSprite.tabIcon = tabIcon


func _showContent() -> void:
	stateView.visible = false
	contentView.visible = true


func _clearView() -> void:
	_clearChildren(memberButtons)
	_clearChildren(equipmentGrid)
	_clearChildren(inventoryGrid)
	_clearChildren(comparisonRows)
	_memberButtons = {}
	_equipmentButtons = {}
	_inventoryButtons = {}
	_membersByKey = {}
	_itemsById = {}
	_itemOrder = []
	_previousItemOrder = []
	_snapshot = {}
	_selectedMemberKey = ""
	_selectedInstanceId = ""
	_selectedEquipmentSlot = ""
	_selectionSource = ""
	itemStatsHost.visible = true
	_itemStats.visible = false
	selectionLabel.setRichTextLabel("")
	feedbackLabel.setRichTextLabel("")
	capacityText.setRichTextLabel("0 / 0")
	emptyInventoryLabel.visible = false
	closeDropOverlayIfVisible()


func _clearChildren(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func closeDropOverlayIfVisible() -> void:
	if dropOverlay.visible:
		_closeDropOverlay(false)
