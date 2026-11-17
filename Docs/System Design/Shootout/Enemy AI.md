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

**Implemented** (the decision pipeline, validated `ai` profiles, separated action-family weights, encounter-kind selection widths, boss scripts, and the commit-13 combat RNG plus measurement driver; broader class/role content authoring remains open):

- `Shootout/ShootoutEnemyAI.gd` replaces the random-target stub with `chooseAct()`: `gatherLegalActs()` uses the exact same validation/expansion as the player (targeting manager ranges, silence, usable-move filtering, `canMoveActor` for repositioning, multi acts collapsed to one entry with their full `targetNames`), `scoreActs()` grades every act/target set, and `pickFromTop()` chooses among the top candidates.
- Scoring (placeholder weights): attack abilities and damage moves score their amount (with a kill bonus); affliction effects score on unafflicted targets; heals score on wounded allies; Ducks score with wounded allies (bonus for the tank archetype); items heal-score by missing HP; multi acts sum their target set; repositioning scores only when useful (preferred-column bonus).
- Validated `ai` profiles (commit 13): `archetype` (`damage`/`support`/`tank`), `pickFromTop` (positive), per-action-family `weights` (`offense`, `support`, `defense`, `reposition` — offensive Moves and damage items weigh `offense`, Ducks weigh `defense`, heals/taunts weigh `support`, repositioning weighs `reposition`), `preferredColumns` and `script`. Unprofiled actors keep today's behavior (legacy `aggression` multiplier, top-2 pick). The content lint rejects unknown archetypes, non-positive widths/weights and unknown scripts.
- Selection width (commit 13): authored `ai.pickFromTop` > encounter kind (a **Showdown** selects only the highest-scored act; a **Dust-up** keeps today's top-2 default) — `CanyonRats` is the wide Dust-up proof (`Squeky rat` authoring `pickFromTop: 3`, `offense`-weighted), and the measurement driver's showdown fixture proves the deterministic best-act selection.
- Combat RNG (commit 13): the Shootout scene owns one `combatRng` seeded by the validated `EncounterRequest.seed` (explicit random fallback). AI picks, initiative rolls/tiebreaks, random cleanses and flavor names consume it; camera shake does not. Seeded fights log the seed, request and outcome. The seed stays inside the encounter context and unseeded production behavior is unchanged.
- Boss scripts: `Data/Shootout/AI/*.gd` (`rules` list of `{ when: { hpBelow/hpAbove }, act: { type, name, targetName } }` with `self`/`lowestHpAlly`/`lowestHpEnemy` targets), loaded into `Shootout.aiData`; the first passing rule beats all scoring.
- Enemy turns route through the same target-set resolution path as player acts (`resolveActOnce` handles moves, items and repositioning uniformly), with per-position taunt redirect.
- Measurement (commit 13): `Tests/TestEncounterMetrics.tscn` drives real-scene fights (player substituted, presentation waits skipped, production result handler disconnected) and records seed, request/Zone/path, teams, outcome, rounds, turns, hits, knockdowns and remaining health. `Tests/EncounterMetricsBaseline.json` stores the recorded `CanyonRats` baseline (seed 20261117: 6 turns, 1 round, victory, 6 hits, 3 knockdowns) and must replay exactly. **Measured deviation:** the current CanyonRats fight resolves in ~1 round against the 5–10-round design target and regular enemies fall in ~1–2 hits against the 3–5-hit target — a content/balance deviation to address through authored health/stat values (rats sit at 2 MxHP), not through test expectations or a global multiplier.
- Tests: `Tests/TestEnemyAI.gd` covers gathering/validation parity, silence, lethal-target preference, support healing, reposition fallback, boss-script priority, multi-act set gathering/scoring, separated offense/defense weights, Dust-up vs Showdown width, authored overrides, unknown-script fallback and seeded-replay determinism. `Tests/TestTurnOrder`/`Tests/TestEffects` cover seeded initiative and cleanse determinism; `Tests/TestContentLint` rejects invalid profiles.

## Design

### Decision pipeline

`chooseAct(actorName) -> Dictionary` replaces `chooseTarget()`, returning a full act `{ "type", "name"?, "targetName", "targetNames"? }`:

1. **Gather legal acts** — each known move usable from the current column (skipping abilities when silenced, see [Effects](Effects.md)); each remaining item; reposition forward/backward. Single-target acts produce one entry per legal target; `positions.type: "multi"` acts produce one entry with the full `targetNames` set. This uses the exact same validation/expansion functions as the player UI so AI and player can never diverge. Basic weapon attacks do not exist; every attack is an authored Move.
2. **Score each act+target set** — weighted scoring; multi acts sum their resolved set:
   - Attack Moves: authored base amount plus scaling, with a kill bonus; cylinder/quality resolution happens at execution.
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
3. **Decided for commit 13 in [First Steps §12](../First%20Steps%20Implementation%20Plan.md#12-phase-3--combat-breadth):** an unprofiled actor keeps today's top-2 selection for compatibility; a Dust-up deliberately chooses from a wider validated candidate set and a Showdown chooses only the highest-scored act. Authored `ai.pickFromTop`, action-family weights and seeded combat drivers replace the single global `PICK_FROM_TOP` constant and supply deterministic metrics before balance changes.
- Dust-ups are easier than Showdowns, which should be expressed in dumber weights and lower stats for enemies
