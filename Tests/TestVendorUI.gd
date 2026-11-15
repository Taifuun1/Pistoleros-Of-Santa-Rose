extends Node

## Scene-run validation of the persistent VendorMenu (Docs/System Design/Location
## Vendors Implementation.md, patches 3-4): layer ownership, open policy,
## pause/music balancing, Journal exclusion, cancel/close, scene-change cleanup,
## and the shop/Bank/newspaper views driven by an injected vendor service.
## Run as TestVendorUI.tscn.

const SceneManagerScene = preload("res://Nodes/Scene Manager/SceneManager.tscn")
const VendorMenuScene = preload("res://UI/Vendors/VendorMenu.tscn")
const VendorsScript = preload("res://Globals/Vendors.gd")
const VendorCatalogScript = preload("res://Data/Vendors/VendorCatalog.gd")
const VendorPricingScript = preload("res://Data/Vendors/VendorPricing.gd")
const PartyScript = preload("res://Globals/Party.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")

const ROOM_SCENE := "res://UI/Journal/Journal.tscn"

var failures := 0
var sceneManager: Node
var journal: Control
var menu: Control
var music: FakeMusic
## Standalone menu driven by the injected fixture vendor service.
var shopMenu: Control
var context := {}


class FakeMusic:
	extends Node

	var pushes := 0
	var pops := 0

	func shop_tracks() -> Array:
		return ["town"]

	func push_music(_tracks) -> void:
		pushes += 1

	func pop_music() -> void:
		pops += 1


class FakeLocations:
	extends Node

	signal trailDeparted(departureId: int)

	var trailDepartureId := 0

	func departForTrail() -> int:
		trailDepartureId += 1
		trailDeparted.emit(trailDepartureId)
		return trailDepartureId

	func restoreTrailDepartureId(value: int) -> void:
		trailDepartureId = maxi(0, int(value))


func _ready() -> void:
	sceneManager = SceneManagerScene.instantiate()
	sceneManager.initialScene = ""
	add_child(sceneManager)
	journal = sceneManager.get_node("JournalLayer/Journal")
	menu = sceneManager.get_node("VendorLayer/VendorMenu")
	music = FakeMusic.new()
	menu.musicProvider = music
	shopMenu = VendorMenuScene.instantiate()
	add_child(shopMenu)
	context = _makeVendorContext()
	shopMenu.vendorProvider = context.vendors
	shopMenu.musicProvider = FakeMusic.new()
	await _run()

	shopMenu.free()
	_freeContext()
	sceneManager.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var realMusic = get_node_or_null("/root/MusicPlayer")
	if realMusic != null and realMusic.has_method("shutdown"):
		realMusic.shutdown()
	await get_tree().create_timer(0.1).timeout
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	get_tree().quit(failures)


func _run() -> void:
	await _testModalPolicy()
	await _testShopPurchase()
	await _testRolledStockAndSales()
	await _testBankFlow()
	await _testNewspaperView()
	await _testLabelHeights()
	await _testProductionGazette()


