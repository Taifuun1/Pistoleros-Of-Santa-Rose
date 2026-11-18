extends Node

## Party state (Docs/System Design/Shootout/Death Injury and Retreat.md): one
## shared party level, journey injuries and the money pouch. Fighters start each
## Shootout at effective max HP; persistent knockout/downed state is removed.
## All fighters' post-fight state flows through applyFightResults().
## Inventories/equipment follow Docs/System Design/Journal/Inventory and Equipment.md.
## Vamoose routing/loss and the versioned New Game snapshot land here too.

signal inventoryChanged
signal moneyChanged
signal equipmentChanged(memberKey: String)
## Empty memberKey means the whole party changed (fight results, town reset, Vamoose).
signal partyChanged(memberKey: String)

const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")
const CharacterStatCalculatorScript = preload("res://Globals/CharacterStatCalculator.gd")
const CombatLoadoutProjectorScript = preload("res://Globals/CombatLoadoutProjector.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const INVENTORY_CAPACITY = 24
## Belt entries reference a carried consumable stack. Enemy actor belts are
## separate content and stay name-based.
const RESERVABLE_ITEM_TYPES = ["consumable"]

# Placeholder: MxHP portion lost when fleeing a fight.
const FLEE_MXHP_LOSS = 0.2
# Placeholder: HP lost per point of MxHP lost to injuries.
const DEFAULT_INJURY_RATE = 4
## Save/New Game snapshot format for Party exportState()/importState(). Version 2
## adds each member's selected active Move loadout (commit 11).
const STATE_FORMAT_VERSION := 2
## The only save payload version this importer accepts for migration: version 1
## carried no selected loadout, which defaults to the member's canonical moves.
const LEGACY_STATE_FORMAT_VERSION := 1
## Vamoose carried-inventory loss (Docs/System Design/Content and Balance
## Catalog.md): 15% of occupied carried stacks, rounded up, minimum one while
## non-empty. Named and injectable so balance changes stay in one place.
const VAMOOSE_STACK_LOSS_FRACTION := 0.15

var level = 1
## Provisional New Game balance used for vertical-slice acceptance.
## Reset tests compare against the canonical Party baseline rather than this value.
var money = 1000
var inventory = [{
	"instanceId": "starter_paregoric",
	"definitionId": "paregoric",
	"itemType": "consumable",
	"quantity": 1,
}]
var inventoryManagementAllowed := false
var classesData = {}
var rodeosData = {}
## Authored Move catalog. The loadout commands and the fight projection both read
## this one source; empty means no Move catalog was resolved (fail closed).
var movesData = {}

var _inventoryRules
var _statCalculator
var _itemCatalog
var _inventoryDataAvailable := false
var _characterDataAvailable := false
var _nextInstanceNumber := 1
## Canonical New Game baseline captured before any gameplay mutation.
var _newGameBaseline := {}

var party = {
	"Walker Langley": {
		"actorName": "Walker Langley",
		"hp": 12,
		"walkingSpeed": 75,
		"runningSpeed": 25,
		"stats": {
			"sixShootin": 3,
			"highTailin": 6,
			"taffyin": 2,
			"damage": {
				"lead": {
					"revolver": 1,
					"rifle": 1,
					"shotgun": 1
				},
				"explosive": {
					"gunpowder": 1,
					"liquid": 1,
					"shrapnel": 1
				}
			},
			"defense": { "style": 2, "sand": 1 },
			"resistances": { "bleed": 0.0, "poison": 0.0 }
		},
		"rodeo": "leaders duck",
		"baseMaxHp": 12,
		"injuryDamage": 0,
		"injuryRate": 4,
		"characterClass": "Gunslinger",
		"moves": ["Sharp Shot", "Hold Steady"],
		# Persistent belt reservations (Docs/System Design/System Coherence.md,
		# belt transaction boundaries). Each entry references one carried stack;
		# belt space counts entries, not reserved quantity.
		"beltReservations": [
			{ "instanceId": "starter_paregoric", "combatId": "Paregoric", "quantity": 1 },
		],
		"magazine": [1, 0, 2],
		"equipment": {
			"weapon": {
				"instanceId": "starter_walker_rifle",
				"definitionId": "starter_rifle",
				"itemType": "weapon",
				"quantity": 1,
				"name": "Rifle",
				"baseName": "Rifle",
				"family": "rifle",
				"familyNoun": "Rifle",
				"baseDamage": 4,
				"stats": {},
				"sprite": "",
				"zone": "anywhere",
				"rarity": "common",
				"rarityName": "Trail-Worn",
				"prefix": {},
				"suffix": {},
			},
			"headwear": null,
			"bandana": null,
			"duster": null,
			"belt": null,
			"trousers": null,
			"justins": null,
		}
	}
}


## New Game baseline: capture the canonical starter state before any gameplay
## mutation so resetForNewGame() can restore it exactly.
func _init() -> void:
	_newGameBaseline = {
		"money": money,
		"level": level,
		"inventory": inventory.duplicate(true),
		"nextInstanceNumber": _nextInstanceNumber,
		"party": party.duplicate(true),
	}


func _ready() -> void:
	var catalog = ItemCatalogScript.new()
	var shootoutGlobals = get_node_or_null("/root/Shootout")
	var classDefinitions = shootoutGlobals.classesData if shootoutGlobals != null else {}
	var rodeoDefinitions = shootoutGlobals.rodeosData if shootoutGlobals != null else {}
	var moveDefinitions = shootoutGlobals.movesData if shootoutGlobals != null else {}
	configureInventory(catalog, classDefinitions)
	configureCharacterData(classDefinitions, rodeoDefinitions, moveDefinitions)
	# Single Town recovery boundary: recovery runs from the Locations command,
	# not from scene loads or vendor-room returns.
	var locations = get_node_or_null("/root/Locations")
	if locations != null and locations.has_signal("townEntered"):
		locations.townEntered.connect(_on_town_entered)


## Test/headless initialization seam: installs the catalog and class definitions
## without touching inventory contents. Invalid catalog data fails closed.
func configureInventory(catalog, classDefinitions := {}) -> void:
	if _inventoryRules == null:
		_inventoryRules = InventoryRulesScript.new()
	if _statCalculator == null:
		_statCalculator = CharacterStatCalculatorScript.new()
	_itemCatalog = catalog
	classesData = classDefinitions
	_inventoryDataAvailable = _itemCatalog != null and _itemCatalog.validate().is_empty()


## Test/headless initialization seam for the Journal Character tab: installs
## immutable class/Rodeo/Move read data independently of inventory availability.
func configureCharacterData(classDefinitions: Dictionary, rodeoDefinitions: Dictionary, moveDefinitions: Dictionary = {}) -> void:
	_ensureStatCalculator()
	classesData = classDefinitions.duplicate(true)
	rodeosData = rodeoDefinitions.duplicate(true)
	movesData = moveDefinitions.duplicate(true)
	_characterDataAvailable = true


func isCharacterDataAvailable() -> bool:
	return _characterDataAvailable and _statCalculator != null


## Move-loadout commands need both the character data and the authored Move
## catalog; a missing catalog fails closed instead of accepting unknown ids.
func isMoveLoadoutDataAvailable() -> bool:
	return isCharacterDataAvailable() and !movesData.is_empty()


## Read-only character-sheet projection (Docs/System Design/Journal/
## Character.md). Returns fresh deep copies in authoritative party order and
## never reads inventory, mutates members, or performs combat work.
func getCharacterJournalSnapshot() -> Dictionary:
	var snapshot = { "level": level, "members": [] }
	if !isCharacterDataAvailable():
		return snapshot
	for memberKey in party:
		var member = party[memberKey]
		var key = str(memberKey)
		if key.is_empty() or !(member is Dictionary):
			push_warning("Party: ignored invalid character member '%s'." % key)
			continue
		var projection = _statCalculator.projectCharacter(member, _classDataFor(member), _attritionContext())
		if !(projection is Dictionary) or !(projection.get("statRows", null) is Array) or !(projection.get("modifiers", null) is Array):
			push_warning("Party: ignored invalid character projection for '%s'." % key)
			continue
		snapshot.members.append({
			"key": key,
			"actorName": str(member.get("actorName", key)),
			"characterClass": str(member.get("characterClass", "")),
			# Persistent downed/knockout state was removed; the field stays for
			# Journal compatibility and is always false outside a fight.
			"downed": false,
			# HP is not carried between fights: the Journal shows effective max HP.
			"hp": int(projection.get("maxHp", projection.get("hp", 0))),
			"maxHp": int(projection.get("maxHp", 0)),
			"statRows": projection.get("statRows", []).duplicate(true),
			"modifiers": projection.get("modifiers", []).duplicate(true),
			"rodeo": _projectRodeo(member.get("rodeo", null)),
			# Move activation reads the same projection the fight uses; the tab
			# never owns the loadout itself.
			"moveLoadout": getMoveLoadoutSnapshot(key),
		})
	return snapshot


## Display metadata only; never scales, registers, or triggers a Rodeo.
func _projectRodeo(rodeoValue):
	if rodeoValue == null:
		return null
	var key = str(rodeoValue)
	if key.strip_edges().is_empty():
		return null
	var definition = _findRodeoDefinition(key)
	if definition == null:
		return { "key": key, "available": false, "name": key, "description": "" }
	return {
		"key": key,
		"available": true,
		"name": str(definition.get("name", key)),
		"description": str(definition.get("description", "")),
	}


func _findRodeoDefinition(rodeoKey: String):
	for dataName in rodeosData:
		if str(dataName).to_lower() == rodeoKey.to_lower():
			var definition = rodeosData[dataName]
			return definition if definition is Dictionary else null
	return null


func isInventoryDataAvailable() -> bool:
	return _inventoryDataAvailable and _inventoryRules != null


func setInventoryManagementAllowed(allowed: bool) -> void:
	inventoryManagementAllowed = allowed


func getInventorySnapshot() -> Dictionary:
	var snapshot = {
		"capacity": INVENTORY_CAPACITY,
		"used": inventory.size(),
		"money": money,
		"managementAllowed": inventoryManagementAllowed,
		"items": [],
		"members": [],
	}
	if !isInventoryDataAvailable():
		return snapshot
	for entry in inventory:
		var projected = _inventoryRules.projectItem(entry, _itemCatalog)
		if projected.is_empty():
			push_warning("Party: ignored invalid inventory entry '%s'." % entry)
			continue
		snapshot.items.append(projected)
	for memberKey in party:
		var member = party[memberKey]
		var equipment = {}
		for slot in InventoryRulesScript.EQUIPMENT_SLOTS:
			var equipped = member.get("equipment", {}).get(slot, null) if member.get("equipment", {}) is Dictionary else null
			equipment[slot] = equipped.duplicate(true) if equipped is Dictionary else null
		snapshot.members.append({
			"key": memberKey,
			"actorName": str(member.get("actorName", memberKey)),
			"equipment": equipment,
			"belt": getBeltSnapshot(memberKey),
			"fightData": _fightDataFor(member),
		})
	return snapshot


## Validates and commits a batch atomically. Capacity overflow is a valid result,
## not a command failure. The private candidate inventory is never returned.
func addItems(items: Array) -> Dictionary:
	if !isInventoryDataAvailable():
		return _addFailure("data_unavailable")
	var plan = _inventoryRules.planAdd(
		inventory,
		items,
		INVENTORY_CAPACITY,
		_itemCatalog,
		_nextInstanceNumber
	)
	if !plan.success:
		return _publicAddResult(plan)
	inventory = plan.inventory
	_nextInstanceNumber = int(plan.nextInstanceNumber)
	if !plan.accepted.is_empty():
		inventoryChanged.emit()
	return _publicAddResult(plan)


func addItem(item: Dictionary) -> Dictionary:
	return addItems([item])


## All-or-nothing capacity pre-check (commit 16): true when the whole batch
## would be accepted with no overflow and no partial acceptance. Nothing is
## mutated — callers use it to refuse before granting (secret reward claims).
func canAddItems(items: Array) -> bool:
	if !isInventoryDataAvailable():
		return false
	var plan = _inventoryRules.planAdd(
		inventory,
		items,
		INVENTORY_CAPACITY,
		_itemCatalog,
		_nextInstanceNumber
	)
	return bool(plan.success) and (plan.overflow as Array).is_empty() and !(plan.accepted as Array).is_empty()


## Atomic vendor purchase (Docs/System Design/Location Vendors Implementation.md,
## patch 2): the whole batch must fit before money or inventory changes. Partial
## acceptance is failure here, unlike loot overflow.
func completePurchase(items: Array, totalPrice: int) -> Dictionary:
	if !isInventoryDataAvailable():
		return _addFailure("data_unavailable")
	if !inventoryManagementAllowed:
		return _addFailure("management_unavailable")
	if typeof(totalPrice) != TYPE_INT or totalPrice < 0:
		return _addFailure("invalid_price")
	if items.is_empty():
		return _addFailure("invalid_item")
	if money < totalPrice:
		return _addFailure("insufficient_money")
	var plan = _inventoryRules.planAdd(
		inventory,
		items,
		INVENTORY_CAPACITY,
		_itemCatalog,
		_nextInstanceNumber
	)
	if !plan.success:
		return _publicAddResult(plan)
	var result = _publicAddResult(plan)
	if !plan.overflow.is_empty():
		result["success"] = false
		result["reason"] = "insufficient_capacity"
		return result
	if plan.accepted.is_empty():
		result["success"] = false
		result["reason"] = "invalid_item"
		return result
	inventory = plan.inventory
	_nextInstanceNumber = int(plan.nextInstanceNumber)
	money -= totalPrice
	inventoryChanged.emit()
	moneyChanged.emit()
	result["totalPrice"] = totalPrice
	result["money"] = money
	return result


## Atomic vendor sale: removes exactly one carried gear instance and credits the
## authoritative quote once. Specialist category/sellable policy lives in the
## vendor service, not here.
func completeSale(instanceId: String, unitPrice: int) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !inventoryManagementAllowed:
		return { "success": false, "reason": "management_unavailable" }
	if typeof(unitPrice) != TYPE_INT or unitPrice <= 0:
		return { "success": false, "reason": "invalid_price" }
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return { "success": false, "reason": "unknown_item" }
	var item = inventory[index]
	if !_inventoryRules.isValidGearEntry(item):
		return { "success": false, "reason": "not_equipment" }
	var sold = item.duplicate(true)
	inventory.remove_at(index)
	money += unitPrice
	inventoryChanged.emit()
	moneyChanged.emit()
	return {
		"success": true,
		"reason": "",
		"instanceId": instanceId,
		"definitionId": str(sold.get("definitionId", "")),
		"item": sold,
		"unitPrice": unitPrice,
		"money": money,
	}


## Bank deposit source: removes one carried gear instance and returns a deep
## copy with its complete rolled data and original instanceId.
func transferGearOut(instanceId: String) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !inventoryManagementAllowed:
		return { "success": false, "reason": "management_unavailable" }
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return { "success": false, "reason": "unknown_item" }
	var item = inventory[index]
	if !_inventoryRules.isValidGearEntry(item):
		return { "success": false, "reason": "not_equipment" }
	var stored = item.duplicate(true)
	inventory.remove_at(index)
	inventoryChanged.emit()
	return { "success": true, "reason": "", "instanceId": instanceId, "item": stored }


## Bank withdrawal sink: inserts complete gear unchanged, preserving its id. The
## Bank service validates its own collection before calling this.
func transferGearIn(item: Dictionary) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !inventoryManagementAllowed:
		return { "success": false, "reason": "management_unavailable" }
	if !_inventoryRules.isValidGearEntry(item):
		return { "success": false, "reason": "invalid_item" }
	var instanceId = str(item.get("instanceId", ""))
	if hasInstanceId(instanceId):
		return { "success": false, "reason": "duplicate_instance_id" }
	if inventory.size() >= INVENTORY_CAPACITY:
		return { "success": false, "reason": "insufficient_capacity" }
	var stored = item.duplicate(true)
	inventory.append(stored)
	_nextInstanceNumber = _inventoryRules.nextInstanceNumberAfter(instanceId, _nextInstanceNumber)
	inventoryChanged.emit()
	return { "success": true, "reason": "", "instanceId": instanceId, "item": stored }


## Exact one-unit consumption for supported out-of-combat effects. Not a generic
## effect dispatcher; the caller validates the effect before consuming.
func consumeItem(instanceId: String, expectedType: String) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !inventoryManagementAllowed:
		return { "success": false, "reason": "management_unavailable" }
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return { "success": false, "reason": "unknown_item" }
	var entry = inventory[index]
	if str(entry.get("itemType", "")) != expectedType:
		return { "success": false, "reason": "wrong_item_type" }
	if int(entry.get("quantity", 0)) <= 0:
		return { "success": false, "reason": "invalid_quantity" }
	var definitionId = str(entry.get("definitionId", ""))
	if int(entry.quantity) == 1:
		inventory.remove_at(index)
	else:
		entry["quantity"] = int(entry.quantity) - 1
	_reconcileBeltReservations(false)
	inventoryChanged.emit()
	return {
		"success": true,
		"reason": "",
		"instanceId": instanceId,
		"definitionId": definitionId,
		"quantity": 1,
	}


## True when a carried or equipped instance owns the id. Bank withdrawals use
## this to reject an id that already exists anywhere in Party.
func hasInstanceId(instanceId: String) -> bool:
	if instanceId == "":
		return false
	if _inventoryRules.inventoryIndex(inventory, instanceId) >= 0:
		return true
	for member in party.values():
		if !(member is Dictionary):
			continue
		var equipment = member.get("equipment", {})
		if !(equipment is Dictionary):
			continue
		for slot in equipment:
			var item = equipment[slot]
			if item is Dictionary and str(item.get("instanceId", "")) == instanceId:
				return true
	return false


func dropItem(instanceId: String, quantity: int) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !inventoryManagementAllowed:
		return { "success": false, "reason": "management_unavailable" }
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return { "success": false, "reason": "unknown_item" }
	var entry = inventory[index]
	if typeof(quantity) != TYPE_INT or quantity <= 0 or quantity > int(entry.quantity):
		return { "success": false, "reason": "invalid_quantity" }
	var projected = _inventoryRules.projectItem(entry, _itemCatalog)
	if projected.is_empty():
		return { "success": false, "reason": "data_unavailable" }
	if !bool(projected.get("droppable", false)):
		return { "success": false, "reason": "not_droppable" }
	var definitionId = str(entry.definitionId)
	if quantity == int(entry.quantity):
		inventory.remove_at(index)
	else:
		entry["quantity"] = int(entry.quantity) - quantity
	_reconcileBeltReservations(false)
	inventoryChanged.emit()
	return {
		"success": true,
		"reason": "",
		"instanceId": instanceId,
		"definitionId": definitionId,
		"quantity": quantity,
	}


func _publicAddResult(plan: Dictionary) -> Dictionary:
	var result = plan.duplicate(true)
	result.erase("inventory")
	result.erase("nextInstanceNumber")
	for index in result.overflow.size():
		var projected = _inventoryRules.projectItem(result.overflow[index], _itemCatalog)
		if !projected.is_empty() and projected.has("name"):
			result.overflow[index]["name"] = projected.name
	return result


func _addFailure(reason: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"accepted": [],
		"acceptedInstanceIds": [],
		"overflow": [],
	}


## Persistent belt reservation (Docs/System Design/System Coherence.md, belt
## transaction boundaries): references an owned consumable stack and reserves a
## positive quantity no greater than the owned amount. Does not create items.
func reserveBeltItem(memberKey: String, instanceId: String, quantity: int) -> Dictionary:
	if !isInventoryDataAvailable():
		return _beltFailure("data_unavailable", memberKey)
	if !inventoryManagementAllowed:
		return _beltFailure("management_unavailable", memberKey)
	if !party.has(memberKey):
		return _beltFailure("unknown_member", memberKey)
	if typeof(quantity) != TYPE_INT or quantity <= 0:
		return _beltFailure("invalid_quantity", memberKey)
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return _beltFailure("unknown_item", memberKey)
	var entry = inventory[index]
	var projected = _inventoryRules.projectItem(entry, _itemCatalog)
	if projected.is_empty():
		return _beltFailure("data_unavailable", memberKey)
	if !RESERVABLE_ITEM_TYPES.has(str(projected.get("itemType", ""))):
		return _beltFailure("not_consumable", memberKey)
	var combatId = str(projected.get("combatId", ""))
	if combatId == "":
		return _beltFailure("not_consumable", memberKey)
	var member = party[memberKey]
	var reservations := _memberReservations(member)
	var existingIndex := _reservationIndex(reservations, instanceId)
	var reservedQuantity := int(reservations[existingIndex].get("quantity", 0)) if existingIndex >= 0 else 0
	var ownedQuantity := int(entry.get("quantity", 0))
	if quantity > ownedQuantity - reservedQuantity:
		return _beltFailure("exceeds_owned", memberKey)
	var effectiveBeltSpace := int(_calculateStats(member).get("beltSpace", -1))
	if existingIndex < 0 and effectiveBeltSpace >= 0 and reservations.size() >= effectiveBeltSpace:
		return _beltFailure("belt_full", memberKey)
	if existingIndex >= 0:
		reservations[existingIndex]["quantity"] = reservedQuantity + quantity
		reservations[existingIndex]["combatId"] = combatId
	else:
		reservations.append({ "instanceId": instanceId, "combatId": combatId, "quantity": quantity })
	inventoryChanged.emit()
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"instanceId": instanceId,
		"combatId": combatId,
		"quantity": quantity,
		"belt": getBeltSnapshot(memberKey),
	}


