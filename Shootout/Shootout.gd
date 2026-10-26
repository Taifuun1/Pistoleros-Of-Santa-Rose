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
const FocusManagerScript = preload("res://Shootout/ShootoutFocusManager.gd")
const EnemyAIScript = preload("res://Shootout/ShootoutEnemyAI.gd")
const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")
const CylinderManagerScript = preload("res://Shootout/ShootoutCylinderManager.gd")
const EffectManagerScript = preload("res://Shootout/ShootoutEffectManager.gd")
const LootGeneratorScript = preload("res://Globals/ItemGeneration.gd")
const HPIndicatorScene = preload("res://Nodes/HP Indicator/HPIndicator.tscn")

# Let the act presentation settle before the next fighter moves.
const BETWEEN_ACTS_PAUSE = 0.4
# Visual walk between repositioning columns (Docs/Features and Issues.md: the
# Move move needs an animation). Must stay under BETWEEN_ACTS_PAUSE so the
# next act can never capture a mid-slide actor position as its rest anchor.
const REPOSITION_SLIDE_TIME = 0.3
# Beat before a turn-end Rodeo procs, so the act settle and the Rodeo's own
# move read as separate moments instead of one snap.
const RODEO_PROC_PAUSE = 0.25

# Armed-move feedback (Docs/System Design/Shootout/Shootout UI.md): while a
# data move waits for its target click, its valid targets tint warm on the
# field; while the reposition picker is open, the reachable destination
# columns get the turn-marker art at the column spot.
const TARGET_TINT = Color(1.0, 0.9, 0.55)
const COLUMN_MARKER_TEXTURE = preload("res://Assets/UI/Highlight2.png")

@onready var actorsRoot = $Actors
@onready var ui = $CanvasLayer/ShootoutUI

var turnManager
var targetingManager
var actionResolver
var animationSequencer
var focusManager
var enemyAI
var rodeoManager
var cylinderManager
var effectManager

var selectedAct = null
var selectedActor = ""
# The enemy's act is chosen when their turn starts (not at the impact frame) so
# the act focus can frame attacker and target together and so the decision
# can't change mid-animation; resolveActOnce reuses it.
var pendingEnemyAct = {}
# Currently hovered actor (indexed name); stale mouse_exited events from a
# previously hovered actor are ignored against it (see clearHoveredActorStats).
var hoveredActorName = ""
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
# Field markers for the reposition picker (direction -> Sprite2D), parented
# under Actors in front of the background but behind every fighter.
var repositionMarkersRoot = null
var repositionMarkers = {}


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
	# Darkest-Dungeon style act presentation (Docs/System Design/Shootout/
	# Shootout UI.md): only the fighters an act affects zoom, the background
	# defocuses and the fighters lunge/recoil while it plays. The
	# release hangs off finishTurn rather than sequenceDone: the turn advances on
	# the acting animation's hit frame, so the next act can already have taken the
	# camera by the time the previous sequence ends, and releasing there would
	# undo the new act's focus.
	focusManager = FocusManagerScript.new()
	add_child(focusManager)
	focusManager.init(self, get_node_or_null("Camera2D"), ui)
	ui.move.connect(_on_shootout_ui_move)
	ui.item.connect(_on_shootout_ui_item)
	ui.reposition.connect(_on_shootout_ui_reposition)
	ui.flee.connect(_on_shootout_ui_flee)
	ui.repositionPicker.connect(_on_shootout_ui_reposition_picker)
	# Reposition column markers draw under every fighter: first child of the
	# scene root (tree order puts it before Actors) instead of a z_index,
	# which is global to the canvas layer. It must NOT live under Actors:
	# several systems iterate Actors' children as the fighters themselves
	# (the turn highlight, the focus manager's actor collection).
	repositionMarkersRoot = Node2D.new()
	repositionMarkersRoot.name = "RepositionMarkers"
	add_child(repositionMarkersRoot)
	move_child(repositionMarkersRoot, 0)
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
	# Encounter music (MusicPlayer resolves it from the encounter data, the
	# MusicData encounter registry or the zone, with a default fight list).
	MusicPlayer.on_shootout_started(encounterData)
	lootTableName = encounterData.get("lootTable", "")
	encounterLootEnabled = encounterData.get("loot", true)
	encounterName = encounterData.get("name", "Shootout")
	flavorName = encounterData.get("flavor", pickFlavorName(encounterData.get("kind", "dustup")))
	print("{flavor}! ({name})".format({ "flavor": flavorName, "name": encounterName }))
	ui.showBanner("{flavor}!".format({ "flavor": flavorName }))
	for actor in actorSpawnPlan(teams):
		spawnActor(actor.side, actor.type, actor.name, actor.position, actor.indexedName)
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_FIGHT_START)
	turnManager.createTurnOrder()
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
	startCurrentTurn()

