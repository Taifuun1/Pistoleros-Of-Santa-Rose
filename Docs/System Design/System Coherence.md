# System coherence and integration requirements

This document defines what the implemented systems need in order to function as one game rather than independent prototypes. It is based on the current code and the [Implementation gap register](Implementation%20Gaps.md) as of 2026-11-16. Authoring locations are in the [Content and balance catalog](Content%20and%20Balance%20Catalog.md).

## 1. Coherence goals

A coherent first playable loop must satisfy all of these:

1. New Game creates one clean, deterministic initial state.
2. A Trail begins only through an explicit action in a Town and rerolls rolled vendor stock once at that boundary. On Trail enables attrition, non-town Location access and loot; Off Trail disables those mechanics while preserving town-to-town Overworld travel and quest progression.
3. Overworld travel uses the same Zone identity for music, events, encounters, equipment and newspapers.
4. An event/Location/quest can launch a selected encounter and retain a typed return destination.
5. Combat consumes and produces authoritative Party state exactly once, then returns to the correct origin, town, or checkpoint.
6. Carried items, belts, equipment, money, Bank and rewards cannot become independent duplicated sources of ownership.
7. Quest completion updates Journal/map state and any level/rarity/Rodeo/reward progression through one command path.
8. Save/Continue and New Game restore/reset every persistent domain together, including On/Off Trail state; transient scene/visual state is excluded.
9. Content validation rejects broken or no-op references before they reach production.

## 2. Canonical ownership and identity contracts

| Concern | Single owner/source | Required consumers and rule |
|---|---|---|
| Zone geometry and ids | `res://Data/Overworld/ZoneData.gd` through `OverworldZoneCatalog.zoneForChunk()` | Music, visual spawns, event pools, encounter selection, equipment generation, vendors and newspapers call the same lookup. Only ZoneData contains chunk bands/default fallback. |
| On/Off Trail lifecycle | `Locations` owns the explicit state and `trailDepartureId`; all feature gates read that state | A Town action is the only start-of-Trail. A Town has two authored exits — the Off-Trail `TownExit` gate back to the Overworld and the `TrailDeparture` that starts a Trail — and one explicit end-of-Trail transition; never infer either from scene presence. Access, attrition and loot check the state independently, while quest commands and town-to-town movement remain available Off Trail. |
| World topology and coordinates | `WorldData`, `HelperVariables`, `OverworldCoordinates`, generated `OverworldMapData` | Streaming, Location collisions, player/map position, secret targets and spawn placement share conversions. Manifest is regenerated, never independently edited. |
| Location identity | Stable key in each Overworld chunk script's `locations` Dictionary, propagated to map manifest | Scene loading, vendor `parentLocationId`, quest `map_target_id`, secret `secret_id`, and last-town/checkpoint records use that id. Display labels are not a second key. |
| Party and item ownership | `Globals/Party.gd` plus `InventoryRules` | Party is authoritative for members, HP/attrition, money, carried stacks, equipped gear and belt reservations. Vendors, combat, quests, Poker and minigames execute commands; none keeps a second ownership ledger. |
| Item definition vs instance | `ItemCatalog`/gear data owns `definitionId`; Party allocates unique `instanceId` | Loot, stock, Bank, equipment and saves preserve complete rolled instances and ids. Combat-item `combatId` references a combat definition, never an instance. |
| Actor/class/act identity | Party `actorName` or `Data/Actors` path; exact class/Move/Rodeo `data.name` | Encounters reference actor content; class grants and loadouts reference validated Move ids. Indexed combat node names remain runtime-only and never leak into save/story ids. |
| Encounter identity and selection | Encounter resource path plus canonical Zone pool entry; loot/music reference their own stable names | Newspapers and gameplay read the same pool. `RatAmbush` is debug-only in production flows. A request carries the selected path, Zone, progression context and origin. |
| Quest identity and progress | `Quests` autoload and typed catalog resources | Cutscene shots are commands; Journal/map are projections. `Locations.currentQuest` must become a derived scene-selection value or be removed as a separate progression truth. |
| Scene transition and return | `SceneManager` active scene plus an encounter/quest return-context object | No system finds gameplay through `get_tree().current_scene`. Return context is explicit, validated, single-use and separate from global content selection. |
| Persistent state | Versioned domain snapshots coordinated by `res://Globals/SaveGame.gd` | Party, Quests, Locations, Overworld position, Discovery, Vendors and cutscene flags define what persists. `SaveGame` is the only disk writer: one JSON payload, validate-before-commit with snapshot rollback, atomic replacement. Live actor nodes, visual parties, timers, tweens, modal state, pending encounters and pending combat animations do not persist. |
| Balance rules | Authored data for per-content values; named shared constants for truly global rules | No private copies of Zone bands, stat calculations, item prices, progression rarity, or scene-return rules. AI/encounter/difficulty overrides are data, not parallel manager implementations. |

