extends Control

## Persistent vendor modal (Docs/System Design/Location Vendors Implementation.md,
## patches 3-4). The shell owns pause/music/focus, the per-kind views, selection,
## quantity, confirmations and command dispatch. Prices, stock and money always
## come from Vendors/Party snapshots, so UI totals stay display-only and every
## command re-resolves its own vendor/offer/item id.

signal opened(vendorId: String)
signal closed(vendorId: String)

const ItemStatsScene = preload("res://Nodes/Item Stats/ItemStats.tscn")
const VendorItemRowScene = preload("res://UI/Vendors/VendorItemRow.tscn")
const ZoneCatalogScript = preload("res://Overworld/OverworldZoneCatalog.gd")

## Vendor kinds with a sell side (see Data/Vendors/VendorCatalog.gd).
const SELL_KINDS := ["gun", "equipment"]
const BANK_KIND := "bank"
const NEWSPAPER_KIND := "newspaper"
## Only these item types trade in more than one copy at a time.
const STACKABLE_TYPES := ["consumable", "resources"]
const SHOP_MAX_QUANTITY := 9999

const STATE_UNAVAILABLE := "Vendor data unavailable."
const STATE_EMPTY_STOCK := "Nothing in stock."
const STATE_EMPTY_SELL := "You have nothing to sell here."
const STATE_NO_REPORTS := "This paper has no reports yet."
const STATE_OPEN_FAILED := "This vendor is unavailable."
const REASON_TEXT := {
	"data_unavailable": STATE_UNAVAILABLE,
	"vendor_unavailable": STATE_OPEN_FAILED,
	"unknown_vendor": STATE_OPEN_FAILED,
	"invalid_vendor": "This vendor does not trade that.",
	"command_in_progress": "A transaction is already running.",
	"invalid_price": "That price is invalid.",
	"invalid_quantity": "Choose a valid quantity.",
	"invalid_item": "That item is invalid.",
	"insufficient_money": "Not enough money.",
	"insufficient_capacity": "Not enough space.",
	"unknown_offer": "That offer is gone.",
	"unknown_item": "That item is gone.",
	"not_equipment": "Only gear can be stored.",
	"wrong_item_type": "This store buys other gear.",
	"not_sellable": "That item cannot be sold.",
	"duplicate_instance_id": "You already carry that item.",
	"already_owned": "You already carry that map.",
	"already_revealed": "That map is already fully revealed.",
	"already_stored": "That item is already stored.",
	"management_unavailable": "Inventory changes are unavailable here.",
	"missing_base_value": "That item has no value data.",
	"invalid_map": "That map is invalid.",
}

## Injectable for tests; production resolves /root/Vendors.
var vendorProvider: Node = null
## Injectable for tests; production resolves /root/MusicPlayer.
var musicProvider = null
## Shared modal/pause coordinator, injected by SceneManager.
var pauseCoordinator = null

var isOpen := false
var vendorId := ""

var _kind := ""
var _view := ""
var _shopTab := "buy"
var _selectedId := ""
var _rowsById := {}
var _rowOrder := []
var _previousOrder := []
var _quantity := 1
var _quantityMax := 1
var _commandInProgress := false
var _musicPushed := false
var _connectedProvider: Node = null
var _confirmInstanceId := ""

var _itemStats: NinePatchRect = null
var _bankItemStats: NinePatchRect = null
## Last successful header snapshot (money/capacity for display bounds only).
var _headerSnapshot := {}