func pickFlavorName(kind: String) -> String:
	var flavors = Shootout.SHOWDOWN_FLAVORS if kind == "showdown" else Shootout.DUSTUP_FLAVORS
	return flavors[randi() % flavors.size()]


## One entry per spawned actor: side, type, name, position and the unique
## indexed actor name. The index continues across the whole encounter — the
## same actor name on both teams must never produce colliding node names,
## because Godot silently rejects a colliding name assignment (the node keeps
## an auto-generated name) and per-actor node paths like
## "{name}/AnimationSprite" break.
static func actorSpawnPlan(teams: Dictionary) -> Array:
	var plan = []
	var indexes = {}
	for actorSide in teams:
		for actorType in teams[actorSide]:
			for actorName in teams[actorSide][actorType]:
				var index = int(indexes.get(actorName, 0))
				for actorPosition in teams[actorSide][actorType][actorName].positions:
					plan.append({
						"side": actorSide,
						"type": actorType,
						"name": actorName,
						"position": actorPosition,
						"indexedName": "{actorName}{index}".format({ "actorName": actorName, "index": index }),
					})
					index += 1
				indexes[actorName] = index
	return plan

## The index continues across the whole encounter (see actorSpawnPlan) so the
## same actor name on both teams never produces colliding node names.
func spawnActor(actorSide: String, actorType: String, actorName: String, actorPosition, actorNameIndexed: String) -> void:
	var newShootoutActor = ShootoutActorScene.instantiate()
	actorsRoot.add_child(newShootoutActor)
	if Party.party.has(actorName):
		newShootoutActor.init(Party.getFightData(actorName))
	else:
		newShootoutActor.init(load("res://Data/Actors/{actorType}/{actorName}.gd".format({
			"actorType": actorType,
			"actorName": actorName.capitalize().replace(" ", "")
		})).new().data)
	newShootoutActor.initShootoutActor(actorType, actorNameIndexed, actorPosition, actorSide)
	# World-space HP bar below the actor (Docs/System Design/Shootout/Shootout UI.md).
	var hpIndicator = HPIndicatorScene.instantiate()
	newShootoutActor.add_child(hpIndicator)
	hpIndicator.init(newShootoutActor)
	var classData = cylinderManager.classesData.get(newShootoutActor.characterClass, {})
	newShootoutActor.applyLoadoutLimits(int(classData.get("beltSpace", -1)))
	newShootoutActor.actorSelected.connect(selectActor.bind(actorNameIndexed))
	newShootoutActor.actorHovered.connect(showHoveredActorStats.bind(actorNameIndexed))
	newShootoutActor.actorUnhovered.connect(clearHoveredActorStats.bind(actorNameIndexed))
	var animations = newShootoutActor.getAnimations()
	if animations != null:
		animations.onAnimationFrameHit.connect(animationSequencer._on_acting_frame_hit)
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
		# The front of the turn order does not resolve to a living actor: drop
		# them and keep the fight moving instead of waiting forever (createTurn
		# Order skips unresolvable names on the rebuild, so this can't loop).
		if !battleOver:
			turnManager.turnOrder.erase(actorName)
			actorDone.emit()
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
	# Only the current actor carries the turn highlight: the old toggle left
	# previous actors highlighted and hid it on an actor's second turn (the
	# "highlight doesn't always show" bug; Docs/System Design/Shootout/Shootout UI.md).
	# get_node_or_null: Actors children are assumed to be fighters, but the
	# loop must survive a non-fighter node slipping in.
	for otherActor in actorsRoot.get_children():
		var highlight = otherActor.get_node_or_null("Highlight2")
		if highlight != null:
			highlight.hide()
	actor.actorTurn.emit()
	if turnManager.isPlayerActing(actorName):
		playerAction = true
		playerHasControl = true
		ui.playerHasControl = true
		setActorCharacterStats(actorName)
		# No act menu: the available moves and belt items render as icons in
		# the Acts row for the whole turn (Docs/System Design/Shootout/Shootout UI.md).
		ui.setPlayerCharacterActs(actor.moves, Shootout.ACT_TYPE_MOVES, targetingManager.moveUsability(actor.moves, actor.name, effectManager.isSilenced(actor.name), Shootout.movesData))
		ui.setPlayerCharacterActs(actor.items, Shootout.ACT_TYPE_ITEMS)
	else:
		playerAction = false
		playerHasControl = false
		ui.playerHasControl = false
		executeEnemyTurn(actor)

