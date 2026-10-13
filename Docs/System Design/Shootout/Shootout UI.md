# Shootout UI

The Shootout interface: act menus, stat panels, Cylinder display, effect icons, damage numbers, animations and fight-level flow (start popup, flee, end screen). Game-design rules live in `Docs/Combat.md` (Open Question 5: both own and enemy Cylinders are visible).

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Current state

`Shootout/UI/ShootoutUI.tscn` + `ShootoutUI.gd` provide:

- Three act buttons (Attack/Shootout button, Move, Item) with a toggleable acts panel populated via `setPlayerCharacterActs()`; `ShootoutAct.tscn`/`ShootoutButton.tscn` are the list entries.
- Player character panel (name, Rodeo, HP, Six Shootin'/High Tailin'/Taffyin', revolver/rifle/shotgun damage) and a hovered-actor panel with the same stats.
- Hover outline on actors (`Shaders/Outline.tres`), click-to-select targets, turn highlight (`Highlight2` toggled by `actorTurn`).
- Damage numbers via `Shootout.spawnDamageNumber()` (`Nodes/Damage Number/DamageNumber.tscn`); Rodeo popups reuse it in yellow.
- Animations: the animation sequencer plays per-act `animations` steps from move/item data (target effect scenes + acting-actor animations), emitting `frameHit` so damage lands on the impact frame.

**Implemented** (display building blocks, act tooltips/grey-out, banners; world-space effect icons, multi-target selection and final art are pending):

- **Cylinder display**: Shootout/UI/CylinderRow.gd renders Chamber pips (letters + colors per quality, Reload/Jammed specials, current Chamber marked); shown in both the player and hovered-actor stat panels from the Cylinder/ChamberIndex payload fields. Letters are placeholders until pip art exists.
- **Effect summary**: effectManager.displayEffects() feeds an Effects line in both stat panels (stack counts per effect type). World-space icon rows above actors remain pending art.
- **Turn order strip**: Shootout/UI/TurnOrderStrip.gd shows the full Round order with the current actor highlighted (decided), rebuilt every turn from turnManager.turnOrder.
- **Acts panel**: entries carry tooltips (description, usable-from positions, usability reason) and unusable moves are greyed out with the reason instead of vanishing (ShootoutTargetingManager.moveUsability); Ducks stay in the Moves list (decided). Reposition (Forward/Backward picker) and Flee buttons exist (see the Positions and Death docs).
- **Fight flow**: showBanner() displays the flavor-name start popup (auto-fade); showEndScreen() shows the outcome and loot summary from the shootoutEnded results payload. Hit quality feedback uses per-quality damage-number colors and the Miss label.
- Tests: Tests/TestShootoutUI.gd covers the pip row, the turn strip and the usability reasons.

Gaps: world-space effect icons, multi-target highlight/confirm flow, and final art/layout pass.

## Design

### Cylinder display

Per `Docs/Combat.md`, the player sees all Cylinders. Once [Cylinders](Cylinders.md) lands:

- The player character panel shows the acting character's Cylinder as a row of Chamber pips (Miss/Graze/Hit/Crit icons, Reload/Jammed icons for special Chambers), with the current Chamber highlighted.
- The hovered-actor panel shows the hovered actor's Cylinder the same way.
- Data comes from `cylinderManager.currentChamber()`/cylinder state; panels refresh on turn start and after every attack.

### Effect icons

Once [Effects](Effects.md) lands: small icon rows above each actor (bleed drop, poison flask, mark crosshair, silence, taunt shield) with stack/turn counts; the same list appears in the hovered-actor panel. `effectManager` exposes a display list per actor.

### Turn order display

Decided: a strip showing the **full Round order**, with the current actor highlighted (e.g. a frame/color on their portrait), portraits dropping off as turns are consumed. Data comes from `turnManager.turnOrder` (rebuilt each Round, see [Turns and Initiative](Turns%20and%20Initiative.md)).

### Acts panel improvements

- Entries show description, range (`actorUser`/target columns) and effect summary from the data Dictionary, as a tooltip or a details line.
- Unusable moves (wrong column, silenced) show greyed out with the reason rather than disappearing (see [Positions and Targeting](Positions%20and%20Targeting.md), [Effects](Effects.md)).
- New buttons: **Reposition** (forward/backward picker, see Positions doc) and **Flee** (enable rules per [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).
- Ducks live in the Moves list with a distinct color/icon (see [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).

### Multi-target and ally targeting

`positions.type: "multi"` acts (e.g. Multi Heal) currently resolve on one selected actor. UI flow: selecting a multi-target act highlights all affected columns; one click confirms. Ally-targeting acts (items, Ducks) switch hover/click to friendly actors — the targeting manager already validates sides, so this is a UI state (`selectedAct.side`).

### Fight flow screens

- **Start popup**: flavor name from encounter metadata ("Hold-up!", "High Noon!", see [Encounters](Encounters.md)) over the fight background.
- **End screen**: victory — loot summary ([Rewards](Rewards.md)); defeat — Vamoose message; both transition back through the launcher.
- **Hit quality feedback**: Miss/Graze/Hit/Crit damage-number colors and labels so Cylinder outcomes read clearly.

## Files to create / modify

**Create**

- Cylinder pip row scene (e.g. `Shootout/UI/CylinderRow.tscn`) + effect icon row scene.
- Start popup and end screen scenes.

**Modify**

- `Shootout/UI/ShootoutUI.tscn` / `ShootoutUI.gd` — all of the above panels and buttons.
- `Shootout/Shootout.gd` — payload extensions (cylinder state, effects, act metadata) in `actorStatsPayload()` and act requests.
- `Nodes/Damage Number/` — quality colors/labels if not already parameterized (color and label already are parameters — just new call sites).

## Testing

UI is mostly verified by hand; headless-checkable parts:

- `Tests/TestShootoutUI.gd` — act list filtering (silence/position grey-outs), panel payload contents incl. Cylinder state, multi-target confirm flow state machine.
- Smoke: run `Shootout/Shootout.tscn` and verify Cylinder pips advance on attacks and Reload/Jammed display correctly.

## Implementation order

1. Act panel tooltips + grey-out states (works with today's data).
2. Reposition and Flee buttons (with their systems).
3. Cylinder display (with [Cylinders](Cylinders.md)).
4. Effect icons (with [Effects](Effects.md)).
5. Turn order strip, start popup, end screen.

## Open Questions

1. ~~Full Round order strip or current actor only?~~ — **decided**: full Round order strip with the current actor highlighted.
2. Cylinder pips: icons per quality or numbers 0-3? (Icons proposed; needs art.)
3. Where do fight backgrounds come from per encounter — encounter metadata (proposed, see Encounters) or the launching Location?
4. Should the acts panel show damage estimates (min-max after defense/quality)? Helpful but reveals math; needs a design call.