## The UI theme's 12px bitmap font draws glyphs ~19-22px tall while a bare Label
## sizes itself to the font's 12px line height, so labels need explicit height or
## their text is clipped. The action rows also keep their own padding.
func _testLabelHeights() -> void:
	print("\n--- Layout: text height and action padding ---")
	shopMenu.open("test_general")
	await get_tree().process_frame
	_check(shopMenu.titleLabel.size.y >= 20, "the vendor name label is tall enough for the bitmap font")
	_check(shopMenu.moneyLabel.size.y >= 20 and shopMenu.statusLabel.size.y >= 20, "header and status labels keep their text height")
	var row = shopMenu.rowList.get_child(0)
	var nameLabel: Label = row.get_node("Layout/Name") if row != null else null
	var priceLabel: Label = row.get_node("Layout/Price") if row != null else null
	_check(nameLabel != null and nameLabel.size.y >= 20, "item names keep their text height")
	_check(priceLabel != null and priceLabel.size.y >= 20, "row prices keep their text height")

	var actionsMargin := shopMenu.get_node("Center/Panel/Margin/Layout/Content/ShopView/ActionsMargin") as MarginContainer
	_check(actionsMargin != null, "shop actions sit inside their own margin container")
	if actionsMargin != null:
		var marginTop := actionsMargin.get_theme_constant("margin_top")
		var marginBottom := actionsMargin.get_theme_constant("margin_bottom")
		_check(marginTop >= 4 and marginBottom >= 4, "shop actions keep padding above and below")
		var actions: HBoxContainer = actionsMargin.get_node("Actions")
		_check(actions.get_theme_constant("separation") >= 6, "shop action buttons are separated")
	_check(shopMenu.actionButton.custom_minimum_size.x >= 72, "the buy/sell button has room for its label")
	_check(shopMenu.quantityLabel.size.y >= 20, "the quantity label keeps its text height")

	var panel := shopMenu.get_node("Center/Panel") as Control
	var panelMinimum := panel.get_combined_minimum_size()
	_check(panelMinimum.x <= 640 and panelMinimum.y <= 360, "the panel fits the 640x360 viewport (%s)" % panelMinimum)
	shopMenu.close()


func _testModalPolicy() -> void:
	print("--- VendorMenu open policy ---")
	sceneManager.currentSceneKey = "pregenerated_location"
	_check(!sceneManager.canOpenVendor(), "vendor menu cannot open outside a vendor room")
	_check(!sceneManager.openVendor("lazysprings_general"), "openVendor rejects the parent Location")
	_check(!menu.isOpen and !get_tree().paused, "rejected open leaves modal/pause closed")

	sceneManager.currentSceneKey = "vendor_room"
	_check(sceneManager.canOpenVendor(), "vendor menu is allowed in a vendor room")
	_check(sceneManager.openVendor("lazysprings_general"), "valid vendor opens")
	_check(menu.isOpen and menu.visible, "menu becomes open/visible")
	_check(menu.titleLabel.text == "Lazysprings General Store", "menu shows the vendor display name")
	_check(get_tree().paused, "open acquires the shared pause")
	_check(music.pushes == 1, "open pushes the shop soundtrack once")
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() != null and get_viewport().gui_get_focus_owner() == menu.getFocusTarget(), "open focuses the first interactive control")

	print("\n--- Journal exclusion ---")
	_check(!sceneManager.canOpenJournal(), "Journal is blocked while the vendor menu is open")
	sceneManager.toggleJournal()
	_check(!journal.isOpen, "toggleJournal is ignored while the vendor menu is open")
	sceneManager._unhandled_input(_actionEvent("TOGGLE_JOURNAL"))
	_check(menu.isOpen and !journal.isOpen, "SceneManager consumes the Journal toggle while vendor menu is open")
	menu._unhandled_input(_actionEvent("TOGGLE_JOURNAL"))
	_check(!menu.isOpen and music.pops == 1, "VendorMenu consumes TOGGLE_JOURNAL and pops its music")
	_check(!get_tree().paused, "closing restores the pause state")

	print("\n--- Cancel and repeated open/close ---")
	sceneManager.openVendor("lazysprings_general")
	menu._unhandled_input(_actionEvent("ui_cancel"))
	_check(!menu.isOpen and music.pushes == 2 and music.pops == 2, "ui_cancel closes and balances pause/music")
	for _index in 3:
		sceneManager.openVendor("lazysprings_general")
		menu.closeButton.pressed.emit()
	_check(!menu.isOpen and !get_tree().paused, "close button closes repeatedly without leaving pause behind")
	_check(music.pushes == music.pops, "every open is matched by exactly one music pop")

	print("\n--- External pause preservation ---")
	get_tree().paused = true
	sceneManager.openVendor("lazysprings_general")
	sceneManager.closeVendor()
	_check(get_tree().paused, "closing does not unpause an externally paused game")
	get_tree().paused = false

	print("\n--- Scene change cleanup ---")
	sceneManager.openVendor("lazysprings_general")
	_check(menu.isOpen and get_tree().paused, "menu is open before the transition")
	var pushesBefore = music.pushes
	var popsBefore = music.pops
	sceneManager.change_scene("main_menu")
	await sceneManager.scene_changed
	_check(!menu.isOpen and !menu.visible, "scene change closes the vendor menu")
	_check(!get_tree().paused, "scene change releases the vendor pause")
	_check(music.pushes == pushesBefore and music.pops == popsBefore + 1, "scene change pops the pushed soundtrack once")
	_check(sceneManager.currentSceneKey == "main_menu" and !sceneManager.canOpenJournal(), "main menu keeps both modals blocked")


