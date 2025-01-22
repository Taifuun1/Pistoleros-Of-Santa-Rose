extends ActFight

@onready var fightActor = preload("res://Actors/Fight/FightActor.tscn")
@onready var damageNumber = preload("res://Nodes/Damage Number/DamageNumber.tscn")

signal actorDone

var outlineShader = load("res://Shaders/Outline.tres")

var playerHasControl = false

var fightActors = {
	"player team": {
		
	},
	"enemy team": {
		
	}
}

var turnOrder = []
var playerAction = false


func _ready():
	init(
		{
			"player team": {
				"Named People": {
					"Walker Langley": {
						"positions": [
							{
								"column": 1,
								"row": 1
							},
							{
								"column": 1,
								"row": 2
							},
							{
								"column": 1,
								"row": 3
							},
							#{
								#"column": 1,
								#"row": 4
							#},
							#{
								#"column": 2,
								#"row": 1
							#},
							#{
								#"column": 2,
								#"row": 2
							#},
							#{
								#"column": 2,
								#"row": 3
							#},
							#{
								#"column": 2,
								#"row": 4
							#},
							#{
								#"column": 3,
								#"row": 1
							#},
							#{
								#"column": 3,
								#"row": 2
							#},
							#{
								#"column": 3,
								#"row": 3
							#},
							#{
								#"column": 3,
								#"row": 4
							#},
							#{
								#"column": 4,
								#"row": 1
							#},
							#{
								#"column": 4,
								#"row": 2
							#},
							#{
								#"column": 4,
								#"row": 3
							#},
							#{
								#"column": 4,
								#"row": 4
							#}
						]
					}
				}
			},
			"enemy team": {
				"Animals": {
					"Squeky rat": {
						"positions": [
							{
								"column": 1,
								"row": 1
							},
							{
								"column": 1,
								"row": 2
							},
							{
								"column": 1,
								"row": 3
							},
							#{
								#"column": 1,
								#"row": 4
							#},
							#{
								#"column": 2,
								#"row": 1
							#},
							#{
								#"column": 2,
								#"row": 2
							#},
							#{
								#"column": 2,
								#"row": 3
							#},
							#{
								#"column": 2,
								#"row": 4
							#},
							#{
								#"column": 3,
								#"row": 1
							#},
							#{
								#"column": 3,
								#"row": 2
							#},
							#{
								#"column": 3,
								#"row": 3
							#},
							#{
								#"column": 3,
								#"row": 4
							#},
							#{
								#"column": 4,
								#"row": 1
							#},
							#{
								#"column": 4,
								#"row": 2
							#},
							#{
								#"column": 4,
								#"row": 3
							#},
							#{
								#"column": 4,
								#"row": 4
							#}
						]
					}
				}
			}
		}
	)

func init(actors: Dictionary):
	actorDone.connect(_on_actor_done)
	for actorSide in actors:
		for actorType in actors[actorSide]:
			for actorName in actors[actorSide][actorType]:
				var index = 0
				for actorPosition in actors[actorSide][actorType][actorName].positions:
					var newFightActor = fightActor.instantiate()
					var actorNameIndexed = "{actorName}{index}".format({ "actorName": actorName, "index": index})
					$Actors.add_child(newFightActor)
					if Party.party.has(actorName):
						$Actors.get_children()[$Actors.get_child_count() - 1].init(Party.party[actorName])
					else:
						$Actors.get_children()[$Actors.get_child_count() - 1].init(
							load("res://Data/Actors/{actorType}/{actorName}.gd".format(
								{ "actorType": actorType, "actorName": actorName.capitalize().replace(" ", "") }
							)
						).new().data)
					$Actors.get_children()[$Actors.get_child_count() - 1].initFightActor(
						actorType,
						actorNameIndexed,
						actorPosition,
						actorSide
					)
					$Actors.get_children()[$Actors.get_child_count() - 1].actorSelected.connect(selectActor.bind(actorNameIndexed))
					$Actors.get_children()[$Actors.get_child_count() - 1].get_node(actorNameIndexed).onAnimationFrameHit.connect(actorFrameHit)
					$Actors.get_children()[$Actors.get_child_count() - 1].get_node(actorNameIndexed).onNextAnimation.connect(manageAnimations)
					fightActors[actorSide][actorNameIndexed] = { "actorPosition": actorPosition }
					index += 1
	createTurnOrder()
	#selectActor()
	#setActorCharacterStats()
	#setActorCharacterItems()
	get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() })).actorTurn.emit()
	#playerHasControl = true
	processEnemyTurn()

