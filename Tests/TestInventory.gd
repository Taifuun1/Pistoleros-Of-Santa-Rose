extends SceneTree

## Headless validation for the inventory rules and Party commands
## (Docs/System Design/Journal/Inventory and Equipment.md, patch 2).
## Run with: godot --headless --script res://Tests/TestInventory.gd

const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const PartyScript = preload("res://Globals/Party.gd")

var failures = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog = ItemCatalogScript.new()
	var rules = InventoryRulesScript.new()
	testRules(catalog, rules)
	testParty(catalog)
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func testRules(catalog, rules) -> void:
	print("--- Rules: stacking, capacity and ids ---")
	var plan = rules.planAdd([], [_stack("paregoric", 3)], 2, catalog, 1)
	_check(plan.success, "three Paregoric fit in one stack")
	_check(plan.inventory.size() == 1 and plan.inventory[0].quantity == 3, "new stack quantity should be 3")
	_check(plan.inventory[0].instanceId == "item_1", "first generated id should be item_1")
	_check(plan.nextInstanceNumber == 2, "next instance number should advance")
	_check(plan.accepted.size() == 1 and plan.accepted[0].quantity == 3, "accepted summary should carry quantity")

	var existing = [{ "instanceId": "item_9", "definitionId": "paregoric", "itemType": "consumable", "quantity": 4 }]
	plan = rules.planAdd(existing, [_stack("paregoric", 3)], 1, catalog, 10)
	_check(plan.success, "merge into an existing stack is valid")
	_check(plan.inventory.size() == 1 and plan.inventory[0].quantity == 5, "merge respects the stack limit")
	_check(plan.overflow.size() == 1 and plan.overflow[0].quantity == 2, "stack overflow keeps the remainder")
	_check(plan.nextInstanceNumber == 10, "merging does not allocate a new id")

	plan = rules.planAdd([], [_stack("paregoric", 12)], 3, catalog, 1)
	_check(plan.inventory.size() == 3, "twelve units use three stacks at limit five")
	_check(plan.inventory[0].quantity == 5 and plan.inventory[2].quantity == 2, "stack distribution is deterministic")
	_check(plan.acceptedInstanceIds == ["item_1", "item_2", "item_3"], "accepted ids are deterministic")

	print("\n--- Rules: unstackable gear and full capacity ---")
	var firstGear = _weapon("cattleman", "Gun One")
	var secondGear = _weapon("cattleman", "Gun Two")
	firstGear["instanceId"] = "attempted_duplicate"
	plan = rules.planAdd([], [firstGear, secondGear], 1, catalog, 1)
	_check(plan.inventory.size() == 1, "gear never stacks")
	_check(plan.inventory[0].instanceId == "item_1", "incoming gear ids are replaced")
	_check(plan.accepted.size() == 1 and plan.overflow.size() == 1, "full-capacity gear goes to overflow")
	_check(!plan.overflow[0].has("instanceId"), "overflow gear has no allocated id")

	print("\n--- Rules: invalid batches are atomic ---")
	var before = [{ "instanceId": "item_7", "definitionId": "paregoric", "itemType": "consumable", "quantity": 2 }]
	plan = rules.planAdd(before, [_stack("paregoric", 1), _stack("missing", 1)], 4, catalog, 8)
	_check(!plan.success and plan.reason == "invalid_item", "unknown definition rejects the whole batch")
	_check(plan.inventory.is_empty(), "failed plans expose no candidate inventory")
	plan = rules.planAdd([_stack("paregoric", 1), _stack("paregoric", 1)], [], 4, catalog, 1)
	_check(!plan.success, "stack IDs are required in existing inventory")

	print("\n--- Rules: projection and slot lookup ---")
	var projected = rules.projectItem(before[0], catalog)
	_check(projected.name == "Paregoric" and projected.stackLimit == 5, "projection merges catalog display data")
	projected["name"] = "Mutated"
	_check(rules.projectItem(before[0], catalog).name == "Paregoric", "projection does not leak mutable definitions")
	_check(rules.equipmentSlot(_weapon("cattleman", "Gun")) == "weapon", "weapon maps to the weapon slot")
	_check(rules.equipmentSlot({ "itemType": "equipment", "slot": "duster" }) == "duster", "equipment uses its authored slot")
	_check(rules.equipmentSlot({ "itemType": "equipment", "slot": "weapon" }) == "", "equipment cannot claim the weapon slot")


