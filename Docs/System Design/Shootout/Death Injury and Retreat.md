# Death, Injury and Retreat

What happens when characters fall and fights are lost: injuries, knockouts, Vamoose (full party down) and fleeing. Game-design rules live in `Docs/Combat.md` ("Death, injury and retreat").

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- **Injury**: a character's MxHP is modified by damage taken on a journey — the more damage taken, the less MxHP in future fights. An internal per-character modifier decides how much HP must be lost per point of MxHP lost. MxHP is restored with bought camp items and resets when entering a town.
- **Knockout**: being knocked out gives additional debuffs for the next few Shootouts.
- **Retreat (Vamoose)**: happens when all 4 gang members are downed; the party is thrown into the last visited town; half of all loot is lost; if a quest is in progress, the party is thrown to the last checkpoint.
- **Fleeing**: possible after 10 turns in Showdowns, instant in Dust-ups; fleeing costs a portion of MxHP.

## Current state

**Implemented** (party persistence, injuries, knockouts, Vamoose and fleeing; the Scene Manager town/checkpoint handoff is pending with the launcher integration):

- `Globals/Party.gd` owns the persistent state: per-member `hp`, `baseMaxHp`, `injuryDamage`, `injuryRate`, `knockoutDebuffs` and `downed`, plus `money` and `questInProgress`. `effectiveMaxHp()` derives MxHp from journey injuries (floor 1); `getFightData()` hands the fight prepared member data (capped HP, debuffed stats on a duplicate).
- Injuries: all damage (attacks, abilities, bleed/poison) accumulates on the actor node (`injuryDamage`) and is written back to the party at fight end.
- Post-fight flow: `Shootout._on_battle_ended()` builds a results payload (`winningSide`, `outcome`, `fled`, per-member `party` state with death snapshots, `rodeoLoot`) and calls `Party.applyFightResults()`; the `shootoutEnded` signal now carries `(winningSide, results)`.
- Knockouts: members at 0 HP at fight end are `downed` and gain the placeholder debuff package (High Tailin' -2, Six Shootin' -1) for 3 Shootouts (decided: winning fights with casualties still knock survivors out); debuffs tick down one per fight and feed fight stats through `getFightData()`.
- Vamoose: an enemy win with the whole party downed yields outcome `vamoose`; `Party.vamoose()` halves the money pouch (loot hook lands with [Rewards](Rewards.md)) and returns the destination (`town`, or `quest_checkpoint` when `questInProgress`).
- Fleeing: a Flee button (UI) enabled via `turnManager.canFlee()` — instant in Dust-ups, turn 10+ in Showdowns (`FLEE_TURN_THRESHOLD`); fleeing yields outcome `fled` (party keeps remaining loot and is not thrown to town) and `Party.applyFleeCost()` models the MxHp loss as injury (placeholder 20% of base MxHp x injury rate). Enemies never flee (decided).
- `resetInjury()` (town entry) and `reduceInjury()` (camp items) are ready for the overworld systems.
- Tests: `Tests/TestInjury.gd` covers injury math and the MxHp floor, fight data preparation, write-back, knockout debuff duration, town/camp resets, flee cost, flee enablement, Vamoose and damage accumulation.

## Design

### Persistent party state

`Globals/Party.gd` becomes the owner of post-fight state. After each Shootout, the scene writes back per member:

```gdscript
Party.party[name] = {
	...,
	"hp": survivingHp,               # current HP after the fight
	"injuryDamage": int,             # cumulative damage taken this journey
	"injuryRate": int,               # HP lost per point of MxHP lost (internal modifier)
	"knockoutDebuffs": [ ... ],      # active debuffs with shootoutsLeft counters
	"downed": bool                   # knocked out in the last fight
}
```

- `Shootout.spawnActor()` already reads `maxHp` via `actorData.get("maxHp", ...)`; effective MxHP becomes `baseMaxHp - floor(injuryDamage / injuryRate)`, clamped to a floor of 1.
- During the fight, `ShootoutActionResolver.applyDamage()` accumulates `injuryDamage` on player-side actors (track on the actor node, write back at fight end).
- Town entry (overworld system) resets `injuryDamage` to 0; camp items reduce it — both are simple `Party` mutations outside the Shootout.