func executeEnemyTurn(actor) -> void:
	pendingResolution = true
	# The act is picked when the turn starts (see pendingEnemyAct): the act
	# focus needs the target to frame attacker and target together, and the
	# enemy's move/item animation steps play the same way the player's do.
	pendingEnemyAct = enemyAI.chooseAct(actor.name)
	var enemyTarget = getActor(pendingEnemyAct.get("targetName", ""))
	playAct(actSteps(pendingEnemyAct.get("type", ""), pendingEnemyAct.get("name", "")), actor, enemyTarget)

## Single seam that starts an act. The focus (fighter zoom, background defocus,
## lunge) only runs when the sequence has something to show: an act with no
## animation steps resolves on the same frame it starts, so focusing it would
## just flicker the presentation in and out.
func playAct(steps: Array, actingActor, targetActor) -> void:
	if !steps.is_empty() and focusManager != null:
		focusManager.beginAct(actingActor, targetActor)
	animationSequencer.play(steps, actingActor, targetActor)

func selectActor(actorName: String = "") -> void:
	if !playerHasControl or !playerAction or selectedAct == null:
		return
	var actingActorName = turnManager.currentActorName()
	if !targetingManager.isValidTarget(selectedAct, actorName, actingActorName):
		return
	var actingActor = getActor(actingActorName)
	selectedActor = actorName
	ui.hideActsPanel()
	_clearTargetHighlights()
	playerHasControl = false
	ui.playerHasControl = false
	actingActor.actorTurn.emit()
	pendingResolution = true
	playAct(buildActSteps(), actingActor, getActor(selectedActor))

func buildActSteps() -> Array:
	return actSteps(selectedAct.type, selectedAct.get("name", ""))

## The data-driven animation steps for a move or item; every other act type
## plays the acting actor's weapon animation.
func actSteps(actType: String, actName: String) -> Array:
	match actType:
		Shootout.ACT_TYPE_MOVES:
			return Shootout.movesData.get(actName, {}).get("animations", [])
		Shootout.ACT_TYPE_ITEMS:
			return Shootout.itemsData.get(actName, {}).get("animations", [])
	return [{ "target": "actingActor" }]

## Applies the act and reports to the focus manager whether the target actually
## lost HP, so only a landed hit recoils (a Miss or a Reload/Jammed chamber
## leaves the target standing still).
func resolveWithFocus(actingActor, targetActor, actType: String, actName: String) -> void:
	var hpBefore = int(targetActor.hp) if targetActor != null else 0
	match actType:
		Shootout.ACT_TYPE_ATTACK:
			actionResolver.resolveAttack(actingActor, targetActor)
		Shootout.ACT_TYPE_MOVES:
			actionResolver.resolveMove(actName, actingActor, targetActor)
		Shootout.ACT_TYPE_ITEMS:
			actionResolver.resolveItem(actName, actingActor, targetActor)
	if focusManager != null:
		focusManager.onActResolved(actingActor, targetActor, targetActor != null and int(targetActor.hp) < hpBefore)

func resolveActOnce() -> void:
	if !pendingResolution or battleOver:
		return
	pendingResolution = false
	var actingActor = getActor(turnManager.currentActorName())
	if actingActor == null:
		# The acting actor vanished mid-turn (freed or unregistered): pass the
		# turn instead of leaving the shootout waiting on them forever.
		finishTurn(null)
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
		resolveWithFocus(actingActor, targetActor, selectedAct.type, selectedAct.get("name", ""))
	else:
		# Enemy acts route through the same resolution path as player acts. The
		# act was chosen when the turn started (so the focus could frame it);
		# choosing again here only happens when nothing was cached.
		var enemyAct = pendingEnemyAct
		if enemyAct.is_empty():
			enemyAct = enemyAI.chooseAct(turnManager.currentActorName())
		if enemyAct.is_empty():
			actingActor.actorTurn.emit()
			finishTurn(null)
			return
		if enemyAct.type == Shootout.ACT_TYPE_REPOSITION:
			var delta = -1 if enemyAct.direction == "forward" else 1
			# Same Move animation as the UI picker: slide to the new column.
			repositionActor(actingActor, turnManager.getActorPosition(actingActor.name) + delta)
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
			# Invalid enemy target (e.g., a scripted act naming a missing
			# actor): pass the turn instead of hanging the fight forever.
			actingActor.actorTurn.emit()
			finishTurn(null)
			return
		actingActor.actorTurn.emit()
		resolveWithFocus(actingActor, targetActor, enemyAct.type, enemyAct.get("name", ""))
	finishTurn(targetActor)

