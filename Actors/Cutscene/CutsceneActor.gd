extends Node2D

const AnimationServiceScript = preload("res://Globals/ActorAnimationService.gd")
const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")

var actorName


func initCutsceneActor(actorType, actorNameInit, actorPosition, actorFlip, actorIdleAnimation):
	# Commit 19: cutscene performers resolve through the shared registry
	# service; the per-actor legacy scenes are deleted.
	var animations = AnimationServiceScript.new().forActor(actorType, actorNameInit)
	if animations == null:
		push_warning("CutsceneActor: no animations for '{actorName}' ({actorType})".format({ "actorName": actorNameInit, "actorType": actorType }))
		return
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