func testParty(catalog) -> void:
	print("\n--- Party: starter data and capacity snapshot ---")
	var starter = PartyScript.new()
	starter.configureInventory(catalog)
	_check(starter.isInventoryDataAvailable(), "valid catalog makes inventory available")
	_check(starter.inventory.size() == 1 and starter.inventory[0].definitionId == "paregoric", "starter carries one shared Paregoric")
	_check(starter.party["Walker Langley"].items == ["Paregoric"], "starter belt no longer exceeds Gunslinger belt space")
	starter.free()

	var party = PartyScript.new()
	party.configureInventory(catalog)
	party.inventory = []
	party._nextInstanceNumber = 1
	var signalCount = []
	party.inventoryChanged.connect(func(): signalCount.append(true))

	print("\n--- Party: add, merge, snapshot and signals ---")
	var result = party.addItem(_stack("paregoric", 2))
	_check(result.success and result.accepted[0].quantity == 2, "Party commits a valid add")
	_check(result.acceptedInstanceIds == ["item_1"], "Party returns the allocated id")
	_check(signalCount.size() == 1, "one successful batch emits one signal")
	var snapshot = party.getInventorySnapshot()
	_check(snapshot.capacity == 24 and snapshot.used == 1, "snapshot exposes capacity and used stacks")
	_check(snapshot.items[0].name == "Paregoric" and snapshot.items[0].quantity == 2, "snapshot projects the stack")
	snapshot.items[0]["quantity"] = 99
	_check(party.getInventorySnapshot().items[0].quantity == 2, "snapshot does not expose mutable state")

	result = party.addItems([_stack("paregoric", 2), _stack("missing", 1)])
	_check(!result.success and signalCount.size() == 1, "invalid batch does not mutate or emit")
	_check(!result.has("inventory") and !result.has("nextInstanceNumber"), "public failure hides internal plan fields")
	_check(party.inventory[0].quantity == 2, "inventory is unchanged after an invalid batch")

	print("\n--- Party: drops and scene policy ---")
	result = party.dropItem("item_1", 1)
	_check(!result.success and result.reason == "management_unavailable", "drops fail closed outside allowed scenes")
	_check(party.inventory[0].quantity == 2 and signalCount.size() == 1, "blocked drop does not mutate")
	party.setInventoryManagementAllowed(true)
	result = party.dropItem("item_1", 1)
	_check(result.success and party.inventory[0].quantity == 1 and signalCount.size() == 2, "partial drop removes one unit")
	result = party.dropItem("item_1", 2)
	_check(!result.success and result.reason == "invalid_quantity", "drop quantity above the stack is rejected")
	result = party.dropItem("item_1", 1)
	_check(result.success and party.inventory.is_empty(), "full-stack drop removes the slot")
	result = party.dropItem("missing", 1)
	_check(!result.success and result.reason == "unknown_item", "unknown item id is rejected")

	print("\n--- Party: non-droppable and invalid catalog states ---")
	var lockedCatalog = ItemCatalogScript.new()
	lockedCatalog.definitions["bound_token"] = {
		"definitionId": "bound_token",
		"itemType": "consumable",
		"combatId": "Paregoric",
		"name": "Bound Token",
		"category": "supplies",
		"description": "Cannot be dropped.",
		"stackLimit": 5,
		"droppable": false,
		"sprite": "",
	}
	party.configureInventory(lockedCatalog)
	_check(party.isInventoryDataAvailable(), "valid extended catalog is available")
	party.addItem(_stack("bound_token", 2))
	snapshot = party.getInventorySnapshot()
	var tokenId = snapshot.items[0].instanceId
	result = party.dropItem(tokenId, 1)
	_check(!result.success and result.reason == "not_droppable", "definition can prohibit dropping")
	_check(party.inventory[0].quantity == 2, "non-droppable item is unchanged")

	var brokenCatalog = ItemCatalogScript.new()
	brokenCatalog.definitions["paregoric"]["stackLimit"] = 0
	party.configureInventory(brokenCatalog)
	_check(!party.isInventoryDataAvailable(), "invalid catalog fails closed")
	result = party.addItem(_stack("paregoric", 1))
	_check(!result.success and result.reason == "data_unavailable", "unavailable data rejects mutations")

	print("\n--- Party: loot money, overflow and fight handoff ---")
	party.configureInventory(catalog)
	party.inventory = []
	party.money = 0
	result = party.applyLoot({ "money": 7, "items": [_stack("missing", 1)] })
	_check(party.money == 7 and !result.success, "money applies independently of invalid items")
	_check(result.reason == "invalid_item", "invalid loot item result is surfaced")

	for index in 24:
		party.inventory.append({
			"instanceId": "full_%d" % index,
			"definitionId": "paregoric",
			"itemType": "consumable",
			"quantity": 5,
		})
	result = party.applyLoot({ "money": 3, "items": [_stack("paregoric", 1)] })
	_check(result.success and result.accepted.is_empty(), "full inventory accepts no more stacks")
	_check(result.overflow.size() == 1 and result.overflow[0].quantity == 1, "full inventory reports overflow")
	_check(result.overflow[0].name == "Paregoric" and result.money == 3, "overflow keeps display name and money result")
	_check(party.inventory.size() == 24 and party.money == 10, "overflow does not exceed capacity or lose money")
	_check(party.getInventorySnapshot().used == 24, "capacity reaches exactly 24 occupied stacks")

	party.inventory = []
	party.money = 0
	var fightResult = party.applyFightResults({
		"loot": { "money": 2, "items": [_stack("paregoric", 1)] },
		"party": {},
		"fled": false,
	})
	_check(fightResult.loot.accepted.size() == 1 and fightResult.loot.money == 2, "fight results return loot application")
	_check(party.money == 2 and party.inventory.size() == 1, "fight loot commits to Party")
	party.free()


func _stack(definitionId: String, quantity: int) -> Dictionary:
	return { "definitionId": definitionId, "itemType": "consumable", "quantity": quantity }


func _weapon(definitionId: String, itemName: String) -> Dictionary:
	return {
		"definitionId": definitionId,
		"quantity": 1,
		"itemType": "weapon",
		"name": itemName,
		"baseName": itemName,
		"family": "revolver",
		"baseDamage": 5,
		"stats": {},
	}


func _check(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		printerr("CHECK FAILED: ", message)

