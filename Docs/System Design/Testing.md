# Test coverage overview

Snapshot of what the project tests today and where testing could be added next. Line counts and coverage claims are current as of writing; treat this as a living map, not a gate.

## How tests are run

Two conventions coexist:

1. **Headless script tests** in `Tests/` — `godot --headless --script res://Tests/TestX.gd` (SceneTree scripts; each prints check lines and exits non-zero on failure). `Tests/TestShootoutTurnTiming.gd` is the exception: it runs as a scene (`godot --headless res://Tests/TestShootoutTurnTiming.tscn`) because `Shootout.gd` needs the project autoloads.
2. **In-tree test scenes** — several systems keep their tests next to the code and run them as scenes or interactive tools:
   - `Location/Location Generation/Test/` — WFC solver + pipeline integration tests, a pathfinding sandbox, chunk-tile helper.
   - `Minigames/Poker/Test/` — hand evaluation + a multi-game flow simulation.
   - `Minigames/Gold Rush/Test/` — automated Robbing minigame simulation.
   - `Nodes/Item Stats/Test/` — interactive item-roller tool (F6, not automated).
   - `Nodes/Scene Manager/Test/` — scene manager checks.
   - `Game/Test/` — manual movement/scene-warp sandboxes (player + overworld/location round trips), not automated.

The single entry point is `Tests/RunAll.gd`: it spawns one isolated Godot child process per test (each test wants to be the main loop or own the tree), routes each test's output into a per-test log file it echoes on completion, kills tests that exceed a per-test timeout (these suites exist because of soft locks — a hung test must fail the run, not hang it) and exits with the number of failed tests:

```
godot --headless --script res://Tests/RunAll.gd            # everything
godot --headless --script res://Tests/RunAll.gd -- Music   # substring filter
```

It discovers `Tests/Test*.gd` and `Tests/Test*.tscn` automatically (a test with a sibling scene runs only as the scene — `--script` mode has no autoloads, which `TestShootoutTurnTiming.gd` needs) plus the automated in-tree scene tests with real exit codes (WFC solver/integration, `ClearwaterGroveSceneTest`, `RobbingTest`). Poker's and the Scene Manager's tests `quit()` unconditionally (always exit 0), so they cannot gate a pass/fail run and are left out of the automated set.

## What is tested

### `Tests/` (headless, logic-focused, fake-collaborator style)