func finishTurn(targetActor) -> void:
	var waitingForAnimation = animationSequencer != null and animationSequencer.running
	if !waitingForAnimation and focusManager != null:
		focusManager.endAct()
	effectManager.onTurnEnd(turnManager.currentActorName())
	# The acting actor is captured before advanceTurn() rolls the turn over:
	# the turn-end Rodeo procs after the settle (below), when the current actor
	# has already changed.
	var turnEndContext = {
		"actor": getActor(turnManager.currentActorName()),
		"target": targetActor
	}
	if targetActor != null:
		turnManager.checkActorDead(targetActor)
	turnManager.checkBattleEnd()
	turnManager.advanceTurn()
	selectedAct = null
	selectedActor = ""
	pendingEnemyAct = {}
	_clearTargetHighlights()
	_hideRepositionMarkers()
	if waitingForAnimation:
		if focusManager != null:
			focusManager.syncRestPositionsFromTurnManager()
		if !battleOver and animationSequencer != null and animationSequencer.running:
			await animationSequencer.sequenceDone
		if focusManager != null:
			focusManager.endAct()
	# Turn-end Rodeos proc on a brief beat after the act/reposition animations
	# have settled, and the Rodeo's own move walks the fighter to its new
	# column instead of snapping there — both keep the transition from reading
	# as a jarring jump, and the popup lands on the right fighter.
	var rodeoProcs = not battleOver and rodeoManager != null \
			and rodeoManager.has_method("hasTurnEndRodeo") and rodeoManager.hasTurnEndRodeo()
	if rodeoProcs:
		await get_tree().create_timer(RODEO_PROC_PAUSE).timeout
	var formationBefore := {}
	var actorRegistry = turnManager.get("shootoutActors")
	if actorRegistry is Dictionary:
		for actorSide in actorRegistry:
			for actorName in actorRegistry[actorSide]:
				var fighter = getActor(actorName)
				if fighter != null:
					formationBefore[fighter] = fighter.position
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_TURN_END, turnEndContext)
	for fighter in formationBefore:
		if is_instance_valid(fighter):
			playRepositionSlide(fighter, formationBefore[fighter])
	# Turn effects, deaths and victory resolve immediately; only the hand-off to
	# the next actor waits, giving the focus/recoil a brief moment to settle.
	if !battleOver:
		await get_tree().create_timer(BETWEEN_ACTS_PAUSE).timeout
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
	_clearTargetHighlights()
	_hideRepositionMarkers()
	# An act may still be mid-animation when the last fighter drops: release the
	# act focus so the end screen shows the whole street, not a zoomed-in corner.
	if focusManager != null:
		focusManager.endAct()
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
	# Outcome stinger for the end screen (MusicPlayer; the fight track stops
	# and the scene change after the results brings the next scene's music).
	MusicPlayer.on_shootout_ended(results)
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
	hoveredActorName = actorName
	var actor = getActor(actorName)
	if actor == null:
		return
	var payload = actorStatsPayload(actor)
	ui.setHoveredActorStats(payload[0], payload[1])

## Stale-exit guard: Godot emits the previous actor's mouse_exited AFTER the
## new actor's mouse_entered when the mouse crosses between touching collision
## boxes in one physics frame (known Viewport._process_picking behavior), so
## an unguarded clear wiped the freshly hovered actor's panel. Only the exit
## of the currently hovered actor clears the panel.
func clearHoveredActorStats(actorName: String = "") -> void:
	if actorName != "" and hoveredActorName != actorName:
		return
	hoveredActorName = ""
	ui.clearHoveredActorStats()

func setActorCharacterStats(actorName: String) -> void:
	var actor = getActor(actorName)
	if actor == null:
		return
	var payload = actorStatsPayload(actor)
	ui.setPlayerCharacterStats(payload[0], payload[1])

func _on_shootout_ui_move(moveName: String) -> void:
	if !playerHasControl:
		return
	selectedAct = { "name": moveName, "type": Shootout.ACT_TYPE_MOVES }
	_refreshTargetHighlights()

func _on_shootout_ui_item(itemName: String) -> void:
	if !playerHasControl:
		return
	selectedAct = { "name": itemName, "type": Shootout.ACT_TYPE_ITEMS }
	_clearTargetHighlights()

