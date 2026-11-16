extends Node

## Party state (Docs/System Design/Shootout/Death Injury and Retreat.md):
## one shared party level, persistent per-member HP, journey injuries, knockout
## debuffs and the money pouch. All fighters post-fight state flows through
## applyFightResults(). Inventories/equipment follow Docs/System Design/Journal/
## Inventory and Equipment.md.

signal inventoryChanged
signal moneyChanged
signal equipmentChanged(memberKey: String)
## Empty memberKey means the whole party changed (fight results, town reset, Vamoose).
signal partyChanged(memberKey: String)

const InventoryRulesScript = preload("res://Globals/InventoryRules.gd")
const CharacterStatCalculatorScript = preload("res://Globals/CharacterStatCalculator.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const INVENTORY_CAPACITY = 24
## Belt entries reference a carried consumable stack. Enemy actor belts are
## separate content and stay name-based.
const RESERVABLE_ITEM_TYPES = ["consumable"]

# Placeholder: MxHP portion lost when fleeing a fight.
const FLEE_MXHP_LOSS = 0.2
# Placeholder: knockout debuff duration in Shootouts.
const KNOCKOUT_SHOOTOUTS = 3
# Placeholder: HP lost per point of MxHP lost to injuries.
const DEFAULT_INJURY_RATE = 4

# Knockout debuff package applied when a member goes down (placeholders).
const KNOCKOUT_DEBUFFS = [
	{ "stat": "highTailin", "amount": -2 },
	{ "stat": "sixShootin", "amount": -1 }
]

var level = 1
var money = 0
var inventory = [{
	"instanceId": "starter_paregoric",
	"definitionId": "paregoric",
	"itemType": "consumable",
	"quantity": 1,
}]
var inventoryManagementAllowed := false
var classesData = {}
var rodeosData = {}
var questInProgress = false

var _inventoryRules
var _statCalculator
var _itemCatalog
var _inventoryDataAvailable := false
var _characterDataAvailable := false
var _nextInstanceNumber := 1

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
		"knockoutDebuffs": [],
		"downed": false,
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


func _ready() -> void:
	var catalog = ItemCatalogScript.new()
	var shootoutGlobals = get_node_or_null("/root/Shootout")
	var classDefinitions = shootoutGlobals.classesData if shootoutGlobals != null else {}
	var rodeoDefinitions = shootoutGlobals.rodeosData if shootoutGlobals != null else {}
	configureInventory(catalog, classDefinitions)
	configureCharacterData(classDefinitions, rodeoDefinitions)


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
## immutable class/Rodeo read data independently of inventory availability.
func configureCharacterData(classDefinitions: Dictionary, rodeoDefinitions: Dictionary) -> void:
	_ensureStatCalculator()
	classesData = classDefinitions.duplicate(true)
	rodeosData = rodeoDefinitions.duplicate(true)
	_characterDataAvailable = true


func isCharacterDataAvailable() -> bool:
	return _characterDataAvailable and _statCalculator != null


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
		var projection = _statCalculator.projectCharacter(member, _classDataFor(member))
		if !(projection is Dictionary) or !(projection.get("statRows", null) is Array) or !(projection.get("modifiers", null) is Array):
			push_warning("Party: ignored invalid character projection for '%s'." % key)
			continue
		snapshot.members.append({
			"key": key,
			"actorName": str(member.get("actorName", key)),
			"characterClass": str(member.get("characterClass", "")),
			"downed": bool(member.get("downed", false)),
			"hp": int(projection.get("hp", 0)),
			"maxHp": int(projection.get("maxHp", 0)),
			"statRows": projection.get("statRows", []).duplicate(true),
			"modifiers": projection.get("modifiers", []).duplicate(true),
			"rodeo": _projectRodeo(member.get("rodeo", null)),
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
	return {
		"success": true,
		"reason": "" if beltValid else "belt_loadout_too_large",
		"memberKey": memberKey,
		"slot": slot,
		"current": current,
		"projected": projected,
		"deltas": _statCalculator.compare(current, projected),
		"beltValid": beltValid,
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
	return _statCalculator.calculate(member, _classDataFor(member), replacementSlot, replacementItem)


func _classDataFor(member: Dictionary) -> Dictionary:
	var classData = classesData.get(member.get("characterClass", ""), {})
	return classData if classData is Dictionary else {}


func _ensureStatCalculator() -> void:
	if _statCalculator == null:
		_statCalculator = CharacterStatCalculatorScript.new()


## Effective max HP: base minus journey injuries, never below 1.
func effectiveMaxHp(member: Dictionary) -> int:
	return int(_calculateStats(member).get("maxHp", 1))


## The member's data prepared for a fight: effective MxHp, HP capped to it,
## equipment modifiers, and knockout debuffs applied to a copied stats block.
func getFightData(actorName: String) -> Dictionary:
	if !party.has(actorName):
		return {}
	return _fightDataFor(party[actorName])


## Post-fight write-back: surviving HP, accumulated injuries, downed members
## gain knockout debuffs, one Shootout is consumed from existing debuffs, and
## fleeing costs every survivor a portion of MxHp. Loot application is returned
## for the end screen so capacity overflow cannot be lost silently.
func applyFightResults(results: Dictionary) -> Dictionary:
	var lootResult = {}
	var beltResult = _commitBeltConsumption(results.get("beltConsumed", []))
	var changed = false
	if _reconcileBeltReservations():
		changed = true
	for member in party.values():
		var debuffs = []
		for debuff in member.get("knockoutDebuffs", []):
			debuff["shootoutsLeft"] = int(debuff.get("shootoutsLeft", KNOCKOUT_SHOOTOUTS)) - 1
			changed = true
			if debuff.shootoutsLeft > 0:
				debuffs.append(debuff)
		member["knockoutDebuffs"] = debuffs
	if results.get("loot") is Dictionary:
		lootResult = applyLoot(results.loot)
	for actorName in results.get("party", {}):
		if !party.has(actorName):
			continue
		changed = true
		var state = results.party[actorName]
		var member = party[actorName]
		member["hp"] = maxi(0, int(state.get("hp", 0)))
		member["injuryDamage"] = int(member.get("injuryDamage", 0)) + int(state.get("injuryDamage", 0))
		member["downed"] = member.hp <= 0
		if member.downed:
			member["knockoutDebuffs"] = makeKnockoutDebuffs()
		if results.get("fled", false) and !member.downed:
			_applyFleeCost(actorName)
	if changed:
		partyChanged.emit("")
	return { "loot": lootResult, "belt": beltResult }


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


func makeKnockoutDebuffs() -> Array:
	var debuffs = []
	for debuff in KNOCKOUT_DEBUFFS:
		debuffs.append({ "stat": debuff.stat, "amount": debuff.amount, "shootoutsLeft": KNOCKOUT_SHOOTOUTS })
	return debuffs


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


## Town entry: injuries reset.
func resetInjury() -> void:
	var changed = false
	for member in party.values():
		if int(member.get("injuryDamage", 0)) != 0 or bool(member.get("downed", false)):
			changed = true
		member["injuryDamage"] = 0
		member["downed"] = false
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


## Full party down: lose half of all loot (money pouch; the loot hook lands
## with Rewards) and return where the party is thrown to.
func vamoose() -> String:
	var moneyBefore = money
	money = int(floor(money / 2.0))
	var changed = false
	for member in party.values():
		changed = true
		member["downed"] = true
		member["knockoutDebuffs"] = makeKnockoutDebuffs()
	if changed:
		partyChanged.emit("")
	if money != moneyBefore:
		moneyChanged.emit()
	return "quest_checkpoint" if questInProgress else "town"
