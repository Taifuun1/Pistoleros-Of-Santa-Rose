extends OverworldActorBase


func initOverworldActor(actorName, actorType, actorPosition):
	var animations = load("res://Animations/Overworld/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.capitalize().replace(" ", "") })).instantiate()
	name = actorName + str(Overworld.overworldActorIdCount)
	animations.name = actorName
	animations.playAnimation("Idle")
	add_child(animations)
	
	position = actorPosition
