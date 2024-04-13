extends ActorBase


func initFightActor(actorType, actorName, actorPosition, actorSide):
	var animations = load("res://Animations/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorName.replace(" ", "") })).instantiate()
	animations.name = actorName
	if actorSide == "enemy team":
		animations.flipAnimation()
	animations.playAnimation("Idle")
	add_child(animations)
	
	position = Fight.fightPositions[actorSide][actorPosition.column][actorPosition.row]


