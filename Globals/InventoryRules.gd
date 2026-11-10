extends RefCounted
class_name InventoryRules

## Pure inventory planning and projection rules (Docs/System Design/Journal/
## Inventory and Equipment.md). The helper never mutates its inputs and owns no
## state; Party commits a successful plan.

const GEAR_TYPES = ["weapon", "equipment"]
const STACKABLE_TYPES = ["consumable", "resources"]
const EQUIPMENT_SLOTS = [
	"weapon", "headwear", "bandana", "duster", "belt", "trousers", "justins",
]
const ARMOR_SLOTS = ["headwear", "bandana", "duster", "belt", "trousers", "justins"]


func planAdd(inventory: Array, items: Array, capacity: int, catalog, firstInstanceNumber: int) -> Dictionary:
	if catalog == null:
		return _failure("data_unavailable")
	if capacity <= 0:
		return _failure("invalid_capacity")
	if inventory.size() > capacity:
		return _failure("invalid_inventory")
	var inventoryIds = {}
	for entryValue in inventory:
		if !_isValidInventoryEntry(entryValue, catalog):
			return _failure("invalid_inventory")
		if inventoryIds.has(entryValue.instanceId):
			return _failure("invalid_inventory")
		inventoryIds[entryValue.instanceId] = true

	var normalizedItems = []
	for itemValue in items:
		if !(itemValue is Dictionary):
			return _failure("invalid_item")
		var normalized = _normalizeItem(itemValue, catalog)
		if normalized.is_empty():
			return _failure("invalid_item")
		normalizedItems.append(normalized)

	var working = inventory.duplicate(true)
	var accepted = []
	var acceptedIds = {}
	var acceptedIdOrder = []
	var overflow = []
	var nextInstanceNumber = maxi(1, firstInstanceNumber)

	for item in normalizedItems:
		var acceptedQuantity = 0
		var touchedIds = []
		if GEAR_TYPES.has(item.itemType):
			if working.size() < capacity:
				var instanceId = _allocateInstanceId(working, nextInstanceNumber, inventoryIds)
				nextInstanceNumber = _nextNumberAfter(instanceId, nextInstanceNumber)
				var entry = item.duplicate(true)
				entry["instanceId"] = instanceId
				working.append(entry)
				inventoryIds[instanceId] = true
				acceptedQuantity = 1
				touchedIds.append(instanceId)
			else:
				overflow.append(item.duplicate(true))
		else:
			var definition = catalog.getDefinition(item.definitionId)
			var stackLimit = int(definition.stackLimit)
			var remaining = int(item.quantity)
			for entry in working:
				if remaining <= 0:
					break
				if entry.itemType != item.itemType or entry.definitionId != item.definitionId:
					continue
				var moved = mini(remaining, maxi(0, stackLimit - int(entry.quantity)))
				if moved <= 0:
					continue
				entry["quantity"] = int(entry.quantity) + moved
				remaining -= moved
				acceptedQuantity += moved
				touchedIds.append(entry.instanceId)
			while remaining > 0 and working.size() < capacity:
				var moved = mini(remaining, stackLimit)
				var instanceId = _allocateInstanceId(working, nextInstanceNumber, inventoryIds)
				nextInstanceNumber = _nextNumberAfter(instanceId, nextInstanceNumber)
				working.append({
					"instanceId": instanceId,
					"definitionId": item.definitionId,
					"itemType": item.itemType,
					"quantity": moved,
				})
				inventoryIds[instanceId] = true
				remaining -= moved
				acceptedQuantity += moved
				touchedIds.append(instanceId)
			if remaining > 0:
				overflow.append({
					"definitionId": item.definitionId,
					"itemType": item.itemType,
					"quantity": remaining,
				})

		if acceptedQuantity > 0:
			for instanceId in touchedIds:
				if !acceptedIds.has(instanceId):
					acceptedIds[instanceId] = true
					acceptedIdOrder.append(instanceId)
			accepted.append({
				"definitionId": item.definitionId,
				"name": _displayName(item, catalog),
				"quantity": acceptedQuantity,
				"instanceIds": touchedIds.duplicate(),
			})

	return {
		"success": true,
		"reason": "",
		"inventory": working,
		"accepted": accepted,
		"acceptedInstanceIds": acceptedIdOrder,
		"overflow": overflow,
		"nextInstanceNumber": nextInstanceNumber,
	}


