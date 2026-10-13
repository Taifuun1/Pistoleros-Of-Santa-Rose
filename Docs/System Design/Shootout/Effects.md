# Effects

Combat effects: afflictions (bleed, poison, marks), buffs (damage piercing), debuffs (damage decrease, cylinder modifiers, silence) and control effects (taunt). Game-design rules live in `Docs/Combat.md` ("Effects", incl. the stacking summary table, and Open Questions 7, 8, 11, 14).

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

| Effect | Behavior | Stacks? | Duration | Removed by |
| --- | --- | --- | --- | --- |
| Bleed | Damage at the start of each of the afflicted character's Turns | No; highest applies, rest are stored | Until healed | Healing items/abilities |
| Poison | Damage at the start of each Round; wears off ~35% per Round | Yes, duration and damage | Wears off | Cleanse, wearing off |
| Cylinder | Increases/decreases Chambers (specific or whole Cylinder) | Replaces previous | Until modified or fight ends | Another cylinder modifier, fight end |
| Mark | After one full Round becomes active; damage to the marked character deals extra damage/effects and consumes it | No | Until consumed or cleansed; expires after a turn or two if never triggered (Open Question 8) | Triggering, cleanse, expiry |
| Damage type mark | Damage of a specific type deals extra damage; keeps the mark for the Round | No | One Round | Cleanse, round end |
| Damage piercing | Pierces a defensive damage type, only up to the blocked amount | Yes, to a limit | Amount of turns | Expiry |
| Damage decrease | Decreases damage against a defensive damage type | Yes, to a limit | Amount of turns | Expiry |
| Taunt | Caster taunts the friendly positions allies stand on; attacks targeting a taunted position redirect to the caster; caster gains defensive buffs | - | Amount of Rounds; not broken by anything else (Open Question 11) | Expiry |
| Silence | Silenced character cannot use Abilities (Open Question 14, answered: Abilities only) | - | Amount of turns | Expiry |
| Heal | Instantly restores HP (beneficial; never picked by random cleanses) | n/a | Instant | n/a |
| Heal over time | Restores HP at the start of the actor's Turn (beneficial) | Yes | `turns` | Expiry |

- Resistances are a percentage reduction of effect potency and apply to bleed and poison (Open Question 7, answered).
- Marks can be cleansed with items or abilities; cleanses exist for bleed and poison too.

## Current state

**Implemented** (steps 1-5 of the implementation order; UI effect icons are pending with [Shootout UI](Shootout%20UI.md)):

