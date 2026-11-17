# First implementation steps: coherent Trail and encounter vertical slice

**Status: commits 1–10 implemented; the production integration blockers found during acceptance are closed, while the affected manual step 5 and controller/audio passes await reconfirmation, and multi-target acts, the effect/stat seams and the disk save service plus Continue are covered by the full automated suite.** Commit 1 added the authoritative On/Off Trail state and gates. Commit 2 added the typed encounter request, SceneManager launch/return router, deterministic Zone pool selection, canonical Zone event pools and the explicit event outcome dispatcher. Commit 3 replaced independent Party belt arrays with validated reservations and one-shot combat consumption. Commit 4 migrated the decided combat rules: max-HP fight starts with Trail-gated attrition, combined bleed stacks with stack-removing healing, authored-Move-only offense, per-actor `hp_below`, explicit Jammed payloads, Miss suppression and Zone-aware loot. Commit 5 added Vamoose routing/loss and the New Game reset coordinator. Commit 6 added the production content lint (`Tests/TestContentLint.gd`) with teeth, the injected-RNG Overworld event suite (`Tests/TestOverworldEvents.tscn`), the duplicate/reference/`hp_below`/Zone/access-gate checks in the existing content tests, and this documentation closure. Commit 7 wires the real Littlehill Grove quest trigger, central quest-result completion, production return-to-menu, gamepad bindings and Overworld Zone-context invalidation. Commit 8 replaces the one-target act handoff with the shared target-set pipeline (expansion, per-position taunt, once-per-act costs, animation fan-out and AI set scoring). Commit 9 adds the supported-stat registry, flat effect modifiers, taunt defensive buffs and one combat/UI stat read. Commit 10 adds the versioned disk save service, Overworld-boundary checkpoints, the production Continue route and the second-process application-restart proof.

This is the first delivery slice for the [Implementation gap register](Implementation%20Gaps.md) and [System coherence requirements](System%20Coherence.md). Use the [Content and balance catalog](Content%20and%20Balance%20Catalog.md) for exact data/scene locations.

## 1. Goal and scope

Build one real, testable loop before expanding content:

1. New Game starts **Off Trail**. The player may use a Town and advance a quest, but cannot enter a non-town Location, accumulate/apply attrition, or receive loot.
2. The player buys one Paregoric in Lazysprings, then explicitly starts a Trail. Rolled vendor stock resets exactly once.
3. A real Overworld event selects a canyon encounter from the shared pool and launches it with an origin and Trail context.
4. The player assigns the purchased Paregoric to Walker's belt, uses it in the Shootout, wins, and returns to the same Overworld position. The carried stack is reduced exactly once and On-Trail loot is awarded once.
5. The same flow is proven Off Trail for a quest encounter: quest progress and combat work, but no loot is generated and non-town Location access remains blocked.
6. A separate Vamoose case returns to the recorded Town, removes half of money and 15% of occupied carried stacks, and does not apply persistent knockout debuffs.

This slice deliberately uses existing Walker, canyon rat, Paregoric and Lazysprings content. The only new combat content should be a small `Scratch` Move needed to remove the rat's basic-attack fallback.

## 2. Contracts to lock before editing behavior

- `Locations` is the only owner of On/Off Trail state and `trailDepartureId`. Scene presence is never used as a substitute.
- `SceneManager` owns encounter scene transitions and one return context. `Globals/Shootout.gd` carries only the pending validated request; it does not own the return destination.
- `Party` is the only owner of money, inventory, equipment and belt reservations. Vendors, combat, quests and minigames call Party commands rather than mutating arrays.
- `CharacterStatCalculator` remains pure. Trail/attrition context is injected by Party; the calculator never reads an autoload.
- Production launches never silently use `RatAmbush`. That encounter remains an explicit debug/test selection only.
- Initial Vamoose inventory rule: **15% of occupied carried stacks, rounded up, minimum one when inventory is non-empty**. Equipped items and Bank contents are excluded. This is the initial balance value within the decided 10–20% range; keep it named and injectable for tests.
- Item use is consumption, not loot. Consumption commits On or Off Trail; Off Trail only suppresses new rewards.
- Recommended end-of-Trail policy: an explicit `Locations.enterTown(locationId)` domain command called on Overworld-to-resupply-town entry ends the Trail. Vendor-room return and generic scene loading do not call it. Confirm this policy in the first review; if changed, keep it behind the same single command.
- **Post-commit-5 follow-up:** a Town also needs an Off-Trail way out. `res://Location/Entities/Town/TownExit.tscn` returns to the Overworld through `Locations.enterOverworld()` without starting or ending a Trail, so quest movement and town-to-town travel stay reachable Off Trail; `TrailDeparture` remains the only Trail start. See System Coherence §3.A.
- **Save contract (commit 10):** `Globals/SaveGame.gd` is the only disk writer. Every wrapper and node domain exposes a versioned `exportState()`/`importState()` pair and the service audits cross-references before committing, rolls a failed commit back, and replaces the file atomically. `SceneManager` owns the two Overworld checkpoint triggers; `MainMenu`/`SceneManager.continueGame()` own Continue; New Game never reads a stored save.