func inventoryIndex(inventory: Array, instanceId: String) -> int:
	for index in inventory.size():
		if str(inventory[index].get("instanceId", "")) == instanceId:
			return index
	return -1


func equipmentSlot(item: Dictionary) -> String:
	if item.get("itemType", "") == "weapon":
		return "weapon"
	if item.get("itemType", "") == "equipment" and ARMOR_SLOTS.has(item.get("slot", "")):
		return str(item.slot)
	return ""


func projectItem(item: Dictionary, catalog) -> Dictionary:
	if item.is_empty() or catalog == null:
		return {}
	var projected = item.duplicate(true)
	if GEAR_TYPES.has(item.get("itemType", "")):
		projected["stackLimit"] = 1
		projected["droppable"] = true
		return projected
	var definition = catalog.getDefinition(str(item.get("definitionId", "")))
	if definition.is_empty():
		return {}
	for key in ["name", "itemType", "category", "description", "stackLimit", "droppable", "sprite", "combatId"]:
		if definition.has(key):
			projected[key] = definition[key]
	return projected


func _normalizeItem(item: Dictionary, catalog) -> Dictionary:
	var itemType = str(item.get("itemType", ""))
	var definitionId = str(item.get("definitionId", ""))
	if definitionId == "":
		return {}
	var quantityValue = item.get("quantity", null)
	if typeof(quantityValue) != TYPE_INT or int(quantityValue) <= 0:
		return {}
	if GEAR_TYPES.has(itemType):
		if int(quantityValue) != 1:
			return {}
		var normalized = item.duplicate(true)
		normalized.erase("instanceId")
		normalized["definitionId"] = definitionId
		normalized["quantity"] = 1
		if equipmentSlot(normalized) == "":
			return {}
		if typeof(normalized.get("stats", null)) != TYPE_DICTIONARY:
			return {}
		if itemType == "weapon":
			if str(normalized.get("family", "")) == "":
				return {}
			if typeof(normalized.get("baseDamage", null)) != TYPE_INT:
				return {}
		return normalized
	if STACKABLE_TYPES.has(itemType):
		var definition = catalog.getDefinition(definitionId)
		if definition.is_empty() or definition.get("itemType", "") != itemType:
			return {}
		return {
			"definitionId": definitionId,
			"itemType": itemType,
			"quantity": int(quantityValue),
		}
	return {}


func _isValidInventoryEntry(value, catalog) -> bool:
	if !(value is Dictionary):
		return false
	var entry = value as Dictionary
	if str(entry.get("instanceId", "")) == "":
		return false
	var itemType = str(entry.get("itemType", ""))
	var definitionId = str(entry.get("definitionId", ""))
	if definitionId == "":
		return false
	var quantityValue = entry.get("quantity", null)
	if typeof(quantityValue) != TYPE_INT or int(quantityValue) <= 0:
		return false
	if GEAR_TYPES.has(itemType):
		return int(quantityValue) == 1 and _isValidGearEntry(entry)
	if STACKABLE_TYPES.has(itemType):
		var definition = catalog.getDefinition(definitionId)
		return !definition.is_empty() and definition.get("itemType", "") == itemType
	return false


func _isValidGearEntry(entry: Dictionary) -> bool:
	if equipmentSlot(entry) == "" or typeof(entry.get("stats", null)) != TYPE_DICTIONARY:
		return false
	if entry.itemType == "weapon":
		return str(entry.get("family", "")) != "" and typeof(entry.get("baseDamage", null)) == TYPE_INT
	return true


func _allocateInstanceId(inventory: Array, number: int, reserved: Dictionary) -> String:
	var candidateNumber = number
	while true:
		var candidate = "item_%d" % candidateNumber
		if inventoryIndex(inventory, candidate) < 0 and !reserved.has(candidate):
			return candidate
		candidateNumber += 1
	return ""


func _nextNumberAfter(instanceId: String, current: int) -> int:
	var number = int(instanceId.trim_prefix("item_"))
	return maxi(current, number + 1)


func _displayName(item: Dictionary, catalog) -> String:
	if GEAR_TYPES.has(item.get("itemType", "")):
		return str(item.get("name", item.get("baseName", item.get("definitionId", ""))))
	var definition = catalog.getDefinition(str(item.get("definitionId", "")))
	return str(definition.get("name", item.get("definitionId", "")))


func _failure(reason: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"inventory": [],
		"accepted": [],
		"acceptedInstanceIds": [],
		"overflow": [],
		"nextInstanceNumber": 0,
	}

