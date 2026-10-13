extends Node2D


signal actorDone
signal shootoutEnded(winningSide)

const ShootoutActorScene = preload("res://Actors/Shootout/ShootoutActor.tscn")
const DamageNumberScene = preload("res://Nodes/Damage Number/DamageNumber.tscn")
const EncounterData = preload("res://Data/Shootout/Encounters/RatAmbush.gd")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")
const AnimationSequencerScript = preload("res://Shootout/ShootoutAnimationSequencer.gd")
const EnemyAIScript = preload("res://Shootout/ShootoutEnemyAI.gd")
const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")
const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")

@onready var actorsRoot = $Actors
@onready var ui = $CanvasLayer/ShootoutUI

var turnManager
var targetingManager
var actionResolver
var animationSequencer
var enemyAI
var rodeoManager
var cylinderManager

var selectedAct = null
var selectedActor = ""
var playerHasControl = false
var playerAction = false
var battleOver = false
var pendingResolution = false


func _ready() -> void:
	turnManager = TurnManagerScript.new()
	turnManager.init(self)
	turnManager.battleEnded.connect(_on_battle_ended)
	targetingManager = TargetingManagerScript.new()
	targetingManager.init(turnManager)
	actionResolver = ActionResolverScript.new()
	actionResolver.init(self)
	enemyAI = EnemyAIScript.new()
	rodeoManager = RodeoManagerScript.new()
	rodeoManager.init(self)
	cylinderManager = CylinderManagerScript.new()
	cylinderManager.init(self)
	animationSequencer = AnimationSequencerScript.new()
	add_child(animationSequencer)
	animationSequencer.frameHit.connect(resolveActOnce)
	animationSequencer.sequenceDone.connect(resolveActOnce)
	ui.attack.connect(_on_shootout_ui_attack)
	ui.move.connect(_on_shootout_ui_move)
	ui.item.connect(_on_shootout_ui_item)
	ui.moveActsRequested.connect(_on_shootout_ui_move_acts_requested)
	ui.itemActsRequested.connect(_on_shootout_ui_item_acts_requested)
	actorDone.connect(_on_actor_done)
	init(EncounterData.new().data)


func init(actors: Dictionary) -> void:
	for actorSide in actors:
		for actorType in actors[actorSide]:
			for actorName in actors[actorSide][actorType]:
				var index = 0
				for actorPosition in actors[actorSide][actorType][actorName].positions:
					spawnActor(actorSide, actorType, actorName, actorPosition, index)
					index += 1
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_FIGHT_START)
	turnManager.createTurnOrder()
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
	startCurrentTurn()

func spawnActor(actorSide: String, actorType: String, actorName: String, actorPosition, index: int) -> void:
	var newShootoutActor = ShootoutActorScene.instantiate()
	var actorNameIndexed = "{actorName}{index}".format({ "actorName": actorName, "index": index })
	actorsRoot.add_child(newShootoutActor)
	if Party.party.has(actorName):
		newShootoutActor.init(Party.party[actorName])
	else:
		newShootoutActor.init(load("res://Data/Actors/{actorType}/{actorName}.gd".format({
			"actorType": actorType,
			"actorName": actorName.capitalize().replace(" ", "")
		})).new().data)
	newShootoutActor.initShootoutActor(actorType, actorNameIndexed, actorPosition, actorSide)
	newShootoutActor.actorSelected.connect(selectActor.bind(actorNameIndexed))
	newShootoutActor.actorHovered.connect(showHoveredActorStats.bind(actorNameIndexed))
	newShootoutActor.actorUnhovered.connect(clearHoveredActorStats)
	newShootoutActor.getAnimations().onAnimationFrameHit.connect(animationSequencer._on_acting_frame_hit)
	turnManager.registerActor(actorSide, actorNameIndexed, actorPosition)
	rodeoManager.registerActor(newShootoutActor, actorSide, actorPosition)
	cylinderManager.registerActor(newShootoutActor)

func getActor(actorName: String) -> Node:
	if actorName == "":
		return null
	return actorsRoot.get_node_or_null(actorName)

func startCurrentTurn() -> void:
	var actorName = turnManager.currentActorName()
	var actor = getActor(actorName)
	if actor == null:
		return
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_TURN_START, { "actor": actor })
	actor.actorTurn.emit()
	if turnManager.isPlayerActing(actorName):
		playerAction = true
		playerHasControl = true
		ui.playerHasControl = true
		setActorCharacterStats(actorName)
	else:
		playerAction = false
		playerHasControl = false
		ui.playerHasControl = false
		executeEnemyTurn(actor)

func executeEnemyTurn(actor) -> void:
	pendingResolution = true
	animationSequencer.play([{ "target": "actingActor" }], actor)

func selectActor(actorName: String = "") -> void:
	if !playerHasControl or !playerAction or selectedAct == null:
		return
	var actingActorName = turnManager.currentActorName()
	if !targetingManager.isValidTarget(selectedAct, actorName, actingActorName):
		return
	var actingActor = getActor(actingActorName)
	selectedActor = actorName
	if selectedAct.type == Shootout.ACT_TYPE_ITEMS:
		actingActor.items.erase(selectedAct.name)
	ui.hideActsPanel()
	playerHasControl = false
	ui.playerHasControl = false
	actingActor.actorTurn.emit()
	pendingResolution = true
	animationSequencer.play(buildActSteps(), actingActor, getActor(selectedActor))

