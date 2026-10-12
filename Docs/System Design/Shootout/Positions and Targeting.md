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

- `Globals/Shootout.gd` `shootoutPositions` maps each team's columns 1-4 to screen coordinates; `Shootout.getPositionForColumn()` resolves them.
- `ShootoutTurnManager.registerActor()` stores `actorPosition` per actor; `ShootoutRodeoManager` tracks a parallel column per actor for position-conditional Rodeos (Happy Shot) and implements `move_position` (Leaders Duck) with clamping to 1-4.
- Move/Item data already declares position rules: `positions.actorUser` (usable-from columns), `positions.targets.columns` (targetable columns), `positions.type` (`single`/`multi`) and `positions.shape` (e.g. `column` for Multi Heal).
- **None of it is enforced**: `ShootoutTargetingManager.isValidTarget()` only checks the act's side. There is no repositioning Move, no displacement outside Leaders Duck, no taunt redirect, and duplicate actors spawn on top of each other when an encounter lists the same position twice (encounter data gives each actor a list of positions, one per copy — see [Encounters](Encounters.md)).

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
- UI button emits `reposition(direction)` (`"forward"`/`"backward"`); `Shootout` validates `1 <= column + delta <= 4` and that the destination is unoccupied (see below), calls `turnManager.setActorPosition()`, and consumes the Move via the normal `finishTurn()` flow.

### Occupancy and displacement

`Docs/Combat.md` doesn't say whether two actors can share a position (see Open Questions). Proposed rule: a position holds at most one living actor per side; displacement (`move_position` effects, Leaders Duck) pushes through occupied spots by shifting the occupant one step in the same direction (recursively, clamped at the ends — if the end is blocked, the move fails). This keeps `move_position` deterministic and matches Darkest Dungeon shuffle semantics.

### Taunt redirect

With the effect system (see [Effects](Effects.md)):

- Taunt is stored on the caster with its protected `positions` and `roundsLeft`.
- `ShootoutTargetingManager.isValidTarget()` stays pure validation; redirect happens at resolution: `Shootout.selectActor()` / enemy AI target choice call `effectManager.redirectTaunt(actingSide, targetName)`, which swaps the target to the taunt caster when the chosen target stands in a taunted position.
- Multi-target acts re-resolve each affected position individually, per Open Question 11 in `Docs/Combat.md`.

## Files to create / modify

**Modify**

- `Shootout/ShootoutTurnManager.gd` — `getActorPosition()` / `setActorPosition()` (moves the node; keeps the registry authoritative).
- `Shootout/ShootoutTargetingManager.gd` — column-range validation, weapon range check.
- `Shootout/Shootout.gd` — reposition act handling, act-list usability filtering, taunt redirect call in `selectActor()`.
- `Shootout/ShootoutRodeoManager.gd` — `move_position` goes through `turnManager.setActorPosition()`; reads positions from the turn manager.
- `Shootout/UI/ShootoutUI.gd` + `ShootoutButton.tscn` — Reposition button with forward/backward choice; greyed-out unusable moves.
- `Globals/Shootout.gd` — `ACT_TYPE_REPOSITION`.

## Testing

`Tests/TestTargeting.gd`:

- A move with `actorUser: [3, 4]` is invalid from column 1 and its target columns are enforced.
- Repositioning moves the actor, costs the Move, respects bounds and occupancy, and does not advance the Cylinder (once [Cylinders](Cylinders.md) lands).
- Displacement pushes chains of occupants correctly and fails gracefully at a blocked end.
- Taunt redirects attacks on protected positions to the caster, per position for multi-target acts, and expires.
- Position-conditional Rodeos (Happy Shot) update when the actor is repositioned or displaced.

## Implementation order

1. Position ownership consolidation (`get/setActorPosition`).
2. Range validation in the targeting manager + act-list filtering.
3. Reposition act (UI + flow).
4. Occupancy/displacement rules in `setActorPosition()`; route Leaders Duck through it.
5. Taunt redirect (after [Effects](Effects.md)).

## Open Questions

1. Can two actors share a position? (Proposed: no, with push-through displacement.)
2. Can repositioning move more than one column if the actor spends multiple Moves, or is it strictly one column per Move? (Per `Docs/Combat.md`: "moving between adjacent positions costs a Move" — assumed one column per Move.)
3. Do ranged weapon attacks have per-weapon position tables distinct from the class table, or is the class table the only source?
4. When a multi-target act partially hits taunted positions, does the caster take all redirected hits (stacking damage) once or per protected position?
