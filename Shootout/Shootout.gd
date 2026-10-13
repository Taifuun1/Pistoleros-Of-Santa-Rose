extends Node2D


signal actorDone
signal shootoutEnded(winningSide, results)

const ShootoutActorScene = preload("res://Actors/Shootout/ShootoutActor.tscn")
const DamageNumberScene = preload("res://Nodes/Damage Number/DamageNumber.tscn")
const DefaultEncounter = preload("res://Data/Shootout/Encounters/RatAmbush.gd")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")
const AnimationSequencerScript = preload("res://Shootout/ShootoutAnimationSequencer.gd")
const EnemyAIScript = preload("res://Shootout/ShootoutEnemyAI.gd")
const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")
const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")
const EffectManagerScript = preload("res://Shootout/ShootoutEffectManager.gd")
const LootGeneratorScript = preload("res://Globals/ItemGeneration.gd")

@onready var actorsRoot = $Actors
@onready var ui = $CanvasLayer/ShootoutUI

var turnManager
var targetingManager
var actionResolver
var animationSequencer
var enemyAI
var rodeoManager
var cylinderManager
var effectManager

var selectedAct = null
var selectedActor = ""
var playerHasControl = false
var playerAction = false
var battleOver = false
var pendingResolution = false
var encounterName = ""
var flavorName = ""
var fled = false
var lootTableName = ""
var encounterLootEnabled = true
var lootGenerator
# baseName -> { hp, injuryDamage, downed } for dead party members this fight.
var partyFightState = {}


func _ready() -> void:
	turnManager = TurnManagerScript.new()
	turnManager.init(self)
	turnManager.battleEnded.connect(_on_battle_ended)
	targetingManager = TargetingManagerScript.new()
	targetingManager.init(turnManager)
	actionResolver = ActionResolverScript.new()
	actionResolver.init(self)
	enemyAI = EnemyAIScript.new()
	enemyAI.init(self)
	rodeoManager = RodeoManagerScript.new()
	rodeoManager.init(self)
	cylinderManager = CylinderManagerScript.new()
	cylinderManager.init(self)
	effectManager = EffectManagerScript.new()
	effectManager.init(self)
	lootGenerator = LootGeneratorScript.new()
	animationSequencer = AnimationSequencerScript.new()
	add_child(animationSequencer)
	animationSequencer.frameHit.connect(resolveActOnce)
	animationSequencer.sequenceDone.connect(resolveActOnce)
	ui.attack.connect(_on_shootout_ui_attack)
	ui.move.connect(_on_shootout_ui_move)
	ui.item.connect(_on_shootout_ui_item)
	ui.moveActsRequested.connect(_on_shootout_ui_move_acts_requested)
	ui.itemActsRequested.connect(_on_shootout_ui_item_acts_requested)
	ui.reposition.connect(_on_shootout_ui_reposition)
	ui.flee.connect(_on_shootout_ui_flee)
	actorDone.connect(_on_actor_done)
	var encounterScript = DefaultEncounter
	if Shootout.pendingEncounter != null:
		encounterScript = load(Shootout.pendingEncounter)
		Shootout.pendingEncounter = null
	init(encounterScript.new().data)


func init(encounterData: Dictionary) -> void:
	var teams = encounterData.get("teams", encounterData)
	turnManager.setWinCondition(encounterData.get("winCondition", {}))
	turnManager.setEncounterKind(encounterData.get("kind", "dustup"))
	lootTableName = encounterData.get("lootTable", "")
	encounterLootEnabled = encounterData.get("loot", true)
	encounterName = encounterData.get("name", "Shootout")
	flavorName = encounterData.get("flavor", pickFlavorName(encounterData.get("kind", "dustup")))
	print("{flavor}! ({name})".format({ "flavor": flavorName, "name": encounterName }))
	ui.showBanner("{flavor}!".format({ "flavor": flavorName }))
	for actorSide in teams:
		for actorType in teams[actorSide]:
			for actorName in teams[actorSide][actorType]:
				var index = 0
				for actorPosition in teams[actorSide][actorType][actorName].positions:
					spawnActor(actorSide, actorType, actorName, actorPosition, index)
					index += 1
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_FIGHT_START)
	turnManager.createTurnOrder()
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
	startCurrentTurn()

func pickFlavorName(kind: String) -> String:
	var flavors = Shootout.SHOWDOWN_FLAVORS if kind == "showdown" else Shootout.DUSTUP_FLAVORS
	return flavors[randi() % flavors.size()]