@onready var titleLabel: Label = $Center/Panel/Margin/Layout/Header/Title
@onready var moneyLabel: Label = $Center/Panel/Margin/Layout/Header/Money
@onready var capacityLabel: Label = $Center/Panel/Margin/Layout/Header/Capacity
@onready var closeButton: Button = $Center/Panel/Margin/Layout/Header/CloseButton
@onready var statusLabel: Label = $Center/Panel/Margin/Layout/Status
@onready var shopView: Control = $Center/Panel/Margin/Layout/Content/ShopView
@onready var tabs: TabBar = $Center/Panel/Margin/Layout/Content/ShopView/Tabs
@onready var rowList: VBoxContainer = $Center/Panel/Margin/Layout/Content/ShopView/ListScroll/RowList
@onready var shopEmptyLabel: Label = $Center/Panel/Margin/Layout/Content/ShopView/ShopEmpty
@onready var detailHost: MarginContainer = $Center/Panel/Margin/Layout/Content/ShopView/DetailHost
@onready var decrementButton: Button = $Center/Panel/Margin/Layout/Content/ShopView/ActionsMargin/Actions/DecrementButton
@onready var quantityLabel: Label = $Center/Panel/Margin/Layout/Content/ShopView/ActionsMargin/Actions/QuantityLabel
@onready var incrementButton: Button = $Center/Panel/Margin/Layout/Content/ShopView/ActionsMargin/Actions/IncrementButton
@onready var totalLabel: Label = $Center/Panel/Margin/Layout/Content/ShopView/ActionsMargin/Actions/TotalLabel
@onready var actionButton: Button = $Center/Panel/Margin/Layout/Content/ShopView/ActionsMargin/Actions/ActionButton
@onready var bankView: Control = $Center/Panel/Margin/Layout/Content/BankView
@onready var carriedList: VBoxContainer = $Center/Panel/Margin/Layout/Content/BankView/CarriedScroll/CarriedList
@onready var storedList: VBoxContainer = $Center/Panel/Margin/Layout/Content/BankView/StoredScroll/StoredList
@onready var bankEmptyLabel: Label = $Center/Panel/Margin/Layout/Content/BankView/BankEmpty
@onready var bankDetailHost: MarginContainer = $Center/Panel/Margin/Layout/Content/BankView/BankDetailHost
@onready var depositButton: Button = $Center/Panel/Margin/Layout/Content/BankView/ActionsMargin/Actions/DepositButton
@onready var withdrawButton: Button = $Center/Panel/Margin/Layout/Content/BankView/ActionsMargin/Actions/WithdrawButton
@onready var newspaperView: Control = $Center/Panel/Margin/Layout/Content/NewspaperView
@onready var zoneLabel: Label = $Center/Panel/Margin/Layout/Content/NewspaperView/ZoneLabel
@onready var headlineLabel: Label = $Center/Panel/Margin/Layout/Content/NewspaperView/HeadlineLabel
@onready var reportBody: VBoxContainer = $Center/Panel/Margin/Layout/Content/NewspaperView/ReportScroll/ReportBody
@onready var confirmationOverlay: Control = $ConfirmationOverlay
@onready var confirmTitle: Label = $ConfirmationOverlay/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmLayout/ConfirmTitle
@onready var confirmBody: Label = $ConfirmationOverlay/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmLayout/ConfirmBody
@onready var confirmCancelButton: Button = $ConfirmationOverlay/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmLayout/ConfirmActions/CancelButton
@onready var confirmButton: Button = $ConfirmationOverlay/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmLayout/ConfirmActions/ConfirmButton


func _ready() -> void:
	visible = false
	tabs.add_tab("Buy")
	tabs.add_tab("Sell")
	tabs.tab_changed.connect(_onShopTabChanged)
	closeButton.pressed.connect(close)
	actionButton.pressed.connect(_onActionPressed)
	depositButton.pressed.connect(_onDepositPressed)
	withdrawButton.pressed.connect(_onWithdrawPressed)
	decrementButton.pressed.connect(_onDecrementPressed)
	incrementButton.pressed.connect(_onIncrementPressed)
	confirmCancelButton.pressed.connect(_onConfirmCancelled)
	confirmButton.pressed.connect(_onConfirmPressed)
	_itemStats = ItemStatsScene.instantiate()
	_itemStats.allowNameTruncation = false
	_itemStats.visible = false
	detailHost.add_child(_itemStats)
	_bankItemStats = ItemStatsScene.instantiate()
	_bankItemStats.allowNameTruncation = false
	_bankItemStats.visible = false
	bankDetailHost.add_child(_bankItemStats)
	_showView("")


