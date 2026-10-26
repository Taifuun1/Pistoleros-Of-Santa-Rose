# Enemy AI

How the enemy side chooses acts and targets. Game-design rules live in `Docs/Combat.md` ("Encounters > Enemies", class compositions per region).

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements

- Enemies take the same kinds of Turns as player characters: attacks, abilities, items, Ducks, repositioning.
- Enemy classes lean on their niche: e.g. Bobtail Guards afflict, Bottle Courage Bulldozers taunt and tank, Dust Whisperers apply effects and use items (`Docs/Combat.md` class ability lists).
- Region flavor: Prairie/Fallen City enemies lean on Bobtail Guards, Snowy Mountains on Line Riders, Wild West on Bottle Courage Bulldozers — an encounter-composition concern (see [Encounters](Encounters.md)), but the AI must play each class to its role.
- Bosses should feel unique — bosses can have bespoke AI scripts or weights (see [Encounters](Encounters.md)).
- The AI must respect the same rules as the player: position ranges, silence, taunt, item consumption.

## Current state

**Implemented** (the decision pipeline, archetypes and boss scripts; content authoring of `ai` blocks and boss scripts is ongoing):

- `Shootout/ShootoutEnemyAI.gd` replaces the random-target stub with `chooseAct()`: `gatherLegalActs()` uses the exact same validation as the player (targeting manager ranges, silence, usable-move filtering, `canMoveActor` for repositioning), `scoreActs()` grades every act/target pair, and `pickFromTop()` chooses randomly among the 2 best.
- Scoring (placeholder weights): attacks score expected damage via a side-effect-free `estimateAttackDamage()` (full pipeline minus mark consumption, current Chamber aware) plus a kill bonus; attack abilities and damage moves score their amount; affliction effects score on unafflicted targets; heals score on wounded allies; Ducks score with wounded allies (bonus for the tank archetype); items heal-score by missing HP; repositioning scores only when useful (preferred-column bonus).
- Archetype weights via the optional `ai` block on actor data (`archetype`, `preferredColumns`, `aggression`, `script`); missing blocks fall back to the damage archetype defaults.
- Boss scripts: `Data/Shootout/AI/*.gd` (`rules` list of `{ when: { hpBelow/hpAbove }, act: { type, name, targetName } }` with `self`/`lowestHpAlly`/`lowestHpEnemy` targets), loaded into `Shootout.aiData`; the first passing rule beats all scoring.
- Enemy turns route through the same resolution path as player acts (`resolveActOnce` handles attacks, moves, items and repositioning uniformly), with taunt redirect on basic attacks.
- Tests: `Tests/TestEnemyAI.gd` covers gathering/validation parity, silence, lethal-target preference, support healing, reposition fallback and boss-script priority.

## Design

### Decision pipeline

`chooseAct(actorName) -> Dictionary` replaces `chooseTarget()`, returning a full act `{ "type", "name"?, "targetName" }`:

1. **Gather legal acts** — basic attack (if the weapon can fire from the actor's current column at a living enemy column, per [Positions and Targeting](Positions%20and%20Targeting.md)); each known move usable from the current column (skipping abilities when silenced, see [Effects](Effects.md)); each remaining item; reposition forward/backward. This uses the exact same validation functions as the player UI so AI and player can never diverge.
2. **Score each act+target pair** — weighted scoring:
   - Attack: expected damage after the defender's known defense and the attacker's current Chamber (the AI "knows" Cylinders since the player can see them, Open Question 5 in `Docs/Combat.md`); bonus if it kills.
   - Affliction moves: value of the effect on targets that lack it; reduced value on already-afflicted targets.
   - Taunt/Ducks: high when allies are low HP or when the caster is the tank class; low when already taunting.
   - Heals/cleanses: high when an ally is below a health threshold or carries a strong bleed/poison.
   - Reposition: only when no attack/move is legal from the current column, or when a class-preferred column is free.
3. **Pick** — highest score with per-enemy randomness: roll against the top scores (`pickFromTop(scoredActs, 2)`) so enemies are competent but not robotic. Per-archetype weight tables in enemy data tune aggression vs. support.

### Archetype weights

Enemy actor data files gain an optional `ai` block:

```gdscript
"ai": {
	"archetype": "afflictor",          # damage | tank | afflictor | support | custom
	"preferredColumns": [3, 4],
	"aggression": 0.7,                 # bias of attack scores vs. utility scores
	"script": null                     # boss scripts: name of a Data/Shootout/AI/*.gd file
}
```

Missing `ai` blocks fall back to `"damage"` archetype defaults, preserving current simple behavior for animals like the Squeky rat.

### Boss scripts

Bosses with unique behavior get a data file (`Data/Shootout/AI/*.gd`, same `data` convention) describing a priority list or phase logic (e.g. "below 50% HP, always use move X"). `chooseAct()` checks for a script first; scripts return an act or fall through to scoring. This keeps boss design data-driven and per-fight.

### Turn flow integration

`Shootout.startCurrentTurn()` currently hardcodes attack resolution for the enemy; it changes to:

```gdscript
var act = enemyAI.chooseAct(turnManager.currentActorName())
selectedAct = act
# reuse the exact player path: resolveActOnce() handles attacks/moves/items uniformly
```

This deletes the special-cased enemy attack and routes everything through the animation sequencer and action resolver like player acts.

## Files to create / modify

**Create**

- `Data/Shootout/AI/*.gd` — boss scripts (as needed).
- `Tests/TestEnemyAI.gd`.

**Modify**

- `Shootout/ShootoutEnemyAI.gd` — the decision pipeline, scoring, archetype defaults.
- `Shootout/Shootout.gd` — `startCurrentTurn()` routes enemy acts through the standard resolution path.
- Enemy actor data files — `ai` blocks.
- `Globals/Shootout.gd` — optionally load `Data/Shootout/AI` into `aiData`.

## Testing

`Tests/TestEnemyAI.gd`:

- Legal-act gathering matches player validation (silenced enemies never pick abilities; out-of-range moves are never picked).
- A lethal attack is always scored above non-lethal ones with default weights.
- Support archetypes heal a low-HP ally instead of attacking (deterministic with seeded RNG).
- Reposition is chosen when no attack is legal from the current column.
- Boss script priority beats scoring; fallthrough works.

## Implementation order

1. ✅ `chooseAct()` + standard resolution path (special case removed).
2. ✅ Scoring + archetypes + randomness.
3. ✅ Move/item/Duck usage (with [Effects](Effects.md) and [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).
4. ✅ Repositioning (with [Positions and Targeting](Positions%20and%20Targeting.md)).
5. Boss scripts: machinery ✅; first boss script content pending with [Encounters](Encounters.md).

## Open Questions

1. How much should enemies "know"? (Proposed: full Cylinder and effect knowledge, since the player sees the same; HP thresholds only for their own side. First pass uses full knowledge.)
2. ~~Should generic enemies flee or surrender?~~ — **decided**: no, enemies never flee; quest variety comes from win conditions instead (survive N turns, get MxHP below an amount, etc. — see [Encounters](Encounters.md)).
3. Difficulty knobs: should Dust-ups use dumber weights (more randomness) than Showdowns? (First pass: `PICK_FROM_TOP = 2` for everything; the knob exists on the AI.)
- Dust-ups are easier than Showdowns, which should be expressed in dumber weights and lower stats for enemies