func spawnActor(actorSide: String, actorType: String, actorName: String, actorPosition, index: int) -> void:
	var newShootoutActor = ShootoutActorScene.instantiate()
	var actorNameIndexed = "{actorName}{index}".format({ "actorName": actorName, "index": index })
	actorsRoot.add_child(newShootoutActor)
	if Party.party.has(actorName):
		newShootoutActor.init(Party.getFightData(actorName))
	else:
		newShootoutActor.init(load("res://Data/Actors/{actorType}/{actorName}.gd".format({
			"actorType": actorType,
			"actorName": actorName.capitalize().replace(" ", "")
		})).new().data)
	newShootoutActor.initShootoutActor(actorType, actorNameIndexed, actorPosition, actorSide)
	var classData = cylinderManager.classesData.get(newShootoutActor.characterClass, {})
	newShootoutActor.applyLoadoutLimits(int(classData.get("beltSpace", -1)))
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
	effectManager.onTurnStart(actorName)
	if actor.hp <= 0:
		# Bleed killed the actor before their turn; move on without them.
		turnManager.checkActorDead(actor)
		if !battleOver:
			actorDone.emit()
		return
	ui.setTurnOrder(turnManager.turnOrder)
	ui.setFleeEnabled(turnManager.canFlee())
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
		if selectedAct.type == Shootout.ACT_TYPE_ATTACK:
			var redirect = effectManager.redirectTaunt(turnManager.sideOfActor(turnManager.currentActorName()), selectedActor)
			if redirect != "":
				selectedActor = redirect
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
		# Enemy acts route through the same resolution path as player acts.
		var enemyAct = enemyAI.chooseAct(turnManager.currentActorName())
		if enemyAct.is_empty():
			actingActor.actorTurn.emit()
			finishTurn(null)
			return
		if enemyAct.type == Shootout.ACT_TYPE_REPOSITION:
			var delta = -1 if enemyAct.direction == "forward" else 1
			turnManager.setActorPosition(actingActor.name, turnManager.getActorPosition(actingActor.name) + delta)
			actingActor.actorTurn.emit()
			finishTurn(null)
			return
		var enemyTargetName = enemyAct.get("targetName", "")
		if enemyAct.type == Shootout.ACT_TYPE_ATTACK:
			var enemyRedirect = effectManager.redirectTaunt(turnManager.sideOfActor(turnManager.currentActorName()), enemyTargetName)
			if enemyRedirect != "":
				enemyTargetName = enemyRedirect
		targetActor = getActor(enemyTargetName)
		if targetActor == null:
			return
		actingActor.actorTurn.emit()
		match enemyAct.type:
			Shootout.ACT_TYPE_ATTACK:
				actionResolver.resolveAttack(actingActor, targetActor)
			Shootout.ACT_TYPE_MOVES:
				actionResolver.resolveMove(enemyAct.name, actingActor, targetActor)
			Shootout.ACT_TYPE_ITEMS:
				actionResolver.resolveItem(enemyAct.name, actingActor, targetActor)
	finishTurn(targetActor)

func finishTurn(targetActor) -> void:
	effectManager.onTurnEnd(turnManager.currentActorName())
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_TURN_END, {
		"actor": getActor(turnManager.currentActorName()),
		"target": targetActor
	})
	if targetActor != null:
		turnManager.checkActorDead(targetActor)
	turnManager.checkBattleEnd()
	turnManager.advanceTurn()
	selectedAct = null
	selectedActor = ""
	actorDone.emit()

func _on_actor_done() -> void:
	if battleOver:
		return
	if turnManager.turnOrder.is_empty():
		rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_END)
		effectManager.onRoundEnd()
		turnManager.createTurnOrder()
		rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
		effectManager.onRoundStart()
		# Poison ticks at round start can kill; clear the dead before acting.
		checkForEffectDeaths()
		turnManager.checkBattleEnd()
	if battleOver:
		return
	startCurrentTurn()

func checkForEffectDeaths() -> void:
	for actorSide in turnManager.shootoutActors.keys():
		for actorName in turnManager.shootoutActors[actorSide].keys():
			var actor = getActor(actorName)
			if actor != null and actor.hp <= 0:
				turnManager.checkActorDead(actor)