func open(id: String) -> bool:
	if isOpen:
		return false
	var vendor = _vendorDefinition(id)
	if vendor.is_empty():
		return false
	vendorId = id
	_kind = str(vendor.get("kind", ""))
	_view = ""
	_shopTab = "buy"
	_select("")
	_previousOrder = []
	isOpen = true
	visible = true
	titleLabel.text = str(vendor.get("displayName", id))
	_setStatus("")
	tabs.visible = SELL_KINDS.has(_kind)
	tabs.current_tab = 0
	_connectProvider(_resolveProvider())
	refresh()
	_acquirePause()
	_pushMusic()
	_grabInitialFocus()
	opened.emit(vendorId)
	return true


func close() -> void:
	if !isOpen:
		return
	var closedId := vendorId
	_closeConfirmation(false)
	isOpen = false
	visible = false
	vendorId = ""
	_kind = ""
	_view = ""
	_select("")
	_rowsById = {}
	_rowOrder = []
	_showView("")
	_disconnectProvider()
	var focusOwner := get_viewport().gui_get_focus_owner()
	if focusOwner != null:
		focusOwner.release_focus()
	_popMusic()
	_releasePause()
	closed.emit(closedId)


func _unhandled_input(event: InputEvent) -> void:
	if !isOpen:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if confirmationOverlay.visible:
			_onConfirmCancelled()
		else:
			close()
		return
	if event.is_action_pressed("TOGGLE_JOURNAL"):
		get_viewport().set_input_as_handled()
		close()


## The control the menu hands focus to when the modal opens (also used by tests).
func getFocusTarget() -> Control:
	var row := _rowControl(_selectedId)
	if row != null:
		return row
	if _view == BANK_KIND:
		return depositButton
	return closeButton


## Rebuilds the current view from fresh domain snapshots. Signals may arrive
## while a command runs; those refreshes are ignored and the command caller
## refreshes once it returns, so a double activation cannot act on a stale row.
func refresh() -> void:
	if !isOpen or _commandInProgress:
		return
	var provider := _resolveProvider()
	if provider == null:
		_showView("")
		_setStatus(STATE_UNAVAILABLE)
		return
	if _kind == BANK_KIND:
		_refreshBank(provider)
	elif _kind == NEWSPAPER_KIND:
		_refreshNewspaper(provider)
	else:
		_refreshShop(provider)
	_wireFocusNeighbours()


func _refreshHeader(snapshot: Dictionary) -> void:
	_headerSnapshot = snapshot
	moneyLabel.text = "Money: %d" % int(snapshot.get("money", 0))
	capacityLabel.text = "%d/%d" % [int(snapshot.get("used", 0)), int(snapshot.get("capacity", 0))]


func _refreshShop(provider: Node) -> void:
	var snapshot = provider.getVendorSnapshot(vendorId)
	if !(snapshot is Dictionary) or !bool(snapshot.get("success", false)):
		_showView("")
		_setStatus(_reasonText(_reasonOf(snapshot)))
		return
	_view = "shop"
	_showView("shop")
	_refreshHeader(snapshot)
	var shopTab := _shopTab if SELL_KINDS.has(_kind) else "buy"
	var rows = []
	if shopTab == "buy":
		shopEmptyLabel.text = STATE_EMPTY_STOCK
		for offerValue in snapshot.get("offers", []):
			if offerValue is Dictionary:
				rows.append(_offerRow(offerValue))
	else:
		shopEmptyLabel.text = STATE_EMPTY_SELL
		for entryValue in snapshot.get("eligibleSell", []):
			if entryValue is Dictionary:
				rows.append(_sellRow(entryValue, false))
		for entryValue in snapshot.get("unavailableSell", []):
			if entryValue is Dictionary:
				rows.append(_sellRow(entryValue, true))
	_rebuildRows(rowList, rows)
	actionButton.text = "Sell" if shopTab == "sell" else "Buy"