## 3. Required end-to-end encounter lifecycle

### A. On/Off Trail lifecycle and departure

1. The player starts Off Trail and may travel between Towns, use town services and advance Quests. Off-Trail travel does not grant loot, apply attrition, or allow entry into non-town Locations.
2. A Town has two authored exits, and they are separate commands. The `TownExit` gate returns to the Overworld through `Locations.enterOverworld()` without starting or ending a Trail, so the party can travel between Towns and reach quest Locations while Off Trail. The `TrailDeparture` marker is the only way to start a Trail.
3. `TrailDeparture` sets the authoritative state On Trail before the scene transition and calls `startTrail()` once. Neither marker changes the Trail state, departure counter, vendor stock or rewards by itself, and neither may be inferred from scene presence.
4. Vendors synchronize stock to that departure id; incidental Overworld entry, town-gate exits, Vamoose, retreat, minigames and quest transitions neither start a new Trail nor reroll stock.
5. Any belt reservation for the journey is committed before departure. Failure leaves the player in town with a readable reason and does not start the Trail.
6. Define one explicit end-of-Trail transition. Do not infer it from loading the Overworld, entering a vendor room, completing a quest or returning from combat. The chosen transition restores Off-Trail restrictions without erasing quest progress or blocking town-to-town travel.

### B. Overworld and Location triggers

- Visual parties remain cosmetic and never call events or Shootouts.
- OverworldEvents resolves the current chunk's canonical Zone and merges generic plus authored Zone event pools using injected/deterministic RNG where tests require it.
- Location entrances validate the current Trail state before transition: Off Trail permits town Locations only and never gates town-to-town Overworld movement. Quest commands and quest-driven encounters may still advance Off Trail, but their rewards remain suppressed.
- Location ambushes and quest triggers use predefined encounter resources; they do not compose a second incompatible party format.
- Every result/ambush/quest trigger validates its encounter, Trail-state permissions and return destination before closing UI or changing scenes.

### C. Encounter request

**Status: implemented in commit 2.** The bare global `pendingEncounter` handoff is replaced by one validated `EncounterRequest` contract (encounter path, canonical Zone, source/sourceId, origin, progression, Trail snapshot and optional seed). `SceneManager.launchShootout()` owns validation, origin capture, result-handler connection and one-shot return; `Globals/Shootout.gd` only holds the single pending request that `Shootout._ready()` consumes once.

| Field | Requirement |
|---|---|
| `encounterPath` | Existing `res://` encounter resource; no silent RatAmbush fallback for production. |
| `zoneId` | Canonical Zone used for pool validation, music and Zone-aware loot. |
| `trailState` | Authoritative On/Off Trail state and departure id captured at launch. It gates attrition and all rewards; it is not inferred from `origin.sceneKey`. |
| `origin` | `{sceneKey, location, overworldPosition, questId/checkpointId}` sufficient to reconstruct the exact origin. |
| `source` | `overworld_event`, `location_ambush`, or `quest`, plus the source/result id for diagnostics. |
| `progression` | Explicit quest/loot band or a reference to the authoritative progression provider; never a copied level/rarity value that can go stale. |
| `seed` | Optional deterministic encounter/loot seed policy for tests and save restoration. |

The launcher validates the whole request, connects the result handler before combat starts, and transitions through SceneManager. Double launch while transitioning is rejected. A load failure clears the pending request without consuming rewards, items, quest progress, or origin context.

### D. Combat commit and return

1. The Shootout builds one results payload containing outcome, Party fight state, Rodeo modifiers and generated loot. Attrition is recorded only while On Trail. Off-Trail fights still resolve and may advance Quests, but generate no money, items, resources or other loot.
2. `Party.applyFightResults()` is called exactly once. It commits the canonical fight-start/max-HP model, any On-Trail attrition, belt consumption and capacity-aware rewards, returning accepted/overflow details for the result screen. Off-Trail reward payloads are empty by contract.
3. The result screen delays `shootoutEnded` until overflow is acknowledged. The launcher consumes the signal once and disconnects before changing scenes.
4. Route by outcome:
   - **Victory:** apply encounter/quest completion commands as appropriate, suppressing every reward while Off Trail, then restore origin.
   - **Fled/non-wipe defeat:** restore origin without rerolling stock or silently granting victory rewards.
   - **Vamoose:** call the single Vamoose command, remove half of money plus a deterministic balance-selected 10–20% of carried inventory, and restore last town or active quest checkpoint. Equipped items and Bank contents are outside this carried-inventory loss.
