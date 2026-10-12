# Rodeo system

Rodeos are a character's passive ability, active during Shootouts (see `Docs/Combat.md`, "Rodeo"). This document describes how Rodeos are implemented in the Shootout scene: the data format, the runtime manager, the trigger hook points, and the phased rollout.

This is a design doc: it describes the intended design, and the implementation may lag behind it.

## Requirements (from `Docs/Combat.md` and `Docs/Actors.md`)

- A Rodeo is **passive** — never chosen as a Move, always on once combat starts.
- Activation timings:
  - Always active (continuous modifier, e.g. "cannot Miss or Graze")
  - At the beginning or end of the fight
  - At the beginning or end of every Round
  - At the beginning or end of the character's Turn
- Decided by character class; unique named characters have unique Rodeos; generic enemies can have Rodeos, but not all of them.
- One Rodeo per character (either the class Rodeo or a unique named Rodeo, never both).
- Higher party levels increase Rodeo values where applicable (linear `perLevel` placeholder scaling until balance passes).
- Rodeos can be game-warping: they can touch Cylinders, afflictions, positioning, stats, loot and special Chambers.
- Walker Langley is a special case: his Rodeo changes on quest completion (handled outside combat by the quest layer swapping `Party.party["Walker Langley"]["rodeo"]`; the combat side just reads whatever Rodeo is current at fight start).

## Current state

- The data plumbing already exists: actor data files (`Data/Actors/Named People/WalkerLangley.gd`, `Data/Actors/Animals/SquekyRat.gd`, `Globals/Party.gd`) carry a `"rodeo"` key, and `ActorBase.init()` stores it in `actor.rodeo`. Nothing reads it after that.
- The Shootout (`Shootout/Shootout.gd`) is orchestrated by `RefCounted` helper managers: `ShootoutTurnManager`, `ShootoutTargetingManager`, `ShootoutActionResolver`, `ShootoutAnimationSequencer`, `ShootoutEnemyAI`.
- Move and Item definitions are data-driven: `Data/Shootout/Moves/*.gd` and `Data/Shootout/Items/*.gd` each expose a `data` Dictionary, loaded at startup by `Globals/Shootout.gd:loadDataFolder()` into `Shootout.movesData` / `Shootout.itemsData`, keyed by `data.name`.
- Not yet implemented (Rodeos must tolerate their absence): Cylinders/Chambers, Effects/afflictions, per-Round initiative re-roll (turn order is currently created once per pass through `createTurnOrder()`, re-rolled only when `turnOrder` empties), repositioning Moves, and loot.

## Architecture

Two pieces, both following existing conventions:

### 1. Data: `Data/Shootout/Rodeos/*.gd`

One file per Rodeo, same shape as Moves/Items — `extends Node`, a single `data` Dictionary. Loaded by `Globals/Shootout.gd` into a new `Shootout.rodeosData` via the existing `loadDataFolder("res://Data/Shootout/Rodeos")`.

```gdscript
# Data/Shootout/Rodeos/LeadersDuck.gd
extends Node

var data = {
	"name": "Leaders Duck",
	"description": "Every other turn, at the end of the turn, move one column backward",
	"trigger": "turn_end",
	"conditions": {
		"target": "self",
		"everyOtherTurn": 2
	},
	"effects": [
		{ "op": "move_position", "direction": "backward", "amount": 1 }
	],
	"scaling": {}
}
```

Fields:

- **name** — display name; also the lookup key. Actor data stores Rodeos in lowercase (`"leaders duck"`); lookups are normalized with `to_lower()` so both forms resolve.
- **description** — shown in UI (hover/character sheet) and in the trigger popup.
- **trigger** — when the Rodeo fires (see Trigger taxonomy below).
- **conditions** — optional gate evaluated each time the trigger fires (target selector, position, counters, chance, HP thresholds).
- **effects** — ordered list of effect ops applied when conditions pass.
- **scaling** — how values grow with party level: `{ "stat": "level", "perLevel": <number>, "appliesTo": <effect field> }`. Empty means the Rodeo doesn't scale.


