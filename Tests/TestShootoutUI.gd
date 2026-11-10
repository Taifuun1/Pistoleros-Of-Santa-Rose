extends SceneTree

## Headless validation for the Shootout UI building blocks (Docs/System Design/Shootout/Shootout UI.md).
## Run with: godot --headless --script res://Tests/TestShootoutUI.gd

const TurnOrderStripScript = preload("res://Shootout/UI/TurnOrderStrip.gd")
const HitrateHitIcon = preload("res://Assets/Stats/HitrateHit.png")
const HitrateGrazeIcon = preload("res://Assets/Stats/HitrateGraze.png")
const CylinderLineIcon = preload("res://Assets/Stats/CylinderLine.png")
const WalkerLangleyIcon = preload("res://Assets/Icons/WalkerLangleyIcon.png")
const PlaceholderIcon = preload("res://Assets/Icons/PlaceholderIcon.png")
const BleedIcon = preload("res://Assets/Effects/Bleed.png")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const TargetingManagerScript = preload("res://Shootout/ShootoutTargetingManager.gd")
const ShootoutActScript = preload("res://Shootout/UI/ShootoutAct.gd")

var failures = 0


class FakeShootout:
	extends Node2D
	var actors = {}
	var turnManager = null
	func getActor(actorName):
		return actors.get(actorName, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n--- Turn order strip ---")
	var strip = TurnOrderStripScript.new()
	root.add_child(strip)
	strip.setTurnOrder(["Walker Langley0", "Squeky rat0", "Squeky rat1"])
	_check(strip.get_child_count() == 3, "one portrait per actor, got %d" % strip.get_child_count())
	_check(strip.get_child(0).texture == WalkerLangleyIcon, "actor portraits use the character icon from Assets/Icons")
	_check(strip.get_child(1).texture == PlaceholderIcon, "actors without portrait art use the placeholder icon")
	_check(strip.get_child(0).modulate.a > strip.get_child(1).modulate.a, "the current actor is highlighted")
	strip.setTurnOrder(["Squeky rat0"])
	_check(strip.get_child_count() == 1, "strip rebuilds per round order")

	print("\n--- Usability reasons for greyed-out acts ---")
	var fake = FakeShootout.new()
	root.add_child(fake)
	var turnManager = TurnManagerScript.new()
	turnManager.init(fake)
	fake.turnManager = turnManager
	var targeting = TargetingManagerScript.new()
	targeting.init(turnManager)
	turnManager.registerActor('player team', 'Mover', 1)
	var movesData = {
		"Long Shot": { "name": "Long Shot", "category": "ability", "positions": { "actorUser": [3, 4], "targets": { "columns": [1] } } },
		"Sharp": { "name": "Sharp", "category": "attack_ability", "positions": { "actorUser": [1, 2], "targets": { "columns": [1] } } },
		"Duck Down": { "name": "Duck Down", "category": "duck", "positions": { "targets": { "columns": [1] } } }
	}
	var usability = targeting.moveUsability(["Long Shot", "Sharp", "Duck Down"], "Mover", false, movesData)
	_check(usability["Long Shot"].usable == false, "out-of-column move is unusable")
	_check(usability["Long Shot"].reason != "", "unusable move has a reason")
	_check(usability["Sharp"].usable, "in-column move is usable")
	_check(usability["Duck Down"].usable, "duck is usable")
	var silencedUsability = targeting.moveUsability(["Long Shot", "Sharp", "Duck Down"], "Mover", true, movesData)
	_check(!silencedUsability["Sharp"].usable and silencedUsability["Sharp"].reason == "Silenced", "silence greys out abilities with a reason")
	_check(silencedUsability["Duck Down"].usable, "silence keeps ducks usable")

	print("\n--- ShootoutUI scene wires the pre-existing containers ---")
	var ui = load("res://Shootout/UI/ShootoutUI.tscn").instantiate()
	root.add_child(ui)
	var turnOrder = ui.get_node("MarginContainer/VBoxContainer/MarginContainer/PanelContainer/Turn Order")
	ui.setTurnOrder(["Walker Langley0", "Squeky rat0", "Squeky rat1"])
	_check(turnOrder.get_child_count() == 3, "turn order renders into the scene's Turn Order container, got %d" % turnOrder.get_child_count())
	_check(turnOrder.get_child(0).texture == WalkerLangleyIcon, "the Turn Order container shows the actor icons")
	_check(turnOrder.get_child(0).modulate.a > turnOrder.get_child(1).modulate.a, "the current actor is highlighted in the Turn Order container")
	turnOrder.get_child(0).mouse_entered.emit()
	var tooltipPanel = ui.get_node("Tooltip/Tooltip")
	_check(tooltipPanel.get_node("MarginContainer/VBoxContainer/Title").get_parsed_text() == "Walker Langley0", "portraits show the actor name in the shared Tooltip node")
	_check(ui.get_node("Tooltip").visible, "hovering a portrait shows the shared Tooltip node")
	turnOrder.get_child(0).mouse_exited.emit()
	_check(!ui.get_node("Tooltip").visible, "leaving the portrait hides the shared Tooltip node")
	ui.setTurnOrder(["Squeky rat0"])
	_check(turnOrder.get_child_count() == 1, "Turn Order container rebuilds per round order")
	var playerContent = ui.get_node("MarginContainer/VBoxContainer/GridContainer/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer")
	var playerMagazine = playerContent.get_node("HBoxContainer2/MagazineContainer/Magazine")
	ui.showCylinder(playerContent, [2, 3, "reload", 0], 2, "HBoxContainer2/MagazineContainer/Magazine")
	_check(playerMagazine.get_child_count() == 6, "the Magazine row provides the Chamber slots, got %d" % playerMagazine.get_child_count())
	_check(playerMagazine.get_child(0).get_node("TextureRect").texture == HitrateHitIcon, "numeric chambers show their quality icon from Assets/Stats")
	playerMagazine.get_child(0).get_node("TextureRect").mouse_entered.emit()
	_check(tooltipPanel.get_node("MarginContainer/VBoxContainer/Title").get_parsed_text() == "Hit", "chamber icons show their quality in the shared Tooltip node")
	_check(playerMagazine.get_child(2).get_node("TextureRect").texture == null, "special chambers have no icon yet")
	_check(playerMagazine.get_child(2).get_node("CylinderLine").texture == CylinderLineIcon, "the current chamber is marked with the CylinderLine")
	_check(playerMagazine.get_child(0).get_node("CylinderLine").texture == null, "other chambers have no CylinderLine")
	_check(!playerMagazine.get_child(4).visible and !playerMagazine.get_child(5).visible, "unused slots are hidden")
	ui.showCylinder(playerContent, [1, 2], 0, "HBoxContainer2/MagazineContainer/Magazine")
	_check(playerMagazine.get_child(0).get_node("TextureRect").texture == HitrateGrazeIcon, "rebuilding swaps the slot icons")
	_check(!playerMagazine.get_child(2).visible, "rebuilding hides the slots left over from the longer cylinder")
	_check(playerMagazine.get_child(0).get_node("TextureRect").mouse_exited.get_connections().size() == 1, "re-attaching a persistent icon's tooltip does not duplicate its connections")
	ui.showEffects(playerContent, ["bleed x2", "poison"])
	var playerEffects = playerContent.get_node("HBoxContainer/Effects")
	_check(playerEffects.get_child_count() == 2, "one icon entry per effect type, got %d" % playerEffects.get_child_count())
	_check(playerEffects.get_child(0).name == "bleed" and playerEffects.get_child(0).get_node("Icon").texture == BleedIcon, "effects render as icons from Assets/Effects")
	_check(playerEffects.get_child(0).get_node("Stacks").get_parsed_text() == "x2", "stack counts render next to the icon")
	playerEffects.get_child(1).get_node("Icon").mouse_entered.emit()
	_check(tooltipPanel.get_node("MarginContainer/VBoxContainer/Title").get_parsed_text() == "Poison" and tooltipPanel.get_node("MarginContainer/VBoxContainer/Text").get_parsed_text() == "poison", "effect icons show their summary in the shared Tooltip node")
	_check(!playerEffects.get_child(1).has_node("Stacks"), "unstacked effects show no count")
	ui.showEffects(playerContent, [])
	_check(playerEffects.get_child_count() == 1 and playerEffects.get_child(0).get_parsed_text() == "-", "empty effects show the placeholder")
	var hoverContent = ui.get_node("MarginContainer/VBoxContainer/GridContainer/PanelContainer3/MarginContainer/VBoxContainer")
	var hoverMagazine = hoverContent.get_node("HBoxContainer3/MagazineContainer/Magazine")
	ui.showCylinder(hoverContent, [3], 0, "HBoxContainer3/MagazineContainer/Magazine")
	_check(hoverMagazine.get_child(0).get_node("TextureRect").texture != null, "the hovered panel magazine shows the cylinder the same way")
	ui.showEffects(hoverContent, ["piercing"])
	var hoverEffects = hoverContent.get_node("HBoxContainer/Effects")
	_check(hoverEffects.get_child_count() == 1, "hovered panel shows effects in its Effects node")
	_check(hoverEffects.get_child(0).get_node("Icon").texture == PlaceholderIcon, "effect types without art use the placeholder icon")

	print("\n--- Acts row act icons ---")
	var actsRow = ui.get_node("MarginContainer/VBoxContainer/GridContainer/PanelContainer/MarginContainer/VBoxContainer/Acts")
	var movesRow = actsRow.get_node("Moves")
	var itemsRow = actsRow.get_node("Items")
	ui.setPlayerCharacterActs(["Long Shot", "Sharp", "Duck Down"], "Moves", usability)
	_check(movesRow.get_child_count() == 3, "one act icon per available move, got %d" % movesRow.get_child_count())
	_check(movesRow.get_child(0).actName == "Long Shot", "act icons render into the Acts row's Moves group")
	_check(movesRow.get_child(0).modulate.r < 1.0, "unusable moves are greyed out")
	_check(movesRow.get_child(1).modulate.r == 1.0, "usable moves are not greyed out")
	ui.setPlayerCharacterActs(["Paregoric"], "Items")
	_check(itemsRow.get_child_count() == 1, "item icons render into the Acts row's Items group")
	_check(movesRow.get_child_count() == 3, "setting the items keeps the move icons")
	ui.setPlayerCharacterActs(["Sharp"], "Moves", usability)
	_check(movesRow.get_child_count() == 1, "rebuilding swaps the act icons")
	var moveRequests = []
	ui.move.connect(func(moveName): moveRequests.append(moveName))
	var actClick = InputEventMouseButton.new()
	actClick.button_index = MOUSE_BUTTON_LEFT
	actClick.pressed = false
	movesRow.get_child(0).gui_input.emit(actClick)
	_check(moveRequests == ["Sharp"], "clicking an act icon requests the act")
	_check(movesRow.get_child(0).selected, "the clicked act icon is marked selected")
	_check(movesRow.get_child(0).modulate.is_equal_approx(ShootoutActScript.SELECTED_MODULATE),
		"the armed act icon carries the selected tint")
	movesRow.get_child(0).mouse_entered.emit()
	_check(movesRow.get_child(0).modulate.b > ShootoutActScript.SELECTED_MODULATE.b,
		"hovering the armed icon lightens it further")
	movesRow.get_child(0).mouse_exited.emit()
	_check(movesRow.get_child(0).modulate.is_equal_approx(ShootoutActScript.SELECTED_MODULATE),
		"leaving the armed icon restores the selected tint")
	movesRow.get_child(0).mouse_entered.emit()
	_check(tooltipPanel.get_node("MarginContainer/VBoxContainer/Title").get_parsed_text() == "Sharp", "act icons show their tooltip in the shared Tooltip node")
	_check(actsRow.get_child(actsRow.get_child_count() - 1).name == "Flee" and actsRow.get_child(actsRow.get_child_count() - 2).name == "Move", "the Move and Flee icons render last in the Acts row")
	var repositionRequests = []
	ui.reposition.connect(func(direction): repositionRequests.append(direction))
	var fleeRequests = []
	ui.flee.connect(func(): fleeRequests.append(true))
	var pickerStates = []
	ui.repositionPicker.connect(func(open): pickerStates.append(open))
	actsRow.get_node("Move").actClicked.emit()
	_check(movesRow.get_child_count() == 3 and movesRow.get_child(1).actName == "Forward", "the Move icon opens the reposition picker, got %d children" % movesRow.get_child_count())
	_check(pickerStates == [true], "opening the reposition picker signals the field to mark the columns")
	_check(actsRow.get_node("Move").selected, "the Move icon is marked selected while the picker is open")
	_check(movesRow.get_child(1).modulate.is_equal_approx(Color(1, 1, 1)),
		"picker directions start enabled")
	ui.setDirectionsUsable({ "Forward": true, "Backward": false })
	_check(movesRow.get_child(2).modulate.r < 1.0, "a blocked direction is greyed out")
	_check(movesRow.get_child(1).modulate.r == 1.0, "a reachable direction stays enabled")
	actsRow.get_node("Move").actClicked.emit()
	_check(movesRow.get_child_count() == 1, "the Move icon toggles the picker closed")
	_check(pickerStates == [true, false], "closing the reposition picker signals the field to clear the markers")
	_check(!actsRow.get_node("Move").selected, "closing the picker disarms the Move icon")
	actsRow.get_node("Move").actClicked.emit()
	movesRow.get_child(1).actClicked.emit()
	_check(repositionRequests == ["forward"], "the picker requests the reposition direction, got %s" % [repositionRequests])
	actsRow.get_node("Flee").actClicked.emit()
	_check(fleeRequests.size() == 1, "the Flee icon requests fleeing")
	ui.hideActsPanel()
	_check(movesRow.get_child_count() == 0 and itemsRow.get_child_count() == 0, "hiding clears the act icons")
	_check(actsRow.get_node_or_null("Move") == null and actsRow.get_node_or_null("Flee") == null, "hiding clears the utility icons")
	_check(turnOrder.get_child_count() == 1, "the Turn Order row keeps showing the Round order")
	print("\n--- End screen acknowledgment and overflow ---")
	var endSignals = []
	ui.endScreenContinuePressed.connect(func(): endSignals.append(true))
	# The result screen is scene-owned: it exists before any results arrive and
	# its hierarchy never changes as results are shown.
	var endScreen = ui.get_node_or_null("EndScreen")
	_check(endScreen != null, "the end screen exists in ShootoutUI from scene load")
	if endScreen == null:
		ui.free()
		quit(1)
		return
	_check(!endScreen.visible, "the end screen starts hidden")
	var hierarchyCount = endScreen.get_child_count()
	ui.showEndScreen({
		"outcome": "victory",
		"loot": { "money": 5, "items": [] },
		"lootResult": {
			"money": 5,
			"accepted": [{ "definitionId": "paregoric", "name": "Paregoric", "quantity": 2 }],
			"overflow": [{ "definitionId": "paregoric", "name": "Paregoric", "quantity": 3 }],
		},
	})
	_check(endScreen.visible, "end screen becomes visible")
	_check(endScreen.get_child_count() == hierarchyCount, "showing results does not add UI nodes")
	var acceptedLoot = endScreen.find_child("AcceptedLoot", true, false)
	var overflowLoot = endScreen.find_child("OverflowLoot", true, false)
	_check(acceptedLoot.get_parsed_text().contains("5 cash") and acceptedLoot.get_parsed_text().contains("2 Paregoric"), "end screen shows accepted money and items")
	_check(overflowLoot.visible and overflowLoot.get_parsed_text().contains("3 Paregoric"), "end screen shows capacity overflow")
	var continueButton = endScreen.find_child("ContinueButton", true, false)
	_check(continueButton.text == "Leave overflow & continue", "overflow mode requires explicit leave action")
	continueButton.pressed.emit()
	_check(endSignals.size() == 1 and continueButton.disabled, "Continue acknowledges once")
	continueButton.pressed.emit()
	_check(endSignals.size() == 1, "repeated press cannot acknowledge twice")
	ui.hideEndScreen()
	_check(!endScreen.visible, "end screen hides after acknowledgment")
	_check(endScreen.get_child_count() == hierarchyCount, "hiding results does not remove UI nodes")

	ui.showEndScreen({ "outcome": "victory", "loot": { "money": 0, "items": [] }, "lootResult": {} })
	continueButton = endScreen.find_child("ContinueButton", true, false)
	_check(endScreen.get_child_count() == hierarchyCount, "repeated results reuse the same hierarchy")
	_check(continueButton.text == "Continue" and !endScreen.find_child("OverflowLoot", true, false).visible, "without overflow only Continue is shown")
	_check(endScreen.find_child("AcceptedLoot", true, false).get_parsed_text() == "No loot.", "empty loot is explicit")

	print("\n--- Effects box stays layout-stable across hover rebuilds ---")
	ui.showEffects(hoverContent, ["bleed x2", "poison"])
	await process_frame
	var effectsBox = hoverContent.get_node("HBoxContainer/Effects")
	_check(effectsBox.custom_minimum_size == ui.EFFECTS_BOX_MIN_SIZE, "the effects box keeps its pinned minimum size")
	_check(effectsBox is HBoxContainer, "effect entries flow horizontally so they never raise the title row")
	_check(effectsBox.get_child_count() == 2, "two effect entries are rendered")
	var bleedEntry = effectsBox.get_child(0)
	_check(bleedEntry.custom_minimum_size == ui.EFFECTS_BOX_MIN_SIZE, "effect entries pin their minimum size")
	var stacksLabel = bleedEntry.get_node_or_null("Stacks")
	_check(stacksLabel != null, "stacked effects render a count label")
	_check(!stacksLabel.fit_content and stacksLabel.autowrap_mode == TextServer.AUTOWRAP_OFF, "inline effect text cannot feed its size back into layout")
	ui.showEffects(hoverContent, ["bleed x2", "poison"])
	await process_frame
	_check(effectsBox.get_child_count() == 2, "rebuilding never duplicates entries")
	ui.showEffects(hoverContent, [])
	await process_frame
	_check(effectsBox.get_child_count() == 1 and effectsBox.get_child(0).get_parsed_text() == "-", "clearing effects renders one placeholder")
	ui.showEffects(hoverContent, ["piercing"])
	await process_frame
	_check(effectsBox.get_child_count() == 1 and effectsBox.get_child(0).name == "piercing", "changed effects rebuild exactly once")

	print("\n--- Hovered panel content always fits its panel ---")
	var hoverStats = { "SixShootin": 1, "HighTailin": 2, "Taffyin": 3, "Revolver": 4, "Rifle": 5, "Shotgun": 6 }
	var titleRow = hoverContent.get_node("HBoxContainer")
	var nameLabel = hoverContent.get_node("HBoxContainer/RichTextLabelExtended")
	var hpLabel = hoverContent.get_node("HBoxContainer/HBoxContainer/RichTextLabelExtended3")
	var hoveredPanel = ui.get_node(ui.STATS_PANEL_PATHS[1])
	await process_frame
	var idlePanelHeight = hoveredPanel.size.y
	ui.setHoveredActorStats({ "Name": "Squeky rat0", "HP": 9, "Rodeo": "-", "Effects": [], "Cylinder": [3], "ChamberIndex": 0 }, hoverStats)
	await process_frame
	await process_frame
	_check(hoveredPanel.size.y == idlePanelHeight,
		"the stats row keeps its height when the panel gets its first real content (%s -> %s)" % [idlePanelHeight, hoveredPanel.size.y])
	var damagedHeight = hoverContent.get_combined_minimum_size().y
	ui.setHoveredActorStats({ "Name": "Squeky rat1", "HP": 12, "Rodeo": "-", "Effects": [], "Cylinder": [3], "ChamberIndex": 0 }, hoverStats)
	await process_frame
	await process_frame
	_check(hoverContent.get_combined_minimum_size().y <= hoverContent.size.y,
		"no row is squeezed below its minimum when crossing from a damaged actor (needs %s, has %s)" % [hoverContent.get_combined_minimum_size().y, hoverContent.size.y])
	_check(hoveredPanel.size.y == idlePanelHeight, "hovering a different actor does not resize the stats row")
	_check(hoverContent.get_combined_minimum_size().y == damagedHeight,
		"changing the HP digit width does not change the content height")
	_check(titleRow.get_combined_minimum_size().y <= 18, "the title row stays one line tall")
	_check(hpLabel.get_global_rect().position.x >= nameLabel.get_global_rect().end.x,
		"the HP value starts after the actor name instead of overlapping it")
	ui.showEffects(hoverContent, ["bleed x2", "poison", "mark"])
	await process_frame
	await process_frame
	_check(titleRow.get_combined_minimum_size().y <= 18, "several effects still fit in the title row")
	_check(hoverContent.get_combined_minimum_size().y == damagedHeight, "extra effects do not grow the panel content")
	ui.free()

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
