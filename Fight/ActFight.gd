extends Node2D
class_name ActFight

signal actorDone

var selectedActor = null
var targetType = "enemy"
var targetActors = {}


func actAnimation(actName, actType):
	var animation = load("res://Animations/Fight/{actType}/{actName}.tscn".format({ "actType": actType, "actName": actName }))
	var animationInstance = animation.instantiate()
	#animationInstance.position.y -= animations.get_node("AnimationSprite").sprite_frames.get_frame_texture(animations.get_node("AnimationSprite").animation, animations.get_node("AnimationSprite").frame).get_size().y / 2
	animationInstance.position.y -= 40
	get_node("Actors/{actorName}".format({ "actorName": selectedActor })).add_child(animationInstance)
	animationInstance.tree_exited.connect(actWithAbilityOrItem.bind(actName, actType, false))
	animationInstance.playAnimation("Effect")

func actWithAbilityOrItem(actName, actType, actAnimation = true):
	if actType == "Items":
		$CanvasLayer/FightUI/VBoxContainer/CenterContainer.visible = false
		if actAnimation:
			actAnimation(actName, actType)
			return
		actWithItem(actName)

func actWithItem(actName):
	match actName:
		"Paregoric":
			get_node("Actors/{actorName}".format({ "actorName": selectedActor })).hp += 4
	get_node(".").doEndOfTurnCheck()

func actOnCharacter():
	pass