func processEnemyTurn():
	var actorName = turnOrder.front()
	var actor = get_node("Actors/{actorName}".format({ "actorName": actorName }))
	actor.get_node(str(actor.name)).playAnimation("Melee", true, true)

func createTurnOrder():
	var actorsHighTailin = []
	for actorSide in fightActors:
		for actorName in fightActors[actorSide]:
			var actor = get_node("Actors/{actorName}".format({ "actorName": actorName }))
			actorsHighTailin.append({
				"actorName": actorName,
				"highTailin": actor.stats.highTailin
			})
	actorsHighTailin.sort_custom(HelperFunctions.sortToTurnOrder)
	var newTurnOrder = []
	for actor in actorsHighTailin:
		newTurnOrder.append(actor.actorName)
	turnOrder = newTurnOrder

func checkIfActorDead(actor) -> bool:
	if actor.hp <= 0:
		if turnOrder.has(actor.name):
			turnOrder.remove_at(turnOrder.find(actor.name))
		for actorSide in fightActors:
			if fightActors[actorSide].has(actor.name):
				fightActors[actorSide].erase(actor.name)
				break
		actor.queue_free()
		checkIfSideIsDead()
		return true
	return false

func checkIfSideIsDead():
	for fightSide in fightActors:
		if fightActors[fightSide].is_empty():
			turnOrder.clear()

func selectActor(actorName = fightActors["enemy team"].keys()[0]) -> void:
	if playerHasControl and playerAction and selectedAct != null:
		var actor = get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() }))
		selectedActor = actorName
		if selectedAct.type == "Attack":
			if Fight.checkIfActorIsOnSide(actorName, "player team", fightActors):
				return
			#actor.get_node(str(actor.name)).playAnimation("Shoot", true, true)
		elif selectedAct.type == "Abilities" or selectedAct.type == "Items":
			if (
				(
					selectedAct.type == "Items" and
					(
						(
							Fight.itemsData[selectedAct.name].side == "player" and
							Fight.checkIfActorIsOnSide(actorName, "enemy team", fightActors)
						) or
						(
							Fight.itemsData[selectedAct.name].side == "enemy" and
							Fight.checkIfActorIsOnSide(actorName, "player team", fightActors)
						)
					)
				) or
				(
					selectedAct.type == "Abilities" and
					(
						(
							Fight.abilitiesData[selectedAct.name].side == "player" and
							Fight.checkIfActorIsOnSide(actorName, "enemy team", fightActors)
						) or
						(
							Fight.abilitiesData[selectedAct.name].side == "enemy" and
							Fight.checkIfActorIsOnSide(actorName, "player team", fightActors)
						)
					)
				)
			):
				return
			if selectedAct.type == "Items":
				actor.items.erase(selectedAct.name)
				animations = Fight.itemsData[selectedAct.name].animations.duplicate(true)
			if selectedAct.type == "Abilities":
				animations = Fight.abilitiesData[selectedAct.name].animations.duplicate(true)
		$CanvasLayer/FightUI/VBoxContainer/CenterContainer.visible = false
		playerHasControl = false
		actor.actorTurn.emit()
		manageAnimations()

func isPlayerActing(actor):
	for actorName in fightActors["player team"]:
		if actorName == actor:
			return true
	return false

func createDamageNumber(damage, targetPosition):
	var newDamageNumber = damageNumber.instantiate()
	add_child(newDamageNumber)
	newDamageNumber.init(damage, "red", targetPosition)

func setActorCharacterStats():
	var actor = get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() }))
	$CanvasLayer/FightUI.setPlayerCharacterStats({
		"Name": actor.actorName,
		"HP": actor.hp
	}, {
		"SixShootin": actor.stats.sixShootin,
		"HighTailin": actor.stats.highTailin,
		"Taffyin": actor.stats.taffyin,
		"Revolver": actor.stats.damage.lead.revolver,
		"Rifle": actor.stats.damage.lead.rifle,
		"Shotgun": actor.stats.damage.lead.shotgun
	})

