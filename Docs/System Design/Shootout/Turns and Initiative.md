# Turns and Initiative

Turn structure of a Shootout: how initiative is computed, how the turn order is built and consumed, and how Rounds and battle end are detected. Game-design rules live in `Docs/Combat.md` ("Overview", "Stats > Initiative", Open Question 4).

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- Turn-based combat; each Turn one character takes one Move; a Round is one full pass in which every living character has taken a Turn.
- Turn order is based on High Tailin', a random roll and other modifiers (Rodeo and item modifiers).
- On even stats, turn order is random.
- Turn order is **re-rolled every Round** (Open Question 4, answered).
- A character that dies is removed from the fight immediately.
- A Shootout ends when one side has no living characters.

## Current state

**Implemented** (steps 1-4 of the implementation order): per-Round re-roll with random roll and tie shuffle, plus Round/Turn counters shared with the Rodeo manager. `Shootout/ShootoutTurnManager.gd` implements:

- `shootoutActors` registry (`{ team: { actorName: { actorPosition } } }`), filled by `registerActor()` from `Shootout.spawnActor()`.
- `createTurnOrder()` collects every living actor's modified High Tailin' **through** `rodeoManager.getStatModifier()` (so always-on Rodeos already affect initiative), adds a `randi_range(0, RANDOM_ROLL_MAX)` roll (placeholder constant 4), and sorts descending with a random tiebreak for equal initiative. It also increments `roundNumber` on every rebuild after the first.
- `advanceTurn()` / `currentActorName()` consume the order; `advanceTurn()` increments `turnNumber` (monotonic for the whole fight). `Shootout._on_actor_done()` rebuilds the order when empty, firing `round_end` / `round_start` Rodeo triggers around the rebuild.
- `checkActorDead()` removes dead actors from the order and registry, unregisters their Rodeo and emits `battleEnded` via `checkBattleEnd()`.
- The Rodeo manager no longer keeps its own round counter: `ShootoutRodeoManager.getRoundNumber()` reads the turn manager's counter (`context["round"]` for Rodeo triggers comes from it).
- Tests: `Tests/TestTurnOrder.gd` (headless) covers counters, tie randomness, stat gaps, Rodeo initiative modifiers and death handling; `Tests/TestRodeos.gd` covers the round delegation.

Gaps vs. the design:

1. **No item/effect modifiers** — only Rodeo modifiers feed initiative; effect-based modifiers come with [Effects](Effects.md).

## Design

### Initiative roll

Each Round, for each living actor:

```
initiative = modifiedHighTailin + randomRoll
modifiedHighTailin = rodeoManager.getStatModifier(actor, "highTailin", actor.stats.highTailin)
                     + effectManager.getStatModifier(actor, "highTailin")   # once Effects land
randomRoll = randi_range(0, RANDOM_ROLL_MAX)                                  # placeholder: 4
```

- Sort descending by `initiative`; ties broken by a coin flip (shuffle equal-initiative groups), satisfying "on even stats, turn order is random".
- `RANDOM_ROLL_MAX` is a placeholder constant for balancing; keep it a named const so balance passes can tune it. A flat 0-4 roll keeps High Tailin' meaningful while making even-stat matchups unpredictable.

### Round tracking

Add `roundNumber` and `turnNumber` to the turn manager (single source of truth; the Rodeo manager reads from it instead of keeping its own counter):

- `roundNumber` increments in `createTurnOrder()` (except the first call at fight start).
- `turnNumber` increments in `advanceTurn()`, monotonic for the whole fight; fleeing unlocks after 10 turns in Showdowns (see [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).
- Both are exposed via `getRoundNumber()` / `getTurnNumber()` so UI, Rodeos and flee logic share one counter.

### New-round flow

`Shootout._on_actor_done()` already centralizes the round boundary; it stays the only place that rebuilds the order:

```gdscript
if turnManager.turnOrder.is_empty():
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_END)
	effectManager.onRoundEnd()          # poison wear-off etc., once Effects land
	turnManager.createTurnOrder()     # re-rolls initiative, increments roundNumber
	rodeoManager.trigger(Shootout.RODEO_TRIGGER_ROUND_START)
	effectManager.onRoundStart()        # poison ticks, per Effects doc
```

### Mid-round deaths

`checkActorDead()` already erases the dead actor from `turnOrder` and `shootoutActors`. Actors that die before their Turn simply never act that Round — no reordering needed. There are no mid-fight reinforcements (decided); quest variety comes from win conditions instead.

## Files to modify

- `Shootout/ShootoutTurnManager.gd` — add `roundNumber`, `turnNumber`, the random roll and tie-breaking in `createTurnOrder()`, and the getters. Merge effect/item initiative modifiers when [Effects](Effects.md) lands. Also: local `TEAM_PLAYER`/`TEAM_ENEMY` consts (same values as the autoload) so the manager stays loadable in headless test runs.
- `Shootout/Shootout.gd` — add the `effectManager` round hooks in `_on_actor_done()` (once Effects land); no other changes.
- `Shootout/ShootoutRodeoManager.gd` — read `roundNumber` from the turn manager instead of its own counter.
- `Tests/TestRodeos.gd` — round-tracking checks now verify delegation to the turn manager counter.

## Testing

`Tests/TestTurnOrder.gd`, headless-runnable like `Tests/TestRodeos.gd`:

- Equal High Tailin' actors produce varying orders over many Rounds (statistical: at least two distinct orders in 50 rolls).
- Higher High Tailin' wins when the roll cannot overcome the gap.
- Rodeo initiative modifiers (e.g. Happy Shot in position 1) apply to the roll's base.
- `roundNumber` increments once per rebuild; `turnNumber` increments once per `advanceTurn()`.
- A dead actor never appears in subsequent orders; battle end emits exactly once.

## Implementation order

1. ✅ Round/turn counters + getters (no behavior change).
2. ✅ Random roll + tie shuffle in `createTurnOrder()`.
3. ✅ Rodeo manager reads the shared round counter.
4. ✅ Tests (`Tests/TestTurnOrder.gd`, updated `Tests/TestRodeos.gd`).
5. Wire effect/item initiative modifiers when the Effects system lands (pending).

## Open Questions

1. Exact size and shape of the random roll (flat 0-4 proposed; dice like 1d6 are an option) — needs a balance pass once [Damage and Stats](Damage%20and%20Stats.md) lands. Any placeholder is fine for now (confirmed).
2. ~~Can reinforcements join mid-fight?~~ — **decided**: no reinforcements; instead, quests can have different win conditions (survive N turns, get characters' MxHP below an amount, etc. — see [Encounters](Encounters.md)).
3. ~~Does the player see the full Round order?~~ — **decided**: yes, a full Round order strip with the current actor highlighted (see [Shootout UI](Shootout%20UI.md)).