func unreserveBeltItem(memberKey: String, instanceId: String) -> Dictionary:
	if !isInventoryDataAvailable():
		return _beltFailure("data_unavailable", memberKey)
	if !inventoryManagementAllowed:
		return _beltFailure("management_unavailable", memberKey)
	if !party.has(memberKey):
		return _beltFailure("unknown_member", memberKey)
	var member = party[memberKey]
	var reservations := _memberReservations(member)
	var index := _reservationIndex(reservations, instanceId)
	if index < 0:
		return _beltFailure("unknown_reservation", memberKey)
	reservations.remove_at(index)
	inventoryChanged.emit()
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"instanceId": instanceId,
		"belt": getBeltSnapshot(memberKey),
	}


## UI/read projection. Invalid reservations are reported but never mutate Party.
func getBeltSnapshot(memberKey: String) -> Dictionary:
	if !isInventoryDataAvailable():
		return _beltFailure("data_unavailable", memberKey)
	if !party.has(memberKey):
		return _beltFailure("unknown_member", memberKey)
	var member = party[memberKey]
	var effectiveBeltSpace := int(_calculateStats(member).get("beltSpace", -1))
	var entries := []
	for reservation in _memberReservationsReadonly(member):
		if !(reservation is Dictionary):
			continue
		var instanceId := str(reservation.get("instanceId", ""))
		var combatId := str(reservation.get("combatId", ""))
		var reservedQuantity := int(reservation.get("quantity", 0))
		var index = _inventoryRules.inventoryIndex(inventory, instanceId)
		var ownedQuantity := 0
		var name := combatId
		var itemType := ""
		var combatMatches := false
		if index >= 0:
			ownedQuantity = int(inventory[index].get("quantity", 0))
			var projected = _inventoryRules.projectItem(inventory[index], _itemCatalog)
			if !projected.is_empty():
				name = str(projected.get("name", combatId))
				itemType = str(projected.get("itemType", ""))
				combatMatches = str(projected.get("combatId", "")) == combatId
		entries.append({
			"instanceId": instanceId,
			"combatId": combatId,
			"quantity": reservedQuantity,
			"ownedQuantity": ownedQuantity,
			"name": name,
			"itemType": itemType,
			"valid": index >= 0 and reservedQuantity > 0 and reservedQuantity <= ownedQuantity and combatMatches,
		})
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"beltSpace": effectiveBeltSpace,
		"unlimited": effectiveBeltSpace < 0,
		"used": entries.size(),
		"entries": entries,
	}


