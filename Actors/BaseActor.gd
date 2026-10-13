extends Node2D
class_name ActorBase

var actorName

var walkingSpeed
var runningSpeed

var hp
var maxHp

var stats = {
	"sixShootin": -1,
	"highTailin": -1,
	"taffyin": -1,
	"damage": {
		"lead": {
			"revolver": -1,
			"rifle": -1,
			"shotgun": -1
		},
		"explosive": {
			"gunpowder": -1,
			"liquid": -1,
			"shrapnel": -1
		},
		# Lassos ignore stats entirely (weapon base damage only); kept for data completeness.
		"lasso": 0
	},
	# Defensive damage types (Docs/Combat.md): Style and Sand.
	"defense": { "style": 0, "sand": 0 },
	# Percentage potency reduction, applied to bleed and poison (0.0-1.0).
	"resistances": { "bleed": 0.0, "poison": 0.0 }
}

var rodeo = null
var characterClass = null
var characterMagazine = null

# Fight loadout (Docs/System Design/Shootout/Moves Items and Ducks.md):
# activated moves (max 4) and the belt contents (capped by belt space).
var moves = []
var items = []

# Damage taken this fight; written back as journey injury at fight end.
var injuryDamage = 0

var weapon = {
	"type": null,
	"weapon": null,
	"baseDamage": 0
}
var equipment = {
	"hat": null,
	"jacket": null,
	"trousers": null,
	"boots": null
}


func init(actorData: Dictionary):
	actorName = actorData.actorName
	
	walkingSpeed = actorData.walkingSpeed
	runningSpeed = actorData.runningSpeed
	
	hp = actorData.hp
	maxHp = actorData.get("maxHp", actorData.hp)
	
	# Duplicated and defaulted so Shootout-time mutations never touch the source data.
	stats = actorData.stats.duplicate(true)
	stats["defense"] = actorData.stats.get("defense", { "style": 0, "sand": 0 })
	stats["resistances"] = actorData.stats.get("resistances", { "bleed": 0.0, "poison": 0.0 })
	if !stats.damage.has("lasso"):
		stats.damage["lasso"] = 0
	rodeo = actorData.rodeo
	characterClass = actorData.get("characterClass", null)
	characterMagazine = actorData.get("magazine", null)
	moves = actorData.get("moves", []).duplicate()
	items = actorData.get("items", []).duplicate()
	
	weapon = actorData.weapon.duplicate()
	if !weapon.has("baseDamage"):
		weapon["baseDamage"] = 2 if weapon.get("type") == "melee" else 0

## Enforces the 4-move cap and the belt space cap on the loadout. Belt space -1
## means no belt limit (class data unknown). Warns and truncates.
func applyLoadoutLimits(beltSpace := -1, moveCap := 4) -> void:
	if moves.size() > moveCap:
		push_warning("BaseActor: '{actorName}' has {count} moves, capping at {moveCap}".format({
			"actorName": actorName, "count": moves.size(), "moveCap": moveCap
		}))
		moves = moves.slice(0, moveCap)
	if beltSpace >= 0 and items.size() > beltSpace:
		push_warning("BaseActor: '{actorName}' has {count} items but only {beltSpace} belt space".format({
			"actorName": actorName, "count": items.size(), "beltSpace": beltSpace
		}))
		items = items.slice(0, beltSpace)
	#equipment = actorData.equipment