- `Shootout/ShootoutEffectManager.gd` — the full effect set: bleed (highest ticks, stacks stored, cleanse removes highest-first so the next takes over), poison (per-stack stacking, round-start ticks, 35% wear-off at round end, optional `rounds` duration), mark (priming -> active after one Round, bonus damage + follow-up effects consume it, expiry, cleanse), damage-type mark (one Round), damage piercing/decrease (turn countdown, stack limit), silence (turn countdown), taunt (round countdown, per-position redirect) and the Cylinder effect type delegated to the cylinder manager.
- Resistances are percentage potency reduction applied at tick time (`stats.resistances.bleed/poison`).
- Damage pipeline hooks (`applyOutgoingModifiers`/`applyIncomingModifiers`) are live: piercing reclaims only the amount actually blocked by defense (decided cap), decrease subtracts flat, active marks add bonus damage and apply their follow-up effects, damage-type marks match the attack's weapon type.
- Lifecycle wiring in `Shootout.gd`: `onTurnStart` before a turn (bleed kills are checked before the actor acts), `onTurnEnd` in `finishTurn()`, `onRoundEnd`/`onRoundStart` around the turn-order rebuild with a post-poison death sweep; taunt redirect on basic attacks for both sides in `resolveActOnce()`.
- Rodeo ops `apply_effect`, `cleanse_effect` and `modify_cylinder` route into the effect manager (warn-and-skip when it's absent).
- Move/item `effects` lists are dispatched after instant damage/healing by the action resolver.
- Tests: `Tests/TestEffects.gd` covers every behavior listed in the testing section below.

## Design

### Manager

New manager `Shootout/ShootoutEffectManager.gd` (`RefCounted`, `init(shootoutRoot)`):

```gdscript
# actorName -> { effectType: [effectInstance, ...] }
var effects = {}

# effectInstance shapes per type:
# bleed:            { amount, source }
# poison:           { amount, roundsLeft, source }
# mark:             { state: "priming"|"active", extraDamage, effects: [], roundsUntilExpiry, source }
# damage_type_mark: { damageType, extraDamage, source }
# piercing/decrease:{ damageType, amount, turnsLeft, source }
# silence:          { turnsLeft, source }
# taunt:            { casterName, roundsLeft, positions: [int] }   # stored on the caster
```

Core API, consumed by the action resolver (moves/items apply effects), the cylinder manager, the targeting manager (taunt redirect) and the UI (effect icons):

- `applyEffect(targetName, effect)` — handles per-type stacking rules: bleed keeps the highest active and stores the rest; poison appends; mark/damage-type-mark replace; piercing/decrease append up to a cap; cylinder delegates to `cylinderManager.applyCylinderModifier()`.
- `onTurnStart(actorName)` — bleed tick: deal the highest stored bleed's damage (reduced by `stats.resistances.bleed`); mark priming/expiry countdown.
- `onRoundStart()` — poison tick on every afflicted actor (reduced by `stats.resistances.poison`).
- `onRoundEnd()` — poison wear-off (multiply each stack's amount by 0.65, drop stacks below 1), damage-type-mark cleanup, taunt round countdown.
- `onTurnEnd(actorName)` — piercing/decrease/silence turn countdown.
- `cleanse(targetName, effectType, amount)` — removes afflictions; `"random"` picks a random affliction (implements the Rodeo `cleanse_effect` op).
- `getStatModifier(actorName, statName)` / `applyOutgoingModifiers()` / `applyIncomingModifiers()` — queries used by [Damage and Stats](Damage%20and%20Stats.md) (initiative/debuff modifiers, piercing vs defense, mark bonus damage on hit).
- `redirectTaunt(actingSide, targetName)` — if the target's position is taunted, returns the caster's name instead (see [Positions and Targeting](Positions%20and%20Targeting.md)).
- `isSilenced(actorName)` — gates the Moves act menu and enemy AI (see [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).
- `unregisterActor(actorName)` — on death; also removes taunts whose caster died and marks sourced by the dead actor.

### Turn/round hooks

Wire into the existing lifecycle (see [Turns and Initiative](Turns%20and%20Initiative.md)): `onTurnStart` at the top of `Shootout.startCurrentTurn()` (bleed damage can kill — check death before giving control), `onTurnEnd` in `finishTurn()`, `onRoundStart`/`onRoundEnd` around `createTurnOrder()` in `_on_actor_done()`.

### Data

Effects are fields on Move/Item data (and future Duck data), keeping acts data-driven:

```gdscript
# Data/Shootout/Moves/VenomRound.gd (example)
"effects": [
	{ "op": "apply_effect", "effect": "poison", "amount": 3, "rounds": 3 }
],

# Data/Shootout/Items/Antidote.gd (example)
"effects": [
	{ "op": "cleanse_effect", "effect": "poison", "amount": 1 }
]
```

The action resolver passes `data.effects` to `effectManager.applyEffect()` after instant damage/healing. Item target-side data (`"side": "player"`) already supports friendly-target cleanses.

### Rodeo integration

Move the reserved `cleanse_effect` op from warn-and-skip to `effectManager.cleanse()`. Rodeos that apply effects (e.g. a Rodeo that poisons on `turn_end`) use the same `apply_effect` op shape as moves, dispatched by the Rodeo manager into the effect manager.

## Files to create / modify

**Create**

- `Shootout/ShootoutEffectManager.gd`.
- `Tests/TestEffects.gd`.

**Modify**

- `Shootout/Shootout.gd` — instantiate the manager; add the four lifecycle hooks.
- `Shootout/ShootoutActionResolver.gd` — apply `data.effects` from moves/items; consult marks and piercing in damage calc.
- `Shootout/ShootoutTargetingManager.gd` — taunt redirect check in `isValidTarget()`/target selection.
- `Shootout/ShootoutTurnManager.gd` — `unregisterActor` on death.
- `Shootout/ShootoutRodeoManager.gd` — route `cleanse_effect` / `apply_effect` into the effect manager.
- `Actors/BaseActor.gd` — `stats.resistances` (with [Damage and Stats](Damage%20and%20Stats.md)).
- `Shootout/UI/ShootoutUI.gd` — effect icons on actors and in the stats panels (see [Shootout UI](Shootout%20UI.md)).

## Testing

`Tests/TestEffects.gd`:

- Bleed: only the highest stack ticks; stored stacks take over when it ends; healing removes it; resistance reduces potency.
- Poison: stacks accumulate, tick at round start, wear off 35% per round end.
- Mark: primes for a Round, bonus damage consumes it; expiry after the configured turns; cleanse removes it.
- Piercing caps at the amount actually blocked by defense.
- Taunt redirects single- and multi-target attacks for each protected position and expires after its Rounds.
- Silence blocks Abilities but not attacks, items or Ducks.
- Death of a taunt caster / mark source cleans up their effects.

## Implementation order

1. ✅ Manager skeleton + hooks + `applyEffect`/`cleanse` with bleed and poison.
2. ✅ Marks and damage-type marks + damage pipeline queries.
3. ✅ Piercing/decrease + silence.
4. ✅ Taunt redirect (basic attacks; multi-target acts follow with [Positions and Targeting](Positions%20and%20Targeting.md)).
5. ✅ Rodeo ops and move/item `effects` dispatch (authoring effect-bearing content pending).
6. UI icons (pending, see [Shootout UI](Shootout%20UI.md)).

## Open Questions

1. Exact numbers per effect (bleed/poison base amounts, mark bonus damage, piercing caps, poison wear-off ~35%) — balance pass; all values in data files, not code. Any placeholder is fine for now (confirmed).
2. Does healing remove the whole bleed stack or one stack per heal (proposed: whole stack — "won't stop until healed")?
3. Does silence also hide already-known ability tooltips, or just block use?
5. Decided placeholder (implementation detail): piercing/decrease amounts sum across types and are capped at the total blocked amount; per-type blocked breakdowns can come with the armor calculations from `Docs/Combat.md` Open Question 12.
4. Mark expiry counts the priming Round or starts after activation ("expires after a turn or two")? Any placeholder is fine for now (confirmed); pick one when implementing.
