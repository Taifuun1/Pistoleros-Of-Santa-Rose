extends SceneTree

## Headless validation for shared belt ownership and consumption (Docs/System
## Design/First Steps Implementation Plan.md, commit 3; System Coherence belt
## transaction boundaries). Run with:
## godot --headless --script res://Tests/TestBeltOwnership.gd

const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const PartyScript = preload("res://Globals/Party.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 10
	var maxHp = 20
	var items = []
	var beltReservations = []


class FakeShootout:
	extends Node2D
	var itemsData = {
		"Paregoric": { "name": "Paregoric", "baseAmount": 5, "effects": [] },
	}
	var records = []
	func spawnDamageNumber(_label, _color, _position):
		pass
	func recordBeltConsumption(instanceId: String, combatId: String) -> void:
		records.append({ "instanceId": instanceId, "combatId": combatId, "quantity": 1 })


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	testStarterMigration()
	testReservationValidation()
	testCombatConsumptionAndWriteBack()
	testUnusedReservationsSurvive()
	testInvalidRecordsAreAtomic()
	testInstanceIdOwnership()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func testStarterMigration() -> void:
	print("--- Starter migration creates one owned stack and one reservation ---")
	var catalog = ItemCatalogScript.new()
	var party = PartyScript.new()
	party.configureInventory(catalog, { "Gunslinger": { "beltSpace": 1 } })
	_check(party.inventory.size() == 1 and party.inventory[0].instanceId == "starter_paregoric", "starter owns exactly one shared Paregoric stack")
	_check(party.inventory[0].quantity == 1, "the starter stack is a single unit")
	var belt = party.getBeltSnapshot("Walker Langley")
	_check(belt.success and belt.used == 1, "starter belt has one entry")
	_check(belt.entries[0].instanceId == "starter_paregoric" and belt.entries[0].quantity == 1, "the reservation references the owned stack")
	_check(belt.entries[0].valid and belt.entries[0].combatId == "Paregoric", "the reservation projects to the combat item")
	var fightData = party.getFightData("Walker Langley")
	_check(fightData.items == ["Paregoric"], "fight data projects one combat item use")
	_check(fightData.beltReservations.size() == 1 and fightData.beltReservations[0].instanceId == "starter_paregoric", "fight data keeps the source instance id")
	party.free()


func testReservationValidation() -> void:
	print("\n--- Reservation validation and belt space ---")
	var catalog = ItemCatalogScript.new()
	var party = _freshParty(catalog, 1)
	var stackResult = party.addItems([_stack("paregoric", 2)])
	var consumableId = stackResult.acceptedInstanceIds[0]
	var mapResult = party.addItems([{ "definitionId": "canyon_cache_map", "itemType": "map", "quantity": 1 }])
	var mapId = mapResult.acceptedInstanceIds[0]

	_check(party.reserveBeltItem("Missing Member", consumableId, 1).reason == "unknown_member", "unknown member is rejected")
	_check(party.reserveBeltItem("Walker Langley", "missing_item", 1).reason == "unknown_item", "unknown item is rejected")
	_check(party.reserveBeltItem("Walker Langley", mapId, 1).reason == "not_consumable", "non-consumables cannot go on a belt")
	_check(party.reserveBeltItem("Walker Langley", consumableId, 0).reason == "invalid_quantity", "zero quantity is rejected")
	_check(party.reserveBeltItem("Walker Langley", consumableId, 3).reason == "exceeds_owned", "reserving more than owned is rejected")
	var management = party.inventoryManagementAllowed
	party.setInventoryManagementAllowed(false)
	_check(party.reserveBeltItem("Walker Langley", consumableId, 1).reason == "management_unavailable", "reservation fails closed outside allowed scenes")
	party.setInventoryManagementAllowed(management)

	var result = party.reserveBeltItem("Walker Langley", consumableId, 2)
	_check(result.success and result.quantity == 2, "reserving an owned quantity succeeds")
	_check(party.getBeltSnapshot("Walker Langley").entries[0].quantity == 2, "the reservation keeps its quantity")
	var second = party.addItems([_stack("multi_heal", 1)]).acceptedInstanceIds[0]
	_check(party.reserveBeltItem("Walker Langley", second, 1).reason == "belt_full", "a new entry beyond belt space is rejected")
	_check(party.unreserveBeltItem("Walker Langley", consumableId).success, "removing a reservation succeeds")
	_check(party.getBeltSnapshot("Walker Langley").entries.is_empty(), "the removed entry leaves the belt")
	_check(party.unreserveBeltItem("Walker Langley", consumableId).reason == "unknown_reservation", "removing a missing reservation is rejected")
	party.free()


func _freshParty(catalog, beltSpace: int):
	var party = PartyScript.new()
	party.configureInventory(catalog, { "Gunslinger": { "beltSpace": beltSpace } })
	party.inventory = []
	party.party["Walker Langley"]["beltReservations"] = []
	party._nextInstanceNumber = 1
	party.setInventoryManagementAllowed(true)
	return party


func _stack(definitionId: String, quantity: int) -> Dictionary:
	return { "definitionId": definitionId, "itemType": "consumable", "quantity": quantity }


func testCombatConsumptionAndWriteBack() -> void:
	print("\n--- Buying, reserving and using in combat decrements once ---")
	var catalog = ItemCatalogScript.new()
	var party = _freshParty(catalog, 2)
	var purchase = party.addItems([_stack("paregoric", 2)])
	var instanceId = purchase.acceptedInstanceIds[0]
	_check(party.reserveBeltItem("Walker Langley", instanceId, 2).success, "a bought stack can be reserved")
	var fightData = party.getFightData("Walker Langley")
	_check(fightData.items == ["Paregoric", "Paregoric"], "fight data projects one name per reserved use")

	var fake = FakeShootout.new()
	root.add_child(fake)
	var actor = FakeActor.new()
	actor.items = fightData.items.duplicate()
	actor.beltReservations = fightData.beltReservations.duplicate(true)
	fake.add_child(actor)
	var target = FakeActor.new()
	target.hp = 1
	target.maxHp = 20
	fake.add_child(target)
	var resolver = ActionResolverScript.new()
	resolver.init(fake)

	resolver.resolveItem("Paregoric", actor, target)
	_check(actor.items.size() == 1 and actor.beltReservations[0].quantity == 1, "one use consumes one reservation only")
	_check(fake.records.size() == 1 and fake.records[0].instanceId == instanceId, "the use records its source instance id")
	resolver.resolveItem("Paregoric", actor, target)
	_check(actor.items.is_empty() and actor.beltReservations[0].quantity == 0, "the second use empties the reservation")

	var application = party.applyFightResults({ "beltConsumed": fake.records.duplicate(true), "party": {} })
	_check(application.belt.success, "the fight commit accepts the valid records")
	_check(application.belt.consumed.size() == 1 and application.belt.consumed[0].quantity == 2, "the commit sums the two uses")
	_check(!party.hasInstanceId(instanceId), "the carried stack is consumed exactly once")
	_check(party.getBeltSnapshot("Walker Langley").used == 0, "the exhausted reservation is reconciled away")

	var repeated = party.applyFightResults({ "beltConsumed": fake.records.duplicate(true), "party": {} })
	_check(!repeated.belt.success and repeated.belt.reason == "unknown_item", "reapplying consumed records fails closed")
	_check(party.inventory.is_empty(), "a rejected reapply does not double-consume or restore")

	actor.free()
	target.free()
	fake.free()
	party.free()


func testUnusedReservationsSurvive() -> void:
	print("\n--- Unused reservations survive victory/flee; Vamoose removes selected stacks ---")
	var catalog = ItemCatalogScript.new()
	var party = _freshParty(catalog, 2)
	var instanceId = party.addItems([_stack("paregoric", 2)]).acceptedInstanceIds[0]
	party.reserveBeltItem("Walker Langley", instanceId, 1)

	for outcome in [{}, { "fled": true }, { "winningSide": "player team" }]:
		var application = party.applyFightResults(outcome.duplicate(true))
		_check(application.belt.success and application.belt.consumed.is_empty(), "no item use commits nothing")
	_check(party.inventory[0].quantity == 2, "the unused stack stays owned")
	_check(party.getBeltSnapshot("Walker Langley").used == 1, "the unused reservation stays reserved")

	# Vamoose removes the balance-selected carried stacks and reconciles the
	# reservation of a removed stack away.
	party.money = 100
	var retreat: Dictionary = party.vamoose({ "rng": _seededRng(11) })
	_check(retreat.removedItems.size() == 1, "Vamoose removes one complete carried stack")
	_check(party.inventory.is_empty(), "the removed stack leaves the inventory")
	_check(party.getBeltSnapshot("Walker Langley").used == 0, "the removed stack's reservation is reconciled away")
	party.free()


func _seededRng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func testInvalidRecordsAreAtomic() -> void:
	print("\n--- Invalid records reject the whole commit ---")
	var catalog = ItemCatalogScript.new()
	var party = _freshParty(catalog, 2)
	var instanceId = party.addItems([_stack("paregoric", 1)]).acceptedInstanceIds[0]
	party.reserveBeltItem("Walker Langley", instanceId, 1)
	var before = party.inventory.duplicate(true)

	var wrongCombat = party.applyFightResults({ "beltConsumed": [
		{ "instanceId": instanceId, "combatId": "NotParegoric", "quantity": 1 },
	], "party": {} })
	_check(!wrongCombat.belt.success and party.inventory == before, "a mismatched combat id leaves inventory unchanged")
	var unknownItem = party.applyFightResults({ "beltConsumed": [
		{ "instanceId": "missing", "combatId": "Paregoric", "quantity": 1 },
	], "party": {} })
	_check(!unknownItem.belt.success and party.inventory == before, "an unknown instance leaves inventory unchanged")
	var overuse = party.applyFightResults({ "beltConsumed": [
		{ "instanceId": instanceId, "combatId": "Paregoric", "quantity": 1 },
		{ "instanceId": instanceId, "combatId": "Paregoric", "quantity": 1 },
	], "party": {} })
	_check(!overuse.belt.success and party.inventory == before, "using more units than owned is rejected atomically")
	party.free()


func testInstanceIdOwnership() -> void:
	print("\n--- Reserved ids cannot be duplicated by transfers ---")
	var catalog = ItemCatalogScript.new()
	var party = _freshParty(catalog, 2)
	var instanceId = party.addItems([_stack("paregoric", 1)]).acceptedInstanceIds[0]
	party.reserveBeltItem("Walker Langley", instanceId, 1)
	_check(party.hasInstanceId(instanceId), "a reserved carried id is already owned")
	_check(party.transferGearOut(instanceId).reason == "not_equipment", "a reserved consumable is not a gear transfer")
	var drop = party.dropItem(instanceId, 1)
	_check(drop.success, "the reserved stack can still be dropped as a deliberate command")
	_check(!party.hasInstanceId(instanceId) and party.getBeltSnapshot("Walker Langley").used == 0, "dropping the stack reconciles its reservation away")
	party.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)