## Read-only Move loadout projection for the Journal: every grant with its
## origin plus the active selection and cap. It comes from the same projector the
## fight uses, so the UI and combat cannot disagree.
func getMoveLoadoutSnapshot(memberKey: String) -> Dictionary:
	if !isMoveLoadoutDataAvailable():
		return _moveFailure("data_unavailable", memberKey)
	if !party.has(memberKey):
		return _moveFailure("unknown_member", memberKey)
	var projection = CombatLoadoutProjectorScript.project(party[memberKey], _classDataFor(party[memberKey]))
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"cap": int(projection.cap),
		"used": (projection.active as Array).size(),
		"active": (projection.active as Array).duplicate(),
		"unavailableActive": (projection.dropped as Array).duplicate(),
		"available": _annotatedMoves(projection),
		"managementAllowed": inventoryManagementAllowed,
	}


## Activates one available granted Move. Validation is atomic: a rejection
## changes no member, loadout or signal.
func activateMove(memberKey: String, moveId: String) -> Dictionary:
	var context := _moveCommandContext(memberKey, moveId)
	if !bool(context.get("success", false)):
		return context
	var member: Dictionary = context.member
	var moveName := str(context.moveId)
	var active: Array = context.active
	if active.has(moveName):
		return _moveFailure("already_active", memberKey)
	if active.size() >= int(context.projection.cap):
		return _moveFailure("move_cap_reached", memberKey)
	member["moves"] = active + [moveName]
	partyChanged.emit(memberKey)
	return _moveCommandSuccess(memberKey, moveName)