| Test | System under test | Covers |
|---|---|---|
| `TestTurnOrder` | `Shootout/ShootoutTurnManager.gd` | Initiative ordering, round cycling, turn bookkeeping |
| `TestTargeting` | TurnManager + `ShootoutTargetingManager.gd` | Squeeze repositioning (swaps, line shuffles, bounds), move/weapon ranges, item permissiveness, position-conditional Rodeos |
| `TestActs` | `ShootoutActionResolver.gd` | Moves, items and ducks: costs, effects, stat gates |
| `TestDamage` | ActionResolver + CylinderManager | Damage pipeline: hit quality, base damage, multipliers |
| `TestCylinders` | `ShootoutCylinderManager.gd` | Cylinder advance, reload/jam, effect delegation |
| `TestEffects` | `ShootoutEffectManager.gd` | Bleed/poison ticking, Mark, piercing, taunt redirect, silence, death cleanup |
| `TestInjury` | `Globals/Party.gd` + resolver | Death, injury, retreat/flee costs (Party's fight-results path) |
| `TestLoot` | `Globals/ItemGeneration.gd` | Rewards and loot table ranges, rarity bands |
| `TestItemGeneration` | `Globals/ItemGeneration.gd` | Affixes, kinds, rarities, band sanity |
| `TestEncounters` | `Globals/Shootout.gd` encounter data | Encounter file validity, team uniqueness, win conditions (defeat_actor, survive_rounds, hp_below, rout default) |
| `TestEnemyAI` | `ShootoutEnemyAI.gd` | Enemy act selection |
| `TestRodeos` | `ShootoutRodeoManager.gd` | Trigger/operation registry, stat modifiers, `move_position` |
| `TestAnimationSequencer` | `ShootoutAnimationSequencer.gd` + `Animations.gd` | Back-to-back animation restarts (the turn soft lock), unreachable hit frames, missing animations, target-effect anchoring above the drawn body |
| `TestShootoutFocus` | `ShootoutFocusManager.gd` + `Animations.gd` act motion | Lunge/recoil hold-until-settle, focus zoom, facing flips, fixed screen anchors, only-landed-hits-recoil |
| `TestShootoutTurnTiming` | `Shootout/Shootout.tscn` (scene-run) | Turn cleanup is immediate; next-actor hand-off waits for the between-act pause |
| `TestShootoutUI` | `Shootout/UI/TurnOrderStrip.gd`, `ShootoutUI.tscn` | Turn order strip rendering, grey-out reasons for acts, armed-act selection tint, reposition picker states, scene wiring, acts row icons |
| `TestHPIndicator` | `Nodes/HP Indicator/HPIndicator.tscn` | World-space HP bar fill clipping, low-HP tint |
| `TestActorShadow` | `Nodes/Actor Shadow/ActorShadow.gd` | Shadow geometry on the feet line, sizing to the frame's visible (opaque) body with raw-frame fallback, HORIZONTAL/DIAGONAL/VERTICAL coverage geometry, re-measure on animation and horizontal-flip changes, sprite re-parenting, scene-created shadows |
| `TestMusicPlayer` | `Globals/MusicPlayer.gd` | Playback, tail fades, crossfades, full-volume start from silence, push/pop stack, zone/location/encounter/cutscene decisions |
| `TestQuests` | `Data/Quests/` + `Globals/Quests.gd` | Definition/catalog validation, availability and fail-closed loading, linear progress and final completion, duplicate/out-of-order rejection, journal projections/history, current-marker derivation, deterministic ordering, copy isolation, production catalog |
| `TestQuestsTab` | `UI/Journal/Tabs/QuestsTab.tscn` (scene-run) | Active/Completed sections, default/selected/completed detail states, empty/unavailable/malformed providers, live signal refresh and connection lifecycle, focus handoff/restoration, Show on map request payload, long-content scrolling at 640×360 |
| `TestQuestTriggers` | `Cutscenes/Cutscene.gd` + Pistoleros Regroup data (scene-run) | Quest shot start/complete dispatch, non-blocking behavior, rejected/unknown actions, end-shot placement and objective order in all five cutscene data files, played-cutscene keys, and the five-Location prologue scene/cutscene/exit chain |
| `TestOverworldChunkStream` | `Overworld/OverworldChunkStreamCache.gd` (+ `Overworld.gd` placement) | Per-chunk queue replacement/drain, budgeted partial writes with resume offsets, the queued erase of an unloaded chunk, the shared unload rule, cache bounds over 120 crossings, and the shared-anchor collision diamond |

### In-tree tests

| Test | System | Notes |
|---|---|---|
| `WFCSolverTest`, `WFCIntegrationTest` | `Location/Location Generation/Wave Function Collapse/` | Solver correctness on synthetic + real location inputs |
| `TestAStarPathfind` | A* over generated chunks | Sandbox-style, manual |
| `ClearwaterGroveSceneTest` | `LocationGeneration.gd` pipeline | Timing/timeout assertions on real generation |
| `PokerHandTest`, `PokerFlowTest` | `Minigames/Poker/Poker.gd` | Hand evaluation; multi-game flow with frame budget |
| `RobbingTest` | `Minigames/Gold Rush/Robbing.gd` | Simulated clicks, scoring, despawn, end condition |
| `SceneManagerTest` | `Nodes/SceneManager/SceneManager.gd` | Scene switching, transition guard, fade state |

**Rough coverage profile:** the Shootout simulation core (turns, targeting, acts, damage, effects, cylinders, rodeos, AI, encounters, loot, injury) is well covered by fast headless fakes. Presentation-adjacent logic (sequencer, focus, shadows, HP indicators, music) is covered at the unit level. Overworld streaming's pure cache/queue/eviction logic is covered by `TestOverworldChunkStream`; everything that is mostly *scene, input or asset plumbing* — the streaming scene wiring, cutscenes, minigames, UI widgets, dialogue/events — is thin or untested.

## Gaps, prioritized

### 1. Overworld chunk streaming (`Overworld/Overworld.gd` + `OverworldChunkStreamCache.gd`) — highest value
The most recently reworked, most concurrency-heavy logic in the game (background thread scene parsing, `chunkScenes` cache, `cellOpQueue` with a per-frame budget, `pendingChunkLoads` retries, merged TileMapLayer cell writes). Bugs here are frame stalls and invisible tiles — exactly the class of regressions that reappear. The cache, queue, eviction and unload-rule bookkeeping now live in `OverworldChunkStreamCache.gd` and are covered by `TestOverworldChunkStream.gd`; what is still untested there:
- cache fill/invalidation and the "no scene file → null cache entry" path,
- the real background-parse round trip (`requestChunkScene` → `pollChunkScenes`) and retry semantics when a chunk is requested while its scene is still parsing,
- `Overworld.gd`'s own crossing orchestration (`setAdjacentChunks`, `processPendingChunkLoads`, `removeFarawayObjects`) — the pure decision (`isKept`) is tested, the scene-level wiring is not.
`Docs/System Design/Overworld Spawns.md` already plans `OverworldSpawnpoint` rework — testing the spawn-point path now would de-risk that.

### 2. Overworld event triggering (`Globals/OverworldEvents.gd`)
Small but decision-heavy: distance accumulation, per-biome event pools (`Data/Events/*.gd` are plain data), random selection, cooldown/gating via `on_event_closed`. A headless test with an injected RNG over the real event data would catch "event pool typo silently never fires" bugs. `PlayerOverworldActor.process_event_result()` (applying event outcomes) is the companion seam.

### 3. Cutscene playback engine (`Cutscenes/Cutscene.gd`)
~190 lines driving every story scene: shot sequencing, actor placement, waits, music hooks, fade handshakes. `TestQuestTriggers` now covers the quest shot's start/complete dispatch, non-blocking behavior, rejected actions, and the Pistoleros Regroup end shots/objective order. The rest of the interpreter (waits, music hooks, end signal) and a full data lint ("every referenced actor/scene/track exists") remain open.

### 4. Bear Hunt minigame (`Minigames/Bear Hunt/` — ~1,700 lines, zero tests)
The largest untested code block in the repo: three sub-games (Dodging, Gathering, Hunting) with scoring, spawning and difficulty logic. `RobbingTest.gd` is the in-repo template for simulating a minigame headlessly; porting that pattern to Bear Hunt (especially scoring and end conditions) is high value per line.

### 5. Location generation glue beyond WFC
The solver is tested, but `LocationGeneration.gd`, `LocationMap.gd`, `LocationMapLayoutGeneration.gd`, `ChunkProcessor.gd`/`ChunkProcessorBase.gd` and the three hand-authored location data files (`Data/Location Generation/`) are not — chunk hand-off, layout rules and processor ordering are regression-prone. The existing `ClearwaterGroveSceneTest` covers one location end-to-end; a data-driven loop over all three location definitions would triple coverage for near-zero extra code.

### 6. Shootout scene-level flows
`Shootout.gd` itself (630 lines) is only touched by `TestEncounters` (data) and `TestShootoutTurnTiming` (one timing property). Untested seams that are still pure logic:
- `actSteps()`/`buildActSteps()` data-driven animation step selection,
- `repositionActor()` snapshot-and-slide bookkeeping and `playRepositionSlide()` no-op guard,
- `fightOutcome()` / `isPartyWiped()` / `generateLootForFight()` outcome mapping,
- `pickFlavorName()` uniqueness,
- hover stat panel stale-exit guard (`hoveredActorName`).
`ShootoutActor` input-collision sizing (body rect from the sprite, capped width) was a bug farm historically and has no regression test.

### 7. UI widgets and small nodes
All small, most pure-ish, all untested: `UI/Dialog/Dialog.gd`, `UI/Popup/Popup.gd`, `UI/Tooltip/Tooltip.gd` + `AddTooltip`, `RichTextLabelExtended(8px)`, `Nodes/ItemNumber.gd`, `Nodes/ItemStats.gd` (interactive-only today), `Nodes/Dynamic Sprite/DynamicSprite.gd`, `Nodes/Exit/Exit.gd`, `Nodes/AStar/AStar.gd` + `AStarGrid.gd`. The two RichTextLabel extensions and the tooltip wrappers are classic "break silently on next Godot upgrade" candidates — a minimal smoke test each (instantiate, set text/theme, no crash) is cheap. `Nodes/Damage Number/DamageNumber.gd` is covered by `Tests/TestDamageNumber.gd` (palette lookup, fallback color, spawn position).

### 8. Party persistence beyond injury
`Party.gd` is tested through the injury lens only. `applyLoot()`, `effectiveMaxHp()`, and the save/serialize side (once save/load exists — MainMenu's Continue is still a stub) will need their own coverage. `PokerMoney.gd` is still a near-stub. `Quests.gd` is covered by `Tests/TestQuests.gd`, the tab by `Tests/TestQuestsTab.gd`, Map navigation by `Tests/TestJournal.gd`/`Tests/TestOverworldMapTab.gd`, and cutscene progression by `Tests/TestQuestTriggers.gd`; persistence remains untested until save support lands.

### 9. Known planned-but-missing tests
`Tests/TestJournal.gd` covers the Journal shell lifecycle, tab navigation, input/pause behavior and the real-shell Quests → Journal → Map navigation flow. `Tests/TestQuestsTab.gd` covers the Quests tab UI, `Tests/TestOverworldMapTab.gd` covers quest marker identity/exact focus/malformed entries/same-anchor selection/active signal lifecycle, and `Tests/TestQuestTriggers.gd` covers the cutscene quest shot, Pistoleros Regroup progression data, and the five-Location prologue chain.

The latest full `RunAll` run is 32/33. The only failure is the pre-existing, unrelated `Tests/TestActorShadow.gd` VERTICAL shadow padding/offset check, which reproduces standalone and is not touched by the Quests feature.

### Lower priority / consciously untested
- **Visual/shader systems** — `Shaders/Blur`, `PlayerRevealController`/`RevealableObject`, outline shaders: headless asserts are mostly meaningless here; keep them manual/QA.
- **`Globals/FrameData.gd`, `MusicData.gd`, item data files** — data tables; a schema/sanity test (all referenced track ids exist on disk, hit-frame indices are in range for their animations) is more useful than unit tests. An animation-scene ↔ FrameData consistency check (e.g. rifle hit frame 5 exists in every Shoot Rifle animation) would have caught recent retiming work by hand.
- **`Globals/MultiThreading.gd`, `WaveFunctionCollapse.gd`, `Locations.gd`** — thin wrappers; cover indirectly via their consumers.

## Suggested next steps
1. Wire `Tests/RunAll.gd` into the workflow (run it before pushing / in CI).
2. ~~Extract the pure-logic parts of `Overworld/Overworld.gd` (cache, queue, adjacency) into a testable seam and add the first overworld test.~~ Done: `Overworld/OverworldChunkStreamCache.gd` + `Tests/TestOverworldChunkStream.gd`. Next in that vein: the background-parse round trip and the scene-level crossing orchestration.
3. Add an OverworldEvents trigger test with an injected RNG.
4. Port the `RobbingTest` simulation pattern to Bear Hunt scoring.
5. Add a data-lint test pass over cutscene data and music/animation references.