### 2. Runtime: `Shootout/ShootoutRodeoManager.gd`

A `RefCounted` manager with `class_name ShootoutRodeoManager`, instantiated in `Shootout._ready()` and wired like the other managers:

```gdscript
# Shootout/Shootout.gd
const RodeoManagerScript = preload("res://Shootout/ShootoutRodeoManager.gd")
...
rodeoManager = RodeoManagerScript.new()
rodeoManager.init(self)
```

Public API:

```gdscript
func init(shootoutRoot) -> void
func registerActor(actor) -> void          # called from Shootout.spawnActor()
func unregisterActor(actorName: String) -> void  # called when an actor dies
func trigger(triggerName: String, context := {}) -> void
func getStatModifier(actor, statName: String, baseValue) -> Variant  # passive modifiers
func getRodeoDisplayName(actor) -> String  # for UI
```

Internals:

- `rodeos: Dictionary` — `actorName -> { "data": <rodeo data>, "state": <runtime state> }`. Runtime state holds counters (`turnsElapsed`), one-shot flags (`usedThisFight`), and the list of temporary modifiers currently applied, so they can be reverted on expiry or fight end.
- `registerActor()` resolves `actor.rodeo` against `Shootout.rodeosData` (normalized lowercase). Unknown Rodeos log a `push_warning` and are skipped, so actor data can reference Rodeos that aren't implemented yet. `null` Rodeos (most animals, some generic enemies) are ignored silently.
- `trigger()` iterates registered Rodeos whose `data.trigger` matches, evaluates conditions, then applies each effect op in order. Dead actors are skipped.
- `getStatModifier()` is the passive-modifier pipeline: stat reads that Rodeos can influence (initiative in `ShootoutTurnManager.createTurnOrder()`, damage in `ShootoutActionResolver.resolveAttack()`) route the base value through it. Modifiers with conditions (e.g. "in the first column") are re-evaluated at query time, so position-dependent Rodeos like Aiyana's Happy Shot stay correct as actors move.

## Trigger taxonomy and hook points

