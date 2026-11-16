# Positions and Targeting

Positional combat: the 4-rank layout, which positions acts can be used from and target, repositioning, displacement and taunt redirects. Game-design rules live in `Docs/Combat.md` ("Overview > Positions", "Classes", "Effects > Taunt").

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Requirements (from `Docs/Combat.md`)

- Darkest Dungeon style positioning, 4 positions per side, max 4 characters per side.
- Positions are numbered 1-4 from the front (position 1 is closest to the enemy).
- Moving between adjacent positions costs a Move.
- Specific weapons and attacks fire only from specific friendly positions and target only specific enemy positions (per-class table in `Docs/Combat.md`, e.g. Bobtail Guards work from positions 3-4 and cannot target enemy position 1).
- Effects can disrupt positioning; a character stuck where none of their moves work must spend Moves repositioning.
- Taunt: the caster taunts the friendly positions their allies stand on; attacks targeting a taunted position redirect to the caster, including multi-target attacks per protected position.

## Current state

**Implemented** (steps 1-6 of the implementation order; the multi-target target-set pipeline is live, with UI grey-out polish still pending):

- `Globals/Shootout.gd` `shootoutPositions` maps each team's columns 1-4 to screen coordinates; `Shootout.getPositionForColumn()` resolves them.
- The turn manager is the single source of truth for positions: `getActorPosition()`, `placeActor()` (raw set + node move) and the occupancy-aware `setActorPosition()` — one actor per position (decided), the mover takes the spot and the displaced occupants shift one column toward the mover's vacated spot (squeeze repositioning; see Occupancy and displacement). The displaced chain fills exactly the vacated span, so a move inside the row never fails; only no-op targets and out-of-row requests do.
- `ShootoutTargetingManager.isValidTarget()` enforces ranges: moves/abilities use their data's `positions.actorUser` / `positions.targets.columns`; basic attacks use weapon ranges from `Data/Items/WeaponData.gd` (`ranges`, placeholders derived from the class table; weapons without entries fire from anywhere); items stay permissive (any ally position — decided).
- **Reposition act** (`Shootout.ACT_TYPE_REPOSITION`): a Reposition button in `ShootoutUI.tscn` opens a Forward/Backward picker in the acts panel; the Move costs the turn, never advances the Cylinder (decided), and fails without spending the Move only when the requested column clamps to a no-op (the row's front or back edge). `Shootout.repositionActor()` commits the squeeze repositioning and slides every fighter the move touched to their new spot.
- Move acts are filtered to those usable from the acting character's current column; silenced actors lose abilities but keep Ducks (see [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).
- The Rodeo manager reads positions live through the turn manager: position-conditional Rodeos (Happy Shot) track repositioning, adjacency targeting (Camaradería) uses live columns, and `move_position` (Leaders Duck) routes through the occupancy-aware mover.
- Taunt redirect is resolved per affected position inside the shared target-set pipeline (see [Effects](Effects.md)); tests cover single- and multi-target redirects.
- **Multi-target acts:** `ShootoutTargetingManager.expandTargets()` turns `positions.type: "multi"` into an ordered, living target set (authored columns, column/name order); `Shootout.resolveActTargetSet()` drops dead entries, applies per-position taunt redirect and calls the resolver once. `ShootoutActionResolver.resolveActTargets()` charges the Cylinder roll / belt use / effects once per act, then applies the result to every target. The same set drives field highlights, focus (anchor target), animation fan-out and enemy AI scoring.
- Tests: `Tests/TestTargeting.gd` covers squeeze repositioning (one-column swaps, multi-column line shuffles, forward moves in a full row, bounds), move/weapon ranges, item permissiveness, multi-set expansion/dead/side filtering and position-conditional Rodeos. `Tests/TestActs`, `Tests/TestEnemyAI`, `Tests/TestEffects`, `Tests/TestAnimationSequencer` and `Tests/TestMultiTargetFlow.tscn` cover once-per-act costs, per-position taunt, AI set scoring and real-scene resolution.

## Design

### Single source of truth for positions

Today both the turn manager (`shootoutActors[side][name].actorPosition`) and the Rodeo manager track columns. Consolidate: the turn manager owns `actorPosition`; the Rodeo manager and the new repositioning logic read/write it through `turnManager.getActorPosition(name)` / `turnManager.setActorPosition(name, column)` (which also moves the actor node to `getPositionForColumn()`). The Rodeo manager keeps only a cached read for condition checks.

### Range validation

Extend `ShootoutTargetingManager.isValidTarget(act, targetActorName, actingActorName)`:

```gdscript
func isValidTarget(act, targetActorName, actingActorName) -> bool:
	# ... existing side check ...
	var actData = actDataFor(act)                      # moves/items data lookup
	var actingCol = turnManager.getActorPosition(actingActorName)
	var targetCol = turnManager.getActorPosition(targetActorName)
	if actData != null:
		if actData.positions.has("actorUser") and not actingCol in actData.positions.actorUser:
			return false
		if not targetCol in actData.positions.targets.columns:
			return false
	elif act.type == Shootout.ACT_TYPE_ATTACK:
		return weaponRangeCheck(actingActorName, actingCol, targetCol)
	return true
```

- `weaponRangeCheck()` — weapons get `actorUser`/`targets` range data too (on weapon data, falling back to the class table from `Docs/Combat.md` until per-weapon data exists).
- **Usability filtering**: `Shootout._on_shootout_ui_move_acts_requested()` filters the act list to moves usable from the actor's current column (unusable moves shown greyed out with the required positions — see [Shootout UI](Shootout%20UI.md)); silence filtering hooks in here too (see [Effects](Effects.md)).

### Repositioning Move

A new act type on the UI alongside Attack/Moves/Items: **Reposition** (per `Docs/Combat.md`, repositioning does not advance the Cylinder). Implementation:

- `Globals/Shootout.gd`: `ACT_TYPE_REPOSITION = "Reposition"`.
- UI button emits `reposition(direction)` (`"forward"`/`"backward"`); `Shootout` validates that the requested column is inside the row and not the actor's current column (`turnManager.canMoveActor()` — occupancy is no longer a blocker, see below), calls `Shootout.repositionActor()` → `turnManager.setActorPosition()`, and consumes the Move via the normal `finishTurn()` flow.

### Occupancy and displacement

Decided rule: a position holds **at most one** living actor per side — the character moving takes the spot. Squeeze repositioning (`Docs/Features and Issues.md`): the occupant of the target and everyone between the target and the mover's old spot shift **one column toward the vacated spot**, so a one-column move swaps the two fighters (1 → 2 leaves 2, 1, 3) and a multi-column move shuffles the line (4 → 2 leaves 1, 4, 2, 3). The displaced chain fills exactly the vacated span, so `move_position` effects, Leaders Duck and repositioning never fail because of a full row. The old push-past-the-end rule is what made forward moves impossible in an occupied row.

### Taunt redirect

With the effect system (see [Effects](Effects.md)):

- Taunt is stored on the caster with its protected `positions` and `roundsLeft`.
- `ShootoutTargetingManager.isValidTarget()` stays pure validation; redirect happens in the resolution pipeline: `Shootout.resolveActTargetSet()` calls `effectManager.redirectTauntSet(actingSide, targetNames)`, which swaps every protected position to the taunt caster.
- Multi-target acts re-resolve each affected position individually (Open Question 4 below is decided).

### Multi-target target sets — implemented

`ShootoutTargetingManager.expandTargets()` is the single expansion point for player clicks and AI acts:

1. `positions.type: "multi"` expands to every living actor on the authored target side and columns, ordered by column then stable name. `single` (default) returns exactly the clicked/anchor target. Dead actors and empty sets return `[]` before any cost is charged.
2. `ShootoutEffectManager.redirectTauntSet()` re-resolves taunt for each affected position. A caster hit through several protected positions appears once per position and takes each redirected hit (Open Question 4 decided below).
3. `Shootout.resolveActTargetSet()` feeds the same set through damage/healing, effects, death checks, focus and animation. `ShootoutActionResolver.resolveActTargets()` charges the Cylinder roll, belt use and act cost once, then applies the result per target. Enemy AI gathers one entry per multi act with that full `targetNames` set and scores the set it will execute.
4. Field highlights show every legal anchor for the armed move/item; clicking any anchor confirms the complete set.

## Files to create / modify

**Modify**

- `Shootout/ShootoutTargetingManager.gd` — column-range validation, weapon range check, and `expandTargets()` multi-set expansion.
- `Shootout/Shootout.gd` — target-set selection/resolution (`resolveActTargetSet()`), act feedback filtering, animation/focus/death fan-out.
- `Shootout/ShootoutActionResolver.gd` — once-per-act target-set resolution (`resolveActTargets()`) with single-target wrappers preserved.
- `Shootout/ShootoutAnimationSequencer.gd` — one target-effect step fans out over the whole set and completes once.
- `Shootout/ShootoutEffectManager.gd` — `redirectTauntSet()` per-position redirect.
- `Shootout/ShootoutEnemyAI.gd` — gather one multi act with its full `targetNames`, score the resolved set.
- `Shootout/ShootoutRodeoManager.gd` — `move_position` goes through `turnManager.setActorPosition()`; reads positions from the turn manager.
- `Shootout/UI/ShootoutUI.gd` + `ShootoutButton.tscn` — Reposition button with forward/backward choice; greyed-out unusable moves.
- `Globals/Shootout.gd` — `ACT_TYPE_REPOSITION`.

## Testing

`Tests/TestTargeting.gd`:

- A move with `actorUser: [3, 4]` is invalid from column 1 and its target columns are enforced.
- Repositioning moves the actor, costs the Move, respects bounds and occupancy, and does not advance the Cylinder (once [Cylinders](Cylinders.md) lands).
- One-column moves swap the two fighters; multi-column moves shuffle the in-between line toward the vacated spot (examples 1 and 2 in `Docs/Features and Issues.md`).
- Taunt redirects attacks on protected positions to the caster, per position for multi-target acts, and expires.
- A multi act expands to its authored, living target set only; dead/empty sets charge nothing, and once-per-act costs (Cylinder/belt) are verified in `TestActs`/`TestMultiTargetFlow`.
- Enemy AI gathers/scored the same target set, and animation fan-out + real-scene resolution are pinned.
- Position-conditional Rodeos (Happy Shot) update when the actor is repositioned or displaced.

## Implementation order

1. ✅ Position ownership consolidation (`get/setActorPosition`).
2. ✅ Range validation in the targeting manager + act-list filtering.
3. ✅ Reposition act (UI + flow).
4. ✅ Occupancy/displacement rules in `setActorPosition()`; Leaders Duck routes through it.
5. ✅ Taunt redirect (with [Effects](Effects.md)).
6. ✅ Multi-target target-set pipeline (expansion, per-position taunt, once-per-act costs, animation fan-out and AI set scoring).
7. UI polish: greyed-out unusable moves with reasons (pending, see [Shootout UI](Shootout%20UI.md)).

## Open Questions

1. ~~Can two actors share a position?~~ — **decided**: no; the moving character takes the spot, displaced occupants shift toward the vacated spot (see Occupancy and displacement).
2. Can repositioning move more than one column if the actor spends multiple Moves, or is it strictly one column per Move? (Per `Docs/Combat.md`: "moving between adjacent positions costs a Move" — assumed one column per Move.)
3. Do ranged weapon attacks have per-weapon position tables distinct from the class table, or is the class table the only source? (First pass: per-weapon `ranges` in `WeaponData.gd` with placeholder values derived from the class table; weapons without entries are unrestricted.)
4. ~~When a multi-target act partially hits taunted positions, does the caster take all redirected hits (stacking damage) once or per protected position?~~ — **decided**: per protected position. Each taunted position redirects its own resolved hit, so a caster protecting two hit positions takes two hits in the same act. `TestEffects`/`TestMultiTargetFlow` pin this behavior and the pipeline is forbidden from collapsing redirected duplicates.