## Deactivates one active Move. The last offensive Move cannot be removed, so a
## Party member can never be left without a way to finish a fight.
func deactivateMove(memberKey: String, moveId: String) -> Dictionary:
	var context := _moveCommandContext(memberKey, moveId)
	if !bool(context.get("success", false)):
		return context
	var member: Dictionary = context.member
	var moveName := str(context.moveId)
	var active: Array = context.active
	if !active.has(moveName):
		return _moveFailure("not_active", memberKey)
	var remaining: Array = active.duplicate()
	remaining.erase(moveName)
	if CombatLoadoutProjectorScript.hasOffensiveMove(active, movesData) and !CombatLoadoutProjectorScript.hasOffensiveMove(remaining, movesData):
		return _moveFailure("last_offensive_move", memberKey)
	member["moves"] = remaining
	partyChanged.emit(memberKey)
	return _moveCommandSuccess(memberKey, moveName)


## Shared command validation: data, policy, member, canonical id, availability
## and a currently valid selection.
func _moveCommandContext(memberKey: String, moveId: String) -> Dictionary:
	if !isMoveLoadoutDataAvailable():
		return _moveFailure("data_unavailable", memberKey)
	if !inventoryManagementAllowed:
		return _moveFailure("management_unavailable", memberKey)
	if !party.has(memberKey):
		return _moveFailure("unknown_member", memberKey)
	var moveName := moveId.strip_edges()
	if moveName == "" or !movesData.has(moveName):
		return _moveFailure("unknown_move", memberKey)
	var member: Dictionary = party[memberKey]
	var projection = CombatLoadoutProjectorScript.project(member, _classDataFor(member))
	if !(projection.dropped as Array).is_empty():
		return _moveFailure("invalid_loadout", memberKey)
	if !(projection.availableNames as Dictionary).has(moveName):
		return _moveFailure("move_not_available", memberKey)
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"moveId": moveName,
		"member": member,
		"active": (projection.active as Array).duplicate(),
		"projection": projection,
	}


func _annotatedMoves(projection: Dictionary) -> Array:
	var entries := []
	var active: Array = projection.active
	for entryValue in projection.available:
		var entry: Dictionary = entryValue
		var entryName := str(entry.get("name", ""))
		entries.append({
			"name": entryName,
			"origin": str(entry.get("origin", "")),
			"slot": str(entry.get("slot", "")),
			"active": active.has(entryName),
			"offensive": CombatLoadoutProjectorScript.isOffensiveMove(entryName, movesData),
		})
	return entries


func _moveCommandSuccess(memberKey: String, moveId: String) -> Dictionary:
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"moveId": moveId,
		"loadout": getMoveLoadoutSnapshot(memberKey),
	}


## Stable command failures so the Journal can show a readable reason.
func _moveFailure(reason: String, memberKey: String) -> Dictionary:
	return { "success": false, "reason": reason, "memberKey": memberKey, "moveId": "" }


func _beltFailure(reason: String, memberKey: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"memberKey": memberKey,
		"entries": [],
	}


func _memberReservations(member: Dictionary) -> Array:
	if !(member.get("beltReservations") is Array):
		member["beltReservations"] = []
	return member.beltReservations


func _memberReservationsReadonly(member: Dictionary) -> Array:
	var reservations = member.get("beltReservations", [])
	return reservations if reservations is Array else []


func _reservationIndex(reservations: Array, instanceId: String) -> int:
	for index in reservations.size():
		var reservation = reservations[index]
		if reservation is Dictionary and str(reservation.get("instanceId", "")) == instanceId:
			return index
	return -1


