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
		# The "Actors/<type>" container can be missing (chunk data naming a type
		# the overworld scene has no node for) or the scene can be mid-transition
		# on this tick; spawning into a null parent crashed the add_child below.
		var actorsRoot = _actorsRoot()
		if actorsRoot == null:
			return
		var newActor = actor.instantiate()
		#newActor.position = spawnPoint
		actorsRoot.add_child(newActor)
		# A missing animations scene (new actor type without one) aborts the
		# actor instead of crashing initOverworldActor's load().instantiate().
		if !newActor.initOverworldActor(actorName, actorType, spawnPoint):
			newActor.queue_free()
			return
		actors.append(newActor.name)
		Overworld.overworldActorIdCount += 1


## The "Actors/<type>" container spawned actors parent under. Null (with a
## warning) when there is no current scene or no node for this actor type.
func _actorsRoot():
	var currentScene = get_tree().current_scene
	if currentScene == null:
		push_warning("OverworldSpawnpoint: no current scene to spawn '{actorName}' into".format({ "actorName": actorName }))
		return null
	var actorsRoot = currentScene.get_node_or_null("Actors/{actorType}".format({ "actorType": actorType }))
	if actorsRoot == null:
		push_warning("OverworldSpawnpoint: no 'Actors/{actorType}' node to spawn '{actorName}' into".format({ "actorType": actorType, "actorName": actorName }))
		return null
	return actorsRoot


func _on_tree_exiting():
	for actorNameExitingTree in actors:
		# The actor may already be freed (consumed by an event, or freed by a
		# sibling spawnpoint exiting first); get_node here crashed on those.
		var currentScene = get_tree().current_scene
		if currentScene == null:
			return
		var exitingActor = currentScene.get_node_or_null("Actors/{actorType}/{actorName}".format({ "actorType": actorType, "actorName": actorNameExitingTree }))
		if exitingActor != null:
			exitingActor.queue_free()
