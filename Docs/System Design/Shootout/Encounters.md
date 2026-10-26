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

**Implemented** (metadata, launcher and win conditions; region pools/ambush wiring is pending with the Location/Overworld systems):

- Encounter metadata: `name`, `kind` (`dustup`/`showdown`), `flavor`, `background`, `lootTable`, `winCondition` and nested `teams`; the legacy flat format still resolves (`data.get("teams", data)`). `RatAmbush` is the default/debug encounter with full metadata.
- Launcher: callers set `Shootout.pendingEncounter` (a `res://` path) on the autoload before switching to the Shootout scene; `_ready()` consumes it (falling back to `RatAmbush` when null) and clears it.
- Win conditions in `ShootoutTurnManager`: `rout` (default), `defeat_actor { actorName }` (ends when the named character dies), `survive_rounds { rounds }` (checked at round rebuilds), and `hp_below { target: "party"|"enemy", fraction | amount, stat? }` (the target side loses when its side-total current HP — or `stat: "maxHp"` — drops below the fraction of its maxHp total, or below an absolute amount; checked after damage resolves). Optional `winner` overrides the default winning side.
- Flavor names: `Shootout.DUSTUP_FLAVORS`/`SHOWDOWN_FLAVORS`; a missing `flavor` picks one at random by `kind`, and `encounterName`/`flavorName` live on the shootout root ready for the start popup (see [Shootout UI](Shootout%20UI.md)).
- Tests: `Tests/TestEncounters.gd` validates every encounter file (sides, position ranges, one actor per column, max 4 copies, win condition shape), the metadata/legacy defaults and all four win-condition behaviors.

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

The Shootout scene needs to receive its encounter instead of preloading one. Following the existing Scene Manager conventions (`Docs/System Design/Scene Manager.md`), the launcher:

1. The caller (Overworld event result, Location ambush trigger, quest script) sets `Shootout.pendingEncounter = "res://Data/Shootout/Encounters/Name.gd"` on the autoload before switching scenes.
2. `Shootout._ready()` loads `pendingEncounter` (falling back to a debug encounter when null, so the scene stays runnable from the editor).
3. On `shootoutEnded`, the scene hands results (winning side, loot modifiers, surviving party HP) back through the Scene Manager to whoever launched it (see [Rewards](Rewards.md) and [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).

### Ambushes and random encounters

- Locations spawn ambush markers; interaction/proximity rolls an encounter from the region's encounter pool (`Data/Shootout/Encounters/{Region}/*.gd` or a pool list in region data).
- Composition: pools list enemy types with counts per party size (2-4 members for basic enemies, full-gang fights for stronger ones); positions within the pool file. Random Dust-ups pick a random flavor name for the start popup.

### Win conditions

`ShootoutTurnManager.checkBattleEnd()` currently only supports rout. Extend:

- `rout` — current behavior.
- `defeat_actor { actorName }` — battle ends when that actor dies (regardless of other survivors).
- `survive_rounds { rounds }` — player wins when `roundNumber` exceeds the count; checked at round rebuild in `Shootout._on_actor_done()`.
- `hp_below { target: "party"|"enemy", fraction: 0.5, stat?: "hp"|"maxHp" }` — quest-style condition (decided: quests can require getting characters' HP/MxHP below an amount); the target side loses when its side-total drops below `fraction` of its maxHp total (or below an absolute `amount`); checked in `finishTurn()` after damage resolves.

The manager reads the win condition from the encounter metadata passed into `Shootout.init()`. Win conditions are how quests vary fights — there are no mid-fight reinforcements (decided).

### Bosses

A boss encounter is a Showdown with: unique enemy actor files (higher stats, unique Rodeos), an optional AI script (see [Enemy AI](Enemy%20AI.md)), a non-rout win condition where applicable, and its own loot table. No special code beyond the above extension points — bosses are content, not systems.

## Files to create / modify

**Create**

- `Data/Shootout/Encounters/**/*.gd` — real encounter files with metadata, organized per region.
- `Tests/TestEncounters.gd`.

**Modify**

- `Globals/Shootout.gd` — `pendingEncounter`, flavor-name lists, encounter pool loading if pooled.
- `Shootout/Shootout.gd` — `init()` reads `teams` + metadata; `_ready()` uses `pendingEncounter`; win-condition checks; start popup with flavor name (see [Shootout UI](Shootout%20UI.md)).
- `Shootout/ShootoutTurnManager.gd` — non-rout win conditions in `checkBattleEnd()`.
- Location/Overworld/quest code — set `pendingEncounter` and launch via the Scene Manager.

## Testing

`Tests/TestEncounters.gd`:

- Every encounter file loads, has valid teams/positions (1-4, max 4 per side, one actor per column per side) and known actor files.
- Old-format encounters (no metadata) still init with defaults.
- Win conditions: `defeat_actor` ends the battle on the right death; `survive_rounds` triggers at the right round; `hp_below` triggers when the targeted side's total MxHP fraction drops below the threshold.
- `Data/Shootout/SqueekyRat.gd` is removed and nothing references it.
- `pendingEncounter` flow: set, launch, correct encounter inits; null falls back to the debug encounter.

## Implementation order

1. ✅ Encounter metadata + `teams` nesting (backwards compatible).
2. ✅ `pendingEncounter` launcher.
3. ✅ Win conditions.
4. Region pools + ambush wiring (pending, with the Location/Overworld teams' systems).
5. First boss encounter content (pending).

## Open Questions

1. ~~Is `Data/Shootout/SqueekyRat.gd`'s grid still used?~~ — **decided**: no; remove the file, keep the assets.
2. Do Location ambushes pick one encounter file per fight, or compose enemies from a pool at spawn time?
- Use predefined encounter files for party compositions
3. Where do quest Shootout party compositions come from — the encounter file's `player team` block (current format supports it) or always the live `Party.party`?
4. Do flavor names have any gameplay effect (e.g. Hold-up = enemies act first) or are they pure flavor? (First pass: pure flavor.)
- Flavour
5. Should `hp_below` also support per-actor thresholds ("the boss under 25%") or is the side total enough? (First pass: side total only.)
- Should be hp below for a character, specifically for the boss