### Knockout

A party member at 0 HP when the fight ends (or who died mid-fight and the fight was still won — see Open Questions) is `downed`: they gain a debuff package (data-defined, e.g. `-2 High Tailin'`, `-1 Six Shootin'`) with `shootoutsLeft: 3`. `spawnActor()` applies active debuffs through the same stat-modifier path as Rodeos ([Damage and Stats](Damage%20and%20Stats.md) `getModifiedStat()`), decrementing counters at each `fight_end`.

### Vamoose

When `battleEnded` fires with the enemy winning (all 4 gang members downed):

1. `shootoutEnded` carries the loss to the launcher.
2. The launcher calls `Party.vamoose()`: halves carried loot/money, records the knockout debuffs, and asks the Scene Manager (`Docs/System Design/Scene Manager.md`) to load the last visited town — or the last quest checkpoint if a quest is in progress (quest system tracks the checkpoint).

### Fleeing

- A **Vamoose/Flee button** in the Shootout UI (see [Shootout UI](Shootout%20UI.md)), enabled when `turnManager.getTurnNumber() >= 10` for Showdowns, always for Dust-ups (encounter `kind` metadata, see [Encounters](Encounters.md)).
- Fleeing applies the MxHP cost (a flat portion, e.g. 20% of current injury capacity — placeholder) to each fleeing member, ends the battle as a loss-with-survivors (distinct from Vamoose: party keeps remaining loot and is not thrown to town — they're simply out of the fight), and returns to the launcher.

### Death of generic enemies vs. named characters

Enemy death is permanent for the fight only; named story characters are downed rather than killed (story concern, out of scope here but the `downed` flag is the seam).

## Files to create / modify

**Modify**

- `Globals/Party.gd` — injury/knockout/downed fields, `vamoose()`, debuff accessors, town-entry reset.
- `Shootout/Shootout.gd` — write back party state at `shootoutEnded`; apply effective MxHP and debuffs in `spawnActor()`; flee handling.
- `Shootout/ShootoutActionResolver.gd` — accumulate `injuryDamage` on player actors.
- `Shootout/UI/ShootoutUI.gd` — flee button with enable rules.
- `Shootout/ShootoutTurnManager.gd` — expose `getTurnNumber()` (see [Turns and Initiative](Turns%20and%20Initiative.md)); distinguish rout vs. flee endings in `battleEnded` payload if needed.
- Launcher/Scene Manager code — town/checkpoint handoff on loss.

## Testing

`Tests/TestInjury.gd`:

- Damage in a fight accumulates `injuryDamage`; effective MxHP at the next fight reflects the injury rate and floor of 1.
- Town entry resets injury; camp items reduce it.
- Knockout debuffs apply for exactly N Shootouts and tick down at `fight_end`.
- Flee button enablement: Dust-up turn 1 enabled, Showdown turn 9 disabled / turn 10 enabled.
- `vamoose()` halves loot and routes to town vs. checkpoint correctly.

## Implementation order

1. ✅ Party write-back of surviving HP.
2. ✅ Injury accumulation + effective MxHp.
3. ✅ Knockout debuffs.
4. ✅ Flee button + turn-gating.
5. ✅ Vamoose; Scene Manager handoff (pending with the launcher integration).

## Open Questions

1. If the party wins a fight where a member died mid-fight, is that member knocked out (downed) or back at 1 HP? (Proposed: downed with knockout debuffs.)
	- No knock-outs or debuffs, party members always start at max hp at start of fights
	- MxHP reduction defined elsewhere for attrition during runs
2. Exact injury rate defaults per character and the camp-item restoration amounts — balance data.
3. Exact MxHP portion lost when fleeing (20% proposed placeholder — any placeholder is fine for now, confirmed).
4. ~~Can enemies flee?~~ — **decided**: no, fleeing is player-only.
5. Does Vamoose halve money only, or items/equipment loot too ("half of all loot")?
	- Money and equipment