## Fight start resolves each reservation into combat item names while retaining
## the source instance id for the one-shot consumption write-back.
func _fightDataFor(member: Dictionary) -> Dictionary:
	var data := _calculateStats(member)
	# Fighters always start a Shootout at effective max HP; HP is not carried
	# between fights (Docs/System Design/System Coherence.md, max-HP migration).
	data["hp"] = int(data.get("maxHp", data.get("hp", 1)))
	# The fight receives the resolved active loadout, never the raw selection.
	var loadout = CombatLoadoutProjectorScript.project(member, _classDataFor(member))
	if !(loadout.dropped as Array).is_empty():
		push_warning("Party: '%s' has unavailable active Moves %s; they are not sent to the fight." % [str(member.get("actorName", "?")), str(loadout.dropped)])
	data["moves"] = (loadout.active as Array).duplicate()
	var projection := _combatBeltProjection(member, data)
	data["items"] = projection.items
	data["beltReservations"] = projection.reservations
	return data


func _combatBeltProjection(member: Dictionary, fightData: Dictionary) -> Dictionary:
	var items := []
	var resolved := []
	var effectiveBeltSpace := int(fightData.get("beltSpace", -1))
	for reservationValue in _memberReservationsReadonly(member):
		if !(reservationValue is Dictionary):
			continue
		if effectiveBeltSpace >= 0 and resolved.size() >= effectiveBeltSpace:
			break
		var reservation: Dictionary = reservationValue
		var instanceId := str(reservation.get("instanceId", ""))
		var combatId := str(reservation.get("combatId", ""))
		var index = _inventoryRules.inventoryIndex(inventory, instanceId)
		if index < 0:
			push_warning("Party: belt reservation '%s' references a missing item." % instanceId)
			continue
		var projected = _inventoryRules.projectItem(inventory[index], _itemCatalog)
		if projected.is_empty() or str(projected.get("combatId", "")) != combatId:
			push_warning("Party: belt reservation '%s' no longer matches its combat item." % instanceId)
			continue
		var quantity := mini(int(reservation.get("quantity", 0)), int(inventory[index].get("quantity", 0)))
		if quantity <= 0:
			continue
		resolved.append({ "instanceId": instanceId, "combatId": combatId, "quantity": quantity })
		for _use in quantity:
			items.append(combatId)
	return { "items": items, "reservations": resolved }


func getEquipmentPreview(memberKey: String, instanceId: String) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !party.has(memberKey):
		return { "success": false, "reason": "unknown_member" }
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return { "success": false, "reason": "unknown_item" }
	var candidate = inventory[index].duplicate(true)
	var slot = _inventoryRules.equipmentSlot(candidate)
	if slot == "" or !_isValidEquipItem(candidate):
		return { "success": false, "reason": "not_equipment" }
	var member = party[memberKey]
	var current = _calculateStats(member)
	var projected = _calculateStats(member, slot, candidate)
	var beltValid = int(projected.get("beltSpace", -1)) < 0 or _memberReservationsReadonly(member).size() <= int(projected.beltSpace)
	var loadout = CombatLoadoutProjectorScript.projectWithEquipment(member, _classDataFor(member), slot, candidate)
	var moveValid := (loadout.dropped as Array).is_empty()
	var reason := ""
	if !beltValid:
		reason = "belt_loadout_too_large"
	elif !moveValid:
		reason = "move_grant_lost"
	return {
		"success": true,
		"reason": reason,
		"memberKey": memberKey,
		"slot": slot,
		"current": current,
		"projected": projected,
		"deltas": _statCalculator.compare(current, projected),
		"beltValid": beltValid,
		"moveValid": moveValid,
		"moveLoadout": loadout,
		"managementAllowed": inventoryManagementAllowed,
	}


func equipItem(memberKey: String, instanceId: String) -> Dictionary:
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable" }
	if !inventoryManagementAllowed:
		return { "success": false, "reason": "management_unavailable" }
	if !party.has(memberKey):
		return { "success": false, "reason": "unknown_member" }
	var index = _inventoryRules.inventoryIndex(inventory, instanceId)
	if index < 0:
		return { "success": false, "reason": "unknown_item" }
	var candidate = inventory[index].duplicate(true)
	var slot = _inventoryRules.equipmentSlot(candidate)
	if slot == "" or !_isValidEquipItem(candidate):
		return { "success": false, "reason": "not_equipment" }

	var member = party[memberKey]
	var projected = _calculateStats(member, slot, candidate)
	if int(projected.get("beltSpace", -1)) >= 0 and _memberReservationsReadonly(member).size() > int(projected.beltSpace):
		return { "success": false, "reason": "belt_loadout_too_large" }
	# An active equipment-granted Move must survive the swap: reject atomically
	# instead of silently trimming the loadout (same rule as the belt cap).
	var loadout = CombatLoadoutProjectorScript.projectWithEquipment(member, _classDataFor(member), slot, candidate)
	if !(loadout.dropped as Array).is_empty():
		return { "success": false, "reason": "move_grant_lost" }

	if !(member.get("equipment") is Dictionary):
		member["equipment"] = {}
	var equipment = member.equipment
	var oldItem = equipment.get(slot, null)
	inventory.remove_at(index)
	if oldItem is Dictionary:
		inventory.insert(index, oldItem.duplicate(true))
	equipment[slot] = candidate
	member["hp"] = mini(int(member.get("hp", projected.maxHp)), int(projected.maxHp))

	inventoryChanged.emit()
	equipmentChanged.emit(memberKey)
	partyChanged.emit(memberKey)
	return {
		"success": true,
		"reason": "",
		"memberKey": memberKey,
		"slot": slot,
		"equippedInstanceId": instanceId,
		"returnedInstanceId": str(oldItem.get("instanceId", "")) if oldItem is Dictionary else "",
	}


func _isValidEquipItem(item: Dictionary) -> bool:
	if !(item.get("stats") is Dictionary):
		return false
	if item.get("itemType") == "weapon":
		return str(item.get("family", "")) != "" and typeof(item.get("baseDamage", null)) == TYPE_INT
	return item.get("itemType") == "equipment"


func _calculateStats(member: Dictionary, replacementSlot := "", replacementItem = null) -> Dictionary:
	_ensureStatCalculator()
	return _statCalculator.calculate(member, _classDataFor(member), replacementSlot, replacementItem, _attritionContext())


## Attrition is injected into the pure calculator (Docs/System Design/System
## Coherence.md): Party resolves the authoritative Trail state, the calculator
## never reads Locations. Missing Locations (headless fixtures) stays On Trail.
func _attritionContext() -> Dictionary:
	var locations = null
	var mainLoop = Engine.get_main_loop()
	if mainLoop is SceneTree and mainLoop.root != null:
		locations = mainLoop.root.get_node_or_null("Locations")
	if locations != null and locations.has_method("canApplyAttrition"):
		return { "applyAttrition": bool(locations.canApplyAttrition()) }
	return { "applyAttrition": true }


func _classDataFor(member: Dictionary) -> Dictionary:
	var classData = classesData.get(member.get("characterClass", ""), {})
	return classData if classData is Dictionary else {}


func _ensureStatCalculator() -> void:
	if _statCalculator == null:
		_statCalculator = CharacterStatCalculatorScript.new()


## Effective max HP: base minus journey injuries, never below 1.
func effectiveMaxHp(member: Dictionary) -> int:
	return int(_calculateStats(member).get("maxHp", 1))


## The member's data prepared for a fight: effective MxHp, HP set to that max,
## equipment modifiers and belt reservations projected to combat items.
func getFightData(actorName: String) -> Dictionary:
	if !party.has(actorName):
		return {}
	return _fightDataFor(party[actorName])


