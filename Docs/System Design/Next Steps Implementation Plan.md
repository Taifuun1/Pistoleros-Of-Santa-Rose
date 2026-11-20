# Next Steps Implementation Plan

**Status: planned.** The [First steps implementation plan](First%20Steps%20Implementation%20Plan.md) is fully delivered (commits 1–13, suite 66/66). This plan sequences the remaining product features and the phase-4 content expansion, ordered by dependency: save slots before settings (settings should not live in a slot), then secret rewards (builds on the save contract), then content breadth. Combat balance tweaks and manual acceptance are deliberately deferred by owner decision.

**Global rules (unchanged):** disk ownership stays in `Globals/SaveGame.gd`; no transient combat state in saves; no new Zone/Party/boss invented to pad a slice; every commit ships its tests and updates Testing.md, the gap register and the affected design docs; commits stay logically grouped (code → wiring/UI → proof → docs).

## ✅ Commit 14 — Save slots and save-management UI

**Implemented.** `Globals/SaveGame.gd` gains slot APIs with no payload schema change: slot files live under `user://saves/<id>.json` (ids restricted to letters, digits, underscore, dash and space), an `index.json` carries only the active slot id, and an empty selection keeps the legacy single-file path fully functional. `listSlots()` returns one validated entry per slot (id, timestamp, format version, valid flag and a human-readable notice — a legacy pre-slot save is imported as `slot1` on first listing so existing players keep it); `selectSlot` fails closed on unknown ids; `createSlot` picks the first free id and only appears in listings after its first checkpoint; `deleteSlot` removes the file and clears the selection when it was active; `migrationNotice` translates failure reasons into player text ("newer version" / "damaged"). Save, load, Continue and checkpoints route through the active slot transparently, and the selection is restored from the index in every fresh process. The Main Menu gains a Saves overlay: one row per slot with timestamp and active marker, Play (select + Continue, disabled for damaged slots), two-step Delete confirmation, New Save and Back, with status text for empty stores and refusals.

**Tests:** `Tests/TestSaveGame` covers slot creation/selection/deletion, path isolation between slots, restore-exactness, id sanitization (traversal and duplicate rejection), notices and the legacy import; `Tests/TestSaveRestart` adds a slot section — slot A stores the played session, slot B a dirtied one, a fresh process restores slot A through the slot index while slot B stays untouched; the new `Tests/TestSaveSlots.tscn` drives the real Main Menu overlay (empty-store text, New Save, checkpoint → playable row, Play selection, two-step delete, Back leaves Continue truthful).

**Exit gate:** ✅ a second process restores the selected slot exactly while slot B is untouched; deleting the active slot disables Continue until another slot is chosen; a corrupt or newer-version slot is reported in player text and never loaded; no combat transient state enters the payload.

## ✅ Commit 15 — User settings