## display-only row for a fixed or rolled offer.
func _offerRow(offer: Dictionary) -> Dictionary:
	var item = offer.get("item", {})
	if !(item is Dictionary):
		item = {}
	var available := bool(offer.get("available", true))
	return {
		"id": str(offer.get("offerId", "")),
		"section": "offer",
		"name": _itemName(item),
		"detail": _itemDetail(item),
		"price": str(int(offer.get("unitPrice", 0))),
		"disabled": !available,
		"reason": _reasonText(str(offer.get("reason", ""))),
		"item": item.duplicate(true),
		"unitPrice": int(offer.get("unitPrice", 0)),
		"stackable": _isStackable(item),
	}


## display-only row for a sellable or refused carried gear instance.
func _sellRow(entry: Dictionary, unavailable: bool) -> Dictionary:
	var item = entry.get("item", {})
	if !(item is Dictionary):
		item = {}
	return {
		"id": str(entry.get("instanceId", "")),
		"section": "sell",
		"name": _itemName(item),
		"detail": _itemDetail(item),
		"price": str(int(entry.get("salePrice", 0))),
		"disabled": unavailable,
		"reason": _reasonText(str(entry.get("reason", ""))),
		"item": item.duplicate(true),
		"unitPrice": int(entry.get("salePrice", 0)),
		"stackable": false,
	}


func _itemName(item: Dictionary) -> String:
	return str(item.get("name", item.get("definitionId", "?")))


func _itemDetail(item: Dictionary) -> String:
	var itemType := str(item.get("itemType", ""))
	match itemType:
		"weapon":
			return str(item.get("family", "")).capitalize()
		"equipment":
			return str(item.get("slot", "")).capitalize()
		"map":
			return "Map"
	return str(item.get("category", itemType)).capitalize()


## Only stackable consumables/resources trade in multiple copies; maps and gear
## are always one copy per purchase (the domain rejects other quantities).
func _isStackable(item: Dictionary) -> bool:
	if !STACKABLE_TYPES.has(str(item.get("itemType", ""))):
		return false
	return int(item.get("stackLimit", 1)) > 1


## Display bound for the quantity stepper: what the player can afford and what
## the remaining slots can hold. Party still validates the real purchase.
func _maxPurchaseQuantity(row: Dictionary) -> int:
	var unitPrice := int(row.get("unitPrice", 0))
	if unitPrice <= 0:
		return 1
	var affordable := SHOP_MAX_QUANTITY
	if typeof(_headerSnapshot.get("money", null)) == TYPE_INT:
		affordable = int(_headerSnapshot["money"]) / unitPrice
	var capacity := int(_headerSnapshot.get("capacity", 0))
	var used := int(_headerSnapshot.get("used", 0))
	var stackLimit := maxi(1, int(row.get("item", {}).get("stackLimit", 1)))
	var space := maxi(0, capacity - used) * stackLimit
	return clampi(mini(affordable, maxi(space, 1)), 1, SHOP_MAX_QUANTITY)


func _reasonOf(value) -> String:
	if value is Dictionary:
		return str(value.get("reason", "data_unavailable"))
	return "data_unavailable"


## --- Rows and selection -------------------------------------------------------

func _rebuildRows(list: VBoxContainer, rows: Array, reset := true) -> void:
	if reset:
		_previousOrder = _rowOrder.duplicate()
		_rowOrder = []
		_rowsById = {}
	for child in list.get_children():
		list.remove_child(child)
		child.free()
	for rowValue in rows:
		var row: Dictionary = rowValue
		var rowId := str(row.get("id", ""))
		if rowId == "" or _rowsById.has(rowId):
			continue
		_rowsById[rowId] = row
		_rowOrder.append(rowId)
		var control = VendorItemRowScene.instantiate()
		control.displayRow(row)
		control.toggled.connect(_onRowToggled.bind(control))
		list.add_child(control)
	_finishRows()


## One list may be rebuilt while another keeps its rows (BankView), so the
## registry reset is explicit and the shared finishing step runs once per list.
func _finishRows() -> void:
	_reconcileSelection()
	_renderSelection()
	_updateEmptyStates()
	_updateActions()


