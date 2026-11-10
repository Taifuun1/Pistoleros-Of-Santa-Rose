extends Node

## Party state (Docs/System Design/Shootout/Death Injury and Retreat.md):
## one shared party level, persistent per-member HP, journey injuries, knockout
## debuffs and the money pouch. All fighters post-fight state flows through
## applyFightResults(). Inventories/equipment follow Docs/System Design/Journal/
## Inventory and Equipment.md.

signal inventoryChanged
signal equipmentChanged(memberKey: String)

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
var questInProgress = false

var _inventoryRules
var _statCalculator
var _itemCatalog
var _inventoryDataAvailable := false
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
	configureInventory(catalog, classDefinitions)


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


func isInventoryDataAvailable() -> bool:
	return _inventoryDataAvailable and _inventoryRules != null


func setInventoryManagementAllowed(allowed: bool) -> void:
	inventoryManagementAllowed = allowed


func getInventorySnapshot() -> Dictionary:
	var snapshot = {
		"capacity": INVENTORY_CAPACITY,
		"used": inventory.size(),
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
	for member in party.values():
		var debuffs = []
		for debuff in member.get("knockoutDebuffs", []):
			debuff["shootoutsLeft"] = int(debuff.get("shootoutsLeft", KNOCKOUT_SHOOTOUTS)) - 1
			if debuff.shootoutsLeft > 0:
				debuffs.append(debuff)
		member["knockoutDebuffs"] = debuffs
	if results.get("loot") is Dictionary:
		lootResult = applyLoot(results.loot)
	for actorName in results.get("party", {}):
		if !party.has(actorName):
			continue
		var state = results.party[actorName]
		var member = party[actorName]
		member["hp"] = maxi(0, int(state.get("hp", 0)))
		member["injuryDamage"] = int(member.get("injuryDamage", 0)) + int(state.get("injuryDamage", 0))
		member["downed"] = member.hp <= 0
		if member.downed:
			member["knockoutDebuffs"] = makeKnockoutDebuffs()
		if results.get("fled", false) and !member.downed:
			applyFleeCost(actorName)
	return { "loot": lootResult }


## Loot from a won fight (Docs/System Design/Shootout/Rewards.md): money goes
## to the pouch and items go through the capacity-aware inventory command. Money
## applies independently when item data is invalid.
func applyLoot(loot: Dictionary) -> Dictionary:
	var moneyAdded = int(loot.get("money", 0))
	money += moneyAdded
	var items = loot.get("items", [])
	var result = {}
	if items is Array:
		result = addItems(items)
	else:
		result = _addFailure("invalid_item")
	result["money"] = moneyAdded
	return result


func makeKnockoutDebuffs() -> Array:
	var debuffs = []
	for debuff in KNOCKOUT_DEBUFFS:
		debuffs.append({ "stat": debuff.stat, "amount": debuff.amount, "shootoutsLeft": KNOCKOUT_SHOOTOUTS })
	return debuffs


## Fleeing costs a portion of MxHp (modeled as journey injury).
func applyFleeCost(actorName: String) -> void:
	if !party.has(actorName):
		return
	var member = party[actorName]
	var base = int(_calculateStats(member).get("baseMaxHp", member.get("baseMaxHp", member.get("hp", 1))))
	var rate = maxi(1, int(member.get("injuryRate", DEFAULT_INJURY_RATE)))
	member["injuryDamage"] = int(member.get("injuryDamage", 0)) + int(ceil(base * FLEE_MXHP_LOSS * rate))


## Town entry: injuries reset.
func resetInjury() -> void:
	for member in party.values():
		member["injuryDamage"] = 0
		member["downed"] = false


## Camp items: reduce journey injuries.
func reduceInjury(amount: int) -> void:
	for member in party.values():
		member["injuryDamage"] = maxi(0, int(member.get("injuryDamage", 0)) - amount)


## Full party down: lose half of all loot (money pouch; the loot hook lands
## with Rewards) and return where the party is thrown to.
func vamoose() -> String:
	money = int(floor(money / 2.0))
	for member in party.values():
		member["downed"] = true
		member["knockoutDebuffs"] = makeKnockoutDebuffs()
	return "quest_checkpoint" if questInProgress else "town"