Trigger constants live in the `Shootout` autoload next to `ACT_TYPE_*` (the manager holds the same constants as the canonical source; both are plain string literals so neither side needs a compile-time reference to the other — the manager resolves autoloads through the scene tree in `init()` so it stays loadable in headless test runs, where autoloads don't exist):

```gdscript
const RODEO_TRIGGER_FIGHT_START = "fight_start"
const RODEO_TRIGGER_FIGHT_END = "fight_end"
const RODEO_TRIGGER_ROUND_START = "round_start"
const RODEO_TRIGGER_ROUND_END = "round_end"
const RODEO_TRIGGER_TURN_START = "turn_start"
const RODEO_TRIGGER_TURN_END = "turn_end"
const RODEO_TRIGGER_ALWAYS = "always"
```

Hook points in the existing turn loop (`Shootout/Shootout.gd`):

| Trigger | Hook location |
| --- | --- |
| `fight_start` | End of `init()`, after all `spawnActor()` calls, before the first `createTurnOrder()` |
| `round_end` | `_on_actor_done()`, when `turnManager.turnOrder.is_empty()`, before re-creating the order |
| `round_start` | `_on_actor_done()`, right after `turnManager.createTurnOrder()` (and once after `fight_start` for the first Round) |
| `turn_start` | `startCurrentTurn()`, after the actor is resolved, before control is handed to player/AI |
| `turn_end` | `finishTurn()`, before `turnManager.advanceTurn()` |
| `fight_end` | `_on_battle_ended()`, with `{ "winningSide": winningSide }` as context |
| `always` | No event — applied once at `registerActor()` and maintained by `getStatModifier()` |

`context` carries what effects need: `{ "actor": <acting actor>, "target": <target actor>, "round": <int> }`.

Reserved for when the supporting systems land (the manager accepts and routes them now, nothing registers them yet): `on_attack`, `on_hit`, `on_damaged`, `on_affliction_applied`, `on_item_used`, `on_move_used`. These will be emitted from `ShootoutActionResolver` once attacks have qualities (Cylinders) and Effects exist.

Reactive triggers that modify an in-flight resolution (e.g. Natural Gunslinger's "cannot Miss or Graze") are implemented as **queries**, not events: the resolver asks `rodeoManager.clampHitQuality(actingActor, quality)` once Cylinders exist. Rule of thumb: use `trigger()` for things that happen *after* a beat; use a query method for things that *change the outcome* of a beat.

## Conditions

Evaluated in `trigger()` before effects run. Initial set:

| Condition | Meaning |
| --- | --- |
| `target` | Who the effects apply to: `self`, `allies`, `enemies`, `adjacent_allies` (both adjacent allies), `ally_in_front` / `ally_behind` (the single adjacent ally in front or behind), `all` |
| `everyOtherTurn` | Fires only when the Rodeo owner's elapsed personal turns are a multiple of N |
| `position` | Owner must stand in one of the listed columns, e.g. `[1]` for Happy Shot |
| `hpBelow` / `hpAbove` | Owner HP threshold (fraction of maxHp) |
| `oncePerFight` | Fires at most once per Shootout |
| `winningSide` | For `fight_end` Rodeos: only fire if this side won (Backpocket Check) |

Condition evaluation lives entirely in the manager; new conditions are added as new keys without changing the data format.

## Effect ops

Each entry in `effects` is `{ "op": <name>, ...params }`. The manager dispatches on `op`. **Unknown ops log a `push_warning` and are skipped** — this is the mechanism that lets Rodeo data reference Cylinder/affliction behavior before those systems exist, without breaking fights.

Implemented in the first pass:

| Op | Params | Behavior |
| --- | --- | --- |
| `modify_stat` | `stat`, `amount`, `duration` (`"fight"` or turn count) | Temporary stat change; reverted on expiry/fight end. Read through `getStatModifier()` |
| `move_position` | `direction` (`forward`/`backward`), `amount` | Repositions the actor, clamped to columns 1-4 (uses the same position data as `Shootout.shootoutPositions`) |
| `heal` | `amount` | Flat heal on the resolved targets |
| `modify_loot` | `stat` (`money`/`resources`), `amount` or `multiplier` | Accumulated by the manager during the fight; handed to the loot layer at `fight_end`. Stacks with all other loot modifiers, from Rodeos and equipment |

Reserved (registered in the dispatcher, warn-and-skip until their systems land):

| Op | Needs |
| --- | --- |
| `apply_effect` / `cleanse_effect` | Effects/afflictions system (bleed, poison, marks...) |
| `modify_cylinder` / `set_hit_quality_floor` | Cylinder system |
| `prevent_effect` | Effects system (immunities, e.g. Mark immunity) |
| `refresh_items` | Belt space / fight inventory |

## Party Rodeos mapped to the format

From `Docs/Actors.md`, showing the format covers the design:

| Rodeo | Trigger | Conditions | Effects | Status |
| --- | --- | --- | --- | --- |
| Leaders Duck (Walker) | `turn_end` | `self`, `everyOtherTurn: 2` | `move_position` backward 1 | First pass |
| Happy Shot (Aiyana) | `always` | `self`, `position: [1]` | `modify_stat` highTailin, duration `fight` | First pass (passive query) |
| Camaradería (Manuel) | `fight_start` | `ally_in_front` | `modify_stat` maxHp | First pass |
| Backpocket Check (Gwyneth) | `fight_end` | `winningSide: player team` | `modify_loot` money | First pass (loot hand-off stubbed) |
| Camp Caretaker (Morrison) | `turn_end` | `adjacent_allies` | `cleanse_effect` random 1 | Blocked on Effects; data ships, op warns+skips |
| Natural Gunslinger (Walker, quest) | `always` | `self` | `set_hit_quality_floor` 2 | Blocked on Cylinders; query API ready |

Class Rodeos from `Docs/Actors.md` follow the same mapping (stat ups, cylinder changes, taunt-piercing, item refresh); they are authored as data once their ops exist.

## Level scaling

- Party level lives in the `Party` autoload (`Party.gd` gains a `level` field, default 1, until quest progression sets it).
- When a Rodeo has `scaling`, the manager computes `value = base + perLevel * (level - 1)` for the listed effect field at registration time. Rodeos whose fantasy doesn't scale (Natural Gunslinger) leave `scaling` empty.

## Death and cleanup

- `ShootoutTurnManager.checkActorDead()` is where actors leave the fight; it calls `rodeoManager.unregisterActor(actor.name)` (via the shootout root) so dead actors' Rodeos stop triggering and their `modify_stat` contributions stop applying.
- At `fight_end` the manager clears all runtime state; nothing persists between Shootouts except the `modify_loot` accumulator, which is emitted with the `shootoutEnded` flow and then reset.

## UI

- Rodeos always show in UI, for player and enemy actors alike: the hovered-actor stats panel shows the actor's Rodeo name (payload `actorStatsPayload` gains a `Rodeo` field), and the player character panel shows the acting character's Rodeo next to their class. Descriptions are available for tooltips.
- Triggered Rodeos surface a small popup/damage-number-style label using the existing `Shootout.spawnDamageNumber()` (Rodeo name in a distinct color) so passive effects are visible to the player.

## Files to create / modify

**Create**

- `Shootout/ShootoutRodeoManager.gd` — the manager (registration, triggers, conditions, effect ops, stat queries).
- `Data/Shootout/Rodeos/*.gd` — one file per Rodeo, starting with the four "first pass" party Rodeos above.
- `Tests/TestRodeos.gd` — test following the `Tests/TestItemGeneration.gd` pattern (`_check` counting failures, `quit(failures)`).

**Modify**

- `Globals/Shootout.gd` — add `rodeosData`, load `res://Data/Shootout/Rodeos` in `loadData()`, add the `RODEO_TRIGGER_*` constants.
- `Shootout/Shootout.gd` — instantiate the manager, call `registerActor` in `spawnActor()`, add the six `trigger()` calls at the hook points in the table above.
- `Shootout/ShootoutTurnManager.gd` — route initiative through `rodeoManager.getStatModifier()` in `createTurnOrder()`; notify `unregisterActor` in `checkActorDead()`. (When the per-Round re-roll from Combat.md Open Question 4 lands, this is the same call site.)
- `Shootout/ShootoutActionResolver.gd` — route damage stat reads through `getStatModifier()`.
- `Globals/Party.gd` — add `level`.
- Actor data files — fill in `"rodeo"` for party members as their Rodeos are implemented.

## Testing

`Tests/TestRodeos.gd`, headless-runnable like `TestItemGeneration.gd`:

- Every file in `Data/Shootout/Rodeos` loads, has `name`/`trigger`/`effects`, uses a known trigger and known (or reserved) ops.
- Trigger plumbing: a manager with a fake `turn_end` Rodeo fires exactly when `trigger("turn_end", ...)` is called, and `everyOtherTurn: 2` fires on turns 2, 4, ... only.
- `getStatModifier()` applies and conditions gate correctly (position-conditional modifier changes value when the actor moves).
- Unknown Rodeo names and unknown ops warn and skip without crashing.
- `unregisterActor` stops a dead actor's Rodeo from triggering.
- Smoke: run `Shootout/Shootout.tscn` and confirm Leaders Duck repositions Walker every second turn end.

## Implementation order

1. Constants + `rodeosData` loading in `Globals/Shootout.gd`; empty `ShootoutRodeoManager` with registration and `trigger()` dispatch wired into all six hook points (no-op until data exists).
2. Condition evaluation and the first-pass effect ops (`modify_stat`, `move_position`, `heal`, `modify_loot`), plus the warn-and-skip dispatcher.
3. `getStatModifier()` query pipeline; route initiative and damage stat reads through it.
4. Author the first-pass party Rodeos (Leaders Duck, Happy Shot, Camaradería, Backpocket Check) and wire actor data; add the test.
5. UI surfacing (trigger popup, hovered-actor Rodeo display).
6. As Cylinders and Effects land, implement the reserved ops and author the remaining party and class Rodeos.