## 3. Delivery sequence

| Commit | Deliverable | Main proof |
|---|---|---|
| 1 | On/Off Trail state and feature gates | Town-only start, explicit end, access/attrition/loot rules and stock boundary tests |
| 2 | Encounter request, launch and return router | One real event launches a selected canyon encounter and returns exactly once |
| 3 | Shared belt ownership and consumption | Purchase → reserve → combat use → carried-stack decrement without duplication |
| 4 | Decided combat-rule migrations | Max-HP/no-knockout, combined bleed, no basic attacks, per-actor HP threshold, Zone loot |
| 5 | Vamoose routing/loss and New Game reset | Correct destination/loss, Off-Trail restrictions restored, clean initial state |
| 6 | Content lint, documentation and acceptance | Full automated suite plus manual vertical-slice run at 640×360 |
| 7 | First-slice integration pass | Quest trigger/result lifecycle, production return-to-menu, gamepad bindings and music-transition invalidation |
| 8 | Multi-target acts | One target-set pipeline for player/AI, per-position taunt, once-per-act costs, animation fan-out |
| 9 | Effect/stat seams | Supported-stat registry, flat effect modifiers, taunt defensive buffs, shared combat/UI stat read |
| 10 | Disk save service and Continue | One versioned, validated payload restored exactly by a second process; Overworld checkpoints; Continue gated on a valid save |

Run focused tests after every commit and `godot --headless --path . --script res://Tests/RunAll.gd` before moving to the next commit. Keep the current uncommitted documentation updates separate from code commits unless a code change requires a doc update.

## 4. ✅ Commit 1 — On/Off Trail state and feature gates

**Implemented.** `Locations` owns `onTrail`, the Town context, last Town and departure id; `TrailDeparture` starts through `startTrail()`; Overworld Location entries carry an authored `isTown` flag and reject non-town access Off Trail; Town entry ends an active Trail once; versioned `exportState()`/`importState()`/`resetForNewGame()` are live. `TestTrailState.gd` covers the state, gates, signals, snapshots and production Town data; the vendor suite still passes with departure-only stock resets.

### Implementation

1. In `res://Globals/Locations.gd`, add the authoritative boolean state and a small command/query surface:
   - `isOnTrail() -> bool`
   - `startTrail() -> Dictionary` with `{success, reason, departureId}`
   - `endTrail() -> Dictionary` with `{success, reason}`
   - `canAccessLocation(isTown: bool) -> bool`
   - `canApplyAttrition() -> bool`
   - `canGrantLoot() -> bool`
   - `trailStateChanged(onTrail: bool)` signal
2. Make `startTrail()` valid only from a Town while Off Trail. It sets the state before incrementing the departure id and emits `trailDeparted` once. Reentrant/repeated starts return a stable reason without changing stock or state.
3. Keep `departForTrail()` as a compatibility wrapper during migration, but give it one implementation path through `startTrail()`. Do not add a second stock-reset caller.
4. Route `res://Location/Entities/Trail/TrailDeparture.gd` through `startTrail()` and transition to the Overworld only on success.
5. Gate non-town entry in `res://Overworld/Overworld.gd::enterLocation()` before changing `Locations.currentLocation` or changing scenes. Town entry and Overworld movement remain available Off Trail.
6. Implement the single `endTrail()` command and recommended `enterTown(locationId)` policy. Do not call it from vendor-room return, ordinary `SceneManager._swapScene()`, quest completion, or combat return by accident.
7. Add `exportState()`, `importState()` and `resetForNewGame()` for the boolean state and departure id. Validate the whole payload before committing; New Game resets to Off Trail and departure id zero. Full disk save/Continue remains a later integration step.

### Tests

Create `res://Tests/TestTrailState.gd` covering:

- initial/reset Off-Trail state and zero departure id;
- start accepted only in a Town, exactly one id increment/signal/stock reset, and no mutation on repeated/reentrant calls;
- explicit end and the chosen Town-entry policy, with vendor-room return not ending a Trail accidentally;
- Off-Trail town-to-town movement, town access and quest commands remaining valid;
- Off-Trail rejection of non-town Locations, attrition and every reward source;
- On-Trail access/attrition/reward eligibility;
- valid/invalid snapshot import and complete New Game reset.

Update `res://Tests/TestVendorStock.gd` and `res://Tests/TestVendors.gd` for the new start command while preserving departure-only stock behavior.

### Exit gate

All Trail-state and vendor tests pass. No production path can start a Trail or reroll stock merely because an Overworld scene loaded.

## 5. ✅ Commit 2 — Encounter request, launch and return router

