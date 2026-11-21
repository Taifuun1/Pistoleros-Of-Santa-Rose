extends Node

## Headless encounter measurement driver (Docs/System Design/First Steps
## Implementation Plan.md, commit 13). Runs the real Shootout scene and its
## production managers — loadout, targeting, Cylinder, effects, turns and AI —
## with only the player side substituted by a driver loop that skips the
## presentation waits. Nothing here reimplements damage, effects, moves or AI,
## and no Party/loot/save state is touched: the production result handler is
## disconnected before driving. Run as TestEncounterMetrics.tscn.

const ShootoutScene = preload("res://Shootout/Shootout.tscn")
const CanyonRatsScript = preload("res://Data/Shootout/Encounters/CanyonRats.gd")
const BASELINE_PATH := "res://Tests/EncounterMetricsBaseline.json"
const MAX_TURNS := 400

var failures := 0


func _ready() -> void:
	await _run()
	get_tree().quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var canyonRatsHolder = CanyonRatsScript.new()
	var canyonRats: Dictionary = canyonRatsHolder.data
	canyonRatsHolder.free()
	var showdownDuel := {
		"name": "Metrics Duel", "kind": "showdown", "flavor": "High Noon",
		"background": str(canyonRats.get("background", "")),
		"winCondition": { "type": "rout" },
		"teams": {
			"player team": { "Named People": { "Walker Langley": { "positions": [2] } } },
			"enemy team": { "Animals": { "Squeky rat": { "positions": [2] } } },
		},
	}

	print("\n--- Determinism: the same seed replays the same encounter ---")
	var first := await measureEncounter(canyonRats, 20261117, MAX_TURNS, "wild_west")
	var replay := await measureEncounter(canyonRats, 20261117, MAX_TURNS, "wild_west")
	_check(not bool(first.get("guardTripped", true)), "CanyonRats terminates inside the turn budget (%s turns, %s rounds)" % [str(first.get("turns")), str(first.get("rounds"))])
	_check(str(first.get("outcome", "")) in ["victory", "vamoose"], "the fight reports a real outcome, got '%s'" % str(first.get("outcome")))
	_check(first == replay, "the same seed and request replay identical metrics")

	print("\n--- Baseline fixture: stored metrics stay reproducible ---")
	var baseline := _readBaseline()
	var baselineRun: Dictionary = baseline.get("canyonRats", {})
	if baselineRun.is_empty():
		# First run on a fresh checkout: record the fixture from the verified
		# replay above rather than asserting a handpicked outcome.
		baselineRun = first.duplicate(true)
		baseline["canyonRats"] = baselineRun
		var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(baseline, "  "))
			file.close()
		print("NOTE: recorded a new metric baseline from seed %s" % str(baselineRun.get("seed", "?")))
	_check(not baselineRun.is_empty(), "the machine-readable baseline exists")
	_check(str(baselineRun.get("encounter", "")) == "Canyon Rats" and int(baselineRun.get("seed", -1)) >= 0, "the baseline records real source data")
	var measured := await measureEncounter(canyonRats, int(baselineRun.get("seed", 20261117)), MAX_TURNS, "wild_west")
	_check(measured == baselineRun, "the baseline replays exactly")

	print("\n--- Commit 17 fixture: the new classes field real loadouts ---")
	var pinesWaylayScript = preload("res://Data/Shootout/Encounters/PinesWaylay.gd")
	var pinesWaylayHolder = pinesWaylayScript.new()
	var pinesWaylay: Dictionary = pinesWaylayHolder.data
	pinesWaylayHolder.free()
	var pinesPath := "res://Data/Shootout/Encounters/PinesWaylay.gd"
	var firstPines := await measureEncounter(pinesWaylay, 20261119, MAX_TURNS, "kipley_wilds", pinesPath)
	_check(not bool(firstPines.get("guardTripped", true)), "PinesWaylay terminates inside the turn budget (%s turns, %s rounds)" % [str(firstPines.get("turns")), str(firstPines.get("rounds"))])
	_check(str(firstPines.get("outcome", "")) in ["victory", "vamoose"], "the bandit fight reports a real outcome, got '%s'" % str(firstPines.get("outcome")))
	var pinesReplay := await measureEncounter(pinesWaylay, 20261119, MAX_TURNS, "kipley_wilds", pinesPath)
	_check(firstPines == pinesReplay, "the same seed replays the bandit fight identically")
	var baselinePines: Dictionary = baseline.get("pinesWaylay", {})
	if baselinePines.is_empty():
		# First run on a fresh checkout: record the fixture from the verified
		# replay above rather than asserting a handpicked outcome.
		baselinePines = firstPines.duplicate(true)
		baseline["pinesWaylay"] = baselinePines
		var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(baseline, "  "))
			file.close()
		print("NOTE: recorded a new Whispering Pines Reach metric fixture from seed %s" % str(baselinePines.get("seed", "?")))
	var measuredPines := await measureEncounter(pinesWaylay, int(baselinePines.get("seed", 20261119)), MAX_TURNS, "kipley_wilds", pinesPath)
	_check(measuredPines == baselinePines, "the Whispering Pines Reach fixture replays exactly")

	print("\n--- Commit 18: the measurement batch covers the new Zone ---")
	var pinesStandoffScript = preload("res://Data/Shootout/Encounters/PinesStandoff.gd")
	var pinesStandoffHolder = pinesStandoffScript.new()
	var pinesStandoff: Dictionary = pinesStandoffHolder.data
	pinesStandoffHolder.free()
	var standoffPath := "res://Data/Shootout/Encounters/PinesStandoff.gd"
	var firstStandoff := await measureEncounter(pinesStandoff, 20261121, MAX_TURNS, "kipley_wilds", standoffPath)
	_check(not bool(firstStandoff.get("guardTripped", true)), "PinesStandoff terminates inside the turn budget (%s turns, %s rounds)" % [str(firstStandoff.get("turns")), str(firstStandoff.get("rounds"))])
	_check(str(firstStandoff.get("outcome", "")) in ["victory", "vamoose"], "the standoff reports a real outcome, got '%s'" % str(firstStandoff.get("outcome")))
	var standoffReplay := await measureEncounter(pinesStandoff, 20261121, MAX_TURNS, "kipley_wilds", standoffPath)
	_check(firstStandoff == standoffReplay, "the same seed replays the standoff identically")
	var baselineStandoff: Dictionary = baseline.get("pinesStandoff", {})
	if baselineStandoff.is_empty():
		# First run on a fresh checkout: record the fixture from the verified
		# replay above rather than asserting a handpicked outcome.
		baselineStandoff = firstStandoff.duplicate(true)
		baseline["pinesStandoff"] = baselineStandoff
		var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(baseline, "  "))
			file.close()
		print("NOTE: recorded a new Whispering Pines Reach standoff fixture from seed %s" % str(baselineStandoff.get("seed", "?")))
	var measuredStandoff := await measureEncounter(pinesStandoff, int(baselineStandoff.get("seed", 20261121)), MAX_TURNS, "kipley_wilds", standoffPath)
	_check(measuredStandoff == baselineStandoff, "the Whispering Pines Reach standoff fixture replays exactly")

	var pinesPatrolScript = preload("res://Data/Shootout/Encounters/PinesPatrol.gd")
	var pinesPatrolHolder = pinesPatrolScript.new()
	var pinesPatrol: Dictionary = pinesPatrolHolder.data
	pinesPatrolHolder.free()
	var patrolPath := "res://Data/Shootout/Encounters/PinesPatrol.gd"
	var pinesBatch := []
	for seedValue in [31, 32, 33]:
		pinesBatch.append(await measureEncounter(pinesPatrol, seedValue, MAX_TURNS, "kipley_wilds", patrolPath))
	_check(pinesBatch.size() == 3 and not pinesBatch.any(func(entry): return bool(entry.get("guardTripped", true))), "every batched pines fight terminates on its own")
	for entry in pinesBatch:
		_check(str(entry.get("encounterPath", "")) == patrolPath and str(entry.get("zoneId", "")) == "kipley_wilds", "each pines batch row records its request path and Zone")

	print("\n--- Batch with a max-turn guard ---")
	var batch := []
	for seedValue in [11, 12, 13]:
		batch.append(await measureEncounter(canyonRats, seedValue, MAX_TURNS, "wild_west"))
	_check(batch.size() == 3 and not batch.any(func(entry): return bool(entry.get("guardTripped", true))), "every batched fight terminates on its own")
	var guarded := await measureEncounter(canyonRats, 11, 1, "wild_west")
	_check(int(guarded.get("turns", 0)) == 1 and bool(guarded.get("guardTripped", false)), "the explicit max-turn guard terminates the driver")

	print("\n--- Metrics carry real source data ---")
	for entry in batch:
		_check(str(entry.get("encounterPath", "")).ends_with("CanyonRats.gd") and str(entry.get("zoneId", "")) == "wild_west", "each metric row records its request path and Zone")
		_check(int(entry.get("hits", -1)) >= 0 and int(entry.get("knockdowns", -1)) >= 0, "each metric row records combat counters")
		_check(not (entry.get("remainingHealth", {}) as Dictionary).is_empty(), "each metric row records remaining health")

	print("\n--- Profiles measurably differ (commit 13) ---")
	var dustupChoices := await sampleChoices(canyonRats, 6)
	var showdownChoices := await sampleChoices(showdownDuel, 6)
	_check(int(showdownChoices.get("total", 0)) > 0 and showdownChoices.size() == 2, "the Showdown profile always takes one deterministic best act, got %s" % [showdownChoices])
	_check(int(dustupChoices.get("total", 0)) > 0 and dustupChoices.size() > 2, "the wide Dust-up profile spreads its candidates, got %s" % [dustupChoices])
	_check(dustupChoices.size() > showdownChoices.size(), "the profiles produce measurably different decision distributions")

	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)