5. A return failure keeps the results/context recoverable and logs a readable error; it must not reapply Party results or generate loot again.
6. Entering a designated resupply town applies the chosen HP/attrition recovery policy once. Ordinary vendor-room entry must not accidentally count as a new town arrival, start a Trail, or repeatedly heal/reset progression.

### E. Required loop acceptance test

Automate one real scene test for each source type: event, Location ambush and quest. Cover selected encounter identity, Zone propagation, one Party commit, victory/flee/Vamoose destinations, stock departure rules, overflow acknowledgment, double input, launch/load failure and no leaked modal/music/pause state. Run the reward/access cases both On and Off Trail: Off Trail must permit quests and town-to-town travel while rejecting non-town Locations, attrition and every reward source.

**Commit 2, 5 and 7 progress:** `TestEncounterFlow.tscn` covers the event source: deterministic pool selection, request/Zone propagation, double-launch rejection, real Overworld → canyon Shootout → exact origin return, duplicate-result rejection and failed-load context cleanup. `TestVamooseFlow.tscn` covers the Vamoose outcome: last-Town interior return, non-town checkpoint Overworld-entrance return, one end-of-Trail/recovery pass, Off-Trail restriction restoration and no stock reroll. The Littlehill Grove `QuestEncounterTrigger` now provides the production quest source; it creates one validated `source: "quest"` request, and SceneManager's one-shot acknowledged result is the sole caller that completes the exact current objective after victory. The real quest request/scene return path is automated. Location-ambush launch callers and reward/access On-vs-Off-Trail cases for the remaining source types remain open.

## 4. Event outcome contract

**Status: `text`/`none` and `encounter` implemented in commit 2.** `OverworldEventOutcomeResolver` validates explicit choice `outcome` descriptors, executes exactly one per choice, and the popup disables legacy result-only choices rather than treating them as no-ops. Loot, injury/recover, quest and scene outcomes remain unimplemented design.

Replace arbitrary result strings passed to an actor `pass` method with validated outcome descriptors. Keep the presentation text in event data, but resolve each choice to a domain command before closing the popup.

| Outcome kind | Required data and command |
|---|---|
| `encounter` | Encounter path/pool selector, canonical Zone, origin and source id; use the encounter lifecycle above. |
| `loot` | Money/items/resource bundle resolved through Party capacity-aware commands, with explicit overflow presentation. Reject or return an empty reward while Off Trail; vendor purchases in Town are not loot. |
| `injury` / `recover` | Member/target and amount routed through the canonical HP/attrition rule, not direct actor-field edits. Attrition mutations are rejected Off Trail; recovery follows the town/camp policy. |
| `quest` | Quest id/objective action routed through Quests; no direct state Dictionary writes. Allowed On and Off Trail, with rewards suppressed Off Trail. |
| `scene` | Typed scene/Location/checkpoint transition with a valid return policy. Off Trail permits town destinations but rejects non-town Location access. |
| `text` / `none` | Deliberately flavor-only outcome, clearly marked so it is not an accidental no-op. |

Validation must reject duplicate event ids, unknown outcome kinds/references and missing choice outcomes. Exactly one outcome executes per choice; closing without a choice remains dismissal, not a hidden default reward.

## 5. Inventory, equipment, and belt coherence

**Status: belt ownership is implemented in commit 3, Vamoose's carried-stack loss in commit 5, and reservation persistence in the save service.** Party members own `beltReservations` referencing carried stacks; fight setup resolves them to combat `combatId`s with source `instanceId`s; successful uses are recorded and committed once through `Party.applyFightResults()`, and unconsumed/stale reservations are reconciled. `Party.vamoose()` removes whole carried stacks and reconciles their reservations. `Globals/SaveGame.gd` persists Party reservations and next instance allocation; the second-process restart proof checks restored references and id uniqueness.

### One ownership model

