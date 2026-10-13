class_name ShootoutCylinderManager
extends RefCounted

## The Cylinder system (Docs/System Design/Shootout/Cylinders.md): builds each
## actor's final Cylinder from character/class/weapon Magazines, tracks the
## current Chamber, and decides hit quality for weapon attacks.

const WeaponDataScript = preload("res://Data/Items/WeaponData.gd")

# Hit quality ids 0-3 (Miss, Graze, Hit, Critical Hit); strings are special
# Chambers ("reload", "jammed") that bypass numeric quality entirely.
const CHAMBER_MISS = 0
const CHAMBER_GRAZE = 1
const CHAMBER_HIT = 2
const CHAMBER_CRITICAL = 3

# Damage multipliers per hit quality (placeholder values from Docs/Combat.md).
const CHAMBER_DAMAGE_MULT = [0.0, 0.5, 1.0, 1.5]

# Fallback when an actor has no Magazine data anywhere: a plain all-Hit cylinder.
const DEFAULT_CYLINDER = [2, 2, 2, 2]

const MIN_CYLINDER_LENGTH = 2
const MAX_CYLINDER_LENGTH = 6

var shootout
var classesData = {}
var weaponMagazines = {}

# actorName -> { cylinder, chamberIndex, characterMagazine, classMagazine,
#                weaponMagazine, modifier }
var cylinders = {}


func init(shootoutRoot) -> void:
	shootout = shootoutRoot
	# Resolved through the tree instead of the autoload identifiers so the
	# manager stays loadable in headless test runs, where autoloads don't exist.
	var shootoutGlobals = shootoutRoot.get_node_or_null("/root/Shootout")
	if shootoutGlobals != null:
		var loadedClasses = shootoutGlobals.get("classesData")
		if loadedClasses is Dictionary:
			classesData = loadedClasses
	var weaponData = WeaponDataScript.new()
	var loadedMagazines = weaponData.get("magazines")
	weaponMagazines = loadedMagazines.duplicate(true) if loadedMagazines is Dictionary else {}


func registerActor(actor) -> void:
	if actor == null:
		return
	var characterMagazine = actor.get("characterMagazine")
	var characterClass = actor.get("characterClass")
	var classMagazine = null
	if characterClass != null and classesData.has(characterClass):
		classMagazine = classesData[characterClass].get("magazine", null)
	var weaponMagazine = null
	if actor.get("weapon") != null and actor.weapon.get("weapon", null) != null:
		weaponMagazine = weaponMagazines.get(actor.weapon.weapon, null)
	cylinders[actor.name] = {
		"characterMagazine": characterMagazine if characterMagazine is Array else [],
		"classMagazine": classMagazine if classMagazine is Array else [],
		"weaponMagazine": weaponMagazine if weaponMagazine is Array else [],
		"modifier": null,
		"chamberIndex": 0,
		"cylinder": []
	}
	rebuild(actor.name)


func unregisterActor(actorName: String) -> void:
	cylinders.erase(actorName)


func hasCylinder(actorName: String) -> bool:
	return cylinders.has(actorName)


func getCylinder(actorName: String) -> Array:
	if cylinders.has(actorName):
		return cylinders[actorName].cylinder
	return []


func getChamberIndex(actorName: String) -> int:
	if cylinders.has(actorName):
		return cylinders[actorName].chamberIndex
	return 0


func currentChamber(actorName: String):
	var cylinder = getCylinder(actorName)
	if cylinder.is_empty():
		return null
	return cylinder[getChamberIndex(actorName)]


## Hit quality for the actor's next weapon attack: a special Chamber string
## passes through unchanged; numeric Chambers are raised by the Rodeo
## hit-quality floor (e.g. Natural Gunslinger: cannot Miss or Graze).
func hitQuality(actorName: String):
	var chamber = currentChamber(actorName)
	if chamber == null:
		return CHAMBER_HIT
	if chamber is String:
		return chamber
	return maxi(chamber, getHitQualityFloor(actorName))


func getHitQualityFloor(actorName: String) -> int:
	if shootout == null:
		return CHAMBER_MISS
	var rodeoManager = shootout.get("rodeoManager")
	if rodeoManager == null or !rodeoManager.has_method("getHitQualityFloor"):
		return CHAMBER_MISS
	var actor = shootout.getActor(actorName) if shootout.has_method("getActor") else null
	return int(rodeoManager.getHitQualityFloor(actor))


## Only weapon attacks and attack abilities advance the Cylinder; the move is
## spent either way (Reload/Jammed consume it without attacking).
func advance(actorName: String) -> void:
	if !cylinders.has(actorName):
		return
	var entry = cylinders[actorName]
	var length = entry.cylinder.size()
	if length == 0:
		return
	entry.chamberIndex = (entry.chamberIndex + 1) % length


## The Cylinder effect type (Docs/Combat.md): one active modifier at a time;
## applying a new one replaces the previous. The modifier never changes special
## Chambers, and is re-derived from the source Magazines so it never compounds.
func applyCylinderModifier(actorName: String, modifier: Dictionary) -> void:
	if !cylinders.has(actorName):
		return
	cylinders[actorName].modifier = modifier
	rebuild(actorName)


func clearCylinderModifier(actorName: String) -> void:
	if !cylinders.has(actorName):
		return
	cylinders[actorName].modifier = null
	rebuild(actorName)


func rebuild(actorName: String) -> void:
	if !cylinders.has(actorName):
		return
	var entry = cylinders[actorName]
	entry.cylinder = buildCylinder(entry.weaponMagazine, entry.classMagazine, entry.characterMagazine, entry.modifier)
	if entry.chamberIndex >= entry.cylinder.size():
		entry.chamberIndex = 0


## Sums the three Magazines slot-by-slot (weapon > class > character priority
## for special Chambers), clamps numerics to 0-3 and applies the optional
## modifier ({ "chambers": "all" | [indices], "amount": int }).
static func buildCylinder(weaponMagazine: Array, classMagazine: Array, characterMagazine: Array, modifier = null) -> Array:
	var sources = [weaponMagazine, classMagazine, characterMagazine]
	var hasContent = false
	var length = MIN_CYLINDER_LENGTH
	for source in sources:
		if !source.is_empty():
			hasContent = true
		length = maxi(length, source.size())
	length = clampi(length, MIN_CYLINDER_LENGTH, MAX_CYLINDER_LENGTH)
	if !hasContent:
		return DEFAULT_CYLINDER.duplicate()
	var cylinder = []
	for i in length:
		var special = null
		var numeric = 0
		for source in sources:
			if i >= source.size():
				continue
			var value = source[i]
			if value is String:
				if special == null:
					special = value
			else:
				numeric += int(value)
		var finalValue
		if special != null:
			finalValue = special
		else:
			finalValue = clampi(numeric, CHAMBER_MISS, CHAMBER_CRITICAL)
			if modifier != null and modifierAppliesTo(modifier, i):
				finalValue = clampi(finalValue + int(modifier.get("amount", 0)), CHAMBER_MISS, CHAMBER_CRITICAL)
		cylinder.append(finalValue)
	return cylinder


static func modifierAppliesTo(modifier: Dictionary, index: int) -> bool:
	var chambers = modifier.get("chambers", "all")
	if chambers is Array:
		return index in chambers
	# Compare same types only: mixed-type equality (e.g. Array == String) is a
	# runtime error, so handle the "all" string case behind a type check.
	if chambers is String:
		return chambers == "all"
	return false