func buildActSteps() -> Array:
	match selectedAct.type:
		Shootout.ACT_TYPE_MOVES:
			return Shootout.movesData[selectedAct.name].get("animations", [])
		Shootout.ACT_TYPE_ITEMS:
			return Shootout.itemsData[selectedAct.name].get("animations", [])
	return [{ "target": "actingActor" }]

func resolveActOnce() -> void:
	if !pendingResolution or battleOver:
		return
	pendingResolution = false
	var actingActor = getActor(turnManager.currentActorName())
	if actingActor == null:
		return
	var targetActor
	if playerAction:
		targetActor = getActor(selectedActor)
		if targetActor == null:
			finishTurn(null)
			return
		match selectedAct.type:
			Shootout.ACT_TYPE_ATTACK:
				actionResolver.resolveAttack(actingActor, targetActor)
			Shootout.ACT_TYPE_MOVES:
				actionResolver.resolveMove(selectedAct.name, actingActor, targetActor)
			Shootout.ACT_TYPE_ITEMS:
				actionResolver.resolveItem(selectedAct.name, actingActor, targetActor)
	else:
		targetActor = getActor(enemyAI.chooseTarget(turnManager.shootoutActors))
		if targetActor == null:
			return
		actingActor.actorTurn.emit()
		actionResolver.resolveAttack(actingActor, targetActor)
	finishTurn(targetActor)

func finishTurn(targetActor) -> void:
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_TURN_END, {
		"actor": getActor(turnManager.currentActorName()),
		"target": targetActor
	})
	if targetActor != null:
		turnManager.checkActorDead(targetActor)
	turnManager.advanceTurn()
	selectedAct = null
	selectedActor = ""
	actorDone.emit()

func _on_actor_done() -> void:
	if battleOver:
		return
	if turnManager.turnOrder.is_empty():
		rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_END)
		turnManager.createTurnOrder()
		rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
	startCurrentTurn()

func _on_battle_ended(winningSide: String) -> void:
	battleOver = true
	playerHasControl = false
	ui.playerHasControl = false
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_FIGHT_END, { "winningSide": winningSide })
	print("Rodeo loot modifiers: ", rodeoManager.consumeLootModifiers())
	shootoutEnded.emit(winningSide)
	print("Shootout ended. Winner: {winningSide}".format({ "winningSide": winningSide }))

func spawnDamageNumber(label, color: String, targetPosition: Vector2) -> void:
	var newDamageNumber = DamageNumberScene.instantiate()
	add_child(newDamageNumber)
	newDamageNumber.init(label, color, targetPosition)

func getPositionForColumn(actorSide: String, column) -> Vector2:
	return Shootout.shootoutPositions.get(actorSide, {}).get(column, Vector2.ZERO)

## Single stat-read seam: every modifier source stacks here (Rodeos today,
## effects once that system lands). Used by UI and future systems.
func getModifiedStat(actor, statPath: String, baseValue):
	var value = baseValue
	value = rodeoManager.getStatModifier(actor, statPath, value)
	if get("effectManager") != null and get("effectManager").has_method("getStatModifier"):
		value = get("effectManager").getStatModifier(actor.name, statPath, value)
	return value

func actorStatsPayload(actor) -> Array:
	return [
		{
			"Name": actor.actorName,
			"HP": actor.hp,
			"Rodeo": rodeoManager.getRodeoDisplayName(actor)
		},
		{
			"SixShootin": actor.stats.sixShootin,
			"HighTailin": actor.stats.highTailin,
			"Taffyin": actor.stats.taffyin,
			"Revolver": actor.stats.damage.lead.revolver,
			"Rifle": actor.stats.damage.lead.rifle,
			"Shotgun": actor.stats.damage.lead.shotgun,
			"Style": actor.stats.get("defense", {}).get("style", 0),
			"Sand": actor.stats.get("defense", {}).get("sand", 0)
		}
	]

func showHoveredActorStats(actorName: String) -> void:
	var actor = getActor(actorName)
	if actor == null:
		return
	var payload = actorStatsPayload(actor)
	ui.setHoveredActorStats(payload[0], payload[1])

func clearHoveredActorStats() -> void:
	ui.clearHoveredActorStats()

func setActorCharacterStats(actorName: String) -> void:
	var actor = getActor(actorName)
	if actor == null:
		return
	var payload = actorStatsPayload(actor)
	ui.setPlayerCharacterStats(payload[0], payload[1])

func _on_shootout_ui_attack() -> void:
	if !playerHasControl:
		return
	selectedAct = { "type": Shootout.ACT_TYPE_ATTACK }

func _on_shootout_ui_move(moveName: String) -> void:
	if !playerHasControl:
		return
	selectedAct = { "name": moveName, "type": Shootout.ACT_TYPE_MOVES }

func _on_shootout_ui_item(itemName: String) -> void:
	if !playerHasControl:
		return
	selectedAct = { "name": itemName, "type": Shootout.ACT_TYPE_ITEMS }

func _on_shootout_ui_move_acts_requested() -> void:
	var actor = getActor(turnManager.currentActorName())
	if actor != null:
		ui.setPlayerCharacterActs(actor.moves, Shootout.ACT_TYPE_MOVES)

func _on_shootout_ui_item_acts_requested() -> void:
	var actor = getActor(turnManager.currentActorName())
	if actor != null:
		ui.setPlayerCharacterActs(actor.items, Shootout.ACT_TYPE_ITEMS)
