extends Node

## Scene-run validation for the multi-target pipeline (Docs/System Design/
## Shootout/Positions and Targeting.md) against the real Shootout scene and its
## real actors/managers. Run as TestMultiTargetFlow.tscn.

const ShootoutScene = preload("res://Shootout/Shootout.tscn")

var failures := 0


func _ready() -> void:
	await _run()
	get_tree().quit(failures)


func _run() -> void:
	print("\n--- Real scene: multi-target target set ---")
	var shootout = ShootoutScene.instantiate()
	add_child(shootout)
	# Stop the default encounter's pending turn so only staged checks resolve.
	shootout.pendingResolution = false
	shootout.animationSequencer.clearActingCompletion()
	shootout.animationSequencer.steps.clear()
	shootout.animationSequencer.running = false
	shootout.focusManager.endAct()
	await get_tree().process_frame

	var players = shootout.turnManager.shootoutActors.get("player team", {}).keys()
	var enemies = shootout.turnManager.shootoutActors.get("enemy team", {}).keys()
	_check(players.size() >= 3 and enemies.size() >= 3, "the real scene provides three fighters per side")
	if players.size() < 3 or enemies.size() < 3:
		shootout.queue_free()
		return

	var globals = get_node("/root/Shootout")
	var originalItems = globals.itemsData
	var originalMoves = globals.movesData
	globals.itemsData = globals.itemsData.duplicate(true)
	globals.movesData = globals.movesData.duplicate(true)
	globals.itemsData["multiHeal"] = {
		"name": "multiHeal", "side": "player", "baseAmount": 5,
		"positions": { "type": "multi", "targets": { "columns": [1, 2, 3, 4] } },
	}
	globals.movesData["multiStrike"] = {
		"name": "multiStrike", "category": "attack_ability", "baseAmount": 3, "side": "enemy",
		"positions": { "type": "multi", "targets": { "columns": [1, 2, 3, 4] } },
	}

	var healer = shootout.getActor(str(players[0]))
	var allyA = shootout.getActor(str(players[1]))
	var allyB = shootout.getActor(str(players[2]))
	allyA.hp = maxi(1, allyA.hp - 10)
	allyB.hp = maxi(1, allyB.hp - 10)
	var allyAHpBefore = allyA.hp
	var allyBHpBefore = allyB.hp
	healer.items = ["multiHeal"]
	healer.beltReservations = [{ "instanceId": "test_heal", "combatId": "multiHeal", "quantity": 2 }]
	var consumedBefore = shootout.consumedBeltItems.size()
	var healed = shootout.resolveActTargetSet("Items", "multiHeal", healer, [allyA, allyB])
	_check(healed.size() == 2, "the real pipeline resolves both multi-heal targets")
	_check(allyA.hp == allyAHpBefore + 5 and allyB.hp == allyBHpBefore + 5, "both allies receive the multi-heal")
	_check(shootout.consumedBeltItems.size() == consumedBefore + 1, "the multi-heal consumes exactly one belt entry")
	_check(healer.beltReservations[0].quantity == 1, "the reservation is spent once for the whole set")

	# Armed multi acts preview the complete legal set on the field; clicking any
	# one of those anchors confirms the whole set.
	shootout.playerHasControl = true
	shootout.selectedAct = { "type": "Items", "name": "multiHeal" }
	shootout._refreshTargetHighlights()
	var actingSide = shootout.turnManager.sideOfActor(shootout.turnManager.currentActorName())
	var previewNames = players if actingSide == "player team" else enemies
	var tinted = 0
	for previewName in previewNames:
		var actor = shootout.getActor(str(previewName))
		if actor != null and actor.getAnimations() != null and actor.getAnimations().modulate.is_equal_approx(shootout.TARGET_TINT):
			tinted += 1
	_check(tinted == 3, "the armed multi act previews every legal ally target, got %d" % tinted)
	shootout.selectedAct = null
	shootout._clearTargetHighlights()
	shootout.playerHasControl = false

	# Taunt redirect per protected position: the enemy tank appears twice when a
	# player act targets two protected enemy columns.
	var tank = shootout.getActor(str(enemies[0]))
	var protectedA = shootout.getActor(str(enemies[1]))
	var protectedB = shootout.getActor(str(enemies[2]))
	var tankHpBefore = tank.hp
	shootout.effectManager.applyEffect(tank.name, {
		"op": "apply_effect", "effect": "taunt",
		"positions": [shootout.turnManager.getActorPosition(protectedA.name), shootout.turnManager.getActorPosition(protectedB.name)],
		"rounds": 2,
	}, tank.name)
	var redirected = shootout.resolveActTargetSet("Moves", "multiStrike", healer, [protectedA, protectedB])
	_check(redirected.size() == 2 and redirected[0] == tank and redirected[1] == tank, "both protected positions redirect to the taunt caster")
	_check(tank.hp == tankHpBefore - 6, "the taunt caster takes one resolved hit per protected position, got %d" % (tankHpBefore - tank.hp))

	# A whole multi attack resolves with one Cylinder advance.
	shootout.effectManager.cleanse(tank.name, "taunt", 99)
	shootout.cylinderManager.cylinders[healer.name] = {
		"cylinder": [2, 2, 2], "chamberIndex": 0, "characterMagazine": [],
		"classMagazine": [], "weaponMagazine": [], "modifier": null,
	}
	var protectedAHpBefore = protectedA.hp
	var protectedBHpBefore = protectedB.hp
	var struck = shootout.resolveActTargetSet("Moves", "multiStrike", healer, [protectedA, protectedB])
	_check(struck.size() == 2, "the real pipeline resolves both multi-attack targets")
	_check(protectedA.hp == protectedAHpBefore - 3 and protectedB.hp == protectedBHpBefore - 3, "both targets take the attack-ability damage")
	_check(shootout.cylinderManager.getChamberIndex(healer.name) == 1, "the whole multi attack advances the Cylinder once")

	# A dead-only set charges nothing: no belt use and no Cylinder advance.
	allyA.hp = 0
	var itemsBefore = healer.items.size()
	var chamberBefore = shootout.cylinderManager.getChamberIndex(healer.name)
	var empty = shootout.resolveActTargetSet("Items", "multiHeal", healer, [allyA])
	_check(empty.is_empty() and healer.items.size() == itemsBefore, "an empty/dead target set consumes no item")
	_check(shootout.cylinderManager.getChamberIndex(healer.name) == chamberBefore, "an empty target set advances no Cylinder")

	# Effect stat modifiers make the resolved and displayed values agree.
	var displayBase = int(allyB.stats.highTailin)
	shootout.effectManager.applyEffect(allyB.name, { "op": "apply_effect", "effect": "stat_modifier", "stat": "highTailin", "amount": 2, "turns": 2 }, healer.name)
	_check(shootout.getModifiedStat(allyB, "highTailin", displayBase) == displayBase + 2, "the shared helper returns the effect-modified stat")
	var payload = shootout.actorStatsPayload(allyB)
	_check(int(payload[1].get("HighTailin", 0)) == displayBase + 2, "the stats panel shows the effect-modified stat")

	globals.itemsData = originalItems
	globals.movesData = originalMoves
	shootout.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