**Implemented.** `EncounterRequest` validates encounter path, canonical Zone, source, origin, progression and Trail snapshot. `SceneManager.launchShootout()` captures the launch origin, installs one pending request, connects `shootoutEnded` before the scene enters the tree, restores the origin once and clears the context on return or failed load. `EncounterPoolData.selectEncounter()` performs seeded weighted selection, `OverworldEvents` uses canonical Zones plus authored Zone event files, `OverworldEventOutcomeResolver` executes explicit `none`/`encounter` outcomes, and the popup disables legacy result-only choices instead of silently closing them. `TestEncounterFlow.tscn` proves the real Overworld → canyon Shootout → exact origin return path.

### Implementation

1. Replace the production use of bare `Shootout.pendingEncounter` with the request contract in System Coherence: `encounterPath`, `zoneId`, `origin`, `source`, `progression`, `trailState`, and optional `seed`.
2. In `res://Nodes/Scene Manager/SceneManager.gd`, add `launchShootout(request) -> bool` and one pending return context. Validate resource, Zone, source, Trail state and destination before connecting the result handler or transitioning.
3. In `res://Shootout/Shootout.gd`, consume and clear the pending request once. Reject invalid production requests instead of falling back to RatAmbush. Preserve an explicit debug-only default for direct test scenes.
4. Connect `shootoutEnded` before combat starts and consume it once after the existing result-screen acknowledgment. Disconnect before restoring origin. A load failure restores the outgoing scene and leaves Party, quest state and rewards unchanged; a return failure never reapplies results.
5. Add a pure weighted encounter selector to `res://Data/Shootout/EncounterPoolData.gd`, using an injected `RandomNumberGenerator`, positive weights and canonical Zone validation. Newspapers and gameplay continue reading the same pool entries.
6. Migrate `res://Globals/OverworldEvents.gd` to resolve current chunk through `OverworldZoneCatalog` and `SceneManager.get_current_scene()`/an injected Overworld reference. Replace private biome rectangles with an explicit Zone → event-pool mapping; do not add a second geometry table.
7. Add a small testable event outcome dispatcher (a `RefCounted` helper under `res://Overworld` or `res://Globals`). `res://UI/OverworldEvent/OverworldEventPopup.gd` calls it instead of the actor's empty `process_event_result()`.
8. For the vertical slice, implement exactly two outcomes:
   - one real choice selects a canyon encounter through the shared router;
   - one explicitly flavor-only `none` outcome closes without a reward.
   Leave all other result ids visibly unavailable until authored; do not silently treat them as success.

### Tests

Create `res://Tests/TestEncounterFlow.gd` and, where autoloads/scene transitions are required, `res://Tests/TestEncounterFlow.tscn` covering:

- request validation and no production RatAmbush fallback;
- deterministic canyon pool selection and Zone propagation;
- event choice → selected encounter → one Party result commit → exact origin restore;
- victory and flee return behavior;
- double launch/continue, failed scene load, failed return and listener cleanup;
- Off-Trail quest encounter completing without loot while preserving quest progression;
- modal, music, pause and inventory-policy cleanup.

### Exit gate

A real event launches a real canyon encounter and returns once. No direct actor `pass` method or `get_tree().current_scene` lookup remains in the exercised event path.

## 6. ✅ Commit 3 — Shared belt ownership and consumption

**Implemented.** Party members now own `beltReservations` (`{instanceId, combatId, quantity}`) instead of name arrays. `Party.reserveBeltItem()/unreserveBeltItem()/getBeltSnapshot()` validate ownership, consumable type, `combatId`, quantity, management policy and effective belt space atomically. `getFightData()` resolves reservations into combat item names while keeping each source `instanceId`; the Shootout records one `{instanceId, combatId, quantity: 1}` per successful use, and `applyFightResults()` commits the summed consumption exactly once and reconciles stale/over-reserved entries. Walker's starter Paregoric is one shared stack with one reservation, enemy-only belts stay name-based, and the Inventory tab has one To Belt/From Belt action. `TestBeltOwnership.gd` plus the extended inventory, equipment, injury, Shootout-loot and InventoryTab tests cover the slice.

### Implementation

1. Replace Party members' independent combat `items` source with persistent reservations shaped as `{instanceId, combatId, quantity}`. Each reservation references one carried stack and positive quantity no greater than the owned amount. Belt space counts reservation entries, preserving the current cap semantics.
2. Add Party commands and read projections:
   - `reserveBeltItem(memberKey, instanceId, quantity) -> Dictionary`
   - `unreserveBeltItem(memberKey, instanceId) -> Dictionary`
   - `getBeltSnapshot(memberKey) -> Dictionary`
   Validate member, ownership, item type, `combatId`, quantity, management policy and effective belt space atomically.