## The newspaper view has no rows; drop any left over from a previous vendor so
## a view switch never keeps stale selectable controls alive.
func _clearRowLists() -> void:
	for list in [rowList, carriedList, storedList]:
		_clearChildren(list)
	_rowsById = {}
	_rowOrder = []
	_previousOrder = []
	_selectedId = ""


func _updateEmptyStates() -> void:
	rowList.visible = rowList.get_child_count() > 0
	shopEmptyLabel.visible = !rowList.visible
	bankEmptyLabel.visible = carriedList.get_child_count() == 0 and storedList.get_child_count() == 0


func _updateActions() -> void:
	if _view == BANK_KIND:
		_updateBankActions()
		return
	_updateShopActions()


## Selection follows a stable id: the same id, else the row at the previous
## index, else the one before it, else nothing.
func _reconcileSelection() -> void:
	if _rowOrder.is_empty():
		_selectedId = ""
		return
	if _rowsById.has(_selectedId):
		return
	var previousIndex = _previousOrder.find(_selectedId)
	if previousIndex < 0:
		_selectedId = _rowOrder[0]
		return
	_selectedId = _rowOrder[mini(previousIndex, _rowOrder.size() - 1)]


func _select(id: String) -> void:
	_selectedId = id
	_quantity = 1
	_renderSelection()
	_updateActions()


func _renderSelection() -> void:
	var control = _rowControl(_selectedId)
	if control != null and control.disabled:
		control = null
	for rowId in _rowsById:
		var candidate = _rowControl(rowId)
		if candidate != null:
			candidate.button_pressed = candidate == control
	_renderDetail()


func _renderDetail() -> void:
	var row := _rowFor(_selectedId)
	var stats = _bankItemStats if _view == BANK_KIND else _itemStats
	if stats == null:
		return
	if row.is_empty():
		stats.visible = false
		return
	stats.visible = true
	stats.displayItem(row.get("item", {}))


func _onRowToggled(pressed: bool, control) -> void:
	if !pressed or control == null or control.disabled:
		return
	_select(control.rowId)


func _rowFor(rowId: String) -> Dictionary:
	if !_rowsById.has(rowId):
		return {}
	var row = _rowsById[rowId]
	return row if row is Dictionary else {}


func _rowControl(rowId: String) -> Button:
	if rowId == "":
		return null
	for list in [rowList, carriedList, storedList]:
		for child in list.get_children():
			if child is Button and child.rowId == rowId:
				return child
	return null


func _onShopTabChanged(index: int) -> void:
	var tab := "buy" if index <= 0 else "sell"
	if tab == _shopTab:
		return
	_shopTab = tab
	_select("")
	_previousOrder = []
	refresh()


func _updateShopActions() -> void:
	if _view != "shop":
		return
	var row := _rowFor(_selectedId)
	var selectable := !row.is_empty() and !bool(row.get("disabled", false))
	if str(row.get("section", "")) == "sell":
		_quantity = 1
		_quantityMax = 1
		totalLabel.text = ("Sell for %d" % int(row.get("unitPrice", 0))) if selectable else ""
	else:
		var stackable := bool(row.get("stackable", false))
		_quantityMax = _maxPurchaseQuantity(row) if stackable else 1
		_quantity = clampi(_quantity, 1, maxi(1, _quantityMax))
		totalLabel.text = _totalText(row, stackable) if selectable else ""
	quantityLabel.text = str(_quantity)
	decrementButton.disabled = _quantity <= 1
	incrementButton.disabled = _quantity >= _quantityMax
	actionButton.disabled = !selectable or _commandInProgress


func _totalText(row: Dictionary, stackable: bool) -> String:
	var unit := int(row.get("unitPrice", 0))
	if !stackable:
		return "%d" % unit
	return "%d x %d = %d" % [_quantity, unit, _quantity * unit]


func _onDecrementPressed() -> void:
	_quantity = maxi(1, _quantity - 1)
	_updateShopActions()


