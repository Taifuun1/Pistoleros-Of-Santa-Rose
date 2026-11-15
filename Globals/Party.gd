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
		"items": ["Paregoric"],
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
			"fightData": _calculateStats(member),
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
	var beltValid = int(projected.get("beltSpace", -1)) < 0 or member.get("items", []).size() <= int(projected.beltSpace)
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
	if int(projected.get("beltSpace", -1)) >= 0 and member.get("items", []).size() > int(projected.beltSpace):
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
	return _calculateStats(party[actorName])


## Post-fight write-back: surviving HP, accumulated injuries, downed members
## gain knockout debuffs, one Shootout is consumed from existing debuffs, and
## fleeing costs every survivor a portion of MxHp. Loot application is returned
## for the end screen so capacity overflow cannot be lost silently.
func applyFightResults(results: Dictionary) -> Dictionary:
	var lootResult = {}
	var changed = false
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
	return { "loot": lootResult }


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