- Carried stackables and rolled gear remain in Party inventory; equipped gear remains in Party member equipment; deposited gear remains in the shared Bank. Each instance exists in exactly one place.
- Belt entries reference carried `instanceId`s (and optionally a reserved quantity), not free-standing item-name copies. A stable combat loadout stores member id plus reserved entries.
- Class/equipment Move grants produce a preview of available Moves. Activated Moves are persistent Party loadout data, capped at four; combat validates rather than silently truncating production content.
- Buying, selling, depositing, withdrawing, equipping, reserving, consuming and dropping are Party/domain commands with stable reason codes. UI never edits arrays directly.

### Belt transaction boundaries

1. Editing a belt validates item type, ownership, stack quantity and effective belt space. Reservations do not create items.
2. Fight setup resolves each reservation to its combat `combatId` and carries the originating instance id into the fight context.
3. Successful item resolution records consumption once; misses, cancelled acts, unknown items and invalid targets consume nothing.
4. Fight results commit recorded consumption to Party stacks exactly once alongside other results. Unconsumed reservations remain owned and become available again.
5. Fleeing uses the same commit rule for items actually used. Vamoose then removes half of money and the selected 10–20% of remaining carried inventory without double-removing consumed instances; equipped items and Bank contents are not part of that carried-inventory selection.
6. Changing a belt's capacity cannot invalidate an existing reservation silently; reject the equipment/loadout command atomically.

Tests must prove no duplication across inventory ↔ belt ↔ Bank ↔ equipment, no free starter belt source, stack write-back on every outcome, and deterministic behavior after save/load.

## 6. Progression, quests, and rewards

Use one progression projection derived from authoritative main-quest completion. Do not independently increment `Party.level`, `Quests.currentMainQuestLevel`, item rarity and loot bands at different call sites.

| Output | Required behavior |
|---|---|
| Party level | Derived or updated once at main-quest completion and consumed by Rodeo scaling and Journal. |
| Item rarity | `ItemGeneration.rollRarity()` reads the current progression projection; vendor stock rolls at departure and retains the rolled result thereafter. |
| Loot band | Encounter/pool selection chooses an eligible band and passes it with the encounter request; loot tables validate that band. |
| Rodeo/story unlocks | Quest completion commands swap authored Rodeo ids through Party and refresh Journal/future fight setup. |
| Stagecoach speed | Read the same Party level projection; no separate speed progression counter. |
| Quest rewards | Typed, idempotent reward commands for money/items/legendaries/unlocks. Encounter `loot: false` routes payout here instead of paying nothing. Quest objectives can complete Off Trail, but those completions produce no money, items, resources or other loot while Off Trail. |
| Map and Journal | The same Quests state produces current objective/history/markers. Map target ids resolve through the generated manifest. |

Reward application first checks Trail eligibility, then inventory capacity. Off Trail produces no reward payload. On Trail, use the existing accepted/overflow result and acknowledgment, a quest reward cache, or another designed recovery path for a full inventory. Never silently delete a unique/legendary reward. Replaying a cutscene or restoring a scene must not grant a completed objective's reward twice.

The prologue needs one authored continuation contract: Littlehill Grove exit, Lazysprings/next-arc destination, final objective completion, Party recruitment, level/reward changes, and the new value used for quest scene selection.

## 7. Stats, effects, and combat-content coherence

**Status: items 3–9 implemented in commit 4 (item 5 follow-ups and item 6 boss content still open), item 4 implemented in commit 8, the supported-stat registry + effect/taunt modifiers implemented in commit 9, and the honest per-affix support contract (generation, pricing, previews, lint) implemented in commit 12.** The registry (`Globals/CombatStatRegistry.gd`) drives content lint, flat effect stat modifiers, `CharacterStatCalculator`'s equipment aggregation, vendor pricing, and the shared combat/UI stat read. Authored effect-bearing content and the commit-13 AI/metrics work remain open.

