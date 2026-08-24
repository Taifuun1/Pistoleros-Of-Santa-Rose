extends Node2D
class_name ActShootout

var selectedAct = null
var selectedActor = null
var targetType = "enemy"
var targetActors = {}
var animations = null


func actWithAbility(actName):
	match actName:
		"Sharp Shot":
			get_node("Actors/{actorName}".format({ "actorName": selectedActor })).hp -= Shootout.abilitiesData[actName].baseAmount
	get_node(".").doEndOfTurnCheck()

func actWithItem(actName):
	match actName:
		"Paregoric":
			get_node("Actors/{actorName}".format({ "actorName": selectedActor })).hp += Shootout.itemsData[actName].baseAmount
	get_node(".").doEndOfTurnCheck()
