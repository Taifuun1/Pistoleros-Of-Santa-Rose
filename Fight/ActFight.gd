extends Node2D
class_name ActFight

signal actorDone

var selectedAct = null
var selectedActor = null
var targetType = "enemy"
var targetActors = {}
var animations = null


func actWithAbility(actName):
	match actName:
		"Sharp Shot":
			get_node("Actors/{actorName}".format({ "actorName": selectedActor })).hp -= Fight.abilitiesData[actName].baseAmount
	get_node(".").doEndOfTurnCheck()

func actWithItem(actName):
	match actName:
		"Paregoric":
			get_node("Actors/{actorName}".format({ "actorName": selectedActor })).hp += Fight.itemsData[actName].baseAmount
	get_node(".").doEndOfTurnCheck()
