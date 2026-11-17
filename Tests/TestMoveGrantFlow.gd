extends Node

## Scene-run validation for the class/equipment Move grant path (Docs/System
## Design/First Steps Implementation Plan.md, commit 11): the real Journal
## Character tab activates a granted Move through Party, the real Shootout
## receives that resolved loadout, an equipment-granted Move is usable, and a
## swap that would remove an active grant is refused atomically.
## Run as TestMoveGrantFlow.tscn.

const ShootoutScene = preload("res://Shootout/Shootout.tscn")
const CharacterTabScene = preload("res://UI/Journal/Tabs/CharacterTab.tscn")
const ItemGenerationScript = preload("res://Globals/ItemGeneration.gd")
const MOVER := "Walker Langley"

var failures := 0


func _ready() -> void:
	await _run()
	get_tree().quit(failures)


func _run() -> void:
	print("\n--- Journal activation reaches the real Shootout ---")
	Party.resetForNewGame()
	Party.setInventoryManagementAllowed(true)
	var tab = CharacterTabScene.instantiate()
	tab.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tab.size = Vector2(560, 240)
	tab.characterProvider = Party
	add_child(tab)
	tab.setTabActive(true)
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame

	_check(Party.getMoveLoadoutSnapshot(MOVER).active == ["Sharp Shot", "Hold Steady"], "the starter loadout resolves from the class grants")
	_check(_moveRow(tab, "Duck Down") != null, "the Journal renders the granted class Move")
	_check(_moveRow(tab, "Hold Steady").disabled == false, "a non-offensive active Move can be deactivated")
	_check(_moveRow(tab, "Sharp Shot").disabled, "the last offensive Move is disabled in the Journal")

	_moveRow(tab, "Duck Down").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(Party.getMoveLoadoutSnapshot(MOVER).active == ["Sharp Shot", "Hold Steady", "Duck Down"], "pressing the Journal row activates the grant through Party")

	var shootout = await _launchShootout()
	var walker = _partyActor(shootout)
	_check(walker != null, "the real Shootout spawns the Party member")
	_check(walker.moves == ["Sharp Shot", "Hold Steady", "Duck Down"], "the Shootout receives the activated loadout, got %s" % str(walker.moves))
	var usable: Array = shootout.targetingManager.usableMoves(walker.moves, walker.name, false, shootout.get_node("/root/Shootout").movesData)
	_check(usable.has("Duck Down"), "the activated class grant is usable in combat")
	shootout.playerHasControl = true
	var applied = shootout.resolveActTargetSet("Moves", "Duck Down", walker, [walker])
	_check(applied.size() == 1, "the granted Move resolves through the real act pipeline")
	_check(!shootout.effectManager.getEffects(walker.name, "taunt").is_empty(), "the granted Move applies its authored effect")
	shootout.playerHasControl = false
	shootout.queue_free()
	await get_tree().process_frame

	print("\n--- Equipment grants and atomic swaps ---")
	Party.party[MOVER]["moves"] = []
	Party.party[MOVER]["characterClass"] = "Fixture Grantless Class"
	Party.classesData["Fixture Grantless Class"] = { "name": "Fixture Grantless Class", "magazine": [1, 0, 2], "moves": [], "beltSpace": 1, "defense": { "sand": 0 }, "explosiveBase": 0 }
	var generator = ItemGenerationScript.new()
	var cattleman: Dictionary = generator.generateWeapon({ "definitionId": "cattleman", "family": "revolver", "rarity": "common" })
	generator.free()
	cattleman["instanceId"] = "grant_test_cattleman"
	Party.inventory = [cattleman]
	_check(Party.equipItem(MOVER, "grant_test_cattleman").success, "the granting Cattleman equips")
	var equipmentSnapshot: Dictionary = Party.getMoveLoadoutSnapshot(MOVER)
	_check(equipmentSnapshot.available.size() == 1 and equipmentSnapshot.available[0].origin == "equipment", "the weapon grant is the member's only available Move, got %s" % str(equipmentSnapshot.available))
	_check(Party.activateMove(MOVER, "Sharp Shot").success, "the equipment-granted Move activates")

	shootout = await _launchShootout()
	walker = _partyActor(shootout)
	_check(walker.moves == ["Sharp Shot"], "the equipment-granted Move reaches the real Shootout, got %s" % str(walker.moves))
	shootout.queue_free()
	await get_tree().process_frame

	var plain = cattleman.duplicate(true)
	plain["instanceId"] = "plain_revolver"
	plain.erase("grantedMoves")
	Party.inventory.append(plain)
	var before: Dictionary = Party.exportState()
	var refused: Dictionary = Party.equipItem(MOVER, "plain_revolver")
	_check(refused.reason == "move_grant_lost", "a swap that removes the active equipment grant is refused, got %s" % str(refused))
	_check(Party.exportState() == before, "the refused swap left Party untouched")
	_check(Party.deactivateMove(MOVER, "Sharp Shot").reason == "last_offensive_move", "an equipment-only offensive loadout also refuses its last removal")

	tab.queue_free()
	Party.resetForNewGame()
	await get_tree().process_frame
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)


func _launchShootout() -> Node:
	var shootout = ShootoutScene.instantiate()
	add_child(shootout)
	shootout.pendingResolution = false
	shootout.animationSequencer.clearActingCompletion()
	shootout.animationSequencer.steps.clear()
	shootout.animationSequencer.running = false
	shootout.focusManager.endAct()
	await get_tree().process_frame
	return shootout


## The spawned Shootout actor for the Party member (actor nodes carry indexed
## names, so look up through the turn manager registry by actorName).
func _partyActor(shootout: Node):
	for actorName in shootout.turnManager.shootoutActors.get("player team", {}):
		var actor = shootout.getActor(str(actorName))
		if actor != null and str(actor.actorName) == MOVER:
			return actor
	return null


## The rendered Journal row for one Move, or null.
func _moveRow(tab: Node, moveName: String) -> Button:
	for child in tab.moveRows.get_children():
		if child is Button and str(child.get_meta("move_name", "")) == moveName:
			return child
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
