extends Node2D

const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")

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
	# Drop shadow under the performer (see Nodes/Actor Shadow/ActorShadow.gd).
	ShadowScript.attachTo(animations)
