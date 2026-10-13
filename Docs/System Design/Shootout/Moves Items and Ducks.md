# Moves, Items and Ducks

The acts a character can take on their Turn: weapon attacks, class/equipment Abilities (Moves), consumable Items, and defensive Ducks — plus belt space and the 4-move limit. Game-design rules live in `Docs/Combat.md` ("Overview > Character moves", "Items", "Classes").

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- Max **4 moves** to choose from in a Shootout per character; if a character has more, they are activated/deactivated outside fights. More belt space generally means fewer activated moves.
- Move types:
  - **Attacks** — attack target(s) with the held weapon.
  - **Abilities** — class abilities (utility-focused) and equipment abilities (damage-focused).
  - **Items** — consumables; amount brought to a Shootout is decided by **belt space**; limited amounts, bought in towns. Healing (instant or over time, single/multi target, usable on allies), Affliction (apply afflictions to enemies), Cleanse (single/multi target, usable on allies).
  - **Ducks** — defensive moves that apply buffs to allied characters.
- Using an item takes a Move; items can target allies in any position (Open Question 13, answered).
- Silence blocks Abilities only (Open Question 14, answered).
- Only weapon attacks advance the Cylinder; Abilities, Items, Ducks and repositioning do not (see [Cylinders](Cylinders.md)).
- Class decides which ability types a character has (per-class ability lists in `Docs/Combat.md` "Classes"); unique named characters can have unique moves.

## Current state

**Implemented** (loadouts, belt space, item consumption, Duck mechanics and silence/position filtering; equipment abilities and the out-of-combat activation UI are outside this doc):

