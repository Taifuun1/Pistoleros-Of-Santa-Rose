extends Node2D

@onready var fightActor = preload("res://Actors/Fight/FightActor.tscn")
@onready var damageNumber = preload("res://Nodes/Damage Number/DamageNumber.tscn")

var outlineShader = load("res://Shaders/Outline.tres")

signal actorDone

var fightActors = {
	"player team": {
		
	},
	"enemy team": {
		
	}
}

var turnOrder = []
var playerAction = true
var selectedActor = null


func _ready():
	init(
		{
			"player team": {
				"Named People": {
					"Walker Langley": {
						"positions": [
							#{
								#"column": 1,
								#"row": 1
							#},
							{
								"column": 1,
								"row": 2
							},
							#{
								#"column": 1,
								#"row": 3
							#},
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
							{
								"column": 1,
								"row": 4
							},
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
					fightActors[actorSide][actorNameIndexed] = { "actorPosition": actorPosition }
					index += 1
	createTurnOrder()
	selectActor()

func _process(_delta):
	if !playerAction:
		processEnemyTurn()

func processEnemyTurn():
	var actorName = turnOrder.pop_front()
	var actor = get_node("Actors/{actorName}".format({ "actorName": actorName }))
	var targetActorName = fightActors["player team"].keys()[randi() % fightActors["player team"].size()]
	var targetActor = get_node("Actors/{actorName}".format({ "actorName": targetActorName }))
	var damage = actor.meleeStats.scratch
	targetActor.hp -= damage
	createDamageNumber(damage, targetActor.position - Vector2(4, 24))
	checkIfActorDead(targetActor)
	actorDone.emit()

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
			set_process(false)
			

func selectActor(actorName = fightActors["enemy team"].keys()[0]) -> void:
	if selectedActor != null:
		get_node("Actors/{actorName}/{actorName}/AnimationSprite".format({ "actorName": selectedActor })).material = null
	selectedActor = actorName
	get_node("Actors/{actorName}/{actorName}/AnimationSprite".format({ "actorName": selectedActor })).material = outlineShader

func isPlayerActing(actor):
	for actorName in fightActors["player team"]:
		if actorName == actor:
			return true
	return false

func createDamageNumber(damage, targetPosition):
	var newDamageNumber = damageNumber.instantiate()
	add_child(newDamageNumber)
	newDamageNumber.init(damage, "red", targetPosition)

func actorFrameHit():
	var actor = get_node("Actors/{actorName}".format({ "actorName": turnOrder.pop_front() }))
	var targetActor = get_node("Actors/{actorName}".format({ "actorName": selectedActor }))
	var damage = actor.weaponStats.revolver
	targetActor.hp -= damage
	createDamageNumber(damage, targetActor.position - Vector2(4, 24))
	if checkIfActorDead(targetActor):
		selectActor()
	actorDone.emit()


func _on_fight_ui_attack():
	if selectedActor == null:
		selectActor()
	if playerAction:
		var actor = get_node("Actors/{actorName}".format({ "actorName": turnOrder.front() }))
		actor.get_node(str(actor.name)).playAnimation("Draw", true, true)

func _on_actor_done():
	if turnOrder.is_empty():
		createTurnOrder()
	if isPlayerActing(turnOrder.front()):
		playerAction = true
		return
	playerAction = false
