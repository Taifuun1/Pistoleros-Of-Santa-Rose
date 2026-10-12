# Rewards

What winning a Shootout gives: party levels and loot (weapons, equipment, money, consumables), and how Rodeos modify loot. Game-design rules live in `Docs/Combat.md` ("Rewards").

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- **Levels**: the whole party shares a level; levels are gained on quest completion (level progression follows quest progression, not per-fight XP); levels increase character stats and Rodeo effectiveness and slightly increase Stagecoach speed.
- **Loot**: different enemies have different loot tables, based on party name (see Open Questions); Rodeos can increase or decrease loot; no uniques from Shootouts unless it's a quest.
- Possible drops: weapons and equipment (with affixes and rarity, see `Docs/Weapons and affixes.md`), money (not too much — quests are the main money source), comestibles and consumables (similar to town vendors).
- Vamoose (full party down) loses half of all loot (see [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).

## Current state

- `Party.gd` has `level` (read by the Rodeo manager for level scaling). Quest-completion leveling is an overworld/quest concern — the Shootout only reads the level.
- The Rodeo manager accumulates loot modifiers: `modify_loot` effects fill `lootModifiers` / `lootMultipliers`, emitted at `fight_end` via `consumeLootModifiers()` — currently just printed (`Shootout._on_battle_ended`). Nothing generates loot, and no loot tables exist.
- Item generation with affixes and rarity exists outside combat (`Tests/TestItemGeneration.gd` covers it).

## Design

### Loot tables

Data-driven, same convention as the rest of `Data/Shootout`:

```gdscript
# Data/Shootout/LootTables/Rats.gd
var data = {
	"name": "Rats",
	"money": { "min": 2, "max": 6, "chance": 0.8 },
	"rolls": 1,                        # item rolls per fight
	"entries": [
		{ "kind": "consumable", "id": "Paregoric", "weight": 3 },
		{ "kind": "weapon", "rarity": ["common"], "weight": 1 },
		{ "kind": "equipment", "rarity": ["common"], "weight": 1 }
	]
}
```

- Encounter metadata points at a loot table (see [Encounters](Encounters.md)); fights without one drop money only.
- Weapon/equipment entries hand off to the existing item generator with the allowed rarities; consumables reference `Data/Shootout/Items` ids.

### Loot generation

New manager `Shootout/ShootoutLootManager.gd` (or a plain helper — the logic is small; proposed: helper on the shootout root to avoid another manager):

```gdscript
func generateLoot(encounterData, lootModifiers) -> Dictionary:
	# 1. roll money from the table; apply lootModifiers.amounts.money, then multipliers.money
	# 2. roll `rolls` entries by weight; resources amounts/multipliers apply to material-type drops
	# 3. returns { "money": int, "items": [itemInstance, ...] }
```

Called from `Shootout._on_battle_ended()` on player victory with `rodeoManager.consumeLootModifiers()`, replacing the current `print()`. The result travels with the `shootoutEnded` payload (extend the signal or emit a follow-up `lootGenerated(loot)` signal — proposed: extend `shootoutEnded(winningSide, results)` where `results` includes loot and surviving party state, consumed by the launcher, see [Encounters](Encounters.md)).

### Level scaling interaction

- Party level already scales Rodeo values via `applyLevelScaling()`; [Damage and Stats](Damage%20and%20Stats.md) stat derivation reads level-scaled bases from actor data when class/level stat growth lands (quest-side system, out of scope here).
- Loot tables can scale with party level later (e.g. rarity pools per level band) — keep `generateLoot()` reading level so this is a data change, not a code change.

## Files to create / modify

**Create**

- `Data/Shootout/LootTables/*.gd`.
- `Tests/TestLoot.gd`.

**Modify**

- `Globals/Shootout.gd` — load `Data/Shootout/LootTables` into `lootTablesData`.
- `Shootout/Shootout.gd` — `generateLoot()`, victory hook, extended `shootoutEnded` payload.
- Launcher code — add loot to the party inventory/money (`Globals/Party.gd`).

## Testing

`Tests/TestLoot.gd`:

- Loot table files validate: weights positive, referenced item ids exist, rarities known.
- Rodeo modifiers apply: Backpocket Check adds flat money; multipliers compose after flats.
- `consumeLootModifiers()` resets after consumption (already true — keep covered).
- Seeded RNG: money within min/max; entries respect weights over many rolls.
- Victory-only: a lost fight generates no loot (Vamoose halves carried loot instead).

## Implementation order

1. Loot table data format + loader + validation test.
2. `generateLoot()` + victory hook + `shootoutEnded` payload.
3. Party inventory/money handoff in the launcher.
4. Author tables per enemy type as encounters are authored.

## Open Questions

1. "Loot tables based on party name" — is this the *enemy* party name (rats drop rat loot), the *player* gang name, or quest-scoped tables? Proposed: enemy-party/encounter tables.
2. Where does the party inventory live — `Globals/Party.gd` (proposed) or a separate inventory autoload?
3. Should money scale with encounter difficulty (Dust-up vs Showdown) via the table or a global multiplier?
4. Do bosses roll from unique tables with guaranteed drops (proposed: yes, quest loot handled by the quest, boss tables for the rest)?