func _actionEvent(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)


## Fixture vendor service: a real Party and item generator plus a fake Location
## service, so money/stock/departure behaviour is the production one.
func _makeVendorContext() -> Dictionary:
	var itemCatalog = ItemCatalogScript.new()
	var party = PartyScript.new()
	party.configureInventory(itemCatalog)
	party.inventory = []
	party._nextInstanceNumber = 1
	party.money = 200
	party.setInventoryManagementAllowed(true)
	var itemGenerator = ItemGenerationScript.new()
	var locations = FakeLocations.new()
	var catalog = VendorCatalogScript.new()
	catalog.vendors = _makeCatalogVendors()
	var vendors = VendorsScript.new()
	vendors.configure(catalog, party, itemGenerator, VendorPricingScript.new(), locations, 4242, null, itemCatalog)
	return {
		"vendors": vendors,
		"party": party,
		"itemGenerator": itemGenerator,
		"locations": locations,
	}


func _makeCatalogVendors() -> Dictionary:
	return {
		"test_general": {
			"vendorId": "test_general", "kind": "general", "displayName": "Test General",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "fixed", "offers": [
				{ "offerId": "paregoric", "definitionId": "paregoric", "unitPrice": 20 },
				{ "offerId": "canyon_cache_map", "definitionId": "canyon_cache_map", "unitPrice": 75 },
			] },
		},
		"test_gunsmith": {
			"vendorId": "test_gunsmith", "kind": "gun", "displayName": "Test Gunsmith",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
			"stock": { "mode": "rolled", "itemType": "weapon", "count": 4 },
		},
		"test_bank": {
			"vendorId": "test_bank", "kind": "bank", "displayName": "Test Bank",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
		},
		"test_news": {
			"vendorId": "test_news", "kind": "newspaper", "displayName": "Test Newspaper",
			"parentLocationId": "Lazysprings", "zoneId": "canyon", "roomScene": ROOM_SCENE,
		},
		"test_news_remote": {
			"vendorId": "test_news_remote", "kind": "newspaper", "displayName": "Test Remote Newspaper",
			"parentLocationId": "Lazysprings", "zoneId": "swamp", "roomScene": ROOM_SCENE,
		},
	}


func _freeContext() -> void:
	if context.is_empty():
		return
	context.vendors.free()
	context.locations.free()
	context.itemGenerator.free()
	context.party.free()
	context = {}


func _shopState() -> Dictionary:
	return {
		"money": context.party.money,
		"inventory": context.party.inventory.duplicate(true),
		"bank": context.vendors.getBankSnapshot().get("bank", []),
		"offers": context.vendors.getVendorSnapshot("test_general").get("offers", []),
	}


func _addWeapon() -> String:
	var item = context.itemGenerator.generateWeapon({ "rarity": "common", "family": "revolver" })
	var result = context.party.addItem(item)
	var accepted = result.get("acceptedInstanceIds", []) if result is Dictionary else []
	if !(accepted is Array) or accepted.is_empty():
		return ""
	return str(accepted[0])


