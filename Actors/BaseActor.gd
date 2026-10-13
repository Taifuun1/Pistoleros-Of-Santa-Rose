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
	
	weapon = actorData.weapon.duplicate()
	if !weapon.has("baseDamage"):
		weapon["baseDamage"] = 2 if weapon.get("type") == "melee" else 0
	#equipment = actorData.equipment
