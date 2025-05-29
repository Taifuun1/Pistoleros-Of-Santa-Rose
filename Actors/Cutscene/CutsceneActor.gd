extends Node2D

var actorName


func initCutsceneActor(actorType, actorNameInit, actorPosition, actorFlip, actorIdleAnimation):
	var animations = load("res://Animations/{actorType}/{actorName}Animations.tscn".format({ "actorType": actorType, "actorName": actorNameInit.capitalize().replace(" ", "") })).instantiate()
	animations.initAnimations(actorIdleAnimation)
	name = actorNameInit
	animations.name = actorNameInit
	position = actorPosition
	if actorFlip:
		animations.flipAnimation()
	animations.playAnimation(actorIdleAnimation)
	add_child(animations)