3. Migrate Walker's starter Paregoric to a reservation without creating an extra carried copy. Keep enemy-only belt arrays unchanged in this slice; they are separate enemy content, not a second Party inventory.
4. In `res://Globals/CharacterStatCalculator.gd`/Party fight-data projection, resolve reservations into combat item names/amounts while retaining each source `instanceId` in the encounter context. Respect effective belt space at reservation time and at fight start.
5. Record successful item resolution as `{instanceId, combatId, quantity: 1}` in the Shootout results. Misses, cancelled acts, unknown items and invalid targets record nothing. Using an item Off Trail still records consumption normally.
6. Commit those records once in `Party.applyFightResults()` through the existing exact-consumption path. Do not erase items at animation time from authoritative Party state. Unconsumed reservations remain owned.
7. Add a minimal Inventory action to assign/remove a selected consumable to/from the selected member's belt. Reuse `res://UI/Journal/Tabs/InventoryTab.*`; do not build a separate inventory or loadout subsystem.

### Tests

Create `res://Tests/TestBeltOwnership.gd` and extend `res://Tests/TestInventoryTab.gd`, `res://Tests/TestShootoutLoot.gd` and `res://Tests/TestInjury.gd` to prove:

- reserve/unreserve validation, capacity and belt-space limits;
- starter migration creates exactly one owned stack and one reservation;
- buying Paregoric → reserving → using it in combat decrements the carried stack exactly once;
- unused reservations survive victory/flee/Vamoose; used quantities are not restored or double-consumed;
- Off-Trail use consumes without generating loot;
- Bank/equipment transfers cannot duplicate a reserved instance id;
- UI cancel/failure paths do not mutate Party state.

### Exit gate

The vertical-slice consumable is fully functional from Town purchase through combat write-back, with no independent Party belt item source.

## 7. ✅ Commit 4 — Decided combat-rule migrations

**Implemented.** Fight setup starts every member at effective max HP; persistent knockout/downed state is removed; `CharacterStatCalculator` takes an injected `applyAttrition` context and `Party.applyFightResults()` commits attrition, flee cost and loot only when the request is On Trail. Bleed uses combined stacks (two stacks per damage before resistance) and healing removes stacks through the cleanse path. Enemy AI only gathers authored Moves (basic Attack removed), the rat uses the new `Scratch` Move, and content validation requires every combat actor to own an offensive Move. `hp_below` targets a named base actor with `fraction`/`amount`, optional `stat` and `winner`. Jammed applies the class-authored payload, Miss applies no on-hit effects, and `generateLoot()` propagates the encounter's canonical Zone so `dropsAnywhere: false` works in combat.

### A. Max-HP and On-Trail attrition

1. In `res://Globals/Party.gd`, make fight setup start each member at effective max HP. Remove persistent knockout debuff creation/countdown/application and the `downed` recovery model; retain only in-fight zero-HP state needed to determine Vamoose.
2. Add an injected `applyAttrition` context to `res://Globals/CharacterStatCalculator.gd` rather than reading `Locations` from the pure calculator. On Trail, injury reduces effective MxHP as designed; Off Trail, attrition neither accumulates nor changes the projection.
3. Update `applyFightResults()` to commit attrition only when the captured request is On Trail. Do not let an Off-Trail scene transition or quest fight change MxHP.
4. Route Town recovery through the single chosen recovery command; repeated vendor-room return must not retrigger it.

Update `res://Tests/TestInjury.gd`, `res://Tests/TestCharacterSheet.gd` and `res://Tests/TestEquipmentStats.gd` for max-HP starts, no knockout debuffs and both Trail states.

### B. Combined bleed and healing

1. In `res://Shootout/ShootoutEffectManager.gd`, replace highest-instance-only ticking with combined stack counts: every two stacks cause one damage before resistance, using the canonical stack-conversion rule.
2. Route healing through bleed-stack removal so healing removes the authored number of stacks through the existing cleanse path rather than merely restoring HP.
3. Add tests for one/two/three/four stacks, resistance rounding, multiple heals, cleanse order and death during a tick. Update `res://Tests/TestEffects.gd` and `res://Tests/TestActs.gd`.

### C. No basic weapon attacks

1. Remove the basic `Attack` branch from `res://Shootout/ShootoutEnemyAI.gd::gatherLegalActs()` and the corresponding resolution special cases where no longer needed. All offense goes through Move data and the shared targeting/effect pipeline.
2. Add `res://Data/Shootout/Moves/Scratch.gd` as a small single-target `attack_ability` using the rat's existing scratch weapon/Magazine/animation rules, and set `moves: ["Scratch"]` in `res://Data/Actors/Animals/SquekyRat.gd`.
3. Add validation requiring every combat actor to have at least one legal offensive Move rather than silently passing every turn. Update `res://Tests/TestEnemyAI.gd`, `res://Tests/TestActs.gd` and `res://Tests/TestEncounters.gd`.

### D. Per-actor `hp_below`