## Drives one full fight with the production turn sequence, minus presentation.
func measureEncounter(encounterData: Dictionary, seedValue: int, maxTurns: int, zoneId: String, encounterPath := "res://Data/Shootout/Encounters/CanyonRats.gd") -> Dictionary:
	var shootout = ShootoutScene.instantiate()
	shootout.autoInit = false
	add_child(shootout)
	await get_tree().process_frame
	var metrics := {
		"seed": seedValue,
		"encounter": str(encounterData.get("name", "")),
		"kind": str(encounterData.get("kind", "dustup")),
		"encounterPath": encounterPath,
		"zoneId": zoneId,
		"source": "measurement_driver",
		"teams": shootout.actorSpawnPlan(encounterData.get("teams", {})).map(func(entry): return str(entry.name)),
	}
	shootout.combatRng = RandomNumberGenerator.new()
	shootout.combatRng.seed = seedValue
	shootout.encounterSeed = seedValue
	if shootout.turnManager.battleEnded.is_connected(shootout._on_battle_ended):
		shootout.turnManager.battleEnded.disconnect(shootout._on_battle_ended)
	var winningSide := [""]
	shootout.turnManager.battleEnded.connect(func(side): winningSide[0] = str(side))
	shootout.init(encounterData, false)
	var turnResult := await driveFight(shootout, maxTurns)
	metrics["outcome"] = "guard_tripped" if bool(turnResult.guarded) else ("victory" if str(winningSide[0]) == Shootout.TEAM_PLAYER else "vamoose")
	metrics["guardTripped"] = turnResult.guarded
	metrics["turns"] = int(turnResult.turns)
	metrics["rounds"] = int(turnResult.rounds)
	metrics["hits"] = int(turnResult.hits)
	metrics["knockdowns"] = int(turnResult.knockdowns)
	metrics["remainingHealth"] = turnResult.remainingHealth
	shootout.queue_free()
	await get_tree().process_frame
	return metrics