## The reposition picker replaced any armed data move: one armed thing at a
## time, so drop the move's target tints and mark the reachable columns.
func _on_shootout_ui_reposition_picker(pickerOpen: bool) -> void:
	_clearTargetHighlights()
	if pickerOpen:
		selectedAct = null
		_showRepositionMarkers()
	else:
		_hideRepositionMarkers()


## --- armed-act field feedback ---

## Valid targets of the armed data move tint warm on the field (the hover
## outline stays independent: it works on a material, the tint on modulate).
func _refreshTargetHighlights() -> void:
	_clearTargetHighlights()
	if selectedAct == null or selectedAct.type != Shootout.ACT_TYPE_MOVES or !playerHasControl:
		return
	var actingActorName = turnManager.currentActorName()
	for actor in actorsRoot.get_children():
		if !is_instance_valid(actor):
			continue
		if targetingManager.isValidTarget(selectedAct, str(actor.name), actingActorName):
			var animations = actor.getAnimations()
			if animations != null:
				animations.modulate = TARGET_TINT


func _clearTargetHighlights() -> void:
	for actor in actorsRoot.get_children():
		if !is_instance_valid(actor):
			continue
		var animations = actor.getAnimations()
		if animations != null:
			animations.modulate = Color(1, 1, 1)


## A marker on each column the current fighter can slide to; blocked
## directions get no marker (and are greyed out in the picker).
func _showRepositionMarkers() -> void:
	_hideRepositionMarkers()
	var actorName = turnManager.currentActorName()
	var actorSide = turnManager.sideOfActor(actorName)
	if actorSide == "":
		return
	var usability = {}
	for direction in ["forward", "backward"]:
		var delta = -1 if direction == "forward" else 1
		var destination = turnManager.getActorPosition(actorName) + delta
		var reachable = turnManager.canMoveActor(actorName, destination)
		usability[direction.capitalize()] = reachable
		if !reachable:
			continue
		var marker = Sprite2D.new()
		marker.texture = COLUMN_MARKER_TEXTURE
		marker.position = getPositionForColumn(actorSide, destination)
		repositionMarkers[direction] = marker
		repositionMarkersRoot.add_child(marker)
	ui.setDirectionsUsable(usability)


func _hideRepositionMarkers() -> void:
	for marker in repositionMarkers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	repositionMarkers.clear()

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
	# Blocked push chains must not spend the Move or close the picker.
	if !turnManager.canMoveActor(actorName, turnManager.getActorPosition(actorName) + delta):
		return
	ui.hideActsPanel()
	_hideRepositionMarkers()
	playerHasControl = false
	ui.playerHasControl = false
	repositionActor(actor, turnManager.getActorPosition(actorName) + delta)
	actor.actorTurn.emit()
	finishTurn(null)


## Reposition act shared by the UI picker and the enemy AI: the turn manager
## commits the squeeze repositioning instantly (positions in the registry are
## the truth), then every fighter the move touched — the mover sliding to the
## new column, the displaced occupants sliding toward the vacated spot —
## travels as a short walk instead of a teleport (Docs/Features and Issues.md).
func repositionActor(actor, column: int) -> bool:
	if actor == null:
		return false
	# Snapshot the whole side: squeeze repositioning also moves everyone
	# between the mover's old and new columns.
	var actorSide = turnManager.sideOfActor(str(actor.name))
	var previousPositions = {}
	for otherName in turnManager.shootoutActors.get(actorSide, {}):
		var other = getActor(otherName)
		if other != null:
			previousPositions[other] = other.position
	if !turnManager.setActorPosition(str(actor.name), column):
		return false
	# playRepositionSlide no-ops on unchanged fighters, so everyone can go
	# through the same path as the mover.
	for other in previousPositions:
		playRepositionSlide(other, previousPositions[other])
	return true


## Short walk tween between the two column spots of the repositioning fighter.
## Purely visual: mechanics resolved already in repositionActor.
func playRepositionSlide(actor, fromPosition: Vector2) -> void:
	if actor == null or !is_instance_valid(actor):
		return
	var toPosition = actor.position
	if toPosition == fromPosition:
		return
	actor.position = fromPosition
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "position", toPosition, REPOSITION_SLIDE_TIME)

func _on_shootout_ui_item_acts_requested() -> void:
	var actor = getActor(turnManager.currentActorName())
	if actor != null:
		ui.setPlayerCharacterActs(actor.items, Shootout.ACT_TYPE_ITEMS)