func _onIncrementPressed() -> void:
	_quantity = mini(_quantityMax, _quantity + 1)
	_updateShopActions()


## --- Bank ---------------------------------------------------------------------

func _refreshBank(provider: Node) -> void:
	var snapshot = provider.getBankSnapshot()
	if !(snapshot is Dictionary) or !bool(snapshot.get("success", false)):
		_showView("")
		_setStatus(_reasonText(_reasonOf(snapshot)))
		return
	_view = BANK_KIND
	_showView(BANK_KIND)
	_refreshHeader(snapshot)
	var carried = []
	for itemValue in snapshot.get("carried", []):
		carried.append(_bankRow(itemValue, "carried"))
	var stored = []
	for itemValue in snapshot.get("bank", []):
		stored.append(_bankRow(itemValue, "stored"))
	_rebuildRows(carriedList, carried)
	_rebuildRows(storedList, stored, false)


func _bankRow(itemValue, section: String) -> Dictionary:
	var item: Dictionary = itemValue if itemValue is Dictionary else {}
	return {
		"id": str(item.get("instanceId", "")),
		"section": section,
		"name": _itemName(item),
		"detail": _itemDetail(item),
		"price": "",
		"disabled": false,
		"reason": "",
		"item": item.duplicate(true),
		"unitPrice": 0,
		"stackable": false,
	}


func _updateBankActions() -> void:
	var row := _rowFor(_selectedId)
	var section := str(row.get("section", ""))
	depositButton.disabled = section != "carried" or row.is_empty() or _commandInProgress
	withdrawButton.disabled = section != "stored" or row.is_empty() or _commandInProgress


## --- Newspaper ----------------------------------------------------------------

func _refreshNewspaper(provider: Node) -> void:
	_view = NEWSPAPER_KIND
	_showView(NEWSPAPER_KIND)
	_clearRowLists()
	zoneLabel.text = _zoneDisplayName()
	headlineLabel.text = ""
	_clearChildren(reportBody)
	var report = provider.getNewspaperReport(vendorId) if provider.has_method("getNewspaperReport") else {}
	var available := report is Dictionary and bool(report.get("success", false)) and bool(report.get("available", false))
	if !available:
		var reason := _reasonOf(report)
		_setStatus(STATE_NO_REPORTS if reason == "data_unavailable" or reason == "no_pool" or reason == "no_copy" else _reasonText(reason))
		return
	_setStatus("")
	headlineLabel.text = str(report.get("headline", ""))
	_addReportLine(str(report.get("editorial", "")), true)
	for partyValue in report.get("parties", []):
		if !(partyValue is Dictionary):
			continue
		_addReportLine("%s (%s)" % [
			str(partyValue.get("name", "")),
			str(partyValue.get("kind", "")).capitalize(),
		], true)
		for unitValue in partyValue.get("composition", []):
			if !(unitValue is Dictionary):
				continue
			var classText := str(unitValue.get("characterClass", ""))
			_addReportLine("  %d x %s%s" % [
				int(unitValue.get("count", 0)),
				str(unitValue.get("actorName", "")),
				"" if classText == "" else " (%s)" % classText,
			])
		var damageTypes = partyValue.get("damageTypes", [])
		if damageTypes is Array and !damageTypes.is_empty():
			_addReportLine("  Damage: %s" % ", ".join(_stringList(damageTypes)))
		for tipValue in partyValue.get("mechanics", []):
			_addReportLine("  - %s" % str(tipValue), true)
	var generalTips = report.get("generalTips", [])
	if generalTips is Array and !generalTips.is_empty():
		_addReportLine("Local wisdom", true)
		for tipValue in generalTips:
			_addReportLine("- %s" % str(tipValue), true)


func _stringList(values) -> Array:
	var strings := []
	if values is Array:
		for value in values:
			strings.append(str(value))
	return strings


func _zoneDisplayName() -> String:
	var zoneId := str(_vendorDefinition(vendorId).get("zoneId", ""))
	if zoneId == "":
		return ""
	return ZoneCatalogScript.new().displayName(zoneId)


