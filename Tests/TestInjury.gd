extends SceneTree

## Headless validation for death, injury and retreat (Docs/System Design/Shootout/Death Injury and Retreat.md).
## Run with: godot --headless --script res://Tests/TestInjury.gd

const PartyScript = preload("res://Globals/Party.gd")
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
	var party = PartyScript.new()
	party.party = {
		"Walker Langley": {
			"actorName": "Walker Langley", "hp": 12, "baseMaxHp": 12,
			"stats": { "sixShootin": 3, "highTailin": 6 },
			"injuryDamage": 0, "injuryRate": 4, "knockoutDebuffs": [], "downed": false
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

	print("\n--- Fight data caps HP and applies knockout debuffs ---")
	member.hp = 12
	member.knockoutDebuffs = [{ "stat": "sixShootin", "amount": -1, "shootoutsLeft": 3 }]
	var fightData = party.getFightData("Walker Langley")
	_check(fightData.maxHp == 11, "fight data carries the effective MxHp, got %d" % fightData.maxHp)
	_check(fightData.hp == 11, "HP capped to effective MxHp, got %d" % fightData.hp)
	_check(fightData.stats.sixShootin == 2, "knockout debuff applied to fight stats, got %d" % fightData.stats.sixShootin)
	_check(member.stats.sixShootin == 3, "source party stats are not mutated")
	member.knockoutDebuffs = []

	print("\n--- Post-fight write-back ---")
	party.applyFightResults({ "party": { "Walker Langley": { "hp": 5, "injuryDamage": 6, "downed": false } }, "fled": false })
	_check(member.hp == 5, "surviving HP written back")
	_check(member.injuryDamage == 10, "fight injuries accumulate, got %d" % member.injuryDamage)
	_check(!member.downed, "survivor is not downed")
	party.applyFightResults({ "party": { "Walker Langley": { "hp": 0, "injuryDamage": 3, "downed": true } }, "fled": false })
	_check(member.downed, "member at 0 HP is downed")
	_check(member.knockoutDebuffs.size() == 2, "downed member gains the knockout debuff package")
	_check(member.knockoutDebuffs[0].shootoutsLeft == 3, "knockout debuffs last 3 Shootouts")

	print("\n--- Knockout debuffs tick down per Shootout ---")
	party.applyFightResults({ "party": {}, "fled": false })
	_check(member.knockoutDebuffs[0].shootoutsLeft == 2, "one Shootout consumed")
	party.applyFightResults({ "party": {}, "fled": false })
	party.applyFightResults({ "party": {}, "fled": false })
	_check(member.knockoutDebuffs.is_empty(), "knockout debuffs expire after 3 Shootouts")

	print("\n--- Injuries reset in town, camp items reduce them ---")
	member.injuryDamage = 20
	party.reduceInjury(5)
	_check(member.injuryDamage == 15, "camp item reduces injuries")
	party.resetInjury()
	_check(member.injuryDamage == 0 and !member.downed, "town entry resets injuries and downed flags")

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
	_check(member.downed and member.knockoutDebuffs.size() == 2, "vamoose downs everyone with knockout debuffs")
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

	if failures == 0:
		print("\nALL CHECKS PASSED")
	else:
		print("\n%d CHECK(S) FAILED" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("CHECK FAILED: ", message)
