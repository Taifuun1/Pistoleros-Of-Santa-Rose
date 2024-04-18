extends Node2D

var actor
var actorName
var actorType
var spawnChance
var maximumSpawns

var actors = []


func init(initActorName, initActorType, initSpawnChance, initMaximumSpawns):
	actorName = initActorName
	actorType = initActorType
	spawnChance = initSpawnChance
	maximumSpawns = initMaximumSpawns
	actor = load("res://Actors/Overworld/{actorType}/{actorName}.tscn".format({ "actorType": actorType, "actorName": actorName }))

func checkForSpawn():
	if actors.size() < maximumSpawns and randi() % 100 < spawnChance:
		var newActor = actor.instantiate()
		newActor.name = Overworld.overworldActorIdCount
		actors.append(Overworld.overworldActorIdCount)
		Overworld.overworldActorIdCount += 1
		get_tree().current_scene.get_node("Actors/{actorType}".format({ "actorType": actorType })).add_child(newActor)