## --- Commands -----------------------------------------------------------------

func _onActionPressed() -> void:
	if _commandInProgress:
		return
	var row := _rowFor(_selectedId)
	if row.is_empty() or bool(row.get("disabled", false)):
		return
	if str(row.get("section", "")) == "sell":
		_openSaleConfirmation(row)
		return
	if str(row.get("section", "")) == "offer":
		_buy(row)


func _onDepositPressed() -> void:
	var row := _rowFor(_selectedId)
	if str(row.get("section", "")) != "carried":
		return
	_runCommand("deposit", str(row.get("id", "")), "Stored.")


func _onWithdrawPressed() -> void:
	var row := _rowFor(_selectedId)
	if str(row.get("section", "")) != "stored":
		return
	_runCommand("withdraw", str(row.get("id", "")), "Withdrawn.")


func _buy(row: Dictionary) -> void:
	var provider := _resolveProvider()
	if provider == null or !provider.has_method("buy"):
		_setStatus(STATE_UNAVAILABLE)
		return
	var quantity := _quantity
	_commandInProgress = true
	var result = provider.buy(vendorId, str(row.get("id", "")), quantity)
	_commandInProgress = false
	if result is Dictionary and bool(result.get("success", false)):
		_setStatus("Bought %d for %d." % [quantity, int(result.get("totalPrice", 0))])
	else:
		_setStatus(_reasonText(_reasonOf(result)))
	refresh()


## Bank transfers use the same guarded, id-based command path as purchases.
func _runCommand(method: String, instanceId: String, successText: String) -> void:
	if _commandInProgress or instanceId == "":
		return
	var provider := _resolveProvider()
	if provider == null or !provider.has_method(method):
		_setStatus(STATE_UNAVAILABLE)
		return
	_commandInProgress = true
	var result = provider.call(method, instanceId)
	_commandInProgress = false
	if result is Dictionary and bool(result.get("success", false)):
		_setStatus(successText)
	else:
		_setStatus(_reasonText(_reasonOf(result)))
	refresh()
	_restoreFocus()


## --- Sale confirmation --------------------------------------------------------

func _openSaleConfirmation(row: Dictionary) -> void:
	_confirmInstanceId = str(row.get("id", ""))
	if _confirmInstanceId == "":
		return
	confirmationOverlay.visible = true
	confirmTitle.text = "Sell this item?"
	confirmBody.text = "%s\nProceeds: %d" % [str(row.get("name", "")), int(row.get("unitPrice", 0))]
	confirmCancelButton.grab_focus()


func _onConfirmPressed() -> void:
	if _commandInProgress or _confirmInstanceId == "":
		return
	var instanceId := _confirmInstanceId
	var provider := _resolveProvider()
	var result = null
	_commandInProgress = true
	if provider != null and provider.has_method("sell"):
		result = provider.sell(vendorId, instanceId)
	_commandInProgress = false
	_closeConfirmation(false)
	if result is Dictionary and bool(result.get("success", false)):
		_setStatus("Sold for %d." % int(result.get("salePrice", 0)))
	else:
		_setStatus(_reasonText(_reasonOf(result)))
	refresh()
	_restoreFocus()


func _onConfirmCancelled() -> void:
	_closeConfirmation(true)


func _closeConfirmation(restoreFocus: bool) -> void:
	confirmationOverlay.visible = false
	_confirmInstanceId = ""
	if restoreFocus and is_inside_tree():
		call_deferred("_restoreFocus")


## --- Focus, provider and modal ownership --------------------------------------

func _grabInitialFocus() -> void:
	var target := getFocusTarget()
	if target != null:
		target.grab_focus()


func _restoreFocus() -> void:
	if !isOpen:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and is_instance_valid(owner) and owner.is_visible_in_tree():
		return
	_grabInitialFocus()


