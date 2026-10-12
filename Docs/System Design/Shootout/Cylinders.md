# Cylinders

The Cylinder system: every character's attack quality is decided by a sequence of Chambers built from their Magazines. Game-design rules live in `Docs/Combat.md` ("Overview > Cylinders", Open Questions 5, 6, 9).

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- A **Cylinder** is a sequence of **Chambers**; a Chamber value (0-3) decides attack quality: 0 Miss, 1 Graze, 2 Hit, 3 Critical Hit.
- Each character, class and weapon has a **Magazine** — a partial cylinder pattern with Chamber values from -3 to 3. All Magazines are summed chamber-by-chamber into the final Cylinder, clamped to 0-3 (clamping, not wrapping — Open Question 6, answered).
- Cylinders are 2-6 Chambers long.
- Characters start combat at the beginning of their Cylinder. **Only weapon attacks advance the Cylinder** — Abilities, Items, Ducks and repositioning do not. When the Cylinder ends it wraps to the beginning.
- Special Chambers: **Reload** (the character spends their Move reloading and cannot attack) and **Jammed** (the attack instead applies a buff or debuff). Special Chambers cannot usually be modified except by special items, modifiers or Rodeos.
- The player can see both their own and enemies' Cylinders (Open Question 5, answered — UI covered in [Shootout UI](Shootout%20UI.md)).
- Cylinder effects can increase/decrease specific Chambers or the whole Cylinder, lasting until replaced or the fight ends (see [Effects](Effects.md)).
- Rodeos can warp Cylinders (e.g. Natural Gunslinger: cannot Miss or Graze — the reserved `set_hit_quality_floor` op).

## Current state

Nothing is implemented. `ShootoutActionResolver.resolveAttack()` uses flat weapon/stat damage with no hit quality. Actor data (`Actors/BaseActor.gd`) has no magazine fields. The Rodeo `Natural Gunslinger` exists in `Data/Shootout/Rodeos` but its `set_hit_quality_floor` op is a reserved no-op in `ShootoutRodeoManager`.

## Design

### Data

Magazines live on the data sources that already define a character:

```gdscript
# Data/Actors/Animals/SquekyRat.gd — character Magazine
"magazine": [1, 0, 2],

# Data/Actors/** class data (new, see below) — class Magazine
"magazine": [0, 1, -1],

# weapon data (Data/Items or wherever weapons are defined) — weapon Magazine
"magazine": [2, -1, 0],
```

A Magazine is an Array of ints in -3..3, length 2-6. Special Chambers use string entries: `"reload"`, `"jammed"`. Special Chambers are never summed or clamped — a special Chamber in any Magazine overrides that slot in the final Cylinder (if multiple Magazines put special Chambers in the same slot, priority is weapon > class > character; see Open Questions).