## One production turn: start hooks, the AI chooser, the real resolver and the
## turn/round bookkeeping. No mechanic is reimplemented here.
func driveFight(shootout, maxTurns: int) -> Dictionary:
	var turnManager = shootout.turnManager
	var turns := 0
	var hits := 0
	var knockdowns := 0
	while not turnManager.battleOver and turns < maxTurns:
		turns += 1
		var actorName := str(turnManager.currentActorName())
		var actor = shootout.getActor(actorName)
		if actor == null:
			turnManager.turnOrder.erase(actorName)
			continue
		shootout.effectManager.onTurnStart(actorName)
		if int(actor.hp) <= 0:
			if bool(turnManager.checkActorDead(actor)):
				knockdowns += 1
			turnManager.checkBattleEnd()
			if turnManager.battleOver:
				break
			_advanceTurn(shootout)
			continue
		shootout.rodeoManager.trigger(Shootout.RODEO_TRIGGER_TURN_START, { "actor": actor })
		# The driver substitutes for the player with the production chooser.
		var act: Dictionary = shootout.enemyAI.chooseAct(actorName)
		var resolved := []
		if act.is_empty():
			pass
		elif str(act.get("type", "")) == Shootout.ACT_TYPE_REPOSITION:
			var delta := -1 if str(act.get("direction", "")) == "forward" else 1
			shootout.repositionActor(actor, turnManager.getActorPosition(actor.name) + delta)
		else:
			var targets = shootout.targetNamesToActors(act.get("targetNames", []))
			if targets.is_empty():
				var primary = shootout.getActor(str(act.get("targetName", "")))
				if primary != null:
					targets = [primary]
			if targets.is_empty() and shootout.targetingManager.isMultiTargetAct(act):
				var anchor: String = shootout.enemyAI.firstLegalTarget(act, actorName, shootout.targetingManager)
				if anchor != "":
					for expandedName in shootout.targetingManager.expandTargets(act, anchor, actorName):
						var found = shootout.getActor(str(expandedName))
						if found != null:
							targets.append(found)
			var hpBefore := {}
			for targetActor in targets:
				if targetActor != null:
					hpBefore[targetActor] = int(targetActor.hp)
			resolved = shootout.resolveActTargetSet(str(act.get("type", "")), str(act.get("name", "")), actor, targets)
			for targetActor in resolved:
				if int(targetActor.hp) < int(hpBefore.get(targetActor, 0)):
					hits += 1
		shootout.effectManager.onTurnEnd(actorName)
		for targetActor in resolved:
			if bool(turnManager.checkActorDead(targetActor)):
				knockdowns += 1
		turnManager.checkBattleEnd()
		if turnManager.battleOver:
			break
		_advanceTurn(shootout)
	var remaining := {}
	var registry = turnManager.get("shootoutActors")
	if registry is Dictionary:
		for actorSide in registry:
			for actorName in registry[actorSide]:
				var fighter = shootout.getActor(str(actorName))
				if fighter != null:
					remaining[str(actorName)] = { "hp": int(fighter.hp), "maxHp": int(fighter.maxHp) }
	return {
		"guarded": turns >= maxTurns and not turnManager.battleOver,
		"turns": turns,
		"rounds": int(turnManager.roundNumber),
		"hits": hits,
		"knockdowns": knockdowns,
		"remainingHealth": remaining,
	}


