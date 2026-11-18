extends RefCounted

## Stackable item definitions shared by generation, loot and inventory.
## Design source: Docs/System Design/Journal/Inventory and Equipment.md

const SUPPORTED_ITEM_TYPES = ["consumable", "resources", "map"]

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
	"multi_heal": {
		"definitionId": "multi_heal",
		"itemType": "consumable",
		"combatId": "multiHeal",
		"name": "Doctor's Kit",
		"category": "supplies",
		"description": "Heals every living party member during a Shootout.",
		"stackLimit": 3,
		"droppable": true,
		"sprite": "",
	},
	"gold_nugget": {
		"definitionId": "gold_nugget",
		"itemType": "resources",
		"name": "Gold Nugget",
		"category": "treasure",
		"description": "A heavy nugget of cache gold. Proof the old stories were true.",
		"stackLimit": 5,
		"droppable": true,
		"sprite": "",
	},
	"canyon_cache_map": {
		"definitionId": "canyon_cache_map",
		"itemType": "map",
		"name": "Canyon Cache Map",
		"category": "maps",
		"description": "Reveals the hidden Gold Run on the Overworld map.",
		"stackLimit": 1,
		"droppable": true,
		"sprite": "res://Assets/Journal/MapIcon.png",
		"effect": { "kind": "reveal_map", "mapId": "canyon_cache_map" },
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
		if definition.get("itemType", "") == "map":
			var effect = definition.get("effect", null)
			if !(effect is Dictionary):
				errors.append("item '%s': map requires an effect Dictionary" % key)
			else:
				if str(effect.get("kind", "")) != "reveal_map":
					errors.append("item '%s': unsupported map effect kind" % key)
				if str(effect.get("mapId", "")) == "":
					errors.append("item '%s': reveal_map requires mapId" % key)
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
