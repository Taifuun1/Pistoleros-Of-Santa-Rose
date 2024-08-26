extends Node2D
class_name ActorBase

var actorName = ""

var walkingSpeed
var runningSpeed

var hp
var ap

var stats = {
	"sixShootin": -1,
	"highTailin": -1,
	"taffyin": -1
}
var weaponStats = {
	"revolver": -1,
	"rifle": -1,
	"explosive": -1
}
var meleeStats = {
	"punch": -1,
	"kick": -1,
	"scratch": -1
}

var perks = []

var wornWeapon = {
	"type": "revolver"
}


func init(actorData: Dictionary):
	actorName = actorData.actorName
	
	hp = actorData.hp
	ap = actorData.ap
	
	stats = actorData.stats
	weaponStats = actorData.weaponStats
	meleeStats = actorData.meleeStats
	
	wornWeapon = actorData.wornWeapon