1. ✅ Define a supported-stat registry shared by content lint, `CharacterStatCalculator`, and combat reads (commit 9). A stat may be `fully_supported`, `display_only`, or `unsupported`; unsupported stats must not roll as if functional.
2. ✅ Implement effect-driven stat modifiers and route every combat/UI/initiative read through `Shootout.getModifiedStat()`, including taunt's defensive buffs (commit 9). Equipment-affix mechanics are covered by commit 12; equipment-granted Moves landed in commit 11.
3. Propagate encounter Zone into loot generation. Zone-tied equipment not dropping from Shootouts is not intentional: use `dropsAnywhere` and the selected Zone exactly as vendor generation does, subject to On-Trail loot eligibility.
4. ✅ Implement multi-target resolution as a target-set pipeline shared by player and AI (commit 8). Per-position taunt, effects, damage, death checks, animations and focus all see the same targets.
5. Remove basic weapon attacks for both teams. Every offensive action is an authored Move; enemy AI must gather and score those Moves through the same legality rules as the player. Make encounter kind select authored AI behavior/difficulty and enemy stats.
6. Make `hp_below` win conditions per-actor, including boss thresholds, rather than side-total HP. Boss scripts and unique Rodeos remain data-driven content.
7. Apply the canonical `Death Injury and Retreat.md` model: fighters start each Shootout at max HP with no persistent knockout debuffs. MxHP attrition is enabled only On Trail and does not leak into Off-Trail fights or travel.
8. Combine bleed stack counts so two stacks equal one damage, and make healing remove stacks. Replace the current highest-stack-only tick and encode stack conversion/healing in tests.
9. Give Jammed an explicit authored buff/debuff source and payload, and enforce no-on-hit-effects-on-Miss for attack abilities as well as any weapon Move.
10. Balance against reproducible metrics: 5–10 Round typical fights, 3–5 hits for regular enemies, 10+ for powerful enemies, and scarce meaningful healing. Record seed, Party, gear, encounter and outcome so changes are comparable. Vamoose uses half of money plus a balance-selected 10–20% of remaining carried inventory, excluding equipped items and Bank contents.

## 8. Save, Continue, and New Game contract

### Snapshot coverage

The save service must define versioned export/import/reset behavior for:

- Party members, level/progression inputs, HP/attrition state, money, inventory, equipment, belt reservations and next instance number.
- Quest runtime state, played cutscenes, current quest/Location selection, last town and quest checkpoints.
- Exact Overworld live/last-known player position, authoritative On/Off Trail state and trail departure id.
- Discovery reveals, vendor stock/Bank/departure synchronization and deterministic base seed.
- Poker/minigame persistent results after their ownership is unified.
- User settings once implemented, in a separate profile/settings payload if they should survive New Game.

Do not serialize active Shootout nodes, pending global encounter paths, transient visual parties, interaction targets, current modal, pause/music stack, async loaders, timers or animation state. Saving during combat/transition must either be disallowed explicitly or use a designed checkpoint payload.

### Restore and reset algorithm

1. Load and schema-check the complete file, including format version and content versions.
2. Build candidate snapshots for every domain and validate all cross-references before mutating live state. Party item ids, quest targets, vendor stock, secret ids and Zone ids must resolve together.
3. Commit in dependency order: content/progression inputs, Party, Quests/Locations, Discovery, Vendors, position, then derived UI/music state. Reuse the validate-before-commit coordinator contract already audited for Vendors/Discovery.
4. Recompute derived state rather than trusting duplicated cached values: equipment stats, current objective markers, current Zone, stock departure alignment and Journal projections.
5. On any failure, preserve the previous valid session and report the error; never partially import money/items/quests.
6. New Game calls every domain reset, closes modals, clears encounter/return context, restores the initial seed/Party/quest/position and initial Off-Trail state, and only then enters the initial scene. **Commit 5 note:** `SceneManager.startNewGame()` + `Globals/NewGameCoordinator.gd` implement this reset path and `MainMenu` uses it.

### Implemented save service

`Globals/SaveGame.gd` is the only disk writer (autoload `SaveGame`):