1. Replace `sideBelowThreshold()` in `res://Shootout/ShootoutTurnManager.gd` with a per-base-actor lookup using the same identity rule as `defeat_actor` (`actor.actorName`, not the indexed node name).
2. Support `{type: "hp_below", actorName, fraction | amount, stat?: "hp" | "maxHp", winner?}`. Check after damage/effect resolution and respect the optional winner. Reject unknown actors and contradictory side-total fields in content lint.
3. Add one rat-boss fixture proving the fight ends only when the named actor crosses the threshold, not when the side total crosses it.

### E. Zone-aware loot

1. Preserve request `zoneId` on the Shootout root and pass it into `res://Globals/ItemGeneration.gd::generateLoot()` as an optional generation context without breaking existing RNG callers.
2. Pass that Zone into generated equipment options so `dropsAnywhere: false` works for combat loot as it already does for vendor stock. Do not roll loot at all when Off Trail.
3. Extend `res://Tests/TestLoot.gd` and `res://Tests/TestShootoutLoot.gd` for Zone-locked versus anywhere equipment, canonical Zone validation and empty Off-Trail rewards.

### Exit gate

Focused rule tests and the full suite pass. The canyon rat fight uses only Moves, starts at max HP, applies combined bleed correctly, supports a per-actor threshold and can award canonical Zone equipment only On Trail.

## 8. ✅ Commit 5 — Vamoose routing/loss and New Game reset

**Implemented.** `Locations.enterTown()` records the last resupply Town used for recovery, `Locations.getLastTownId()` exposes it, and quest checkpoints resolve from `Quests.getCurrentObjectiveTarget()` (the authoritative current-objective map target) instead of the removed `Party.questInProgress` flag. `Party.vamoose(options)` halves money once, removes `max(1, ceil(inventory.size * 0.15))` occupied stacks atomically with an injectable RNG, excludes equipped gear and the Bank, applies no knockout state, reconciles removed reservations and returns the checkpoint or last-Town destination. The SceneManager routes Vamoose only for the `vamoose` outcome: a Town enters its interior through the single `enterTown()` command (end-of-Trail plus recovery once), a non-town checkpoint is placed at its authored Overworld entrance while Off Trail, and flees and non-wipe defeats still restore the launch origin without stock reroll. Versioned `Party.exportState()/importState()/resetForNewGame()` and the `NewGameCoordinator` (Party, Quests, Locations, Overworld, Cutscene, OverworldEvents, Vendors, Discovery, PokerMoney, Poker) are live behind `SceneManager.startNewGame()`. `TestVamooseFlow.tscn` and `TestNewGameReset.tscn` cover the slice.

### Implementation

1. In `res://Globals/Locations.gd`, record the last resupply Town through the same `enterTown(locationId)` command used for recovery. Quest checkpoints resolve from authoritative Quests state/current objective target, not from `Party.questInProgress` as a second flag.
2. In `res://Globals/Party.gd`, make `vamoose()`:
   - halve current money once;
   - select `max(1, ceil(inventory.size * 0.15))` occupied stacks when inventory is non-empty, using an injected RNG/seed;
   - remove those complete stacks atomically, preserving instance-id uniqueness;
   - exclude equipped items and the shared Bank;
   - apply no persistent knockout debuffs;
   - return the quest checkpoint when applicable, otherwise the recorded last Town.
3. In the encounter result router, call Vamoose only for the `vamoose` outcome. Fled and non-wipe defeat restore origin without applying Vamoose loss. Do not reroll vendor stock on Vamoose; stock changes only on a new explicit Trail start.
4. On Town/checkpoint return, apply the explicit end-of-Trail and recovery commands once. Restore Off-Trail Location/attrition/loot restrictions without deleting quest progress. If the quest checkpoint is a non-town Location and the party is then Off Trail, restore its authored Overworld entrance instead of entering the interior and bypassing the access gate.
5. Add versioned Party `exportState()`, `importState()` and `resetForNewGame()` for money, members/attrition, inventory/equipment, belt reservations and next instance number. Validate all item ids/references before committing. This prepares Party for the later save coordinator; actual disk Continue remains outside this slice.
6. Add a New Game reset coordinator used by `res://UI/Main Menu/MainMenu.gd` before entering the Overworld. Reset Party, Quests, Locations, Overworld position, Cutscene flags, Vendors, Discovery and current minigame/Poker session state. Close modals, clear encounter context and restore music/pause state. Keep Continue disabled until full application-restart persistence exists.

### Tests

Create `res://Tests/TestVamooseFlow.gd` and `res://Tests/TestNewGameReset.gd` covering:

- half-money rounding and exact 15%-of-occupied-stacks selection at inventory sizes 0, 1, 6, 7 and 24;
- deterministic selection, atomic mutation, no equipped/Bank loss and no duplicate ids;
- quest checkpoint versus last-Town destination and no stock reroll;
- one end-of-Trail/recovery application and Off-Trail restrictions afterward;
- Party snapshot round-trip and malformed-import rollback;
- New Game returning every current domain to canonical initial state.

### Exit gate

