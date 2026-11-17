extends RefCounted
class_name CombatLoadoutProjector

## Single Move grant source -> active loadout projection (Docs/System Design/
## First Steps Implementation Plan.md, commit 11). Grants come from directly
## authored character moves, the class definition and equipped items; the active
## list is the member's selection filtered to available canonical ids and capped
## at four. Party owns the persistent selection; the Shootout only receives the
## resolved list. Keep this class pure: no autoload reads, no mutation of inputs.

const MOVE_CAP := 4
const ORIGIN_DIRECT := "direct"
const ORIGIN_CLASS := "class"
const ORIGIN_EQUIPMENT := "equipment"
## Equipment grant order: a stable slot order, never Dictionary iteration order.
const EQUIPMENT_SLOT_ORDER := ["weapon", "headwear", "bandana", "duster", "belt", "trousers", "justins"]


## Ordered, origin-annotated grants available to a member. Duplicate ids keep
## their first origin so an id is never listed twice.
static func availableMoves(member: Dictionary, classData: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var seen := {}
	for nameValue in _stringList(member.get("innateMoves", [])):
		_appendGrant(available, seen, nameValue, ORIGIN_DIRECT, "")
	for nameValue in _stringList(classData.get("moves", [])):
		_appendGrant(available, seen, nameValue, ORIGIN_CLASS, "")
	var equipment = member.get("equipment", {})
	if equipment is Dictionary:
		for slot in EQUIPMENT_SLOT_ORDER:
			var item = (equipment as Dictionary).get(slot, null)
			if !(item is Dictionary):
				continue
			for nameValue in _stringList((item as Dictionary).get("grantedMoves", [])):
				_appendGrant(available, seen, nameValue, ORIGIN_EQUIPMENT, slot)
	return available


## Projects a member to its available grants and active selection. No validation
## against the Move catalog happens here (the act pipeline owns authored Move
## data): this only resolves grants and the four-cap.
static func project(member: Dictionary, classData: Dictionary) -> Dictionary:
	return _projectSelection(member.get("moves", []), availableMoves(member, classData), classData.has("moves"))


## Same projection with one equipment slot replaced, so a swap can be validated
## before it mutates Party state.
static func projectWithEquipment(member: Dictionary, classData: Dictionary, slot: String, replacementItem) -> Dictionary:
	if slot == "":
		return project(member, classData)
	return _projectSelection(member.get("moves", []), availableMoves(_memberWithEquipment(member, slot, replacementItem), classData), classData.has("moves"))


## Final list for a directly authored actor (enemy content): authored moves
## first, then any class and equipment grants, capped. Direct actors keep their
## authored order, so this never reshuffles existing enemy content.
static func resolvedDirectMoves(actorData: Dictionary, classData: Dictionary) -> Array:
	var resolved := []
	var seen := {}
	for nameValue in _stringList(actorData.get("moves", [])):
		_appendUnique(resolved, seen, nameValue)
	for nameValue in _stringList(classData.get("moves", [])):
		_appendUnique(resolved, seen, nameValue)
	var equipment = actorData.get("equipment", {})
	if equipment is Dictionary:
		for slot in EQUIPMENT_SLOT_ORDER:
			var item = (equipment as Dictionary).get(slot, null)
			if !(item is Dictionary):
				continue
			for nameValue in _stringList((item as Dictionary).get("grantedMoves", [])):
				_appendUnique(resolved, seen, nameValue)
	return resolved.slice(0, MOVE_CAP)



## A Move that can reduce an enemy to zero: attack abilities and any authored
## damage Move. Used to refuse a loadout that could never finish a fight.
static func isOffensiveMove(moveId: String, movesData: Dictionary) -> bool:
	var moveData = movesData.get(moveId, null)
	if !(moveData is Dictionary):
		return false
	if str((moveData as Dictionary).get("category", "")) == "attack_ability":
		return true
	return int((moveData as Dictionary).get("baseAmount", 0)) > 0


static func hasOffensiveMove(active: Array, movesData: Dictionary) -> bool:
	for nameValue in _stringList(active):
		if isOffensiveMove(nameValue, movesData):
			return true
	return false


## Selected ids with no authored Move data, in selection order.
static func unknownMoveIds(names, movesData: Dictionary) -> Array:
	var unknown := []
	for nameValue in _stringList(names):
		if !movesData.has(nameValue):
			unknown.append(nameValue)
	return unknown


static func _projectSelection(selected, available: Array[Dictionary], classDeclaresGrants: bool) -> Dictionary:
	var availableNames := {}
	var origins := {}
	for entry in available:
		var entryName := str(entry.get("name", ""))
		availableNames[entryName] = true
		if !origins.has(entryName):
			origins[entryName] = str(entry.get("origin", ""))
	# Only a class that declares no grant list (legacy content or a headless
	# fixture) means the caller already owns the final list. A class that declares
	# its grants is authoritative, so a selection it does not grant is dropped.
	var unresolved := available.is_empty() and !classDeclaresGrants
	var active := []
	var dropped := []
	var duplicated := []
	for nameValue in _stringList(selected):
		if active.has(nameValue):
			duplicated.append(nameValue)
			continue
		if !unresolved and (!availableNames.has(nameValue) or active.size() >= MOVE_CAP):
			dropped.append(nameValue)
			continue
		if active.size() >= MOVE_CAP:
			dropped.append(nameValue)
			continue
		active.append(nameValue)
	return {
		"available": available,
		"availableNames": availableNames,
		"origins": origins,
		"active": active,
		"dropped": dropped,
		"duplicated": duplicated,
		"unresolved": unresolved,
		"cap": MOVE_CAP,
	}


## Deep-copied member with one equipment slot replaced (or cleared by null).
static func _memberWithEquipment(member: Dictionary, slot: String, replacementItem) -> Dictionary:
	var projected: Dictionary = member.duplicate(true)
	var equipment = projected.get("equipment", {})
	if !(equipment is Dictionary):
		equipment = {}
		projected["equipment"] = equipment
	equipment[slot] = replacementItem.duplicate(true) if replacementItem is Dictionary else null
	return projected


static func _appendGrant(available: Array[Dictionary], seen: Dictionary, moveId: String, origin: String, slot: String) -> void:
	if moveId == "" or seen.has(moveId):
		return
	seen[moveId] = true
	var entry := { "name": moveId, "origin": origin }
	if slot != "":
		entry["slot"] = slot
	available.append(entry)


static func _appendUnique(resolved: Array, seen: Dictionary, moveId: String) -> void:
	if moveId == "" or seen.has(moveId) or resolved.size() >= MOVE_CAP:
		return
	seen[moveId] = true
	resolved.append(moveId)


static func _stringList(value) -> Array:
	var names := []
	if value is Array:
		for entry in value:
			if typeof(entry) == TYPE_STRING and str(entry) != "":
				names.append(str(entry))
	return names
