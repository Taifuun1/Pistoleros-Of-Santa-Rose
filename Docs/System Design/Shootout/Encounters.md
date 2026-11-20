# Encounters

How Shootouts are defined, launched and composed: encounter data, Dust-ups vs Showdowns, spawn sources (Overworld events, Location ambushes, quests) and bosses. Game-design rules live in `Docs/Combat.md` ("Encounters", "Rewards").

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- Shootouts happen three ways: **Overworld events** (multiple results based on chosen options), **Location ambushes** (randomly spawned, possibly with a visible indicator), **quest Shootouts** (scripted, prebuilt locations, predefined party compositions; player chooses when to start).
- Each Shootout is a **Dust-up** (attritional, numerous, mostly Locations) or a **Showdown** (difficult: quest fights, event results, player-activated Location fights).
- Flavor variation naming used e.g. in Shootout start popups: Dust-ups — Scuffle, Ruckus, Hold-up, Tussle; Showdowns — Gunfight, Slingin', High Noon, Bangin'.
- Bosses: higher stats, unique enemies, game-warping Rodeos; boss fights can have non-standard win conditions (defeat a character, survive N turns, defeat the party); each boss should feel unique.
- Enemies: basic enemies take 2-4 gang members; stronger ones the full gang plus companions; regions lean on specific classes (see [Enemy AI](Enemy%20AI.md)).
- Fleeing is possible after 10 turns in Showdowns, instant in Dust-ups (see [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).

## Current state

**Implemented** (metadata, typed launcher/return router, deterministic pool selection, win conditions and the shared per-Zone pool data/loader; Location-ambush and quest callers are still pending with those systems):

- Encounter metadata: `name`, `kind` (`dustup`/`showdown`), `flavor`, `background`, `lootTable`, `winCondition` and nested `teams`; the legacy flat format still resolves (`data.get("teams", data)`). `RatAmbush` is the default/debug encounter with full metadata.
- Shared Zone pools: `Data/Shootout/EncounterPoolData.gd` merges every authored `Data/Shootout/EncounterPools/<zone>.gd` file through `loadProductionPools()`, so one pool serves both the gameplay launcher and the vendor newspaper; `selectEncounter(zoneId, rng)` performs seeded weighted selection. Authored pools: `canyon` (`CanyonRats`, `CanyonRatNest`) and `whispering_pines_reach` (`PinesPatrol`, `PinesWaylay`, `PinesStandoff` — commit 17, launched through a ForestEvents outcome); other Zones still need their own pools and actors.
- Launcher: `EncounterRequest` validates the encounter path, canonical Zone, source, origin, progression and Trail snapshot. `SceneManager.launchShootout()` installs one pending request, captures the origin, connects `shootoutEnded` before the scene enters the tree, restores the origin once and clears the context. `Shootout._ready()` consumes the request exactly once; a direct scene run uses the debug `RatAmbush`, while a malformed production request is rejected instead of silently falling back.
- Win conditions in `ShootoutTurnManager`: `rout` (default), `defeat_actor { actorName }` (ends when the named character dies), `survive_rounds { rounds }` (checked at round rebuilds), and per-actor `hp_below { actorName, fraction | amount, stat?: "hp"|"maxHp", winner? }` (the named base actor crossing the threshold ends the fight; checked after damage resolves). Optional `winner` overrides the default winning side.
- Flavor names: `Shootout.DUSTUP_FLAVORS`/`SHOWDOWN_FLAVORS`; a missing `flavor` picks one at random by `kind`, and `encounterName`/`flavorName` live on the shootout root ready for the start popup (see [Shootout UI](Shootout%20UI.md)).
- Region-pool schema: `Data/Shootout/EncounterPoolData.gd` defines per-Zone weighted encounter references and newspaper visibility (patch 1 of [Location vendors](../Location%20Vendors%20Implementation.md)); `loadProductionPools()` merges the authored `Data/Shootout/EncounterPools/*.gd` files, so the launcher and the newspaper read the same pools. The Canyon Zone publishes a real pool (patch 6); every other Zone stays unavailable until its encounters are authored, and an unpublished Zone is never substituted with another one or with the debug `RatAmbush`.
- Tests: `Tests/TestEncounters.gd` validates every encounter file (sides, position ranges, one actor per column, max 4 copies, win condition shape), the metadata/legacy defaults and all four win-condition behaviors. `Tests/TestEncounterFlow.tscn` covers request validation, deterministic pool selection, canonical Zone event dispatch and the real Overworld → canyon Shootout → exact origin return path.

## Design

### Encounter data format

Extend the encounter files with metadata while keeping the actor layout:

```gdscript
# Data/Shootout/Encounters/RatAmbush.gd
var data = {
	"name": "Rat Ambush",
	"kind": "dustup",                  # dustup | showdown
	"flavor": "Hold-up",               # one of the flavor variations, or picked randomly from kind
	"background": "res://Assets/Shootout Backgrounds/GrassLandsShootoutBackground.png",
	"lootTable": "res://Data/Shootout/LootTables/Rats.gd",   # see Rewards doc
	"winCondition": { "type": "rout" },                        # rout | defeat_actor | survive_rounds
	"teams": {
		"player team": { "Named People": { "Walker Langley": { "positions": [1, 2, 3] } } },
		"enemy team": { "Animals": { "Squeky rat": { "positions": [1, 2, 3] } } }
	}
}
```

`Shootout.init()` reads `data.teams` where it today reads the root Dictionary. Missing metadata defaults to `dustup` / random flavor / rout — old-format files keep working.

### Encounter launcher

Implementation follows the Scene Manager conventions (`Docs/System Design/Scene Manager.md`):

1. The caller (Overworld event outcome, Location ambush trigger, quest script) builds an `EncounterRequest` (or the options Dictionary that builds one) and calls `SceneManager.launchShootout(request)`.
2. The Scene Manager validates the request, captures the origin, installs exactly one pending request and connects `shootoutEnded` before the Shootout scene enters the tree.
3. `Shootout._ready()` consumes the pending request once. A null request means a direct debug run and uses `RatAmbush`; an invalid production request is rejected instead of substituting another encounter.
4. After the result screen is acknowledged, `shootoutEnded` restores the launch origin exactly once and clears the request/context. Vamoose-specific destination/loss routing remains a later commit (see [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).

### Ambushes and random encounters

- Locations spawn ambush markers; interaction/proximity rolls an encounter from the region's encounter pool (`Data/Shootout/Encounters/{Region}/*.gd` or a pool list in region data).
- Composition: pools list enemy types with counts per party size (2-4 members for basic enemies, full-gang fights for stronger ones); positions within the pool file. Random Dust-ups pick a random flavor name for the start popup.

### Win conditions

`ShootoutTurnManager.checkBattleEnd()` currently only supports rout. Extend:

- `rout` — current behavior.
- `defeat_actor { actorName }` — battle ends when that actor dies (regardless of other survivors).
- `survive_rounds { rounds }` — player wins when `roundNumber` exceeds the count; checked at round rebuild in `Shootout._on_actor_done()`.
- per-actor `hp_below { actorName, fraction: 0.5, stat?: "hp"|"maxHp", amount?, winner? }` — quest-style condition (decided: quests can require getting a named character's HP/MxHP below a threshold); the named base actor crossing `fraction`/`amount` ends the fight, checked after damage resolves.

The manager reads the win condition from the encounter metadata passed into `Shootout.init()`. Win conditions are how quests vary fights — there are no mid-fight reinforcements (decided).

### Bosses

A boss encounter is a Showdown with: unique enemy actor files (higher stats, unique Rodeos), an optional AI script (see [Enemy AI](Enemy%20AI.md)), a non-rout win condition where applicable, and its own loot table. No special code beyond the above extension points — bosses are content, not systems.

## Files to create / modify

**Create**

- `Data/Shootout/Encounters/**/*.gd` — real encounter files with metadata, organized per region.
- `Tests/TestEncounters.gd`, `Tests/TestEncounterFlow.tscn` (implemented).

**Modify**

- `Shootout/EncounterRequest.gd` — validated launch contract (implemented).
- `Globals/Shootout.gd` — single pending request handoff, flavor-name lists (implemented).
- `Shootout/Shootout.gd` — `init()` reads `teams` + metadata; `_ready()` consumes the request once with a direct-debug fallback; win-condition checks; start popup with flavor name (see [Shootout UI](Shootout%20UI.md)).
- `Nodes/Scene Manager/SceneManager.gd` — launch/return router (implemented).
- Location/Overworld/quest code — build an `EncounterRequest` and launch through the Scene Manager.

## Testing

`Tests/TestEncounters.gd`:

- Every encounter file loads, has valid teams/positions (1-4, max 4 per side, one actor per column per side) and known actor files.
- Old-format encounters (no metadata) still init with defaults.
- Win conditions: `defeat_actor` ends the battle on the right death; `survive_rounds` triggers at the right round; `hp_below` triggers when the named actor's HP/MxHP crosses the threshold, never on a side total.
- `Data/Shootout/SqueekyRat.gd` is removed and nothing references it.
- Request flow: a validated `EncounterRequest` launches the requested encounter; null in a direct scene run falls back to the debug encounter; invalid requests and duplicate results launch/return nothing. `Tests/TestEncounterFlow.tscn` also covers deterministic pool selection and exact origin return.

## Implementation order

1. ✅ Encounter metadata + `teams` nesting (backwards compatible).
2. ✅ Typed `EncounterRequest` launcher + SceneManager launch/return router.
3. ✅ Win conditions.
4. Region pools + ambush wiring: the shared Zone pool data and loader are implemented (`EncounterPoolData.loadProductionPools()`, `selectEncounter()`), and Overworld events launch through it — the `canyon` pool (`CanyonRats`/`CanyonRatNest`) and, since commit 17, the `whispering_pines_reach` pool (`PinesPatrol`/`PinesWaylay`/`PinesStandoff`) via a ForestEvents outcome. Location-ambush wiring and further Zone pools remain pending with those systems.
5. ✅ Combat-rule migrations (commit 4): max-HP fight starts with Trail-gated attrition, combined-stack bleed, Moves-only enemy AI with the rat's `Scratch`, per-actor `hp_below`, class-authored Jammed payloads, no on-hit effects on Miss, and Zone-aware loot.
6. First boss encounter content (pending — sequenced as post-18 backlog commit 21).

## Open Questions

1. ~~Is `Data/Shootout/SqueekyRat.gd`'s grid still used?~~ — **decided**: no; remove the file, keep the assets.
2. Do Location ambushes pick one encounter file per fight, or compose enemies from a pool at spawn time?
- Use predefined encounter files for party compositions
3. Where do quest Shootout party compositions come from — the encounter file's `player team` block (current format supports it) or always the live `Party.party`?
4. Do flavor names have any gameplay effect (e.g. Hold-up = enemies act first) or are they pure flavor? (First pass: pure flavor.)
- Flavour
5. Should `hp_below` also support per-actor thresholds ("the boss under 25%") or is the side total enough? (First pass: side total only.)
- Should be hp below for a character, specifically for the boss
