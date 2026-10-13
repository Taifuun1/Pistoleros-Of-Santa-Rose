extends Node

## Party state (Docs/System Design/Shootout/Death Injury and Retreat.md):
## one shared party level, persistent per-member HP, journey injuries, knockout
## debuffs and the money pouch. All fighters post-fight state flows through
## applyFightResults().

# Placeholder: MxHP portion lost when fleeing a fight.
const FLEE_MXHP_LOSS = 0.2
# Placeholder: knockout debuff duration in Shootouts.
const KNOCKOUT_SHOOTOUTS = 3
# Placeholder: HP lost per point of MxHP lost to injuries.
const DEFAULT_INJURY_RATE = 4

# Knockout debuff package applied when a member goes down (placeholders).
const KNOCKOUT_DEBUFFS = [
	{ "stat": "highTailin", "amount": -2 },
	{ "stat": "sixShootin", "amount": -1 }
]

var level = 1
var money = 0
var questInProgress = false

var party = {
	"Walker Langley": {
		"actorName": "Walker Langley",
		"hp": 12,
		"walkingSpeed": 75,
		"runningSpeed": 25,
		"stats": {
			"sixShootin": 3,
			"highTailin": 6,
			"taffyin": 2,
			"damage": {
				"lead": {
					"revolver": 1,
					"rifle": 1,
					"shotgun": 1
				},
				"explosive": {
					"gunpowder": 1,
					"liquid": 1,
					"shrapnel": 1
				}
			},
			"defense": { "style": 2, "sand": 1 },
			"resistances": { "bleed": 0.0, "poison": 0.0 }
		},
		"rodeo": "leaders duck",
		"baseMaxHp": 12,
		"injuryDamage": 0,
		"injuryRate": 4,
		"knockoutDebuffs": [],
		"downed": false,
		"characterClass": "Gunslinger",
		"moves": ["Sharp Shot", "Hold Steady"],
		"items": ["Paregoric", "Paregoric"],
		"magazine": [1, 0, 2],
		#"weapon": {
			#"type": "lead",
			#"weapon": "revolver"
		#}
		"weapon": {
			"type": "lead",
			"weapon": "rifle",
			"baseDamage": 4
		}
	}
}


## Effective max HP: base minus journey injuries, never below 1.
func effectiveMaxHp(member: Dictionary) -> int:
	var base = int(member.get("baseMaxHp", member.get("maxHp", member.get("hp", 1))))
	var rate = maxi(1, int(member.get("injuryRate", DEFAULT_INJURY_RATE)))
	return maxi(1, base - int(floor(float(member.get("injuryDamage", 0)) / rate)))


## The member's data prepared for a fight: effective MxHp, HP capped to it,
## and knockout debuffs applied to a duplicated stats block.
func getFightData(actorName: String) -> Dictionary:
	var member = party[actorName].duplicate(true)
	var maxHp = effectiveMaxHp(member)
	member["maxHp"] = maxHp
	member["hp"] = mini(int(member.get("hp", maxHp)), maxHp)
	for debuff in member.get("knockoutDebuffs", []):
		if member.stats.has(debuff.get("stat", "")):
			member.stats[debuff.stat] += int(debuff.get("amount", 0))
	return member


## Post-fight write-back: surviving HP, accumulated injuries, downed members
## gain knockout debuffs, one Shootout is consumed from existing debuffs, and
## fleeing costs every survivor a portion of MxHp.
func applyFightResults(results: Dictionary) -> void:
	for member in party.values():
		var debuffs = []
		for debuff in member.get("knockoutDebuffs", []):
			debuff["shootoutsLeft"] = int(debuff.get("shootoutsLeft", KNOCKOUT_SHOOTOUTS)) - 1
			if debuff.shootoutsLeft > 0:
				debuffs.append(debuff)
		member["knockoutDebuffs"] = debuffs
	for actorName in results.get("party", {}):
		if !party.has(actorName):
			continue
		var state = results.party[actorName]
		var member = party[actorName]
		member["hp"] = maxi(0, int(state.get("hp", 0)))
		member["injuryDamage"] = int(member.get("injuryDamage", 0)) + int(state.get("injuryDamage", 0))
		member["downed"] = member.hp <= 0
		if member.downed:
			member["knockoutDebuffs"] = makeKnockoutDebuffs()
		if results.get("fled", false) and !member.downed:
			applyFleeCost(actorName)


func makeKnockoutDebuffs() -> Array:
	var debuffs = []
	for debuff in KNOCKOUT_DEBUFFS:
		debuffs.append({ "stat": debuff.stat, "amount": debuff.amount, "shootoutsLeft": KNOCKOUT_SHOOTOUTS })
	return debuffs


## Fleeing costs a portion of MxHp (modeled as journey injury).
func applyFleeCost(actorName: String) -> void:
	if !party.has(actorName):
		return
	var member = party[actorName]
	var base = int(member.get("baseMaxHp", member.get("hp", 1)))
	var rate = maxi(1, int(member.get("injuryRate", DEFAULT_INJURY_RATE)))
	member["injuryDamage"] = int(member.get("injuryDamage", 0)) + int(ceil(base * FLEE_MXHP_LOSS * rate))


## Town entry: injuries reset.
func resetInjury() -> void:
	for member in party.values():
		member["injuryDamage"] = 0
		member["downed"] = false


## Camp items: reduce journey injuries.
func reduceInjury(amount: int) -> void:
	for member in party.values():
		member["injuryDamage"] = maxi(0, int(member.get("injuryDamage", 0)) - amount)


## Full party down: lose half of all loot (money pouch; the loot hook lands
## with Rewards) and return where the party is thrown to.
func vamoose() -> String:
	money = int(floor(money / 2.0))
	for member in party.values():
		member["downed"] = true
		member["knockoutDebuffs"] = makeKnockoutDebuffs()
	return "quest_checkpoint" if questInProgress else "town"