## Post-fight write-back. Attrition, flee MxHP cost and loot commit only when
## the captured request is On Trail; Off-Trail fights and scene transitions must
## not change MxHP or grant rewards. Fighters return to effective max HP after
## the fight and keep no knockout/downed state. Loot is returned for the end
## screen so capacity overflow cannot be lost silently.
func applyFightResults(results: Dictionary) -> Dictionary:
	var onTrail := _resultsGrantAttrition(results)
	var lootResult = {}
	var beltResult = _commitBeltConsumption(results.get("beltConsumed", []))
	var changed = false
	if _reconcileBeltReservations():
		changed = true
	if onTrail and results.get("loot") is Dictionary:
		lootResult = applyLoot(results.loot)
	for actorName in results.get("party", {}):
		if !party.has(actorName):
			continue
		changed = true
		var state = results.party[actorName]
		var member = party[actorName]
		if onTrail:
			member["injuryDamage"] = int(member.get("injuryDamage", 0)) + int(state.get("injuryDamage", 0))
			if results.get("fled", false):
				_applyFleeCost(actorName)
		# HP is not carried between fights: return at the new effective max.
		member["hp"] = effectiveMaxHp(member)
	if changed:
		partyChanged.emit("")
	return { "loot": lootResult, "belt": beltResult }


## Production results carry the request's Trail snapshot; a missing key is a
## legacy/direct-test call and keeps the previous On-Trail behavior.
func _resultsGrantAttrition(results: Dictionary) -> bool:
	if results.get("trailState") is Dictionary:
		return bool(results.trailState.get("onTrail", false))
	return true


## Commits the Shootout's successful item records exactly once. Records are
## `{instanceId, combatId, quantity}`; multiples for the same instance are summed
## so a reservation quantity above one consumes the matching number of units.
## Any invalid record rejects the whole batch without mutating inventory.
func _commitBeltConsumption(records) -> Dictionary:
	var empty := { "success": true, "reason": "", "consumed": [] }
	if !(records is Array) or records.is_empty():
		return empty
	if !isInventoryDataAvailable():
		return { "success": false, "reason": "data_unavailable", "consumed": [] }
	var totals := {}
	var expectedCombatIds := {}
	for recordValue in records:
		if !(recordValue is Dictionary):
			return { "success": false, "reason": "invalid_item", "consumed": [] }
		var record: Dictionary = recordValue
		var instanceId := str(record.get("instanceId", ""))
		var combatId := str(record.get("combatId", ""))
		var quantity := int(record.get("quantity", 0))
		if instanceId == "" or combatId == "" or quantity <= 0:
			return { "success": false, "reason": "invalid_item", "consumed": [] }
		if expectedCombatIds.has(instanceId) and expectedCombatIds[instanceId] != combatId:
			return { "success": false, "reason": "invalid_item", "consumed": [] }
		expectedCombatIds[instanceId] = combatId
		totals[instanceId] = int(totals.get(instanceId, 0)) + quantity
	var candidate = inventory.duplicate(true)
	var consumed := []
	for instanceId in totals:
		var index = _inventoryRules.inventoryIndex(candidate, instanceId)
		if index < 0:
			return { "success": false, "reason": "unknown_item", "consumed": [] }
		var entry = candidate[index]
		var projected = _inventoryRules.projectItem(entry, _itemCatalog)
		if projected.is_empty() or str(projected.get("combatId", "")) == "":
			return { "success": false, "reason": "invalid_item", "consumed": [] }
		var combatId := str(projected.get("combatId", ""))
		if combatId != str(expectedCombatIds.get(instanceId, "")):
			return { "success": false, "reason": "invalid_item", "consumed": [] }
		var quantity := int(totals[instanceId])
		if quantity > int(entry.get("quantity", 0)):
			return { "success": false, "reason": "invalid_quantity", "consumed": [] }
		if quantity == int(entry.quantity):
			candidate.remove_at(index)
		else:
			entry["quantity"] = int(entry.quantity) - quantity
		consumed.append({ "instanceId": instanceId, "combatId": combatId, "quantity": quantity })
	inventory = candidate
	inventoryChanged.emit()
	return { "success": true, "reason": "", "consumed": consumed }


## Removes reservations whose owned stack is gone and clamps over-reserved
## quantities after consumption, drops, sales or imports. Unconsumed quantity
## stays owned and reserved.
func _reconcileBeltReservations(emitSignal := true) -> bool:
	if !isInventoryDataAvailable():
		return false
	var changed := false
	for memberKey in party:
		var member = party[memberKey]
		if !(member is Dictionary) or !(member.get("beltReservations") is Array):
			continue
		var kept := []
		for reservationValue in member.beltReservations:
			if !(reservationValue is Dictionary):
				changed = true
				continue
			var reservation: Dictionary = reservationValue
			var instanceId := str(reservation.get("instanceId", ""))
			var combatId := str(reservation.get("combatId", ""))
			var index = _inventoryRules.inventoryIndex(inventory, instanceId)
			if index < 0:
				changed = true
				continue
			var projected = _inventoryRules.projectItem(inventory[index], _itemCatalog)
			if projected.is_empty() or str(projected.get("combatId", "")) != combatId:
				changed = true
				continue
			var quantity := mini(int(reservation.get("quantity", 0)), int(inventory[index].get("quantity", 0)))
			if quantity <= 0:
				changed = true
				continue
			if quantity != int(reservation.get("quantity", 0)):
				changed = true
				reservation["quantity"] = quantity
			kept.append(reservation)
		if kept.size() != member.beltReservations.size():
			changed = true
		member["beltReservations"] = kept
	if changed and emitSignal:
		inventoryChanged.emit()
	return changed


## Loot from a won fight (Docs/System Design/Shootout/Rewards.md): money goes
## to the pouch and items go through the capacity-aware inventory command. Money
## applies independently when item data is invalid.
func applyLoot(loot: Dictionary) -> Dictionary:
	var moneyAdded = int(loot.get("money", 0))
	var moneyBefore = money
	money += moneyAdded
	var items = loot.get("items", [])
	var result = {}
	if items is Array:
		result = addItems(items)
	else:
		result = _addFailure("invalid_item")
	result["money"] = moneyAdded
	if money != moneyBefore:
		moneyChanged.emit()
	return result


## Fleeing costs a portion of MxHp (modeled as journey injury).
func applyFleeCost(actorName: String) -> void:
	if _applyFleeCost(actorName):
		partyChanged.emit(actorName)


## Batch-safe flee mutation: returns whether the member's injury actually changed.
func _applyFleeCost(actorName: String) -> bool:
	if !party.has(actorName):
		return false
	var member = party[actorName]
	var base = int(_calculateStats(member).get("baseMaxHp", member.get("baseMaxHp", member.get("hp", 1))))
	var rate = maxi(1, int(member.get("injuryRate", DEFAULT_INJURY_RATE)))
	var amount = int(ceil(base * FLEE_MXHP_LOSS * rate))
	if amount <= 0:
		return false
	member["injuryDamage"] = int(member.get("injuryDamage", 0)) + amount
	return true


## Town recovery command (single boundary): entering a Town restores injuries
## and full effective MxHP once through the Locations command.
func _on_town_entered(_locationId: String) -> void:
	resetInjury()