func _fillInventory() -> void:
	while context.party.inventory.size() < 24:
		context.party.inventory.append({
			"instanceId": "filler_%d" % context.party.inventory.size(),
			"definitionId": "paregoric", "itemType": "consumable", "quantity": 5,
		})


func _carriedWeaponCount() -> int:
	var count := 0
	for entry in context.party.inventory:
		if entry is Dictionary and str(entry.get("itemType", "")) == "weapon":
			count += 1
	return count


func _testShopPurchase() -> void:
	print("\n--- Shop: fixed stackables, totals and failures ---")
	_check(shopMenu.open("test_general"), "the general store opens")
	_check(shopMenu.moneyLabel.text == "Money: 200", "the header shows Party money")
	_check(shopMenu.capacityLabel.text == "0/24", "the header shows inventory capacity")
	_check(!shopMenu.tabs.visible, "general stores show no Buy/Sell tabs")
	_check(shopMenu.rowList.get_child_count() == 2, "both fixed offers are listed")
	_check(shopMenu._selectedId == "paregoric", "the first offer is selected by stable id")
	_check(!shopMenu.actionButton.disabled, "the selected offer can be bought")
	_check(shopMenu.quantityLabel.text == "1", "quantity starts at one")
	_check(!shopMenu.incrementButton.disabled and shopMenu.decrementButton.disabled, "the stepper starts at its lower bound")
	shopMenu.incrementButton.pressed.emit()
	shopMenu.incrementButton.pressed.emit()
	_check(shopMenu.quantityLabel.text == "3", "the stepper increments")
	_check(shopMenu.totalLabel.text == "3 x 20 = 60", "the total multiplies the authoritative unit price")
	shopMenu.actionButton.pressed.emit()
	_check(context.party.money == 140, "buying three debits exactly 60")
	_check(shopMenu.statusLabel.text == "Bought 3 for 60.", "the status reports the accepted purchase")
	_check(context.party.inventory.size() == 1 and int(context.party.inventory[0].quantity) == 3, "the purchased stack lands in Party inventory")
	_check(shopMenu.moneyLabel.text == "Money: 140", "the header refreshes after the purchase")

	print("\n--- Shop: failure text and single-copy offers ---")
	context.party.money = 0
	shopMenu.refresh()
	var beforeFailedBuy = _shopState()
	shopMenu.actionButton.pressed.emit()
	_check(shopMenu.statusLabel.text == "Not enough money.", "insufficient money maps to readable status text")
	_check(_shopState() == beforeFailedBuy, "a failed purchase changes no money, inventory or offers")
	context.party.money = 500
	shopMenu.refresh()
	var mapRow = shopMenu._rowFor("canyon_cache_map")
	_check(!bool(mapRow.get("stackable", true)), "map offers are not stackable")
	shopMenu._select("canyon_cache_map")
	_check(shopMenu.quantityLabel.text == "1" and shopMenu.incrementButton.disabled, "single-copy offers lock the quantity to one")
	_check(shopMenu.totalLabel.text == "75", "the single-copy total shows the unit price")
	shopMenu.actionButton.pressed.emit()
	_check(context.party.money == 425, "the map purchase debits its price")
	var mapOffer = {}
	for offer in context.vendors.getVendorSnapshot("test_general").get("offers", []):
		if str(offer.get("offerId", "")) == "canyon_cache_map":
			mapOffer = offer
	_check(str(mapOffer.get("reason", "")) == "already_owned" and !bool(mapOffer.get("available", true)), "a carried map offer is exhausted")
	shopMenu.refresh()
	var mapControl = shopMenu._rowControl("canyon_cache_map")
	_check(mapControl != null and mapControl.disabled, "the exhausted offer is listed disabled")
	shopMenu.close()


