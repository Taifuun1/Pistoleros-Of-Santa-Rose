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