## Town entry: injuries reset to full effective MxHP.
func resetInjury() -> void:
	var changed = false
	for member in party.values():
		if int(member.get("injuryDamage", 0)) != 0:
			changed = true
			member["injuryDamage"] = 0
		member["hp"] = effectiveMaxHp(member)
	if changed:
		partyChanged.emit("")


## Camp items: reduce journey injuries.
func reduceInjury(amount: int) -> void:
	if amount <= 0:
		return
	var changed = false
	for member in party.values():
		var before = int(member.get("injuryDamage", 0))
		var after = maxi(0, before - amount)
		if after != before:
			changed = true
			member["injuryDamage"] = after
	if changed:
		partyChanged.emit("")


## Full-party-down retreat (Docs/System Design/Shootout/Death Injury and
## Retreat.md). Halves the money pouch once, removes the balance-selected
## carried stacks atomically, never touches equipped gear or the shared Bank,
## creates no knockout/downed state, and returns the active quest checkpoint
## when one exists, otherwise the recorded last Town. `options` may inject
## `rng`, `checkpointId` and `lastTownId` for deterministic tests.
func vamoose(options := {}) -> Dictionary:
	var checkpointId := str(options.get("checkpointId", _resolveQuestCheckpointId()))
	var lastTownId := str(options.get("lastTownId", _lastTownId()))
	var destination := ""
	var destinationKind := ""
	if !checkpointId.is_empty():
		destination = checkpointId
		destinationKind = "quest_checkpoint"
	elif !lastTownId.is_empty():
		destination = lastTownId
		destinationKind = "town"

	var moneyBefore := int(money)
	money = int(floor(money / 2.0))
	var removed := _removeVamooseStacks(options.get("rng", null))
	_reconcileBeltReservations(false)
	inventoryChanged.emit()
	if money != moneyBefore:
		moneyChanged.emit()
	partyChanged.emit("")
	return {
		"success": true,
		"reason": "",
		"destination": destination,
		"destinationKind": destinationKind,
		"moneyLost": moneyBefore - money,
		"money": money,
		"removedItems": removed,
	}


## Number of occupied carried stacks Vamoose removes. Removed stacks stay whole
## and each removal preserves instance-id uniqueness (stacks are whole rows).
static func vamooseLossCount(inventorySize: int) -> int:
	if inventorySize <= 0:
		return 0
	return maxi(1, int(ceil(inventorySize * VAMOOSE_STACK_LOSS_FRACTION)))


## Removes complete carried stacks at deterministic indices; equipment and any
## service-owned storage (the Bank) live outside Party.inventory.
func _removeVamooseStacks(rng) -> Array:
	var removalCount := vamooseLossCount(inventory.size())
	if removalCount <= 0:
		return []
	var generator: RandomNumberGenerator = rng if rng is RandomNumberGenerator else RandomNumberGenerator.new()
	if !(rng is RandomNumberGenerator):
		generator.randomize()
	var indices := []
	for index in inventory.size():
		indices.append(index)
	# Partial Fisher-Yates: deterministic for a seeded RNG, uniform otherwise.
	for position in removalCount:
		var swapIndex := generator.randi_range(position, indices.size() - 1)
		var swapValue = indices[position]
		indices[position] = indices[swapIndex]
		indices[swapIndex] = swapValue
	var targets := indices.slice(0, removalCount)
	targets.sort()
	targets.reverse()
	var removed := []
	for index in targets:
		removed.append((inventory[index] as Dictionary).duplicate(true))
		inventory.remove_at(index)
	return removed


## Quest checkpoint resolution uses authoritative Quests state (the current
## objective's map target), not a second Party flag. Missing services resolve
## to "" so a headless call simply falls back to the last Town.
func _resolveQuestCheckpointId() -> String:
	var quests = _serviceNode("Quests")
	if quests != null and quests.has_method("getCurrentObjectiveTarget"):
		return str(quests.getCurrentObjectiveTarget())
	return ""


func _lastTownId() -> String:
	var locations = _serviceNode("Locations")
	if locations != null and "lastTownId" in locations:
		return str(locations.lastTownId)
	return ""


func _serviceNode(nodeName: String) -> Node:
	var mainLoop = Engine.get_main_loop()
	if mainLoop is SceneTree and mainLoop.root != null:
		return mainLoop.root.get_node_or_null(nodeName)
	return null

## Versioned Party snapshot for the later save service and the New Game reset
## path. Covers money/level, mutable member state, inventory/equipment, belt
## reservations and the instance-id counter.
func exportState() -> Dictionary:
	var members := {}
	for memberKey in party:
		var member = party[memberKey]
		if !(member is Dictionary):
			continue
		members[str(memberKey)] = {
			"hp": int(member.get("hp", 1)),
			"injuryDamage": int(member.get("injuryDamage", 0)),
			"injuryRate": int(member.get("injuryRate", DEFAULT_INJURY_RATE)),
			"equipment": _duplicateDictionary(member.get("equipment", {})),
			"beltReservations": _duplicateArray(member.get("beltReservations", [])),
			# Selected active Move loadout (commit 11). Grants stay authored in
			# class/item content; only the selection is mutable state.
			"moves": _stringArray(member.get("moves", [])),
		}
	return {
		"formatVersion": STATE_FORMAT_VERSION,
		"level": level,
		"money": money,
		"nextInstanceNumber": _nextInstanceNumber,
		"inventory": inventory.duplicate(true),
		"members": members,
	}