func _testRolledStockAndSales() -> void:
	print("\n--- Shop: rolled stock, sale quote and confirmation ---")
	context.party.money = 500
	_check(shopMenu.open("test_gunsmith"), "the gun store opens")
	_check(shopMenu.tabs.visible, "gun stores show the Buy/Sell tabs")
	_check(shopMenu._shopTab == "buy", "the shop starts on the Buy tab")
	_check(shopMenu.rowList.get_child_count() == 4, "rolled stock lists every generated offer")
	var offerId = shopMenu._selectedId
	var offerRow = shopMenu._rowFor(offerId)
	_check(offerId.begins_with("test_gunsmith:"), "rolled offers are selected by their composed id")
	_check(shopMenu.quantityLabel.text == "1" and shopMenu.incrementButton.disabled, "rolled gear locks the quantity to one")
	var unitPrice = int(offerRow.get("unitPrice", 0))
	shopMenu.actionButton.pressed.emit()
	_check(context.party.money == 500 - unitPrice, "the weapon costs its frozen offer price")
	_check(shopMenu.rowList.get_child_count() == 3, "the bought offer leaves the stock")
	_check(_carriedWeaponCount() == 1, "the weapon enters Party inventory")

	shopMenu.tabs.current_tab = 1
	_check(shopMenu._shopTab == "sell", "the Sell tab switches the list")
	_check(shopMenu.rowList.get_child_count() == 1, "the bought weapon is offered back for sale")
	var instanceId = shopMenu._selectedId
	var sellRow = shopMenu._rowFor(instanceId)
	var quote = int(sellRow.get("unitPrice", 0))
	_check(shopMenu.totalLabel.text == "Sell for %d" % quote, "the sale shows the recalculated quote")
	shopMenu.actionButton.pressed.emit()
	_check(shopMenu.confirmationOverlay.visible, "selling asks for confirmation first")
	_check(shopMenu.confirmBody.text.contains(str(sellRow.get("name", ""))), "the confirmation names the whole item")
	_check(shopMenu.confirmBody.text.contains(str(quote)), "the confirmation shows the exact proceeds")
	shopMenu.confirmCancelButton.pressed.emit()
	_check(!shopMenu.confirmationOverlay.visible, "cancel closes the confirmation")
	_check(_carriedWeaponCount() == 1, "cancel leaves the item carried")
	var moneyBefore = context.party.money
	shopMenu.actionButton.pressed.emit()
	shopMenu.confirmButton.pressed.emit()
	_check(context.party.money == moneyBefore + quote, "confirming credits the exact quote once")
	_check(_carriedWeaponCount() == 0, "the sold item leaves the inventory")
	_check(shopMenu.statusLabel.text == "Sold for %d." % quote, "the status reports the proceeds")
	_check(shopMenu.rowList.get_child_count() == 0 and shopMenu.shopEmptyLabel.visible, "the emptied sell list shows its empty state")
	shopMenu.tabs.current_tab = 0
	_check(shopMenu.rowList.get_child_count() == 3, "the Buy tab returns to the remaining stock")
	shopMenu.close()