Vamoose has one complete outcome path and New Game is clean even after purchases, reveals, quest progress, belt use and Vamoose.

## 9. ✅ Commit 6 — Content lint, documentation and acceptance

**Implemented.** `Tests/TestContentLint.gd` is the production content lint: it rejects duplicate `data.name` values instead of silently overwriting them, unknown Move/item/effect/class/actor/loot/encounter/background references, invalid `hp_below` targets and side-total fields, non-canonical Zone ids in pools/loot/events, ungated reward producers and ungated non-town Location entrances, and proves it rejects deliberately broken fixtures. `Tests/TestEncounters.gd` gained unknown-Move, duplicate-encounter-name and `hp_below` side-total/`stat`/`winner` checks; `Tests/TestLoot.gd` rejects duplicate loot-table names. `Tests/TestOverworldEvents.tscn` covers injected-RNG cadence determinism and the active-event lock, exact canonical Zone → event-pool mapping with no cross-Zone bleed, every enabled outcome executing once through the resolver, and every legacy/unimplemented result staying explicitly unavailable. All focused suites plus `RunAll` pass without new leaks. The available 640×360 manual checks have since been performed and recorded below; production integration gaps remain separate from automated coverage.

### Automated closure

1. Extend the production content tests to reject:
   - duplicate `data.name` values instead of silently overwriting them;
   - actors without a legal offensive Move and unknown Move/item/effect references;
   - `hp_below` without a valid `actorName`, contradictory side-total fields and unknown targets;
   - encounter/pool/loot references with invalid canonical Zone ids;
   - reward producers without a Trail-state gate and non-town Location entrances without an access gate.
2. Extend `res://Tests/TestEncounterFlow.gd` (or add `TestOverworldEvents.gd`) for injected-RNG cadence, exact Zone-pool mapping, active-event lifecycle and every currently enabled outcome. Unimplemented result ids must remain explicitly unavailable.
3. Run focused suites for each commit, then the complete runner:

   ```sh
   godot --headless --path . --script res://Tests/RunAll.gd
   ```

4. Fix any new ownership/resource leaks introduced by these flows. Record pre-existing shutdown warnings separately rather than hiding them behind a zero exit code.

### Manual vertical-slice acceptance

**Status: previous mouse/keyboard production checks are recorded; commit 7's changed paths require manual reconfirmation.** The affected quest trigger, music-return and controller checks now exist in product code, but automated tests do not substitute for running them at 640×360.

At 640×360 with mouse and keyboard:

1. Start New Game Off Trail; confirm a non-town Location is blocked while quest progress and Town access work.
   - Confirmed to work
2. Buy Paregoric and inspect it in Inventory. Start a Trail once and confirm stock changes once.
   - Confirmed to work
3. Trigger the authored event, verify the canyon encounter/music/Flair-independent transition, assign/use Paregoric and win.
   - Expected Zone fight track is `Shootout/Steel Cannon Run`; inspect `MusicPlayer.currentTrackId` with F8. The Shootout now passes its request Zone to `MusicPlayer.on_shootout_started()` as the fallback when the encounter file omits `zone`; a default-track result remains a regression.
   - Generic events can fire before the Canyon event and currently have no executable outcomes; closing one with its disabled/choiceless UI intact is expected. Keep walking until `Canyon Cache Raiders` appears.
   - Confirmed to work
4. Confirm exact origin restoration, one carried-stack decrement and one On-Trail loot award.
   - Paregoric purchases share the existing stack, so buying one changes the one `starter_paregoric` stack from quantity 2 rather than creating a second row. That is expected stack behavior. Verify one `{ instanceId, combatId, quantity: 1 }` combat record and exactly one unit removed by Party; loot can also be a Paregoric, so use the authoritative consumption/accepted-loot details rather than net quantity alone.
   - Previously confirmed except the victory-stinger continuation. Zone-context invalidation now forces the Overworld playlist on result return; re-run this check to close the manual defect.
5. Complete the Off-Trail quest encounter and confirm no reward.
   - **Production path implemented:** Littlehill Grove's `QuestEncounterTrigger` starts `Littlehill Approach`, and the acknowledged victory result completes `find_morrison` through `Quests`. Re-run the 640×360 Off-Trail path; do not mark this manual step passed until the trigger, objective advance, exact return and empty reward payload are observed.
6. Trigger Vamoose and verify destination, money/stack loss, no knockout debuff and Off-Trail restrictions.
   - Confirmed to work
7. Return to the main menu and start New Game; verify all current state resets.
   - **Former blockers closed:** `MOVE_*`, `INTERACT` and `TOGGLE_JOURNAL` now include standard gamepad events; Journal → Settings provides the production confirmed **Quit to Main Menu** action, so the QA helper shortcut is no longer part of the acceptance path.
   - State reset previously was confirmed with the QA helper. Re-run through the product Settings action, then verify New Game state with mouse/keyboard and controller.

### Current manual-acceptance status

