extends OverworldActorBase

const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")


func initOverworldActor(actorName, actorType, actorPosition) -> bool:
	var animationsPath = "res://Animations/Overworld/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.capitalize().replace(" ", "") })
	# New actor types without an animations scene aborted the spawn with
	# load() returning null; skip the actor with a warning instead.
	if !ResourceLoader.exists(animationsPath):
		push_warning("OverworldActor: no animations scene at '{animationsPath}' for '{actorName}'".format({ "animationsPath": animationsPath, "actorName": actorName }))
		return false
	var animations = load(animationsPath).instantiate()
	name = actorName + str(Overworld.overworldActorIdCount)
	animations.name = actorName
	animations.playAnimation("Idle")
	add_child(animations)
	# Drop shadow under the wanderer (see Nodes/Actor Shadow/ActorShadow.gd).
	ShadowScript.attachTo(animations)
	
	position = actorPosition
	return true


# Called by OverworldEventPopup when the player selects a choice.
# result is the result string defined in the event data.
func process_event_result(result: String) -> void:
	pass