func _on_battle_ended(winningSide: String) -> void:
	battleOver = true
	playerHasControl = false
	ui.playerHasControl = false
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_FIGHT_END, { "winningSide": winningSide })
	var results = {
		"winningSide": winningSide,
		"fled": fled,
		"outcome": fightOutcome(winningSide),
		"party": buildPartyFightState(),
		"rodeoLoot": rodeoManager.consumeLootModifiers()
	}
	results["loot"] = generateLootForFight(results.rodeoLoot, winningSide)
	Party.applyFightResults(results)
	shootoutEnded.emit(winningSide, results)
	ui.showEndScreen(results)
	print("Shootout ended. Winner: {winningSide}, outcome: {outcome}".format({
		"winningSide": winningSide, "outcome": results.outcome
	}))

## Loot (Docs/System Design/Shootout/Rewards.md): victory only, skipped for
## quest fights that pay out at quest end (encounter "loot": false).
func generateLootForFight(rodeoLoot, winningSide: String) -> Dictionary:
	var empty = { "money": 0, "items": [] }
	if winningSide != Shootout.TEAM_PLAYER or fled or !encounterLootEnabled or lootTableName == "":
		return empty
	var table = null
	var globals = get_node_or_null("/root/Shootout")
	if globals != null:
		table = globals.lootTablesData.get(lootTableName, null)
	if !(table is Dictionary):
		push_warning("Shootout: unknown loot table {table}".format({ "table": lootTableName }))
		return empty
	return lootGenerator.generateLoot(table, rodeoLoot)

func fightOutcome(winningSide: String) -> String:
	if fled:
		return "fled"
	if winningSide == Shootout.TEAM_PLAYER:
		return "victory"
	return "vamoose" if isPartyWiped() else "defeat"

func isPartyWiped() -> bool:
	var state = buildPartyFightState()
	if state.is_empty():
		return false
	for actorName in state:
		if !state[actorName].downed:
			return false
	return true

# Death snapshots so freed actors still report their final state.
func recordActorDeath(actor) -> void:
	if actor != null and Party.party.has(actor.actorName):
		var injury = actor.get("injuryDamage")
		partyFightState[actor.actorName] = {
			"hp": 0,
			"injuryDamage": injury if injury != null else 0,
			"downed": true
		}

func buildPartyFightState() -> Dictionary:
	var state = partyFightState.duplicate(true)
	for actorSide in turnManager.shootoutActors:
		for actorName in turnManager.shootoutActors[actorSide]:
			var actor = getActor(actorName)
			if actor == null or !Party.party.has(actor.actorName) or state.has(actor.actorName):
				continue
			var injury = actor.get("injuryDamage")
			state[actor.actorName] = {
				"hp": actor.hp,
				"injuryDamage": injury if injury != null else 0,
				"downed": actor.hp <= 0
			}
	return state

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
			"Rodeo": rodeoManager.getRodeoDisplayName(actor),
			"Effects": effectManager.displayEffects(actor.name),
			"Cylinder": cylinderManager.getCylinder(actor.name),
			"ChamberIndex": cylinderManager.getChamberIndex(actor.name)
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
		ui.setPlayerCharacterActs(actor.moves, Shootout.ACT_TYPE_MOVES, targetingManager.moveUsability(actor.moves, actor.name, effectManager.isSilenced(actor.name), Shootout.movesData))

# Fleeing is instant in Dust-ups and unlocks after 10 turns in Showdowns
# (decided: enemies never flee). Costs every survivor a portion of MxHp.
func _on_shootout_ui_flee() -> void:
	if !playerHasControl or !playerAction or battleOver or !turnManager.canFlee():
		return
	fled = true
	turnManager.endBattle(Shootout.TEAM_ENEMY)

# Repositioning costs the Move and never advances the Cylinder (decided).
func _on_shootout_ui_reposition(direction: String) -> void:
	if !playerHasControl or !playerAction:
		return
	var actorName = turnManager.currentActorName()
	var actor = getActor(actorName)
	if actor == null:
		return
	var delta = -1 if direction == "forward" else 1
	if !turnManager.setActorPosition(actorName, turnManager.getActorPosition(actorName) + delta):
		return
	ui.hideActsPanel()
	playerHasControl = false
	ui.playerHasControl = false
	actor.actorTurn.emit()
	finishTurn(null)

func _on_shootout_ui_item_acts_requested() -> void:
	var actor = getActor(turnManager.currentActorName())
	if actor != null:
		ui.setPlayerCharacterActs(actor.items, Shootout.ACT_TYPE_ITEMS)