func _testBankFlow() -> void:
	print("\n--- Bank: deposits, withdrawals and identity ---")
	context.party.inventory = []
	context.party._nextInstanceNumber = 1
	_check(shopMenu.open("test_bank"), "the bank opens")
	_check(shopMenu.carriedList.get_child_count() == 0 and shopMenu.storedList.get_child_count() == 0, "an empty Bank lists nothing")
	_check(shopMenu.bankEmptyLabel.visible, "the empty Bank state is visible")
	_check(shopMenu.depositButton.disabled and shopMenu.withdrawButton.disabled, "no transfer is enabled without a selection")
	shopMenu.close()

	var instanceId = _addWeapon()
	_check(instanceId != "", "the fixture weapon is carried")
	_check(shopMenu.open("test_bank"), "the bank reopens with carried gear")
	_check(shopMenu.moneyLabel.text == "Money: %d" % context.party.money, "the bank header shows money")
	_check(shopMenu.carriedList.get_child_count() == 1, "carried gear is listed")
	_check(shopMenu.storedList.get_child_count() == 0, "the shared Bank starts empty")
	_check(!shopMenu.depositButton.disabled and shopMenu.withdrawButton.disabled, "only the matching transfer is enabled")
	shopMenu.depositButton.pressed.emit()
	_check(context.party.inventory.is_empty(), "depositing removes the carried item")
	_check(context.vendors.getBankSnapshot().bank.size() == 1, "the Bank holds the item")
	_check(shopMenu.carriedList.get_child_count() == 0 and shopMenu.storedList.get_child_count() == 1, "both lists refresh")
	_check(shopMenu.statusLabel.text == "Stored.", "the status reports the deposit")
	shopMenu.withdrawButton.pressed.emit()
	_check(context.party.inventory.size() == 1 and str(context.party.inventory[0].instanceId) == instanceId, "withdrawing returns the same item id")
	_check(context.vendors.getBankSnapshot().bank.is_empty(), "the Bank is empty again")

	shopMenu.depositButton.pressed.emit()
	_fillInventory()
	shopMenu.withdrawButton.pressed.emit()
	_check(shopMenu.statusLabel.text == "Not enough space.", "a full inventory reports readable text")
	_check(context.vendors.getBankSnapshot().bank.size() == 1, "a failed withdrawal keeps the item stored")
	_check(!shopMenu.withdrawButton.disabled, "the bank buttons return to their idle state")
	context.party.inventory = []
	shopMenu.close()


func _testNewspaperView() -> void:
	print("\n--- Newspaper: published report and unavailable Zone ---")
	_check(shopMenu.open("test_news"), "the newspaper vendor opens")
	_check(shopMenu.newspaperView.visible and !shopMenu.shopView.visible and !shopMenu.bankView.visible, "only the newspaper view is shown")
	_check(shopMenu.zoneLabel.text == "Canyon", "the view names the vendor's Zone")
	_check(shopMenu.headlineLabel.text != "", "a published Zone shows its headline")
	var bodyText := _reportBodyText(shopMenu)
	_check(bodyText.contains("3 x Squeky rat"), "the report gives the enemy composition with counts")
	_check(bodyText.contains("Damage:"), "the report lists the damage types the enemies deal")
	_check(bodyText.contains("Local wisdom"), "the report ends with the general tips")
	_check(shopMenu.rowList.get_child_count() == 0 and shopMenu.statusLabel.text == "", "a published report shows no purchase controls or errors")
	shopMenu.close()

	_check(shopMenu.open("test_news_remote"), "a newspaper vendor in a Zone without a pool opens")
	_check(shopMenu.newspaperView.visible and shopMenu.headlineLabel.text == "", "an unpublished Zone fabricates no headline")
	_check(shopMenu.statusLabel.text == "This paper has no reports yet.", "an unpublished Zone reports the intentional unavailable state")
	_check(_reportBodyText(shopMenu) == "", "an unpublished Zone fabricates no report body")
	_check(shopMenu.closeButton != null, "Close stays available on the unavailable view")
	shopMenu.close()


func _reportBodyText(view) -> String:
	var lines := []
	for child in view.reportBody.get_children():
		if child is Label:
			lines.append((child as Label).text)
	return "\n".join(lines)


## The production vendor/autoload path: the real Vendors service resolves the
## authored pools and copy through the SceneManager-owned menu.
func _testProductionGazette() -> void:
	print("\n--- Production newspaper vendor ---")
	sceneManager.currentSceneKey = "vendor_room"
	_check(sceneManager.openVendor("lazysprings_gazette"), "the production gazette opens through the real vendor service")
	_check(menu.newspaperView.visible and menu.headlineLabel.text != "", "the real service renders the canyon report headline")
	var bodyText := _reportBodyText(menu)
	_check(bodyText.contains("Squeky rat"), "the real report names the authored enemy actor")
	_check(bodyText.contains("Local wisdom"), "the real report ends with the authored tips")
	_check(menu.statusLabel.text == "", "a published production report shows no error")
	menu.close()