**Implemented.** A `Globals/UserSettings.gd` autoload owns `user://settings.json` — separate from any save slot — with defaults, validation, clamped writes and an atomic replacement (temp file + verified read-back + rename). Settings: music volume (0–1, applied to the Master audio bus with an explicit mute at zero since music is the game's only audio) and fullscreen (window mode toggle; headless-safe no-op). A malformed, unknown-keyed or wrong-typed payload falls back to the defaults and never breaks the session; `resetToDefaults` restores and persists. The Journal Settings tab now exposes a Music volume slider (with percentage read-out, controller focus entry point) and a Fullscreen toggle with immediate effect and immediate persistence, keeping the production quit-to-menu confirmation flow unchanged; settings never touch a save slot and New Game/Continue never touch settings.

**Tests:** the new `Tests/TestUserSettings.gd` covers defaults, round trips, clamping, invalid-input rejection, five malformed-payload cases (not-JSON, non-dictionary, unknown key, wrong volume type, wrong fullscreen type) falling back to defaults, atomic writes, Master-bus application (decibels and mute-at-zero) and the real Settings tab wiring (slider drives service + bus + disk, fullscreen applies, quit flow unchanged); `Tests/TestJournal` still passes its settings return-to-menu contract.

**Exit gate:** ✅ changing the slider or toggle takes effect immediately and survives restart; no save payload gained settings fields; settings and saves never intersect. Gamepad-layout persistence stays deferred until a remapping system exists (the standard bindings are project-level).


## ✅ Commit 16 — Secret destinations and reward claims

**Implemented.** A revealed secret cache is claimable for its authored reward through the Discovery service: `claimSecretTarget(targetId)` validates in contract order — Trail eligibility first (an Off-Trail claim is refused), then known target, revealed, and one-shot (already-claimed) checks, then an all-or-nothing capacity pre-check (`Party.canAddItems`) before anything is granted — so a full inventory refuses with nothing consumed and the cache stays claimable for a later attempt; the unique reward is never silently dropped. On success the authored reward item is granted through `Party.addItem` and the one-shot `claimedTargetIds` persist in the Discovery snapshot, which moves to version 2 (version 1 payloads migrate with no phantom claims; imports validate claimed ids as known, unique and revealed). The Gold Run target authors its reward (`gold_nugget`, added to the ItemCatalog as a treasure resource) and `SecretMapData.validate` requires every target to carry a known reward definition. The Overworld wires the real interaction: chunk locations carry their `secret_id` into `createLocation`/`enterLocation`, and a revealed secret cache is claimed in place — the player stays on the Overworld, an unrevealed cache is hidden (no interaction), and a spent cache refuses a second attempt; the Trail gate ahead of the branch keeps Off-Trail entry refused as before. `SaveGame`'s discovery audit accepts the claim list (unique non-empty strings) while content drift still rolls back through the Discovery import.

**Tests:** `Tests/TestDiscovery` covers the full chain (Off-Trail, unrevealed, unknown target, full-inventory refusal with an unchanged state, successful grant of exactly one gold nugget, repeat refusal, snapshot v2 round trips, the v1 migration and nine malformed-claim rejections); `Tests/TestSecretClaims.tscn` runs the chain against the real autoloads and drives the real Overworld `enterLocation` handler on the Gold Run cache (claim then spent-cache refusal in place); `Tests/TestSaveRestart` claims the cache in the played session and its second-process verify asserts the claimed id, its reveal and the granted nugget all survive the restart; `Tests/TestSaveGame` audits claim lists.

**Exit gate:** ✅ one secret claim succeeds once per map and persists across a restart; a second attempt or a full inventory changes nothing; the reward never drops silently.


## Commit 17a — Shared actor animation service and manifest registry (design first) ✅ **implemented**

**Goal:** replace the per-actor hand-authored `*Animations.tscn` scenes with one data-driven animation service, so commit 17's new actors need only small data entries instead of duplicated scene editing.

**Implemented as designed**, with two honest scope cuts (see [Actor Animations](Actor%20Animations.md) §Scope):
- The Shootout spawn routes through the service; the Overworld animal scenes (they carry `CanvasTexture` normal maps and their own `OverworldAnimations.gd` runtime) and the player actors (directional Move states + shadow contract, mid-art-rework) stay on their runtimes and migrate in a follow-up.
- The registry initially covers the committed Walker Langley sheets plus all Squeky rat states; the service's legacy merge supplies every state the registry does not cover, so conversion can land as the art lands. Spawn-index suffixes ("Squeky rat0") are stripped for the registry lookup — the old code silently failed its indexed scene load, so this also fixes fighters spawning without visuals.

1. ✅ `Data/Actors/ActorAnimationRegistry.gd`: per-actor states as data (sheet path, frame size or whole-sheet, frame count, step, loop) with the same `SpriteFrames` semantics as the current scenes — Walker Langley and Squeky rat converted.
2. ✅ `Globals/ActorAnimationService.gd`: `forActor(actorType, actorName)` builds the `Animations.gd` runtime in code (root, `AnimationSprite` with one cached `SpriteFrames` per actor id, `AnimationPlayer` with generated per-state frame tracks); `idleForWeapon` reads `idleByWeapon` (default Idle otherwise), and unknown actors degrade to Idle with a warning rather than aborting a spawn; legacy-only actors keep their scene via the fallback.
3. ✅ (scoped) `Actors/Shootout/ShootoutActor.gd` routes through the service with the legacy-scene merge; `FrameData` stays the combat hit-frame read (no duplicate contract).
4. ✅ `Tests/TestActorAnimations.gd` (built frames counts/loop/speed, generated playback library, weapon-idle selection and default fallback, indexed-id resolution, cache sharing, unknown-actor degradation, legacy fallback) and `Tests/TestContentLint` registry checks (sheet paths exist, positive frames/step, idle selections point at authored states, broken-entry fixture proof).
5. ✅ Exit gate: registry-authored actors animate identically to their old scenes; legacy scenes fall back cleanly; no per-actor `.tscn` is needed for new content. Legacy scenes are deleted only in a later cleanup commit.

Design doc: [Actor Animations](Actor%20Animations.md).

## Commit 17 — Combat content breadth ✅ **implemented**

**Goal:** the representative fight is no longer Walker-plus-rats.

**Implemented as designed**, with the Whispering Pines Reach Zone rename as the canonical forest-area name (Zone id `pine_forest` → `whispering_pines_reach`, displayName "Whispering Pines Reach"; equipment, music, events, the quest trigger scene and their tests updated with it):

1. ✅ Authored executable Moves for the classes that only carried `futureAbilities` prose: Bobtail Guard (Venom Shot, Cylinder Drop, Mark Target), Dust Whisperer (Open Vein, Bleed Cleanse, Toxin Throw, Poison Cleanse, Type Mark, Weaken, Piercing Coat), Line Rider (Poison Cleanse, Sharpened Spurs) and Bottle Courage Bulldozer (Bottle Up, Cylinder Boost; taunting stays the authored Duck Down). The implemented lines moved into canonical `moves` grants; the two "Disrupt positioning" designs stay prose because position disruption has no move op yet (Rodeo-only). Grants resolve through the existing projector/lint unchanged.
2. ✅ New actor files + animation sets **through the commit-17a registry**: five Whispering Pines Reach bandits (`Data/Actors/Bandits/` — Pistolero grunt, Bobtail Guard, Dust Whisperer, Line Rider, Whiskey Bulldozer) and four main-party files (`Data/Actors/Named People/` — Aiyana, Gwyneth Remington, Manuel Cárdenas, Morrison Branson) with profiled `ai` blocks using the commit-13 per-family weights (support guards, support whisperer, tank bulldozer with `preferredColumns`). No boss script was warranted — no boss encounter is authored in this commit.
3. ✅ New content breadth: `Data/Shootout/Encounters/PinesPatrol.gd`, `PinesWaylay.gd` (main party + Aiyana/Gwyneth against the bandits) and `PinesStandoff.gd` (Showdown), the `whispering_pines_reach` pool, the `Bandits` loot table, and a ForestEvents outcome that launches the pool. `Tests/TestContentLint` now audits the `Data/Actors/Bandits` folder like the other actor folders.
4. ✅ Re-recorded `Tests/EncounterMetricsBaseline.json`: the existing canyon fixture replays exactly (no authored health/stat change to Walker or the rats, so no deviation there), and the driver gained a `pinesWaylay` fixture proving the new classes field real loadouts in a real encounter with measured, reproducible metrics. Measured deviation worth recording: at the authored placeholder stats the bandit party loses the measured run without dealing a hit (all three bandits knocked down in 4 rounds while Walker, Aiyana and Gwyneth finish at full HP) — combat balance tweaks stay deliberately deferred by owner decision, so the stats are recorded as authored-light rather than tuned to force a result.
5. ✅ Exit gate: the new classes field real loadouts in real encounters with measured, reproducible metrics.

**Tests:** `Tests/TestContentLint` audits the `Bandits` actor folder (reference integrity, class grants, offensive-move survival, AI profiles) and every new Move/class/loot/encounter/pool reference; `Tests/TestEncounters` validates the three new encounter files; `Tests/TestActorAnimations` covers the new registry entries (indexed Pistolero id, rifle bandit `idleByWeapon`, Aiyana's full state set, the accented Manuel Cárdenas id); `Tests/TestEncounterMetrics` (scene) replays both baseline fixtures deterministically. Full suite: 70/70.

**Exit gate:** ✅ the new classes field real loadouts in real encounters with measured, reproducible metrics.

## Commit 18 — Zone breadth ✅ **implemented**

**Goal:** at least one more Zone beyond canyon has coherent encounters, loot and newspaper data.

**Implemented for Whispering Pines Reach** (the commit-17 zone), with vendor catalogs deliberately staying authored for the canyon towns only — every un-authored Zone keeps failing closed:

1. ✅ Newspaper copy: `Data/Vendors/NewspaperData.gd` authors the Zone's headline, editorial, general tips and per-encounter tips for all three published encounters (`PinesPatrol`, `PinesWaylay`, `PinesStandoff`); composition is never copied — the report builder projects it from the shared pool and actor data, and `NewspaperData.validate` rejects tips the pool does not publish. `Tests/TestNewspaper` proves the production report is available, projects exactly the three published parties and carries the authored tips.
2. ✅ Zone-specific equipment and loot: the authored Whispering Pines Reach items (Woodsman Flannel Coat, Pine Pitch Stetson, Needle-Stitched Boots) roll through the existing `dropsAnywhere` rules — `generateLoot(zoneId: "whispering_pines_reach")` restricts equipment to the Zone's own items plus generic bases, verified by a seeded sweep in `Tests/TestEncounterFlow`; affix content stays inside the supported `CombatStatRegistry` (generation and lint unchanged).
3. ✅ Measurement batch extended: `Tests/TestEncounterMetrics` gains a committed `pinesStandoff` Showdown baseline fixture (seeded replay + exact replay against `EncounterMetricsBaseline.json`, now three fixtures) and a three-seed `PinesPatrol` batch with the max-turn guard and real source-data rows in the new Zone.
4. ✅ Exit gate: a seeded encounter from the new Zone runs the real launch/return route — `Tests/TestEncounterFlow` launches `Whispering Pines Waylay` through `SceneManager` with a validated seeded request, proves the Shootout keeps the Zone and combat-RNG seed, rolls the fight's loot through `generateLootForFight` with Zone propagation, and returns to the origin exactly once.

**Tests:** `Tests/TestNewspaper` (second authored Zone projects real news), `Tests/TestEncounterFlow` (pines pool selection, ForestEvents dispatch, launch/loot/return route), `Tests/TestEncounterMetrics` (standoff fixture + new-Zone batch). All existing suites pass unchanged.

**Exit gate:** ✅ a seeded encounter from the new Zone runs through the real launch/return route with valid loot and newspaper projections; the content lint covers every new reference.

## Explicitly still deferred

Dynamic spawns (VisualParty director), Flair, Poker integration, the excluded-affix backlog (mxEn/lasso/gems/affliction-duration stats need systems first), vendor schedules/haggling/buyback, general fog of war/fast travel, and all manual visual/controller acceptance passes. These stay in the gap register's deferred rows and are not blockers for commits 14–18.