- **Payload:** one JSON object with `formatVersion` (currently 2), `savedAt` and exactly the `party`, `quests`, `locations`, `cutscene`, `vendors`, `discovery` and `overworld` domain snapshots. A strict key audit rejects any other key, so transient scene/combat state cannot be written, and every value must be plain JSON data (no engine types, no non-String keys, no non-finite numbers).
- **Audit before commit:** carried/equipped/reserved/Bank instance ids must be unique and resolve together, a reservation may not exceed its stack, the vendor cycle must equal the Trail departure, rolled stock must belong to that cycle, the member set must match the live Party, progression inputs must use an authored rarity, and the recorded position must be numeric. `Party`, `Quests`, `Locations`, `Cutscene`, `Vendors`, `Discovery` and `Overworld` own their own importers and their own `formatVersion`.
- **Commit and rollback:** commit order is `party → quests → locations → cutscene → vendors → discovery → overworld`. Every domain snapshot is captured first; if an importer rejects its payload (content drift included), the domains already committed are restored from those snapshots, so a failed load preserves the previous valid session. `validatePayload()` is pure and runs before any mutation.
- **File handling:** the temp file is written, read back and compared byte-for-byte before the previous file is renamed to a one-generation backup and replaced; a leftover backup is recovered when the main file is missing. JSON cannot express the int/float distinction, so integral numbers are normalized back to ints on read.
- **Migration:** version 1 is the pre-service payload pinned by `Tests/TestVendorPersistence.gd` (Party money/inventory, vendor and discovery states, one scalar departure id). `migrateLegacyVendorAudit()` fills the missing domains from the canonical New Game snapshots, raises the instance-id counter past every carried id and drops reservations whose stack is gone. Removed content ids are never re-mapped: the domain importer rejects them and the previous session survives.
- **Checkpoints and Continue:** `SceneManager.autosaveEnabled` records a checkpoint when the session leaves the Overworld (exact walked position) and when it enters the Overworld (the anchor/origin it resumes from); no other code writes the file. The Main Menu enables **Continue** only while a valid save exists, and `SceneManager.continueGame()` restores the payload, clears transient contexts and resumes on the Overworld — scene re-entry stays cell-accurate through the shared coordinate contract while the provider keeps the exact position. New Game is independent of any stored save and immediately checkpoints its own new session.

Enable Continue only after a valid save exists and an application-restart test passes. `Tests/TestSaveRestart.tscn` is that proof: it plays a session, saves, spawns a second Godot process that restores and verifies every domain (including the exact position, departure/stock synchronization, reservation references and id uniqueness), then exercises the production Continue route. Migration is covered by `Tests/TestSaveGame.gd`; a save-management UI (multiple slots, delete/overwrite) and user settings are still later work.

## 9. Remaining cross-system requirements

### Dynamic visual parties

Implement the designed pure seeded director and thin Overworld adapter before authoring SpawnData. Use canonical Zone lookup, shared coordinates, atomic party roots, off-screen/player margins and chunk cleanup. Parties never generate encounters, rewards, saves or event triggers. Replace legacy current-scene parenting rather than building on it.

### Vendors, newspapers, and secrets

- Newspaper prose and enemy composition continue to use the same Zone pool as gameplay. If an encounter is not eligible in that Zone, it cannot appear in that Zone's report.
- Fixed offers must resolve working mechanics. Add boosts/explosives/magazines/camp items only with their actual consumers. Vendor purchases in Town are allowed Off Trail because they are purchases, not loot.
- A revealed secret is not complete until its world destination, reachable navigation and reward interaction exist. Reward claims need persistent one-shot state if they are unique, must be rejected Off Trail, and must not bypass the non-town Location gate.
- Keep stock reset tied to explicit Trail start, and vendor-room return separate from town recovery and Trail state transitions.

### Poker and other minigames

Decide whether poker uses Party money directly or a clearly defined buy-in/cash-out transaction; remove the independent PokerMoney source for production. Add SceneManager entry/return context, story-scoped table limits and persistence. Record the unresolved four-card-flush/every-player-blind house-rule decision before economy balancing. Convert Bear Hunt/Gold Rush points/materials to Party resources through explicit capacity-aware result commands, or document why they are separate non-economic scores. Any conversion or reward payout is disabled Off Trail.

### Music, Settings, Flair, and presentation

- Settings owns audio volumes and game options; MusicPlayer consumes them without changing playlist decision data. The Settings tab currently adds only the confirmed quit-to-menu route; audio and disk-save controls remain unavailable.
- Every `MusicPlayer.on_scene_changed()` call invalidates the prior Overworld Zone. The Overworld must then re-request its chunk Zone, so returning to the same Zone starts Zone music rather than continuing a Location track or Shootout stinger.
- Gameplay input actions carry keyboard and standard gamepad events together. Movement uses left stick plus D-pad, `INTERACT` uses A, and `TOGGLE_JOURNAL` uses Start; real-device 640×360 feel still requires manual acceptance.
- Implement Flair in SceneManager's pre-swap transition with one shared encounter-loading/selection path, so text and combat cannot disagree. Remove the duplicate in-combat banner afterward.
- Finish 640×360 keyboard/controller/visual reviews for Journal, vendors, Shootout, maps and new content. Automated layout assertions do not replace this gate.

### Scene and service access