Steps 1–3, 6 and the previous state-reset check passed with mouse/keyboard. Step 4 passed its functional restoration, belt-consumption and loot checks; its music-return behavior requires reconfirmation after commit 7. Step 5 now has a production trigger and central result route, but has not yet been re-run manually. Steps 7 and controller acceptance likewise require a new pass through product UI and a real gamepad. Map acquisition/use remains a separate open verification item.

### Documentation closure

Update the relevant feature design docs and mark only the completed rows in the gap register. Link this plan from the coherence document's implementation section. Do not mark full save/Continue, dynamic spawns, multi-target acts or other untouched gaps complete.

## 10. Do not pull into this slice

Defer these until the vertical slice is stable:

- multi-target acts and effect-driven stat modifiers;
- Jammed payload redesign and the remaining affix/class/equipment-ability systems;
- full disk Save/Continue and migration UI;
- dynamic visual parties and their new SpawnData/director;
- additional Zones, bosses, quests, legendary rewards, secret destinations and vendor interiors;
- Poker house rules/economy integration, Flair and broad presentation polish.

The immediate next slice after acceptance should be **multi-target acts plus effect/stat seams**, followed by **full save-service integration**. Expanding content before those foundations would repeat the ownership and no-op-content problems this plan is intended to solve.

## 11. ✅ Commit 7 — First-slice integration pass

**Implemented.** The acceptance follow-ups from commit 6 now ship through production routes rather than the local QA helper. Automated coverage is complete; the manual controller, quest and audio passes still need to be observed at 640×360 before their acceptance rows can be marked passed.

### Implementation

1. **Quest-encounter lifecycle:** Littlehill Grove instantiates a `LocationInteractionDirector` and a reusable `QuestEncounterTrigger`. The trigger appears only while `pistoleros_regroup:find_morrison` is the authoritative current objective, creates one validated `source: "quest"` request for authored `LittlehillApproach.gd`, and carries the objective identity in request `progression`. `SceneManager` stores the request in its one-shot Shootout context and only an acknowledged `outcome: "victory"` result calls `Quests.completeCurrentObjective()`. Non-victory, duplicate and out-of-order results cannot advance or regress progress; Party/belt commit and Off-Trail reward suppression remain owned by the existing one result path.
2. **Prologue story adjustment:** the final Littlehill cutscene no longer completes `find_morrison` by shot. The Shootout clears that objective, then the cutscene completes the regroup objective. This gives the existing quest objective a playable trigger instead of adding a duplicate completion owner.
3. **Return to menu:** Journal → Settings contains **Quit to Main Menu** and a confirmation dialog. The action calls `SceneManager.change_scene("main_menu")` through the shared route helper; it is not an unconditional process quit or QA shortcut.
4. **Controller bindings:** `MOVE_UP`, `MOVE_DOWN`, `MOVE_LEFT` and `MOVE_RIGHT` accept both left-stick motion and D-pad button events. `INTERACT` accepts controller A, and `TOGGLE_JOURNAL` accepts Start. Existing keyboard bindings remain active.
5. **Music transitions:** every `MusicPlayer.on_scene_changed()` call clears `currentZone`. Returning to the same Overworld Zone therefore forces the chunk-driven decision rather than retaining a Location track or victory stinger. `play_music()` and `stop_music()` also become no-ops after `shutdown()` so a late test transition cannot touch released players.
6. **Map verification:** purchase alone still only places the item in Party inventory; Journal Inventory **Use** is the discovery command. Existing command/UI tests pass, while the reported real-play mismatch remains explicitly open for manual re-test.

**Exit gate:** automated tests now prove the production quest route, confirmed menu route, controller binding shapes and Zone-context invalidation. Physical controller, visual quest-trigger placement, 640×360 audio and live map-use confirmation remain the final manual gates.

### ✅ Commit 8 — Multi-target acts

**Implemented.** The one-target handoff in `Shootout.selectActor()`/`resolveWithFocus()` is replaced by one validated, ordered target-set pipeline shared by player acts and enemy AI. Open Question 4 is decided: a taunted caster takes one redirected hit per protected position.

1. `ShootoutTargetingManager.expandTargets()` expands `positions.type: "multi"` into living targets on the authored side/columns in column/name order; single-target acts keep their one anchor. Dead/empty sets return no targets.
2. `Shootout.resolveActTargetSet()` re-resolves per-position taunt with `redirectTauntSet()`, drops dead entries and calls `ShootoutActionResolver.resolveActTargets()`. Damage/healing, effects, death checks, focus and animations all consume the same resolved set, and the Cylinder/belt/turn cost is charged once per act.
3. Armed moves/items tint every legal anchor for confirmation; `ShootoutAnimationSequencer` fans one effect step over each target and completes once. Enemy AI gathers one entry per multi act with its full `targetNames`, scores that set and executes the same dictionary.
4. `Tests/TestTargeting`, `Tests/TestActs`, `Tests/TestEnemyAI`, `Tests/TestEffects`, `Tests/TestAnimationSequencer` and `Tests/TestMultiTargetFlow.tscn` cover expansion, per-position taunt, once-per-act costs, deaths/duplicates, AI set scoring and real-scene resolution.

