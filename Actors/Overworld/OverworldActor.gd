extends OverworldActorBase

const AnimationServiceScript = preload("res://Globals/ActorAnimationService.gd")
const ShadowScript = preload("res://Nodes/Actor Shadow/ActorShadow.gd")


func initOverworldActor(actorName, actorType, actorPosition) -> bool:
	# Commit 19: overworld wanderers resolve through the shared registry
	# (normal maps included); the per-actor scenes are deleted. Unregistered
	# actors still fall back to a legacy scene inside the service, and
	# unresolvable actors skip the spawn with a warning instead of crashing.
	var animations = AnimationServiceScript.new().forActor(actorType, actorName, { "overworld": true })
	if animations == null:
		push_warning("OverworldActor: no animations for '{actorName}' ({actorType})".format({ "actorName": actorName, "actorType": actorType }))
		return false
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