func _advanceTurn(shootout) -> void:
	var turnManager = shootout.turnManager
	turnManager.advanceTurn()
	if turnManager.turnOrder.is_empty():
		shootout.rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_END)
		shootout.effectManager.onRoundEnd()
		turnManager.createTurnOrder()
		shootout.rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
		shootout.effectManager.onRoundStart()
		shootout.checkForEffectDeaths()
		turnManager.checkBattleEnd()


## Samples the produced act distribution of the spawned profiled actor without
## running the fight: re-seed between draws, choose with the production AI.
func sampleChoices(encounterData: Dictionary, draws: int) -> Dictionary:
	var shootout = ShootoutScene.instantiate()
	shootout.autoInit = false
	add_child(shootout)
	await get_tree().process_frame
	shootout.init(encounterData, false)
	var choices := { "total": 0 }
	var enemyNames: Array = shootout.turnManager.shootoutActors.get("enemy team", {}).keys()
	if enemyNames.is_empty():
		shootout.queue_free()
		return choices
	var actorName := str(enemyNames[0])
	for i in draws:
		shootout.combatRng = RandomNumberGenerator.new()
		shootout.combatRng.seed = 7000 + i
		var act: Dictionary = shootout.enemyAI.chooseAct(actorName)
		var actName := str(act.get("name", act.get("type", ""))) + "->" + str(act.get("targetName", ""))
		choices[actName] = int(choices.get(actName, 0)) + 1
		choices["total"] = int(choices["total"]) + 1
	shootout.queue_free()
	await get_tree().process_frame
	return choices


func _readBaseline() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	if !(parsed is Dictionary):
		return {}
	# JSON has no int type: coerce the numeric counters of every fixture row
	# back so the comparison is against the measured integer metrics.
	var baseline: Dictionary = parsed
	for fixtureName in baseline.keys():
		var run: Dictionary = baseline[fixtureName] if baseline[fixtureName] is Dictionary else {}
		if run.is_empty():
			continue
		for key in ["seed", "turns", "rounds", "hits", "knockdowns"]:
			run[key] = int(run.get(key, 0))
		var remaining: Dictionary = run.get("remainingHealth", {})
		for actorName in remaining:
			if remaining[actorName] is Dictionary:
				(remaining[actorName] as Dictionary)["hp"] = int((remaining[actorName] as Dictionary).get("hp", 0))
				(remaining[actorName] as Dictionary)["maxHp"] = int((remaining[actorName] as Dictionary).get("maxHp", 0))
		run["remainingHealth"] = remaining
		baseline[fixtureName] = run
	return baseline
