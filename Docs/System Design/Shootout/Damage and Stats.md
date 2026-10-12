# Damage and Stats

The stat model and the hit/damage calculation pipeline: offensive and defensive damage types, weapon family rules, resistances and final modifiers. Game-design rules live in `Docs/Combat.md` ("Stats", "Damage and hit calculation", "Weapons").

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

Pipeline for a weapon attack (numbers are placeholders for balancing):

1. The attacker's current Chamber decides hit quality (see [Cylinders](Cylinders.md)).
2. Hit quality multiplies damage: Miss 0%, Graze 50%, Hit 100%, Critical Hit 150%.
3. Base damage comes from the weapon plus the relevant offensive stat (Lead, Explosive or Lasso).
4. The target's defensive damage types (Style and Sand) modify the damage, per the weapon family rules.
5. Resistances, damage piercing, damage decrease and flat modifiers are applied last.

Damage types:

- **Offensive**: Lead (base from Six Shootin', modified by Rodeos/items), Explosive (base from class), Lasso (weapon base damage only, never modified by stats — but modifiers like piercing and marks still apply, Open Question 3 answered).
- **Defensive**: Style (base from equipment and Taffyin'), Sand (base from equipment and class).
- **Resistances**: percentage reduction of effect potency, applied to bleed and poison (Open Question 7, answered) — handled in [Effects](Effects.md), but the stat lives here.

Weapon family rules:

| Family | Defensive interaction |
| --- | --- |
| Revolvers | Higher of target's Style/Sand reduces damage |
| Rifles | Target's Style increases damage, Sand lowers it |
| Shotguns | Target's Sand increases damage, Style lowers it |
| Explosives | Effect application over raw damage (minimal defensive interaction) |
| Lassos | Flat damage, ignores stats |

## Current state

`Actors/BaseActor.gd` holds `stats`: `sixShootin`, `highTailin`, `taffyin` and `stats.damage.lead.{revolver,rifle,shotgun}` / `stats.damage.explosive.{gunpowder,liquid,shrapnel}`. There are **no defensive stats** (Style/Sand), **no lasso damage stats**, **no resistances**, and no weapon base damage on the actor (only `weapon.type` / `weapon.weapon` identifiers).

`ShootoutActionResolver.resolveAttack()` deals `stats.damage[type][weapon]` routed through `rodeoManager.getStatModifier()` — no hit quality, no defense, no weapon base. Melee is a hardcoded 2.

## Design

### Stat model

Extend `BaseActor.stats`:

```gdscript
var stats = {
	"sixShootin": -1, "highTailin": -1, "taffyin": -1,
	"damage": {
		"lead": { "revolver": -1, "rifle": -1, "shotgun": -1 },
		"explosive": { "gunpowder": -1, "liquid": -1, "shrapnel": -1 },
		"lasso": -1,                    # unused at runtime; lassos ignore stats (kept for data completeness)
	},
	"defense": { "style": -1, "sand": -1 },
	"resistances": { "bleed": 0.0, "poison": 0.0 },   # 0.0-1.0 potency reduction
}
var weapon = { "type": null, "weapon": null, "baseDamage": 0 }
```

Defensive bases are derived from equipment + Taffyin' (Style) and equipment + class (Sand); until equipment data exists, actor data files carry explicit `defense` values and the derivation is a later pass (see `Docs/Combat.md` "Equipment").

### Damage calculation

New method on the action resolver, replacing the body of `resolveAttack()`:

```gdscript
func calculateAttackDamage(actingActor, targetActor) -> int:
	var quality = shootout.cylinderManager.hitQuality(actingActor.name)
	if quality is String:                       # special Chamber, handled by the caller
		return -1
	var base = actingActor.weapon.baseDamage + offensiveStat(actingActor)
	var qualityMult = Shootout.CHAMBER_DAMAGE_MULT[quality]    # [0.0, 0.5, 1.0, 1.5]
	var damage = base * qualityMult
	damage = applyWeaponFamilyRule(damage, actingActor.weapon, targetActor.stats.defense)
	damage = shootout.effectManager.applyOutgoingModifiers(actingActor, damage)   # piercing vs decrease
	damage = shootout.effectManager.applyIncomingModifiers(targetActor, damage)   # marks, flat modifiers
	return maxi(0, roundi(damage))
```

- `offensiveStat()` — Lead/Explosive: the matching `stats.damage` entry routed through `rodeoManager.getStatModifier()`; Lasso: 0 (weapon base only).
- `applyWeaponFamilyRule()` — a `match` on weapon family implementing the table above: `revolver: damage - max(style, sand)`, `rifle: damage + style - sand`, `shotgun: damage + sand - style`, `explosive: damage` (effects are the point), `lasso: damage`.
- Resistances do not touch weapon damage; they reduce bleed/poison potency at application time (see [Effects](Effects.md)).
- Melee stays a fallback for actors without a real weapon but should read a `baseDamage` from actor data instead of the hardcoded 2.

### Stat query conventions

All combat reads of stats go through a single helper so every modifier source stacks in one place:

```gdscript
func getModifiedStat(actor, statPath: String, baseValue):
	var value = baseValue
	value = shootout.rodeoManager.getStatModifier(actor, statPath, value)
	value = shootout.effectManager.getStatModifier(actor, statPath, value)   # once Effects land
	return value
```

This lives on the shootout root (`Shootout.getModifiedStat`) so turn manager (initiative), action resolver (damage) and UI (display) all share it.

## Files to create / modify

**Modify**

- `Actors/BaseActor.gd` — extend the `stats` shape; `init()` reads `defense`, `resistances` and `weapon.baseDamage` with safe defaults.
- `Globals/Shootout.gd` — `CHAMBER_DAMAGE_MULT` and weapon family constants.
- `Shootout/ShootoutActionResolver.gd` — `calculateAttackDamage()`, `offensiveStat()`, `applyWeaponFamilyRule()`; `resolveMove()` gains the same modifier hooks for damaging abilities.
- `Shootout/Shootout.gd` — `getModifiedStat()` helper; UI stat payload includes Style/Sand.
- `Shootout/UI/ShootoutUI.gd` + scene — Style/Sand labels in stat panels.
- Actor/weapon data files — fill in defense, resistances, weapon base damage.

## Testing

`Tests/TestDamage.gd`:

- The `Docs/Combat.md` worked example: Cylinder [2,3,1,0], second attack (Chamber 3), base 10 x 150% = 15, Style 4 / Sand 1 with a revolver -> 11.
- Rifle vs high-Style target out-damages rifle vs high-Sand target; shotgun mirror.
- Lasso damage is identical regardless of Six Shootin'.
- Damage never goes below 0; Miss deals 0 but still applies on-hit effects (see Open Questions).
- Rodeo and effect modifiers stack through `getModifiedStat()`.

## Implementation order

1. Stat model extension + data defaults (no behavior change).
2. `calculateAttackDamage()` with quality multiplier (requires [Cylinders](Cylinders.md)).
3. Weapon family defense rules.
4. Modifier hooks (piercing/decrease/marks) once [Effects](Effects.md) lands.
5. Equipment-derived defense once equipment data exists.

## Open Questions

1. Do on-hit effects (bleed from a weapon, etc.) apply on a Miss (0% damage)? Proposed: no — a Miss applies nothing.
2. Can rifle/shotgun "defense increases damage" push damage above what a zero-defense target would take, or is the bonus capped at the target's contributed defense? (The `Docs/Combat.md` example implies uncapped; confirm.)
3. Exact rounding: round once at the end (proposed) or at each step?
4. Armor calculations and whether piercing/decrease stack with themselves — explicitly deferred in `Docs/Combat.md` Open Question 12 until armor calculations are built; this doc's step-5 hooks are the seam for that decision.