Class Magazines live in a dedicated `Data/Shootout/Classes/*.gd` folder (decided) — same `data` Dictionary convention as Moves/Items/Rodeos, loaded by the `Shootout` autoload into `Shootout.classesData`. Each class file holds the class name, class Magazine, class ability list, belt space and class-based stat bases (Sand defense, Explosive damage — see [Damage and Stats](Damage%20and%20Stats.md)). Actor data files reference the class by name via `"characterClass": "Gunslinger"`; unique named characters can carry their own overrides on top of the class data (see [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).

### Runtime state

New manager `Shootout/ShootoutCylinderManager.gd` (`RefCounted`, `init(shootoutRoot)` like the others):

```gdscript
# actorName -> { cylinder: Array, chamberIndex: int, characterMagazine: Array,
#                classMagazine: Array, weaponMagazine: Array, modifier: Dictionary }
var cylinders = {}
```

- `registerActor(actor)` — builds the final Cylinder: sum the three Magazines per slot, clamp to 0-3, apply special-Chamber overrides, then apply any cylinder effect modifier. Stores the source Magazines so effects can re-derive the Cylinder.
- `currentChamber(actorName)` — returns the Chamber the actor's next weapon attack uses.
- `advance(actorName)` — called by the action resolver **only after a weapon attack resolves**; wraps at the end.
- `hitQuality(actorName)` — returns the clamped value for the current Chamber, or a special-Chamber id. Routes through the Rodeo manager's `set_hit_quality_floor` so Natural Gunslinger clamps Miss/Graze up to Hit.
- `applyCylinderModifier(actorName, modifier)` / `clearCylinderModifier(actorName)` — implements the Cylinder effect type: `{ "chambers": "all" | [indices], "amount": int }`; re-sums and re-clamps. A new modifier replaces the previous one (per the stacking table in `Docs/Combat.md`).
- `unregisterActor(actorName)` — called from `ShootoutTurnManager.checkActorDead()`.

### Attack flow integration

In `ShootoutActionResolver.resolveAttack()`:

1. `quality = cylinderManager.hitQuality(actor)`.
2. `reload` — spend the Move without attacking (play a reload animation, show a "Reload" damage-number label), still advance the Cylinder.
3. `jammed` — attack fails; apply the Jammed buff/debuff defined on the weapon or class data, advance the Cylinder.
4. Numeric quality — multiply damage: Miss 0%, Graze 50%, Hit 100%, Critical Hit 150% (placeholder percentages from `Docs/Combat.md`), then continue the pipeline in [Damage and Stats](Damage%20and%20Stats.md). A Miss still advances the Cylinder.

### Cylinder effects and Rodeos

- Effects modify Chambers through `applyCylinderModifier`; the manager re-derives the Cylinder from stored Magazines so modifiers never compound on already-modified values.
- Rodeo integration: extend `ShootoutRodeoManager.getStatModifier()` with a `getHitQualityFloor(actor)` query implementing the reserved `set_hit_quality_floor` op; the cylinder manager consults it in `hitQuality()`.

## Files to create / modify

**Create**

- `Shootout/ShootoutCylinderManager.gd` — the manager.
- `Data/Shootout/Classes/*.gd` — class data incl. class Magazines (shared with [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).
- `Tests/TestCylinders.gd`.

**Modify**

- `Globals/Shootout.gd` — load `Data/Shootout/Classes`; add Chamber quality constants (`CHAMBER_MISS` etc.) and the damage multiplier table.
- `Shootout/Shootout.gd` — instantiate the manager; `registerActor` in `spawnActor()`.
- `Shootout/ShootoutActionResolver.gd` — hit quality lookup, special Chambers, multiplier, `advance()`.
- `Shootout/ShootoutTurnManager.gd` — `unregisterActor` on death.
- Actor/weapon data — add `magazine` fields.
- `Shootout/ShootoutRodeoManager.gd` — implement `set_hit_quality_floor`.

## Testing

`Tests/TestCylinders.gd`:

- Magazine summing and 0-3 clamping, incl. negative Magazine values.
- Wrap-around after the last Chamber; non-attack acts do not advance.
- Special Chambers: Reload spends the Move, Jammed applies its effect, neither is changed by cylinder modifiers.
- Cylinder modifiers re-derive correctly and replace (not stack with) previous ones.
- `set_hit_quality_floor` raises 0/1 Chambers to 2.
- Smoke: a full Shootout where a known Cylinder produces the expected quality sequence.

## Implementation order

1. Manager + summing/clamping + actor registration (no gameplay effect yet).
2. `resolveAttack` integration: quality multiplier + advance.
3. Special Chambers (Reload, Jammed).
4. Cylinder modifiers + Rodeo floor op.
5. Class data files and Magazine authoring.
6. UI display (see [Shootout UI](Shootout%20UI.md)).

## Open Questions

1. ~~Where does class data live~~ — **decided**: new `Data/Shootout/Classes/*.gd` folder; actor data references the class by name via `characterClass`.
2. Special Chamber conflict priority when several Magazines put special Chambers in the same slot (weapon > class > character proposed).
3. Exact Jammed outcome per weapon/class: is the buff/debuff defined on the weapon, the class, or globally?
4. Do cylinder effects with `"chambers": [indices]` use absolute indices or indices relative to the current Chamber?
