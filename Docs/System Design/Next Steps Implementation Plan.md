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


## Commit 17 — Combat content breadth

**Goal:** the representative fight is no longer Walker-plus-rats.

1. Author executable Moves for the classes that still only carry `futureAbilities` prose (Bobtail Guard, Dust Whisperer, Line Rider, Bottle Courage Bulldozer) and move their implemented lines into canonical `moves`; grants resolve through the existing projector/lint unchanged.
2. New actor files + animation sets and profiled `ai` blocks for the added roles (support/tank archetypes use the per-family weights from commit 13); boss `ai` scripts where a role warrants a priority override.
3. Re-record `EncounterMetricsBaseline.json` after authored health/stat changes and record the new measured deviation, if any — no test expectations edited to force a pass.
4. Exit gate: the new classes field real loadouts in real encounters with measured, reproducible metrics.

## Commit 18 — Zone breadth

**Goal:** at least one more Zone beyond canyon has coherent encounters, loot and newspaper data.

1. Author the Zone's encounter pools, loot tables, actors and newspaper reports; vendor catalogs keep failing closed for un-authored Zones.
2. Zone-specific equipment (`dropsAnywhere` rules), affix content within the supported registry, and the measurement batch extended to the new Zone.
3. Exit gate: a seeded encounter from the new Zone runs through the real launch/return route with valid loot and newspaper projections; the content lint covers every new reference.

## Explicitly still deferred

Dynamic spawns (VisualParty director), Flair, Poker integration, the excluded-affix backlog (mxEn/lasso/gems/affliction-duration stats need systems first), vendor schedules/haggling/buyback, general fog of war/fast travel, and all manual visual/controller acceptance passes. These stay in the gap register's deferred rows and are not blockers for commits 14–18.
