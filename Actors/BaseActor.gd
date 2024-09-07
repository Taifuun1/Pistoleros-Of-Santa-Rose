extends Node2D
class_name ActorBase

var actorName

var walkingSpeed
var runningSpeed

var hp

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
		}
	}
}

var rodeo = null

var weapon = {
	"range": null,
	"type": null
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
	
	stats = actorData.stats
	rodeo = actorData.rodeo
	
	weapon = actorData.weapon
	#equipment = actorData.equipment
