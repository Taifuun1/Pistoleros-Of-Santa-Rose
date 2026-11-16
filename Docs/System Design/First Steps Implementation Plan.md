# First implementation steps: coherent Trail and encounter vertical slice

**Status: commits 1–3 implemented and verified; commits 4–6 remain proposed.** Commit 1 added the authoritative On/Off Trail state and gates. Commit 2 added the typed encounter request, SceneManager launch/return router, deterministic Zone pool selection, canonical Zone event pools and the explicit event outcome dispatcher. Commit 3 replaced the independent Party belt arrays with validated reservations, one-shot combat consumption write-back and a minimal Inventory belt action.

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

## 3. Delivery sequence

| Commit | Deliverable | Main proof |
|---|---|---|
| 1 | On/Off Trail state and feature gates | Town-only start, explicit end, access/attrition/loot rules and stock boundary tests |
| 2 | Encounter request, launch and return router | One real event launches a selected canyon encounter and returns exactly once |
| 3 | Shared belt ownership and consumption | Purchase → reserve → combat use → carried-stack decrement without duplication |
| 4 | Decided combat-rule migrations | Max-HP/no-knockout, combined bleed, no basic attacks, per-actor HP threshold, Zone loot |
| 5 | Vamoose routing/loss and New Game reset | Correct destination/loss, Off-Trail restrictions restored, clean initial state |
| 6 | Content lint, documentation and acceptance | Full automated suite plus manual vertical-slice run at 640×360 |

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

## 7. Commit 4 — Decided combat-rule migrations

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

## 8. Commit 5 — Vamoose routing/loss and New Game reset

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

## 9. Commit 6 — Content lint, documentation and acceptance

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

At 640×360 with mouse and keyboard/controller:

1. Start New Game Off Trail; confirm a non-town Location is blocked while quest progress and Town access work.
2. Buy Paregoric and inspect it in Inventory. Start a Trail once and confirm stock changes once.
3. Trigger the authored event, verify the canyon encounter/music/Flair-independent transition, assign/use Paregoric and win.
4. Confirm exact origin restoration, one carried-stack decrement and one On-Trail loot award.
5. Complete the Off-Trail quest encounter and confirm no reward.
6. Trigger Vamoose and verify destination, money/stack loss, no knockout debuff and Off-Trail restrictions.
7. Return to the main menu and start New Game; verify all current state resets.

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