## Explicit focus wiring: rows connect to the tabs/close button above them and to
## the primary action below them, so traversal never depends on hover.
func _wireFocusNeighbours() -> void:
	var rows := _rowControls()
	var entry: Control = tabs if tabs.visible else closeButton
	var action: Button = _primaryActionButton()
	if rows.is_empty():
		if action != null:
			action.focus_neighbor_top = action.get_path_to(entry)
		entry.focus_neighbor_bottom = NodePath()
		return
	entry.focus_neighbor_bottom = entry.get_path_to(rows[0])
	for index in rows.size():
		var row: Control = rows[index]
		row.focus_neighbor_top = row.get_path_to(rows[index - 1] if index > 0 else entry)
		row.focus_neighbor_bottom = row.get_path_to(rows[index + 1] if index + 1 < rows.size() else action)
	if action != null:
		action.focus_neighbor_top = action.get_path_to(rows[rows.size() - 1])


func _rowControls() -> Array:
	var controls := []
	for list in [rowList, carriedList, storedList]:
		for child in list.get_children():
			if child is Button and !child.disabled:
				controls.append(child)
	return controls


func _primaryActionButton() -> Button:
	if _view == BANK_KIND:
		return depositButton if str(_rowFor(_selectedId).get("section", "")) == "carried" else withdrawButton
	return actionButton


func _resolveProvider() -> Node:
	if vendorProvider != null:
		return vendorProvider
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Vendors")


func _vendorDefinition(id: String) -> Dictionary:
	var provider := _resolveProvider()
	if provider == null or !provider.has_method("getVendorDefinition"):
		return {}
	var definition = provider.getVendorDefinition(id)
	return definition if definition is Dictionary else {}


func _connectProvider(provider: Node) -> void:
	if _connectedProvider == provider:
		return
	_disconnectProvider()
	if provider == null:
		return
	for signalName in ["vendorChanged", "bankChanged", "departureStockChanged"]:
		if provider.has_signal(signalName):
			var callback := Callable(self, "_onProviderChanged")
			if !provider.is_connected(signalName, callback):
				provider.connect(signalName, callback)
	_connectedProvider = provider


func _disconnectProvider() -> void:
	if _connectedProvider == null:
		return
	for signalName in ["vendorChanged", "bankChanged", "departureStockChanged"]:
		var callback := Callable(self, "_onProviderChanged")
		if _connectedProvider.has_signal(signalName) and _connectedProvider.is_connected(signalName, callback):
			_connectedProvider.disconnect(signalName, callback)
	_connectedProvider = null


func _onProviderChanged(_value = null) -> void:
	refresh()


func _showView(view: String) -> void:
	shopView.visible = view == "shop"
	bankView.visible = view == BANK_KIND
	newspaperView.visible = view == NEWSPAPER_KIND


func _setStatus(text: String) -> void:
	statusLabel.text = text


func _reasonText(reason: String) -> String:
	if reason == "":
		return ""
	return str(REASON_TEXT.get(reason, "That action could not be completed."))


## Report lines wrap so long copy stays readable inside the scroll view.
func _addReportLine(text: String, wrap := false) -> void:
	if text == "":
		return
	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		line.custom_minimum_size = Vector2(0, 20)
	reportBody.add_child(line)


func _clearChildren(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func _resolveMusicProvider() -> Node:
	if musicProvider != null:
		return musicProvider
	if !is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("MusicPlayer")


func _acquirePause() -> void:
	if pauseCoordinator != null:
		pauseCoordinator.acquirePause(self)


func _releasePause() -> void:
	if pauseCoordinator != null:
		pauseCoordinator.releasePause(self)


func _pushMusic() -> void:
	if _musicPushed:
		return
	var provider := _resolveMusicProvider()
	if provider == null or !provider.has_method("push_music"):
		return
	var tracks = provider.shop_tracks() if provider.has_method("shop_tracks") else []
	provider.push_music(tracks)
	_musicPushed = true


func _popMusic() -> void:
	if !_musicPushed:
		return
	var provider := _resolveMusicProvider()
	if provider != null and provider.has_method("pop_music"):
		provider.pop_music()
	_musicPushed = false


func _exit_tree() -> void:
	if !isOpen:
		return
	isOpen = false
	_popMusic()
	_releasePause()



