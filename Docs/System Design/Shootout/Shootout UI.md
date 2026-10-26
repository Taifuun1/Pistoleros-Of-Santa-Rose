# Shootout UI

The Shootout interface: act icons, stat panels, Cylinder display, effect icons, damage numbers, animations and fight-level flow (start popup, flee, end screen). Game-design rules live in `Docs/Combat.md` (Open Question 5: both own and enemy Cylinders are visible).

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Current state

`Shootout/UI/ShootoutUI.tscn` + `ShootoutUI.gd` provide:

- Act icon groups in the player panel's Acts row (moves after the Moves icon, belt items after the Belt icon) populated via `setPlayerCharacterActs()`; `ShootoutAct.tscn` is the icon entry, the Move/Flee utility icons render last in the row.
- Player character panel (name, Rodeo, HP, Six Shootin'/High Tailin'/Taffyin', revolver/rifle/shotgun damage) and a hovered-actor panel with the same stats.
- Hover outline on actors (`Shaders/Outline.tres`), click-to-select targets, turn highlight (`Highlight2` shown by `actorTurn` for the current actor only — `Shootout.startCurrentTurn()` hides every other actor's marker; the old toggle left stale markers and hid the highlight on an actor's second turn). The actor `Area2D` input/collision rectangle is sized from the animation sprite at spawn (was a 16×12 feet-only rectangle that made hover and click-targeting miss the character's body), centered on the sprite's drawn rect (AnimatedSprite2D `offset` puts the drawn body above the actor origin — a shape centered at the origin missed the head), with the width capped at the column spacing so side-by-side actors' boxes never overlap (columns sit 30px apart while sprites are 40px wide — overlapping boxes made hover and click register on both actors at once). Because adjacent boxes touch, the hovered-actor panel uses a stale-exit guard (`Shootout.hoveredActorName`): Godot emits the previous actor's `mouse_exited` after the new actor's `mouse_entered` when the mouse crosses between touching boxes in one physics frame (known `Viewport._process_picking` behavior), which wiped the freshly hovered actor's panel.
- Damage numbers via `Shootout.spawnDamageNumber()` (`Nodes/Damage Number/DamageNumber.tscn`); Rodeo popups reuse it in yellow. The popup is a `Node2D` hosting the shared `UI/RichTextLabel Extended/RichTextLabelExtended.tscn` label, so damage numbers use the same font and theme as the rest of the UI; colors come from that node's palette (`green`, `red`, `yellow`, `orange`, `white`, …) and the popup floats up and frees itself. The shared label carries a `+2/+5` transform offset (`offset_transform_position`) meant to inset text inside panels — `DamageNumber.pinLabelToAnchor()` drops that offset (in code, not just the scene) so the popup lands exactly on the spawn point; a world-space popup reusing a panel widget without clearing it drifts right. The spawn offsets (`DAMAGE_NUMBER_OFFSET = (-4, -48)`, `RODEO_POPUP_OFFSET = (-4, -60)`) put the text fully above the 40px-tall actor sprite (feet at the actor origin, body top ≈ 35px up) — lower values dropped the text onto the sprite's torso, which stood out once a Rodeo spawned several popups at once. The turn-end Rodeo procs on a short beat (`RODEO_PROC_PAUSE`) after `endAct()` restores the formation, and any fighter the Rodeo moved walks to its new column (`playRepositionSlide`) instead of snapping — proccing mid-animation parked the popup at a focus anchor next to the wrong fighter and overlapped the slides.
- World-space HP bars: `Nodes/HP Indicator/HPIndicator.tscn` spawned per actor in `Shootout.spawnActor()` — a pixel frame with a left-anchored fill rendered *below* each actor (damage numbers spawn above and float up, so the two never collide). The bar polls the actor's `hp`/`maxHp` in `_process` (actors expose no HP signals and many call sites write HP, so polling makes a missed refresh impossible) and redraws only on change: the fill is clipped via `region_rect` (pixel-crisp at any fraction, depletes from the right) and tints at ≤ 1/3 HP. Placeholder frame/fill art at `Assets/UI/HPBarFrame.png` / `Assets/UI/HPBarFill.png` — swap the two PNGs when final art lands.
- Animations: the animation sequencer plays per-act `animations` steps from move/item data (target effect scenes + acting-actor animations), emitting `frameHit` so damage lands on the impact frame. Target effect scenes float above the target's drawn body (`targetEffectAnchor` — the actor origin is the character's feet and the body's center covers the character), and the Reposition Move slides every fighter the squeeze repositioning touched to their new column (`Shootout.gd playRepositionSlide`).

**Implemented** (display building blocks, act tooltips/grey-out, banners; world-space effect icons, multi-target selection and final art are pending):

- **Cylinder display**: the stats panels' pre-existing `MagazineContainer/Magazine` rows render the Cylinder from the Cylinder/ChamberIndex payload fields — one Chamber icon per slot (Miss/Graze/Hit/Critical Hit icons from `Assets/Stats`), the current Chamber marked with the `CylinderLine` underline, unused slots hidden; Reload/Jammed specials have no icons yet (tooltip only).
- **Effect summary**: effectManager.displayEffects() renders one icon per effect type (bleed/poison/mark/damage-type mark/silence/taunt icons from `Assets/Effects`, placeholder fallback for types without art) into the Effects box of both stat panels, with stack counts (`x2`) next to the icon and the full summary line as tooltip. The box keeps a fixed minimum size (`EFFECTS_BOX_MIN_SIZE`): letting its minimum shrink to the empty `-` label and grow back per entry trips the Godot layout oscillation crash described under the turn order strip. World-space icon rows above actors remain pending art.
- **Turn order strip**: Shootout/UI/TurnOrderStrip.gd shows the full Round order as portrait icons (character icon from `Assets/Icons` derived from the actor name, placeholder fallback, actor name as tooltip) with the current actor highlighted via modulate; rebuilt every turn from turnManager.turnOrder. The row is never used for anything else — act icons live in the Acts row (decided: no act menu). The strip keeps a fixed `custom_minimum_size` (widest possible row, 8 portraits): shrinking/growing container minimums while the stat panels churn (hover updates) trips a Godot layout oscillation that overflows the deferred-call message queue and hard-crashes the engine ("Object was deleted while awaiting a callback" spam + segfault, known engine bug); the Effects box fix below is the same pattern.
- **World-space HP bars**: `Nodes/HP Indicator/HPIndicator.tscn` — one small pixel bar below every actor (see Current state above for the refresh/clipping rules). Covered by `Tests/TestHPIndicator.gd`.
- **Acts row**: the player panel's Acts row shows the acting character's available acts as `ShootoutAct` icons — moves (incl. Ducks) in the `Moves` group after the Moves icon, belt items in the `Items` group after the Belt icon — populated from Shootout.gd when the player's turn starts, and cleared when the turn ends (`hideActsPanel()`). There is no act menu (decided): every act is directly clickable. There are no basic attacks (decided): the player attacks through their moves. Entries carry tooltips (description, usable-from positions, usability reason) and unusable moves are greyed out with the reason instead of vanishing (ShootoutTargetingManager.moveUsability). Hover feedback brightens the icon via modulate (greyed-out entries stay greyed) — deliberately not the `Highlight2` turn-marker art, which read like the actor turn highlight appearing on the abilities. The Move icon (toggles the Forward/Backward reposition picker into the Moves group) and the Flee icon render last in the row as utility icons; Flee grey-out rules per [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md). Arming an act (clicking a move or item icon, or opening the reposition picker) tints its icon a persistent warm gold (`ShootoutAct.SELECTED_MODULATE`, distinct from the transient hover lighten) until another act is armed or the panel clears.
- **Armed-act field feedback**: Shootout.gd shows what an armed act will affect while the player picks. A armed data move tints its valid targets' animation sprites warm (`TARGET_TINT` via `isValidTarget` — the hover outline stays independent: material vs modulate). The reposition picker marks each reachable destination column with the turn-marker art at the column spot (`Shootout.gd _showRepositionMarkers`, markers parented as the first child of the scene root — tree order puts them above the background but under every fighter, and they stay out of `Actors`, which several systems iterate as the fighters themselves — no z_index, which is global to the canvas layer), greys out blocked directions in the picker (`setDirectionsUsable`), and both highlights clear when the act resolves, the picker closes or the turn/battle ends.
- **Fight flow**: showBanner() displays the flavor-name start popup (auto-fade); showEndScreen() shows the outcome and loot summary from the shootoutEnded results payload. Hit quality feedback uses per-quality damage-number colors and the Miss label.
- Tests: Tests/TestShootoutUI.gd covers the Magazine cylinder icons, the turn strip, the usability reasons and the scene wiring (Turn Order row, Acts row icon groups incl. the armed-act selection and reposition picker states, Effects boxes).

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

### Acts row icons

The Acts row of the player panel shows everything the acting character can do this turn — there is no act menu:

- Moves (incl. Ducks) render as `ShootoutAct` icons in the `Moves` group, right after the Moves icon; belt items render in the `Items` group, right after the Belt icon. Shootout.gd populates both when the player's turn starts and clears them when the turn ends.
- Entries take clicks directly as Control input (`gui_input`): the act row sits on panel Controls that consume the mouse, so physics picking (`Area2D`) would never receive the click.
- Entries show description, range (`actorUser`/target columns) and effect summary from the data Dictionary as a tooltip, and load their icon from `Assets/{actType}/{actName}.png`.
- Unusable moves (wrong column, silenced) show greyed out with the reason rather than disappearing (see [Positions and Targeting](Positions%20and%20Targeting.md), [Effects](Effects.md)).
- Ducks live in the Moves group with a distinct color/icon (see [Moves Items and Ducks](Moves%20Items%20and%20Ducks.md)).
- The Reposition direction picker (Forward/Backward) renders into the Moves group, toggled by the Move icon; there are no basic attacks (decided), and Flee is a utility icon (enable rules per [Death Injury and Retreat](Death%20Injury%20and%20Retreat.md)).

### Multi-target and ally targeting

`positions.type: "multi"` acts (e.g. Multi Heal) currently resolve on one selected actor. UI flow: selecting a multi-target act highlights all affected columns; one click confirms. Ally-targeting acts (items, Ducks) switch hover/click to friendly actors — the targeting manager already validates sides, so this is a UI state (`selectedAct.side`).

### Fight flow screens

- **Start popup**: flavor name from encounter metadata ("Hold-up!", "High Noon!", see [Encounters](Encounters.md)) over the fight background.
- **End screen**: victory — loot summary ([Rewards](Rewards.md)); defeat — Vamoose message; both transition back through the launcher.
- **Hit quality feedback**: Miss/Graze/Hit/Crit damage-number colors and labels so Cylinder outcomes read clearly.

## Files to create / modify

**Create**

- Effect icon row scene.
- Start popup and end screen scenes.

**Modify**

- `Shootout/UI/ShootoutUI.tscn` / `ShootoutUI.gd` — all of the above panels and buttons.
- `Shootout/Shootout.gd` — payload extensions (cylinder state, effects, act metadata) in `actorStatsPayload()` and act requests.
- `Nodes/Damage Number/` — quality colors/labels if not already parameterized (color and label already are parameters — just new call sites). The popup renders through the shared `RichTextLabelExtended` node, so new colors are added to that node's palette.

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