Use dependency injection or `SceneManager.get_current_scene()` for gameplay-scene access. Legacy direct `get_tree().current_scene` calls in events, visual spawns, Location actors and minigames must be migrated as each feature is integrated. Autoloads own cross-scene domain state; scene nodes own only live presentation/interaction state.

## 10. Content-validation gate

Add a single production content-lint entry point, run before the full suite and in CI, covering:

1. **Schemas and uniqueness:** every data Dictionary/Resource has required fields; duplicate `data.name`, definition ids, encounter ids, vendor ids, quest ids and event ids fail.
2. **References:** actor/class/Move/Rodeo/effect/item/loot/encounter/pool/quest/map/vendor/Zone references resolve exactly.
3. **Assets:** actor Overworld/Shootout animations, Move/item animations, sprites, backgrounds, OGGs, noise resources and FrameData hit frames exist.
4. **Rules:** positions, team caps, Magazine lengths, win conditions, weights, stack limits, prices, sale ratio, AI selectors and progression bands are valid.
5. **Functional support:** consumable combat ids, map effects, event outcomes, item stats/Move grants and quest rewards resolve implemented mechanics; unsupported content fails rather than shipping no-ops.
6. **Trail rules:** every Location entry and reward source declares/uses the shared Trail-state gate; Off-Trail quests and town travel remain available while non-town access, attrition and loot are rejected.
7. **World reachability:** generated manifest targets, secret destinations, vendor interiors/doors and quest transitions exist. Regenerate map outputs and require `--check` to pass.
8. **Persistence:** all persistent content state, including On/Off Trail state, round-trips with stable ids and no duplication; transient content is absent.

Production should fail closed for malformed content. Warn-and-skip remains useful for isolated tooling/tests, but it must not turn a broken live encounter or paid item into silent empty behavior.

**Commit 6 status:** `Tests/TestContentLint.gd` implements the uniqueness rule (1), reference resolution for Moves/items/effects/classes/actors/loot/encounters/backgrounds and canonical Zone ids (2, 5 partially), the `hp_below` rule shape (4 partially) and the Trail gates for reward producers and non-town Location entrances (6), with a fixture test proving it rejects broken content; `Tests/TestEncounters.gd`/`TestLoot.gd` cover duplicate encounter/loot/Move names and `hp_below` side-total fields, and `Tests/TestOverworldEvents.tscn` covers event outcomes. Asset lint (3), quest rewards, and full world reachability (7) remain open.

## 11. Dependency-ordered implementation plan

The concrete first delivery slice for phases 0–2 (authoritative Trail state, the encounter request/router, shared belt ownership, the decided combat rules, Vamoose/New Game, and the content lint and documentation closure) is tracked in the [First steps implementation plan](First%20Steps%20Implementation%20Plan.md).

**Current delivery status (2026-11-17):** commits 1–10 are implemented and the full suite passes 63/63. The first-slice integration pass ships the production quest-encounter trigger/result route, Journal quit-to-menu confirmation, standard controller bindings and Overworld Zone-context invalidation; the multi-target commit replaces the one-target handoff with one target-set pipeline shared by player and enemy AI; the effect/stat commit adds the supported-stat registry, flat effect modifiers, taunt defensive buffs and one shared combat/UI stat read; the save-service commit adds the versioned disk save, Overworld checkpoints, production Continue and the second-process restart proof. Step 5 and physical-controller acceptance still require a manual re-run; automated tests establish the production paths but do not record visual/controller feel. The ordered next mechanics steps are:

0. ~~**First-slice integration pass:** quest-sourced encounter launch/result completion, production return-to-menu, gamepad bindings, and Overworld music-transition invalidation.~~ Implemented in commit 7.
1. ~~**Multi-target acts:** one target-set pipeline for player and AI resolution, per-position taunt, UI/animation/focus and death handling.~~ Implemented in commit 8.
2. ~~**Effect/stat seams:** data-driven effect modifiers, the supported-stat registry, taunt's defensive buffs and all combat reads through `Shootout.getModifiedStat()`.~~ Implemented in commit 9.
3. ~~**Full save-service integration:** the versioned disk save, validate-before-commit restore, format/content-id migration policy, Main Menu Continue and application-restart proof.~~ Implemented in the save-service commit; a save-management UI and user settings remain later work.
4. ~~**Canonical class/equipment Move grants:** validated grant ids, one active-loadout projection for Party and actor data, Journal activation, four-Move/equipment-swap guards and saved selections with migration.~~ Implemented as commit 11.
5. ~~**Honest affix support:** one support registry shared by generation, vendor pricing, combat, loot and the Journal; remove every remaining unsupported paid roll.~~ Implemented as commit 12.
6. ~~**Differentiated AI and reproducible metrics:** actor-authored action weights/candidate counts, seeded combat decisions and a real-scene measurement driver for Dust-up/Showdown behavior and encounter balance.~~ Implemented as commit 13.

