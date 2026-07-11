extends OverworldActorBase


func initOverworldActor(actorName, actorType, actorPosition):
	var animations = load("res://Animations/Overworld/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.capitalize().replace(" ", "") })).instantiate()
	name = actorName + str(Overworld.overworldActorIdCount)
	animations.name = actorName
	animations.playAnimation("Idle")
	add_child(animations)
	
	position = actorPosition


# Called by OverworldEventPopup when the player selects a choice.
# result is the result string defined in the event data.
func process_event_result(result: String) -> void:
	pass