func setActorCharacterActs(actType: String):
	if actType == "Abilities":
		$CanvasLayer/FightUI.setPlayerCharacterActs(get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() })).abilities, actType)
	elif actType == "Items":
		$CanvasLayer/FightUI.setPlayerCharacterActs(get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() })).items, actType)

func manageAnimations():
	var actor = get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() }))
	if animations != null and animations.is_empty() and !selectedAct.type == "Attack":
		animations = null
		actorFrameHit()
		return
	if selectedAct.type == "Attack":
		if actor.weapon.weapon == "revolver":
			actor.get_node(str(actor.name)).playAnimation("Shoot Revolver", true, true)
		elif actor.weapon.weapon == "rifle":
			actor.get_node(str(actor.name)).playAnimation("Shoot Rifle", true, true)
		#actor.get_node(str(actor.name)).playAnimation("Shoot", true, true)
	elif selectedAct.type == "Abilities" or selectedAct.type == "Items":
		var animation = animations.pop_front()
		if animation.target == "selectedActor":
			actAnimation()
			#actor.get_node(str(actor.name)).playAnimation(, true, true)
		elif animation.target == "actingActor":
			if actor.weapon.weapon == "revolver":
				actor.get_node(str(actor.name)).playAnimation("Shoot Revolver", true, true)
			elif actor.weapon.weapon == "rifle":
				actor.get_node(str(actor.name)).playAnimation("Shoot Rifle", true, true)
			#actor.get_node(str(actor.name)).playAnimation(animation.animation, true, true)

func actAnimation():
	var animation = load("res://Animations/Fight/{actType}/{actName}.tscn".format({ "actType": selectedAct.type, "actName": selectedAct.name.replace(" ", "") }))
	var animationInstance = animation.instantiate()
	#animationInstance.position.y -= animations.get_node("AnimationSprite").sprite_frames.get_frame_texture(animations.get_node("AnimationSprite").animation, animations.get_node("AnimationSprite").frame).get_size().y / 2
	#animationInstance.position.y -= 40
	get_node("Actors/{actorName}".format({ "actorName": selectedActor })).add_child(animationInstance)
	animationInstance.tree_exited.connect(manageAnimations)
	animationInstance.playAnimation("Effect")

func actorFrameHit():
	if playerAction:
		if selectedAct.type == "Attack":
			damageTarget()
		elif selectedAct.type == "Abilities":
			actWithAbility(selectedAct.name)
		elif selectedAct.type == "Items":
			actWithItem(selectedAct.name)
	else:
		damageTarget()

func damageTarget():
	var actor = get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() }))
	var targetActorName
	if playerAction:
		targetActorName = selectedActor
	else:
		actor.actorTurn.emit()
		targetActorName = fightActors["player team"].keys()[randi() % fightActors["player team"].size()]
	var targetActor = get_node("Actors/{actorName}".format({ "actorName": targetActorName }))
	var damage
	if actor.weapon.type == "melee":
		damage = 2
	else:
		damage = actor.stats.damage[actor.weapon.type][actor.weapon.weapon]
	targetActor.hp -= damage
	createDamageNumber(damage, targetActor.position - Vector2(4, 24))
	doEndOfTurnCheck(targetActor)

func doEndOfTurnCheck(targetActor = get_node("Actors/{actorName}".format({ "actorName": selectedActor }))):
	if checkIfActorDead(targetActor):
		selectActor()
	turnOrder.pop_front()
	actorDone.emit()

func _on_fight_ui_attack() -> void:
	selectedAct = {
		"type": "Attack"
	}

func _on_fight_ui_ability(abilityName: String) -> void:
	selectedAct = {
		"name": abilityName,
		"type": "Abilities"
	}

func _on_fight_ui_item(itemName: String) -> void:
	selectedAct = {
		"name": itemName,
		"type": "Items"
	}

func _on_actor_done():
	if turnOrder.is_empty():
		createTurnOrder()
	get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() })).actorTurn.emit()
	if isPlayerActing(turnOrder.front()):
		playerAction = true
		setActorCharacterStats()
		playerHasControl = true
		return
	playerAction = false
	processEnemyTurn()
	playerHasControl = false