**Exit gate:** Doctor's Kit heals every legal living target from a single belt use, multi-target offense/support behave identically for both sides, and no effect or cost is applied twice.

The implemented gates, in order:

### ✅ Commit 9 — Effect/stat seams

**Implemented.**

1. `Globals/CombatStatRegistry.gd` is the single supported-stat source. It marks each path `fully_supported` / `display_only` / `unsupported`, flags flat vs percent, and only flat `fully_supported` paths may be targeted by `stat_modifier` effects. `TestContentLint` rejects unknown or non-flat effect stat paths with the same teeth as the other content rules.
2. `ShootoutEffectManager.getStatModifier()` now sums flat `stat_modifier` instances; `onTurnEnd()` counts them down and a dead source removes them. Initiative (`ShootoutTurnManager.createTurnOrder`), offense/defense/ability scaling (`ShootoutActionResolver`), and the in-fight stat panels (`Shootout.actorStatsPayload`) all read `Shootout.getModifiedStat()` — Rodeo first, effects second. `CharacterStatCalculator` reads the registry's flat equipment affix list.
3. Taunt payloads author `damageTakenReduction` and `mxHpHealPerTurn`. While taunting, incoming damage is reduced by the authored percent and the caster heals MxHP at its turn start; both share the taunt's Rounds lifecycle, expiry and death cleanup.
4. `TestEffects`, `TestDamage`, `TestTurnOrder`, `TestContentLint` and `TestMultiTargetFlow` cover stacking order, expiry, taunt defensive buffs, shared-helper parity and lint rejection. Unsupported equipment affixes and equipment-granted Moves remain later work.

**Exit gate:** every displayed modified stat has a real consumer, initiative/damage/UI agree, and no production stat read bypasses `Shootout.getModifiedStat()`.

### ✅ Commit 10 — Full save-service integration

**Implemented.** `Globals/SaveGame.gd` (autoload `SaveGame`) is the only disk writer: one versioned JSON payload with exactly the `party`, `quests`, `locations`, `cutscene`, `vendors`, `discovery` and `overworld` snapshots plus `formatVersion`/`savedAt`. `validatePayload()` is a pure audit (required keys, JSON-safe values only, carried/equipped/reserved/Bank id uniqueness and resolution, reservation quantity versus stack, Trail departure equals the vendor cycle, stock belongs to that cycle, member set equals the live Party, authored rarity, numeric position) that runs before any mutation; `commitPayload()` captures every domain snapshot first and rolls the already-committed domains back when an importer rejects its payload, so a failed load preserves the previous valid session. Files are replaced through a verified temp file plus a one-generation backup, and a leftover backup is recovered when the main file is missing. Quests and Cutscene gained the missing versioned `exportState()`/`importState()` contracts, the Overworld provider gained its exact-position snapshot, and `migrateLegacyVendorAudit()` upgrades the pre-service payload pinned by `Tests/TestVendorPersistence.gd`. `SceneManager` records checkpoints only when the session leaves or enters the Overworld, `MainMenu` enables **Continue** only while `SaveGame.hasValidSave()` is true, `SceneManager.continueGame()` restores and resumes on the Overworld, and New Game remains independent of any stored save.

**Proof:** `Tests/TestSaveGame.gd` (assembly/audit/rollback/migration/atomic replacement), `Tests/TestSaveRestart.tscn` + `Tests/SaveRestartVerify.tscn` (a second Godot process restores and verifies the exact position, departure/stock synchronization, reservation references and id uniqueness, then the production Continue route and New Game independence), `Tests/TestCutsceneState.gd` and the extended `Tests/TestQuests.gd`.

**Exit gate:** ✅ a save made during an allowed scene restores exactly after an application restart; malformed files fail safely, the legacy format migrates explicitly, and Continue never restores a partial domain.

### Work that remains after these foundations

With the Trail/encounter slice, the multi-target and effect/stat seams and the save service in place, the remaining gate before phase-4 expansion is **phase-3 combat breadth**: supported equipment affixes, equipment-granted Moves, differentiated encounter AI and representative Party/enemy content. Do not expand Zones, parties, bosses, quests, legendary awards or vendor breadth first, and do not treat this slice as a general content license. A save-management UI (slots, delete/overwrite, migration prompts) and user settings also remain later work. Secret destinations/rewards also remain later content work: a future secret-item claim must check Trail eligibility before capacity, refuse a full inventory all-or-nothing, persist a one-shot claimed-target id, and never silently drop a unique reward. Dynamic spawns, multi-source affixes/equipment abilities, differentiated encounter AI, Flair and Poker integration stay in their existing deferred/priority rows.
