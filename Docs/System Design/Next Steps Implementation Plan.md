# Next Steps Implementation Plan

**Status: planned.** The [First steps implementation plan](First%20Steps%20Implementation%20Plan.md) is fully delivered (commits 1–13, suite 66/66). This plan sequences the remaining product features and the phase-4 content expansion, ordered by dependency: save slots before settings (settings should not live in a slot), then secret rewards (builds on the save contract), then content breadth. Combat balance tweaks and manual acceptance are deliberately deferred by owner decision.

**Global rules (unchanged):** disk ownership stays in `Globals/SaveGame.gd`; no transient combat state in saves; no new Zone/Party/boss invented to pad a slice; every commit ships its tests and updates Testing.md, the gap register and the affected design docs; commits stay logically grouped (code → wiring/UI → proof → docs).

## ✅ Commit 14 — Save slots and save-management UI

**Implemented.** `Globals/SaveGame.gd` gains slot APIs with no payload schema change: slot files live under `user://saves/<id>.json` (ids restricted to letters, digits, underscore, dash and space), an `index.json` carries only the active slot id, and an empty selection keeps the legacy single-file path fully functional. `listSlots()` returns one validated entry per slot (id, timestamp, format version, valid flag and a human-readable notice — a legacy pre-slot save is imported as `slot1` on first listing so existing players keep it); `selectSlot` fails closed on unknown ids; `createSlot` picks the first free id and only appears in listings after its first checkpoint; `deleteSlot` removes the file and clears the selection when it was active; `migrationNotice` translates failure reasons into player text ("newer version" / "damaged"). Save, load, Continue and checkpoints route through the active slot transparently, and the selection is restored from the index in every fresh process. The Main Menu gains a Saves overlay: one row per slot with timestamp and active marker, Play (select + Continue, disabled for damaged slots), two-step Delete confirmation, New Save and Back, with status text for empty stores and refusals.

**Tests:** `Tests/TestSaveGame` covers slot creation/selection/deletion, path isolation between slots, restore-exactness, id sanitization (traversal and duplicate rejection), notices and the legacy import; `Tests/TestSaveRestart` adds a slot section — slot A stores the played session, slot B a dirtied one, a fresh process restores slot A through the slot index while slot B stays untouched; the new `Tests/TestSaveSlots.tscn` drives the real Main Menu overlay (empty-store text, New Save, checkpoint → playable row, Play selection, two-step delete, Back leaves Continue truthful).

**Exit gate:** ✅ a second process restores the selected slot exactly while slot B is untouched; deleting the active slot disables Continue until another slot is chosen; a corrupt or newer-version slot is reported in player text and never loaded; no combat transient state enters the payload.

## Commit 15 — User settings

**Goal:** volume and display preferences persist independently of any save slot.

1. `user://settings.json` (separate from slot payloads): master/music volume, integer-scale toggle/fullscreen, and the current gamepad layout. A small `Globals/UserSettings.gd` autoload (defaults, validation, clamping, atomic write) owns it; audio applies through `Globals/MusicPlayer.gd`, display through the existing window/scale setup.
2. Settings UI in the Journal/pause settings view: sliders + toggles with immediate effect and no save-slot writes. New Game and Continue leave settings alone.
3. Tests: `TestUserSettings` (defaults, clamp, malformed-payload rejection, round trip), `TestMusicPlayer` volume application, a scene test for the settings view.
4. Exit gate: changing a slider takes effect immediately and survives restart; no save payload gains settings fields.

## Commit 16 — Secret destinations and reward claims

**Goal:** purchased secret maps lead to real, claimable one-shot rewards.

1. A secret-cache interaction at revealed secret Locations: Trail-eligibility check first (Off-Trail secrets cannot be claimed), then the claim command — refuse all-or-nothing when inventory is full before anything is granted, grant the authored secret item through `Party.addItem`, persist the one-shot `claimedTargetId` in the Discovery snapshot (v2 migration), and mark the map spent.
2. Never silently drop a unique reward: a full-inventory claim keeps the cache available for a later attempt; nothing is consumed on refusal.
3. Tests: `TestSecretClaims` (eligibility, full-inventory refusal, one-shot idempotency, duplicate-claim rejection, snapshot round trip), a flow scene test through the real interaction, `TestSaveRestart` for the claimed id across restart.
4. Exit gate: one secret claim succeeds once per map and persists; a second attempt or a full inventory changes nothing.

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
