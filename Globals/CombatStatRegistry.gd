class_name CombatStatRegistry
extends RefCounted

## Supported combat stat paths and equipment affix names (Docs/System Design/
## Shootout/Effects.md, commit 9). One source so content lint, the effect manager
## and CharacterStatCalculator cannot disagree about which modifiers are real.

const SUPPORT_FULL := "fully_supported"
const SUPPORT_DISPLAY := "display_only"
const SUPPORT_NONE := "unsupported"

const KIND_FLAT := "flat"
const KIND_PERCENT := "percent"

## `stat` paths an authored effect may modify. Flat paths stack by adding their
## amount; percent paths are consumed by damage reduction, not raw addition.
const STAT_PATHS := {
	"sixShootin": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"highTailin": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"taffyin": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"style": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"sand": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"mxHp": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"mxEn": { "support": SUPPORT_DISPLAY, "kind": KIND_FLAT },
	"damage.lead.revolver": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"damage.lead.rifle": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"damage.lead.shotgun": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"damage.explosive.gunpowder": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"damage.explosive.liquid": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"damage.explosive.shrapnel": { "support": SUPPORT_FULL, "kind": KIND_FLAT },
	"damage.lasso": { "support": SUPPORT_NONE, "kind": KIND_FLAT },
	"damageTakenReduction": { "support": SUPPORT_DISPLAY, "kind": KIND_PERCENT },
	"damageTakenReductionTaunting": { "support": SUPPORT_DISPLAY, "kind": KIND_PERCENT },
	"mxHpHealTauntingPerTurn": { "support": SUPPORT_DISPLAY, "kind": KIND_FLAT },
}

## Equipment affixes CharacterStatCalculator sums. Style/Sand are handled with
## their nested defense entries; these are the flat core stats.
const FLAT_EQUIPMENT_AFFIXES := ["sixShootin", "highTailin", "taffyin", "mxHp"]

## Per-affix decision record (commit 12): one entry per `Data/Items/AffixData.gd`
## stat key, so generation, vendor pricing, the Journal previews and the content
## lint cannot disagree about which affixes are real. `generation` marks whether
## the affix may roll or be sold; `consumer` names the production mechanic that
## reads it. Excluded affixes keep their record so legacy items stay priceable
## and importable without phantom mechanics.
const AFFIX_DECISIONS := {
	"sixShootin": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator core stat (Shootout offense)" },
	"highTailin": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator core stat; ShootoutTurnManager initiative" },
	"taffyin": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator core stat" },
	"style": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator defense; ShootoutActionResolver family rule" },
	"sand": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator defense; ShootoutActionResolver family rule" },
	"mxHp": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator max HP" },
	"revolverDamage": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator weapon base damage" },
	"rifleDamage": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator weapon base damage" },
	"shotgunDamage": { "kind": KIND_FLAT, "generation": true, "consumer": "CharacterStatCalculator weapon base damage" },
	"gunpowderDamage": { "kind": KIND_FLAT, "generation": true, "consumer": "stats.damage.explosive.gunpowder via ShootoutActionResolver.offensiveStat" },
	"liquidSkullDamage": { "kind": KIND_FLAT, "generation": true, "consumer": "stats.damage.explosive.liquid via ShootoutActionResolver.offensiveStat" },
	"shrapnelDamage": { "kind": KIND_FLAT, "generation": true, "consumer": "stats.damage.explosive.shrapnel via ShootoutActionResolver.offensiveStat" },
	"initiative": { "kind": KIND_FLAT, "generation": true, "consumer": "ShootoutTurnManager.createTurnOrder (one authored initiative effect)" },
	"damageVsMarked": { "kind": KIND_FLAT, "generation": true, "consumer": "ShootoutEffectManager.applyIncomingModifiers (marked targets)" },
	"damagePiercing": { "kind": KIND_FLAT, "generation": true, "consumer": "ShootoutEffectManager.applyOutgoingModifiers (capped at blocked)" },
	"cylinderIncrease": { "kind": KIND_FLAT, "generation": true, "consumer": "ShootoutCylinderManager extra chambers" },
	"damageTakenReduction": { "kind": KIND_PERCENT, "generation": true, "consumer": "ShootoutEffectManager.applyIncomingModifiers (percent, clamped)" },
	"damageTakenReductionTaunting": { "kind": KIND_PERCENT, "generation": true, "consumer": "ShootoutEffectManager.applyIncomingModifiers while taunting" },
	"mxHpHealTauntingPerTurn": { "kind": KIND_FLAT, "generation": true, "consumer": "ShootoutEffectManager.onTurnStart while taunting" },
	"silenceImmunity": { "kind": "flag", "generation": true, "consumer": "ShootoutEffectManager.applyAffliction silence gate" },
	"negativeEffectPotencyReduction": { "kind": KIND_PERCENT, "generation": true, "consumer": "stats.resistances bleed/poison via ShootoutEffectManager.resistance" },
	"lootGold": { "kind": KIND_PERCENT, "generation": true, "consumer": "ItemGeneration.generateLoot money multiplier (fight loot only)" },
	"lootItems": { "kind": KIND_PERCENT, "generation": true, "consumer": "ItemGeneration.generateLoot roll bonus (fight loot only)" },
	"turnOrder": { "kind": KIND_FLAT, "generation": false, "reason": "no distinct contract versus initiative" },
	"mxEn": { "kind": KIND_FLAT, "generation": false, "reason": "no energy system" },
	"lassoDamage": { "kind": KIND_FLAT, "generation": false, "reason": "no lasso system" },
	"lootGems": { "kind": KIND_PERCENT, "generation": false, "reason": "no gem system" },
	"liquidSkullDuration": { "kind": KIND_FLAT, "generation": false, "reason": "undocumented duration rule" },
	"poisonAffliction": { "kind": KIND_FLAT, "generation": false, "reason": "undocumented equipment affliction contract" },
	"bleedAffliction": { "kind": KIND_FLAT, "generation": false, "reason": "undocumented equipment affliction contract" },
	"negativeEffectDurationReduction": { "kind": KIND_PERCENT, "generation": false, "reason": "undocumented duration reduction rule" },
}


static func affixDecision(statKey: String) -> Dictionary:
	var decision = AFFIX_DECISIONS.get(statKey, null)
	return decision if decision is Dictionary else {}


static func isGenerationEligible(statKey: String) -> bool:
	return bool(affixDecision(statKey).get("generation", false))


static func affixKind(statKey: String) -> String:
	return str(affixDecision(statKey).get("kind", ""))


static func hasPath(statPath: String) -> bool:
	return STAT_PATHS.has(statPath)


static func isStatModifierPath(statPath: String) -> bool:
	return hasPath(statPath) and str(STAT_PATHS[statPath].get("support", "")) == SUPPORT_FULL \
		and str(STAT_PATHS[statPath].get("kind", "")) == KIND_FLAT


static func supportLevel(statPath: String) -> String:
	return str(STAT_PATHS.get(statPath, {}).get("support", SUPPORT_NONE))


static func kindFor(statPath: String) -> String:
	return str(STAT_PATHS.get(statPath, {}).get("kind", KIND_FLAT))


static func validateStatModifierPath(statPath: String) -> String:
	if statPath == "":
		return "effect stat modifier is missing its stat path"
	if !hasPath(statPath):
		return "unknown stat path '%s'" % statPath
	if !isStatModifierPath(statPath):
		return "stat path '%s' is not a supported flat combat modifier" % statPath
	return ""
