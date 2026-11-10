extends RefCounted

## Stackable item definitions shared by generation, loot and inventory.
## Design source: Docs/System Design/Journal/Inventory and Equipment.md

const SUPPORTED_ITEM_TYPES = ["consumable", "resources"]

var definitions = {
	"paregoric": {
		"definitionId": "paregoric",
		"itemType": "consumable",
		"combatId": "Paregoric",
		"name": "Paregoric",
		"category": "supplies",
		"description": "Restores HP in a Shootout.",
		"stackLimit": 5,
		"droppable": true,
		"sprite": "res://Assets/Items/Paregoric.png",
	},
}


func validate() -> Array:
	var errors = []
	for key in definitions:
		var definition = definitions[key]
		var definitionId = str(definition.get("definitionId", ""))
		if definitionId == "" or definitionId != key:
			errors.append("item '%s': definitionId must match its key" % key)
		if !SUPPORTED_ITEM_TYPES.has(definition.get("itemType", "")):
			errors.append("item '%s': unsupported itemType" % key)
		if str(definition.get("name", "")) == "":
			errors.append("item '%s': missing name" % key)
		if str(definition.get("category", "")) == "":
			errors.append("item '%s': missing category" % key)
		if str(definition.get("description", "")) == "":
			errors.append("item '%s': missing description" % key)
		var stackLimit = definition.get("stackLimit", null)
		if typeof(stackLimit) != TYPE_INT or int(stackLimit) <= 0:
			errors.append("item '%s': stackLimit must be a positive integer" % key)
		if typeof(definition.get("droppable", null)) != TYPE_BOOL:
			errors.append("item '%s': droppable must be a Boolean" % key)
		var sprite = definition.get("sprite", "")
		if typeof(sprite) != TYPE_STRING:
			errors.append("item '%s': sprite must be a String" % key)
		elif sprite != "" and !ResourceLoader.exists(sprite):
			errors.append("item '%s': sprite does not exist" % key)
		if definition.get("itemType", "") == "consumable" and str(definition.get("combatId", "")) == "":
			errors.append("item '%s': consumable requires combatId" % key)
	return errors


func hasDefinition(definitionId: String) -> bool:
	return definitions.has(definitionId)


func getDefinition(definitionId: String) -> Dictionary:
	if !definitions.has(definitionId):
		return {}
	return definitions[definitionId].duplicate(true)


func makeStackable(definitionId: String, quantity: int) -> Dictionary:
	var definition = getDefinition(definitionId)
	if definition.is_empty():
		return {}
	definition["quantity"] = maxi(0, quantity)
	return definition