## Validates the whole payload (item ids and references included) before
## committing anything; a rejected import leaves Party state untouched.
func importState(state) -> Dictionary:
	if !isInventoryDataAvailable():
		return _stateFailure("data_unavailable")
	if !(state is Dictionary):
		return _stateFailure("invalid_state")
	var stateVersion := int(state.get("formatVersion", -1))
	if stateVersion != STATE_FORMAT_VERSION and stateVersion != LEGACY_STATE_FORMAT_VERSION:
		return _stateFailure("invalid_state")
	# Version 1 carried no selected loadout: it defaults to the member's
	# canonical moves instead of inventing a new selection.
	var legacyLoadout := stateVersion == LEGACY_STATE_FORMAT_VERSION
	var moneyValue = state.get("money", null)
	var levelValue = state.get("level", null)
	var nextInstanceValue = state.get("nextInstanceNumber", null)
	if typeof(moneyValue) != TYPE_INT or int(moneyValue) < 0:
		return _stateFailure("invalid_state")
	if typeof(levelValue) != TYPE_INT or int(levelValue) < 1:
		return _stateFailure("invalid_state")
	if typeof(nextInstanceValue) != TYPE_INT or int(nextInstanceValue) < 1:
		return _stateFailure("invalid_state")
	var inventoryValue = state.get("inventory", null)
	if !(inventoryValue is Array):
		return _stateFailure("invalid_state")
	var membersValue = state.get("members", null)
	if !(membersValue is Dictionary):
		return _stateFailure("invalid_state")

	var seenIds := {}
	var candidateInventory := []
	for entryValue in inventoryValue:
		if !(entryValue is Dictionary):
			return _stateFailure("invalid_state")
		var entry: Dictionary = entryValue
		var instanceId := str(entry.get("instanceId", ""))
		if instanceId == "" or seenIds.has(instanceId):
			return _stateFailure("invalid_state")
		if typeof(entry.get("quantity", null)) != TYPE_INT or int(entry.quantity) <= 0:
			return _stateFailure("invalid_state")
		if str(entry.get("definitionId", "")) == "":
			return _stateFailure("invalid_state")
		if _inventoryRules.projectItem(entry, _itemCatalog).is_empty():
			return _stateFailure("invalid_item")
		seenIds[instanceId] = true
		candidateInventory.append(entry.duplicate(true))

	var candidateMembers := {}
	for memberKeyValue in membersValue:
		var memberKey := str(memberKeyValue)
		if !party.has(memberKey):
			return _stateFailure("invalid_state")
		var memberValue = membersValue[memberKeyValue]
		if !(memberValue is Dictionary):
			return _stateFailure("invalid_state")
		var memberState: Dictionary = memberValue
		var hpValue = memberState.get("hp", null)
		var injuryValue = memberState.get("injuryDamage", null)
		var injuryRateValue = memberState.get("injuryRate", null)
		if typeof(hpValue) != TYPE_INT or int(hpValue) < 0:
			return _stateFailure("invalid_state")
		if typeof(injuryValue) != TYPE_INT or int(injuryValue) < 0:
			return _stateFailure("invalid_state")
		if typeof(injuryRateValue) != TYPE_INT or int(injuryRateValue) < 1:
			return _stateFailure("invalid_state")
		var equipmentValue = memberState.get("equipment", null)
		if equipmentValue != null and !(equipmentValue is Dictionary):
			return _stateFailure("invalid_state")
		var reservationsValue = memberState.get("beltReservations", null)
		if !(reservationsValue is Array):
			return _stateFailure("invalid_state")
		var equipment := {}
		if equipmentValue is Dictionary:
			for slot in equipmentValue:
				if !InventoryRulesScript.EQUIPMENT_SLOTS.has(str(slot)):
					return _stateFailure("invalid_state")
				var itemValue = equipmentValue[slot]
				if itemValue == null:
					equipment[slot] = null
					continue
				if !(itemValue is Dictionary):
					return _stateFailure("invalid_state")
				var item: Dictionary = itemValue
				var itemId := str(item.get("instanceId", ""))
				if itemId == "" or seenIds.has(itemId) or !_isValidEquipItem(item):
					return _stateFailure("invalid_state")
				seenIds[itemId] = true
				equipment[slot] = item.duplicate(true)
		var reservations := []
		var reservationIds := {}
		for reservationValue in reservationsValue:
			if !(reservationValue is Dictionary):
				return _stateFailure("invalid_state")
			var reservation: Dictionary = reservationValue
			var reservationId := str(reservation.get("instanceId", ""))
			if reservationId == "" or !seenIds.has(reservationId) or reservationIds.has(reservationId):
				return _stateFailure("invalid_state")
			if str(reservation.get("combatId", "")) == "":
				return _stateFailure("invalid_state")
			if typeof(reservation.get("quantity", null)) != TYPE_INT or int(reservation.quantity) <= 0:
				return _stateFailure("invalid_state")
			reservationIds[reservationId] = true
			reservations.append(reservation.duplicate(true))
		var moves: Array = []
		if legacyLoadout:
			moves = _canonicalMovesFor(memberKey)
		else:
			var movesValue = memberState.get("moves", null)
			if !(movesValue is Array):
				return _stateFailure("invalid_state")
			var seenMoves := {}
			for moveValue in movesValue:
				if typeof(moveValue) != TYPE_STRING:
					return _stateFailure("invalid_state")
				var moveName := str(moveValue)
				if moveName == "" or seenMoves.has(moveName) or moves.size() >= CombatLoadoutProjectorScript.MOVE_CAP:
					return _stateFailure("invalid_state")
				if !movesData.is_empty() and !movesData.has(moveName):
					return _stateFailure("invalid_move")
				seenMoves[moveName] = true
				moves.append(moveName)
		var candidateMember: Dictionary = party[memberKey].duplicate(true)
		candidateMember["equipment"] = equipment
		candidateMember["moves"] = moves
		if !_loadoutResolvable(candidateMember):
			return _stateFailure("invalid_move")
		candidateMembers[memberKey] = {
			"hp": int(hpValue),
			"injuryDamage": int(injuryValue),
			"injuryRate": int(injuryRateValue),
			"equipment": equipment,
			"beltReservations": reservations,
			"moves": moves,
		}

	money = int(moneyValue)
	level = int(levelValue)
	_nextInstanceNumber = int(nextInstanceValue)
	inventory = candidateInventory
	for memberKey in candidateMembers:
		var member = party[memberKey]
		var memberState: Dictionary = candidateMembers[memberKey]
		member["hp"] = memberState.hp
		member["injuryDamage"] = memberState.injuryDamage
		member["injuryRate"] = memberState.injuryRate
		member["equipment"] = memberState.equipment
		member["beltReservations"] = memberState.beltReservations
		member["moves"] = memberState.moves.duplicate()
	inventoryChanged.emit()
	moneyChanged.emit()
	partyChanged.emit("")
	return { "success": true, "reason": "" }


## New Game: restore the canonical starter state captured at construction.
func resetForNewGame() -> void:
	var baseline: Dictionary = _newGameBaseline
	money = int(baseline.get("money", 0))
	level = int(baseline.get("level", 1))
	_nextInstanceNumber = int(baseline.get("nextInstanceNumber", 1))
	inventory = _duplicateArray(baseline.get("inventory", []))
	var baselineParty: Dictionary = baseline.get("party", {})
	for memberKey in party:
		if baselineParty.has(memberKey):
			party[memberKey] = _duplicateDictionary(baselineParty[memberKey])
	inventoryManagementAllowed = false
	inventoryChanged.emit()
	moneyChanged.emit()
	partyChanged.emit("")



## A candidate loadout is resolvable when its selection fits the member's actual
## grants and keeps a usable, offensive-capable act list. When static class data
## is unavailable (headless fixtures), grants cannot be resolved and the shape
## checks above stand alone.
func _loadoutResolvable(candidateMember: Dictionary) -> bool:
	var classData := _classDataFor(candidateMember)
	var projection = CombatLoadoutProjectorScript.project(candidateMember, classData)
	if !(projection.dropped as Array).is_empty() or !(projection.duplicated as Array).is_empty():
		return false
	var availableNames: Dictionary = projection.availableNames
	var active: Array = projection.active
	if availableNames.is_empty():
		# No resolvable grants: a class that declares no grant list cannot judge
		# the selection, but one that declares an empty list must not claim one.
		return true if !classData.has("moves") else active.is_empty()
	if active.is_empty():
		return false
	var offensiveAvailable := false
	for entryValue in projection.available:
		if CombatLoadoutProjectorScript.isOffensiveMove(str((entryValue as Dictionary).get("name", "")), movesData):
			offensiveAvailable = true
			break
	if offensiveAvailable and !CombatLoadoutProjectorScript.hasOffensiveMove(active, movesData):
		return false
	return true


## Legacy payload default: the member's canonical New Game selection.
func _canonicalMovesFor(memberKey: String) -> Array:
	var baselineParty: Dictionary = _newGameBaseline.get("party", {})
	var baselineMember = baselineParty.get(memberKey, null)
	if baselineMember is Dictionary:
		return _stringArray((baselineMember as Dictionary).get("moves", []))
	return _stringArray(party[memberKey].get("moves", []))


func _stringArray(value) -> Array:
	var names := []
	if value is Array:
		for entry in value:
			if typeof(entry) == TYPE_STRING and str(entry) != "":
				names.append(str(entry))
	return names


func _duplicateDictionary(value) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _duplicateArray(value) -> Array:
	return value.duplicate(true) if value is Array else []


func _stateFailure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason }

