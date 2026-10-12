# Shootout system

A Shootout is the game's turn-based combat encounter (see `Docs/Combat.md` for the full game-design rules). This document is the overview of how Shootouts are implemented in code and links to the per-system design docs. Each linked doc covers one system: its requirements, current state, architecture and a code-level implementation plan.

This is a design doc: it describes the intended design, and the implementation may lag behind it.

## Scene architecture

The Shootout lives in `Shootout/Shootout.tscn` (`Shootout/Shootout.gd`). The scene root orchestrates combat and delegates to `RefCounted` helper managers, each owning one concern:

| Manager | File | Concern | Design doc |
| --- | --- | --- | --- |
| Turn manager | `Shootout/ShootoutTurnManager.gd` | Actor registry, turn order, death, battle end | [Turns and Initiative](Turns%20and%20Initiative.md) |
| Targeting manager | `Shootout/ShootoutTargetingManager.gd` | Validating act targets | [Positions and Targeting](Positions%20and%20Targeting.md) |
| Action resolver | `Shootout/ShootoutActionResolver.gd` | Applying attacks, moves and items | [Damage and Stats](Damage%20and%20Stats.md), [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md) |
| Animation sequencer | `Shootout/ShootoutAnimationSequencer.gd` | Playing act animations, emitting `frameHit` | [Shootout UI](Shootout%20UI.md) |
| Enemy AI | `Shootout/ShootoutEnemyAI.gd` | Choosing enemy acts and targets | [Enemy AI](Enemy%20AI.md) |
| Rodeo manager | `Shootout/ShootoutRodeoManager.gd` | Passive Rodeo triggers and stat queries | [Rodeos](../Rodeos.md) |

Shared combat constants and data live in the `Shootout` autoload (`Globals/Shootout.gd`): team names, act types, Rodeo trigger names, screen positions per column (`shootoutPositions`), and the data-driven act registries (`movesData`, `itemsData`, `rodeosData`) loaded from `Data/Shootout/**` via `loadDataFolder()`.

Actors in a Shootout are `Actors/Shootout/ShootoutActor.tscn` instances (`ShootoutActor.gd`, extending `Actors/BaseActor.gd`), initialized either from `Party.party` (gang members) or from `Data/Actors/{type}/{name}.gd` files (enemies).

## Combat lifecycle

1. **Init** — `Shootout.init(actors)` spawns actors from an encounter definition, registers them with the turn and Rodeo managers, fires `fight_start` Rodeos, builds the first turn order, fires `round_start`, and starts the first turn.
2. **Turn loop** — `startCurrentTurn()` gives control to the player (`playerHasControl`) or the enemy AI. The acting side picks an act (attack / move / item) and a target; the targeting manager validates it; the animation sequencer plays the act and emits `frameHit`, at which point the action resolver applies the effect exactly once; `finishTurn()` fires `turn_end` Rodeos, checks deaths and advances the order.
3. **Round boundary** — when the turn order empties, `round_end` Rodeos fire, a new turn order is built and `round_start` fires.
4. **Battle end** — when one side has no living actors, `ShootoutTurnManager` emits `battleEnded`; `fight_end` Rodeos fire, loot modifiers are consumed, and `shootoutEnded(winningSide)` is emitted to whatever launched the Shootout.

## System docs

| Doc | System | State |
| --- | --- | --- |
| [Turns and Initiative](Turns%20and%20Initiative.md) | Turn order, rounds, initiative rolls | Implemented: per-Round re-roll with random roll, round/turn counters |
| [Cylinders](Cylinders.md) | Cylinders, Magazines, Chambers, hit quality, special Chambers | Missing |
| [Damage and Stats](Damage%20and%20Stats.md) | Stats, damage types, hit/damage pipeline, resistances | Partial: flat stat damage only; no hit quality, no Style/Sand, no resistances |
| [Effects](Effects.md) | Bleed, poison, marks, taunt, silence, cylinder mods, piercing | Missing (Rodeo ops reserved) |
| [Positions and Targeting](Positions%20and%20Targeting.md) | 4-position ranks, move ranges, repositioning, displacement, taunt redirects | Partial: columns exist; no range validation, no repositioning Move |
| [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md) | Act types, move/ability/item data, Ducks, belt space | Partial: attacks/moves/items work; Ducks and belt space missing |
| [Enemy AI](Enemy%20AI.md) | Enemy decision making | Stub: random target, attacks only |
| [Encounters](Encounters.md) | Encounter data, Dust-ups vs Showdowns, bosses, spawn sources | Partial: one hardcoded encounter (`RatAmbush`) |
| [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md) | Injury, knockout, Vamoose, fleeing | Missing |
| [Rewards](Rewards.md) | Levels, loot tables, Rodeo loot modifiers | Partial: loot modifier accumulator exists, nothing consumes it |
| [Shootout UI](Shootout%20UI.md) | Act menus, stat panels, cylinder display, damage numbers | Partial: menus and panels exist; cylinder display missing |
| [Rodeos](../Rodeos.md) | Passive abilities | Implemented (first pass) |

## Cross-cutting conventions

- **Data-driven content**: every Move, Item, Rodeo and Encounter is a `Data/Shootout/**.gd` file exposing a single `data` Dictionary; the `Shootout` autoload loads whole folders. New systems should follow the same pattern (e.g. `Data/Shootout/Ducks`, `Data/Shootout/Encounters`).
- **Warn and skip**: managers tolerate missing data and unimplemented ops with `push_warning`, so systems can land incrementally (see the Rodeo manager's reserved ops).
- **Headless-testable**: managers resolve autoloads via `get_node_or_null("/root/...")` so tests like `Tests/TestRodeos.gd` can run without the full game. Each system doc includes a matching test plan.
- **Indexed actor names**: spawned actors get `"{name}{index}"` names (e.g. `Squeky rat0`) so duplicate enemies are addressable; `turnManager.shootoutActors` is the registry of living actors.

## Build order

The systems depend on each other; suggested order (details in each doc):

1. [Turns and Initiative](Turns%20and%20Initiative.md) — per-Round re-roll (small, unblocks balance testing).
2. [Cylinders](Cylinders.md) — hit quality gates the damage pipeline.
3. [Damage and Stats](Damage%20and%20Stats.md) — full damage pipeline on top of Cylinders.
4. [Effects](Effects.md) — afflictions need the damage pipeline and turn/round hooks.
5. [Positions and Targeting](Positions%20and%20Targeting.md) — range validation and repositioning.
6. [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md) — Ducks and belt space on top of Effects.
7. [Enemy AI](Enemy%20AI.md) — smarter decisions once moves/effects exist.
8. [Encounters](Encounters.md), [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md), [Rewards](Rewards.md) — meta layer around finished combat.
9. [Shootout UI](Shootout%20UI.md) — cylinder display and polish as systems land.
