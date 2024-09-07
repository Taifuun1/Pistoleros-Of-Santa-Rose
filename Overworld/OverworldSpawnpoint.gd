extends Node2D

var actor
var actorName
var actorType
var spawnPoint
var spawnChance
var maximumSpawns

var actors = []


func init(initActorName, initActorType, initSpawnPoint, initSpawnChance, initMaximumSpawns):
	actorName = initActorName
	actorType = initActorType
	spawnPoint = initSpawnPoint
	spawnChance = initSpawnChance
	maximumSpawns = initMaximumSpawns
	#actor = load("res://Actors/Overworld/{actorType}/{actorName}.tscn".format({ "actorType": actorType, "actorName": actorName }))
	actor = load("res://Actors/Overworld/OverworldActor.tscn")

func checkForSpawn():
	if actors.size() < maximumSpawns and randi() % 100 < spawnChance:
		var newActor = actor.instantiate()
		#newActor.position = spawnPoint
		get_tree().current_scene.get_node("Actors/{actorType}".format({ "actorType": actorType })).add_child(newActor)
		newActor.initOverworldActor(actorName, actorType, spawnPoint)
		actors.append(actorName + str(Overworld.overworldActorIdCount))
		Overworld.overworldActorIdCount += 1


func _on_tree_exiting():
	for actorNameExitingTree in actors:
		get_tree().current_scene.get_node("Actors/{actorType}/{actorName}".format({ "actorType": actorType, "actorName": actorNameExitingTree })).queue_free()
