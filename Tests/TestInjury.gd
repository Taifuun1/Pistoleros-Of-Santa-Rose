extends SceneTree

## Headless validation for death, injury and retreat (Docs/System Design/Shootout/Death Injury and Retreat.md).
## Run with: godot --headless --script res://Tests/TestInjury.gd

const PartyScript = preload("res://Globals/Party.gd")
const ItemCatalogScript = preload("res://Data/Items/ItemCatalog.gd")
const TurnManagerScript = preload("res://Shootout/ShootoutTurnManager.gd")
const ActionResolverScript = preload("res://Shootout/ShootoutActionResolver.gd")

var failures = 0


class FakeActor:
	extends Node2D
	var actorName = ""
	var hp = 30
	var maxHp = 50
	var injuryDamage = 0
	var stats = { "sixShootin": 3, "damage": { "lead": { "revolver": 4 } } }
	var weapon = { "type": "lead", "weapon": "revolver", "baseDamage": 0 }


class FakeRodeoManager:
	extends RefCounted
	func getStatModifier(_actor, _statName, baseValue):
		return baseValue
	func unregisterActor(_actorName):
		pass


class FakeShootout:
	extends Node2D
	var actors = {}
	var rodeoManager = FakeRodeoManager.new()
	func _init():
		actors = {}
	func getActor(actorName):
		return actors.get(actorName, null)
	func spawnDamageNumber(_label, _color, _position):
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_setTrail(true)
	var party = PartyScript.new()
	party.party = {
		"Walker Langley": {
			"actorName": "Walker Langley", "hp": 12, "baseMaxHp": 12,
			"stats": { "sixShootin": 3, "highTailin": 6 },
			"injuryDamage": 0, "injuryRate": 4
		}
	}
	var member = party.party["Walker Langley"]

	print("--- Effective MxHp reflects journey injuries ---")
	_check(party.effectiveMaxHp(member) == 12, "no injuries: full MxHp")
	member.injuryDamage = 8
	_check(party.effectiveMaxHp(member) == 10, "8 damage at rate 4 costs 2 MxHp")
	member.injuryDamage = 44
	_check(party.effectiveMaxHp(member) == 1, "injuries floor at 1 MxHp")
	member.injuryDamage = 4

	print("\n--- Fight data starts at effective MxHp with no knockout state ---")
	member.hp = 3
	var fightData = party.getFightData("Walker Langley")
	_check(fightData.maxHp == 11, "fight data carries the effective MxHp, got %d" % fightData.maxHp)
	_check(fightData.hp == 11, "HP starts at effective MxHp, got %d" % fightData.hp)
	_check(fightData.stats.sixShootin == 3, "no knockout debuff changes fight stats")
	_check(member.hp == 3 and !member.has("knockoutDebuffs") and !member.has("downed"), "source member keeps no persistent knockout/downed state")

	print("\n--- Belt use commits without touching fight state ---")
	var catalog = ItemCatalogScript.new()
	party.configureInventory(catalog)
	party.inventory = [{
		"instanceId": "injury_belt", "definitionId": "paregoric",
		"itemType": "consumable", "quantity": 2,
	}]
	member["beltReservations"] = [{ "instanceId": "injury_belt", "combatId": "Paregoric", "quantity": 1 }]
	var beltApplication = party.applyFightResults({
		"party": {},
		"beltConsumed": [{ "instanceId": "injury_belt", "combatId": "Paregoric", "quantity": 1 }],
	})
	_check(beltApplication.belt.success and party.inventory[0].quantity == 1, "one belt use decrements the carried stack")
	_check(member.injuryDamage == 4, "the belt commit does not change fight injuries")

	print("\n--- On-Trail write-back commits attrition at effective max HP ---")
	party.applyFightResults({
		"party": { "Walker Langley": { "hp": 0, "injuryDamage": 6 } },
		"fled": false,
		"trailState": { "onTrail": true },
	})
	_check(member.injuryDamage == 10, "fight injuries accumulate, got %d" % member.injuryDamage)
	_check(member.hp == party.effectiveMaxHp(member) and member.hp == 10, "the member returns at the new effective MxHP")
	_check(!member.has("downed") and !member.has("knockoutDebuffs"), "no persistent downed/knockout state is created")

	print("\n--- Off-Trail fights never change MxHP, loot or flee cost ---")
	_setTrail(false)
	var moneyBefore = party.money
	party.applyFightResults({
		"party": { "Walker Langley": { "hp": 0, "injuryDamage": 5 } },
		"fled": true,
		"loot": { "money": 99, "items": [] },
		"trailState": { "onTrail": false },
	})
	_check(member.injuryDamage == 10, "Off-Trail attrition and flee cost are rejected")
	_check(member.hp == party.effectiveMaxHp(member), "Off-Trail returns at the full effective MxHP")
	_check(party.money == moneyBefore, "Off-Trail loot is not applied")
	_setTrail(true)

	print("\n--- Injuries reset in town, camp items reduce them ---")
	member.injuryDamage = 20
	party.reduceInjury(5)
	_check(member.injuryDamage == 15, "camp item reduces injuries")
	party.resetInjury()
	_check(member.injuryDamage == 0 and party.effectiveMaxHp(member) == 12, "town entry resets injuries to full MxHP")
	_check(!member.has("downed") and !member.has("knockoutDebuffs"), "town reset creates no downed/knockout state")

	print("\n--- Fleeing costs a portion of MxHp ---")
	member.injuryDamage = 0
	party.applyFleeCost("Walker Langley")
	_check(member.injuryDamage == 10, "flee costs ceil(12 * 0.2 * 4) = 10 injury damage, got %d" % member.injuryDamage)
	_check(party.effectiveMaxHp(member) == 10, "flee cost lowers effective MxHp")

	print("\n--- Flee enablement ---")
	var turnManager = TurnManagerScript.new()
	turnManager.init(FakeShootout.new())
	turnManager.setEncounterKind("dustup")
	_check(turnManager.canFlee(), "Dust-ups allow fleeing immediately")
	turnManager.setEncounterKind("showdown")
	turnManager.turnNumber = 9
	_check(!turnManager.canFlee(), "Showdowns block fleeing before turn 10")
	turnManager.turnNumber = 10
	_check(turnManager.canFlee(), "Showdowns allow fleeing from turn 10")

	print("\n--- Vamoose halves loot and picks the destination ---")
	party.money = 100
	party.questInProgress = false
	_check(party.vamoose() == "town", "vamoose without a quest throws the party to town")
	_check(party.money == 50, "vamoose halves the money pouch, got %d" % party.money)
	_check(!member.has("downed") and !member.has("knockoutDebuffs"), "vamoose creates no persistent knockout/downed state")
	party.questInProgress = true
	_check(party.vamoose() == "quest_checkpoint", "vamoose during a quest throws the party to the checkpoint")

	print("\n--- Damage accumulates as injury ---")
	var fake = FakeShootout.new()
	root.add_child(fake)
	var resolver = ActionResolverScript.new()
	resolver.init(fake)
	var target = FakeActor.new()
	target.name = "Target"
	target.actorName = "Target"
	fake.actors["Target"] = target
	resolver.applyDamage(target, 3)
	resolver.applyDamage(target, 2)
	_check(target.injuryDamage == 5, "all damage accumulates on the actor node, got %d" % target.injuryDamage)

	print("\n--- Town entry is the single recovery boundary ---")
	var locations = _locations()
	var townEvents = []
	if locations != null:
		locations.townEntered.connect(func(locationId): townEvents.append(locationId))
		locations.resetForNewGame()
		locations.enterTown("Test Town")
		_check(townEvents == ["Test Town"], "entering a Town emits the recovery boundary, got %s" % [townEvents])
		locations.enterNonTownLocation("Test Cave")
		_check(townEvents.size() == 1, "entering a non-town Location does not emit Town recovery")
		locations.resetForNewGame()

	_resetTrail()
	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _locations():
	var mainLoop = Engine.get_main_loop()
	if mainLoop is SceneTree and mainLoop.root != null:
		return mainLoop.root.get_node_or_null("Locations")
	return null


func _setTrail(onTrail: bool) -> void:
	var locations = _locations()
	if locations == null:
		return
	if onTrail:
		locations.enterTown("Test Town")
		locations.startTrail()
	elif bool(locations.onTrail):
		locations.endTrail()


func _resetTrail() -> void:
	var locations = _locations()
	if locations != null:
		locations.resetForNewGame()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