- Character loadouts are data-driven: actor data and `Party.party` carry `moves` (final activated list, max 4) and `items` (belt contents); `ActorBase.applyLoadoutLimits(beltSpace)` enforces the 4-move cap and the class belt space with warn-and-truncate (belt space -1 = uncapped when class data is unknown). Class belt space comes from the class files in `Data/Shootout/Classes` (decided).
- Move data carries `category`: `ability` (utility; blocked by silence), `attack_ability` (fires the weapon; advances the Cylinder — see [Cylinders](Cylinders.md)), `duck` (defensive buffs; effects only, no damage, never advances the Cylinder — decided).
- Ducks live in `Data/Shootout/Moves/` with `category: "duck"` (decided) — first placeholders: Duck Down (self-taunt) and Hold Steady (heal over time).
- Item use consumes exactly one instance from the belt at resolution time (unknown items are not consumed); the acts panel is rebuilt from the remaining list on open.
- Effects can heal: `effect: "heal"` (instant) and `heal_over_time` (ticks at the actor's turn start for `turns`) in the effect manager; both are beneficial (never picked by random cleanses).
- Filtering: `ShootoutTargetingManager.usableMoves()` drops moves unusable from the acting character's current column and (when silenced) everything except Ducks.
- Tests: `Tests/TestActs.gd` covers loadout caps, item consumption, duck semantics, heal-over-time and the usable-move filter.

## Design

### Character loadout

Actor data gains explicit loadout fields, replacing the hardcoded arrays on `ShootoutActor`:

```gdscript
# Data/Actors/Named People/WalkerLangley.gd (and Party data)
"moves": ["Sharp Shot", "Draw"],      # activated abilities, max 4
"items": ["Paregoric", "Paregoric"],  # contents of the belt, max = belt space
"beltSpace": 1,
"characterClass": "Gunslinger",
```

`ShootoutActor.init()` reads them with safe defaults. Class ability lists and belt space come from the class data file in `Data/Shootout/Classes/` (decided — actors reference their class via `characterClass`; see [Cylinders](Cylinders.md)). The Shootout loadout is the class abilities intersected with the actor's activated `moves` (max 4) plus any equipment abilities; belt space is the class/equipment value capping `items`. Out-of-combat move activation/deactivation and belt management are overworld/UI concerns outside this doc; the Shootout just receives the final loadout.

### Move data, unified

Extend the existing move/item Dictionary shape with effect lists (shared with [Effects](Effects.md)) and an explicit `category`:

```gdscript
# Data/Shootout/Moves/MarkedForDeath.gd (example ability)
var data = {
	"name": "Marked for Death",
	"description": "Mark an enemy",
	"category": "ability",            # ability | attack_ability | duck
	"baseAmount": 0,
	"side": "enemy",
	"positions": { "type": "single", "actorUser": [1, 2, 3], "targets": { "columns": [1, 2, 3, 4] } },
	"effects": [
		{ "op": "apply_effect", "effect": "mark", "extraDamage": 4 }
	],
	"animations": [ ... ]
}
```

- `category: "ability"` — utility; blocked by silence.
- `category: "attack_ability"` — equipment-style damage abilities that also fire the weapon. **Decided**: all abilities that are attacks advance the Cylinder exactly like basic attacks; items, Ducks and repositioning never do. Non-attack abilities don't interact with the Cylinder mechanic at all (no hit quality roll, no advance).
- `category: "duck"` — defensive buffs for allies; `side: "player"`.

The resolver dispatches: instant damage/heal as today, then every `effects` entry through `effectManager.applyEffect()`.

### Ducks

Ducks are not a new act type at the code level — they are moves with `category: "duck"` and `side: "player"` whose effects are buffs (stat modifiers, piercing, heals-over-time, taunt). This reuses the acts panel, targeting validation and effect plumbing. Examples from `Docs/Combat.md` class lists: self-increase damage type defense (Bottle Courage Bulldozer), self-taunt position.

Rationale for not adding `ACT_TYPE_DUCKS`: the UI already has a Moves menu; Ducks appear there with a distinct icon/color. If the UI later wants a dedicated Duck button, the category field makes filtering trivial.

### Items and belt space

- Using an item **consumes it**: `resolveItem()` removes one instance from `actor.items` after a successful resolution; the acts panel is rebuilt from the remaining list, so empty belts show no items.
- `side: "player"` items target any ally regardless of position (already supported by targeting; range enforcement for items stays permissive per Open Question 13).
- Over-time healing items apply a `heal_over_time` effect via the effect manager rather than instant healing.

### Silence

`Shootout._on_shootout_ui_move_acts_requested()` filters out `category` in `["ability", "attack_ability"]` when `effectManager.isSilenced(actor)`; attacks, items and Ducks remain available. Enemy AI applies the same filter (see [Enemy AI](Enemy%20AI.md)).

## Files to create / modify

**Create**

- `Data/Shootout/Ducks/*.gd` — Duck definitions (or keep Ducks in `Data/Shootout/Moves` with `category: "duck"`; proposed: same folder, fewer loaders).
- `Tests/TestActs.gd`.

**Modify**

- `Actors/BaseActor.gd` / `ShootoutActor.gd` — loadout fields from actor data instead of hardcoded arrays.
- `Shootout/ShootoutActionResolver.gd` — effect dispatch, item consumption, category handling.
- `Shootout/Shootout.gd` — silence filtering in `moveActsRequested`, act panel rebuild after item use.
- `Globals/Shootout.gd` — category constants if needed; load `Data/Shootout/Classes` into `classesData`.
- Actor data files — `moves`, `items`, `characterClass`; class files in `Data/Shootout/Classes/` carry ability lists and belt space.

## Testing

`Tests/TestActs.gd`:

- Item use consumes exactly one instance; empty item list empties the acts panel.
- Ducks target only allies and apply their buff; they do not advance the Cylinder.
- Silenced actors cannot pick abilities but can attack, use items and Duck.
- Moves with `actorUser` restrictions are filtered (with [Positions and Targeting](Positions%20and%20Targeting.md)).
- The 4-move cap is enforced on loadout validation (warn when data exceeds it).

## Implementation order

1. ✅ Loadout fields on actor data; hardcoded arrays removed.
2. ✅ Item consumption + panel rebuild.
3. ✅ `category` field + effect dispatch in the resolver.
4. ✅ First Ducks (taunt, heal-over-time) on top of [Effects](Effects.md).
5. ✅ Silence + position filtering.
6. Class ability lists + equipment abilities when class/equipment data lands (pending; see [Cylinders](Cylinders.md) for class data).

## Open Questions

1. ~~Do attack_abilities that fire the weapon advance the Cylinder?~~ — **decided**: yes, all attack abilities advance it; non-attack abilities don't use the Cylinder at all.
2. Ducks in the Moves folder vs. a separate `Data/Shootout/Ducks` folder (proposed: same folder).
3. Is the 4-move cap validated at data load (warn) or enforced silently (truncate)? (First pass: warn and truncate.)
4. Can a character bring duplicates of the same item (current hardcoded data suggests yes)?