Only after those gates should the project resume phase-4 content expansion. Phase 3 is not complete merely because the decided HP/bleed/basic-attack/boss-threshold rules and Vamoose landed: supported affixes/equipment abilities, differentiated encounter AI and representative Party/enemy content remain open. Detailed commit scopes and exit gates are in [First steps implementation plan §12](First%20Steps%20Implementation%20Plan.md#12-phase-3--combat-breadth).

| Phase | Work | Exit gate |
|---|---|---|
| **0 — Apply decided rules and lint foundation** | Encode the canonical HP/knockout, bleed, no-basic-attack, per-actor boss-HP, Vamoose-scope and Zone-loot decisions; define the supported-stat registry and canonical ids; add duplicate/reference/asset lint. Stop generating unsupported paid affixes or mark them unavailable honestly. Keep Poker house rules explicitly open. | Decided rules have one implementation contract and tests; production content lint fails on deliberate broken fixtures and passes valid current content. |
| **1 — Complete the playable encounter and Trail loop** | Implement authoritative On/Off Trail state and its start/end transitions, access/attrition/loot gates, encounter request/origin router, event outcome execution, Zone-aware pool selection, production launch/return, Vamoose/checkpoint handling, town recovery and scene-access migration. Add one canyon end-to-end path. | Event and direct Location/quest fights launch, apply Party results once, and return correctly for victory/flee/Vamoose. Off Trail permits quests and town-to-town travel but blocks non-town Locations, attrition and every reward source; no debug fallback or soft lock. |
| **2 — Unify inventory and progression** | Implement shared belt reservations/write-back, class/equipment Move grants, Trail-aware quest reward execution, one level/rarity/band projection, Zone-aware loot and full New Game/save coordinator, including On/Off Trail state. | Purchased consumables work in combat without duplication; quests progress in either state while rewards pay only On Trail; application-restart restore is exact and atomic. |
| **3 — Finish required combat mechanics** | Implement multi-target acts, supported affixes/equipment abilities, differentiated Move-only AI, per-actor boss conditions, and the decided max-HP/no-knockout, combined-bleed and Vamoose rules. Add full Party/enemy content needed for representative fights. | Reproducible combat tests and scene tests pass for every shipped mechanic and both Trail states; no basic attacks or displayed inert stats remain; target balance metrics can be measured. |
| **4 — Expand coherent content** | Add other Zone actors/pools/loot/newspapers, bosses, quest arcs/map targets, prologue continuation, legendary awards, secret destinations/rewards, additional towns/vendors and general-store mechanics. | Every new entry is reachable, functional, lint-clean, persistent and represented in an end-to-end test or authored acceptance case. |
| **5 — Ambient systems and acceptance** | Implement dynamic visual parties, Flair, Poker/economy integration, Settings, remaining WFC/Location content improvements, bespoke art and all manual UI/controller/visual passes. | Full automated suite and content lint pass; generated map is current; real 640×360 gameplay loops and ambient cleanup pass manual acceptance. |

Phases 0–2 should not be bypassed by adding more Zones or items. More content increases the cost of fixing identity, ownership and return-flow mistakes.

## 12. Definition of a coherent completed feature

A feature is complete only when all applicable statements are true:

- Its content has a stable id and one authoritative dataset.
- Its runtime entry point is reachable through SceneManager or a domain trigger, not only a test scene.
- It consumes the canonical Zone/Party/Quest/Location providers rather than copying their state.
- Its Location access, attrition and rewards obey the authoritative On/Off Trail state, while Off-Trail quests and town-to-town travel continue to work.
- Its effects execute once and survive every cancellation, failure, scene exit and repeated-input path without duplication.
- Its UI presents actual mechanics and handles empty/error/full states at 640×360 with mouse and keyboard/controller.
- Its persistent state participates in New Game and validate-before-commit save restore; transient state is cleaned up.
- Its references and assets pass content lint, focused and full tests pass, generated resources are current, and required manual acceptance is recorded.
- Its source design doc, this coherence plan, and the gap register are updated to reflect the shipped behavior rather than historical plans.
