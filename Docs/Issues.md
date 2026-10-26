
# Issues

Markdown file for listing issues that popup.

## Open

(none)

## Fixed

- Fixed — Shootout moves have no visual feedback when hovered or selected
    - Arming a move (or item, or opening the reposition picker) changed nothing on screen: the player could not see which act was waiting for its target, which actors were clickable, or which reposition columns were reachable
    - Act icons now carry a persistent armed tint (`ShootoutAct.SELECTED_MODULATE`, a warm gold distinct from the transient hover lighten) for the armed act, cleared when another act is armed or the panel clears
    - While a data move is armed, Shootout.gd tints its valid targets' sprites warm on the field (`isValidTarget` decides; the hover outline stays independent — material vs modulate)
    - While the reposition picker is open, each reachable destination column gets the turn-marker art at the column spot (markers parented as the scene root's first child — above the background, below every fighter, and out of `Actors` whose children several systems iterate as the fighters), blocked directions are greyed out in the picker (`setDirectionsUsable`) instead of silently doing nothing, and both highlights clear when the act resolves, the picker closes or the turn/battle ends
- Fixed — The wagon's shadow does not cover it while moving diagonally
    - The thin feet ellipse sits under one corner of the diagonally drawn wagon (Move Up Side / Move Down Side show it from above at an angle with a 14x16 top-down footprint), leaving the rest of the sprite hanging over bare ground
    - `ActorShadow.gd` gained a `Coverage` mode: `FEET` (the default thin feet ellipse) and `BODY` (an ellipse spanning the whole visible body, centered on it, with the sprite's own pixels drawing over it). `PlayerOverworldActor` switches its shadow to `BODY` for the two diagonal-move animations and back to `FEET` for everything else (`BODY_SHADOW_ANIMATIONS`); stopping keeps the last animation's frame, so the coverage stays correct while parked mid-diagonal
- Fixed — OverworldActor shadows are tiny and out of proportion with other actors
    - The shared ActorShadow sized itself from the raw animation frame width, but assets pad their frames very differently: the overworld rabbit packs a ~10px body into 12x12 frames (shadow = 36% of its body) while 40x40 character frames carry a ~17px body (shadow = 70% of its body), so tightly-cropped actors got disproportionately small shadows — most visibly the overworld rabbit's near-invisible 3.6px ellipse
    - `ActorShadow.gd` now measures the frame's visible (non-transparent) pixel bounds and sizes the shadow from those: every actor's shadow is the same fraction of its actual body. Width ratio is 0.7 of the body width, which keeps the previous look for the padded 40x40 character frames, and the feet lift scales with body height instead of a fixed 4px (a third of the rabbit's height)
    - Pixel bounds are decoded once per texture+frame and cached, and unreadable/blank frames (e.g. test textures) fall back to the raw frame, so behaviour degrades to the old measurement instead of failing
- Fixed — In locations, the transparency shader makes character shadows disappear
    - The shared ActorShadow set `z_index = -1`, but z_index is global to the whole canvas layer: every ground tilemap (z_index 0) drew over the shadows in all locations except Lazysprings (whose `Entities` happens to sit at z_index 1) — most visibly through Clearwater Grove's transparency shader, where the see-through trees revealed the ground but no shadow
    - The shadow now parents under the character's sprite with `show_behind_parent` (`Nodes/Actor Shadow/ActorShadow.gd`), so it draws directly behind its own character and never under ground tiles, buildings or transparent objects; scene-created shadows (LocationActor) re-parent at runtime
    - Also removed the stale `PlayerLocationActor` Area2D handlers that nulled tree sprites' reveal materials while walking near them, fighting the PlayerReveal controller
- Fixed — Shootout animations like Paregoric are on the characters feet, should be above
    - First fixed off the feet (2026-10-24) by anchoring effects on the body center — which still covered the character, so re-fixed to the final anchor: effects now float ABOVE the character, horizontally centered with the effect's bottom on the body's top line (`ShootoutAnimationSequencer.gd` `targetEffectAnchor`)
- Fixed — The "Move" move doesn't have an animation
    - The reposition act (player picker and enemy AI) now slides the fighter to the new column (`Shootout.gd` `playRepositionSlide`), short enough to finish before the between-acts pause hands the turn on; after the squeeze-repositioning fix it also slides everyone the move displaced
- Fixed — Move doesn't work correctly — expected squeeze repositioning behaviour
    - `ShootoutTurnManager.setActorPosition()` now implements squeeze repositioning: the mover takes the target column, and the target's occupant plus everyone between the target and the mover's old spot shift one column toward the vacated spot — a one-column move swaps (1 → 2 leaves 2, 1, 3), a multi-column move shuffles (4 → 2 leaves 1, 4, 2, 3)
    - The old rule pushed the chain in the mover's travel direction and failed when the chain ran past the row's end
    - `move_position` effects (Leaders Duck) route through the same semantics, and the displaced fighters slide too
- Fixed — Move doesn't seem to work when moving forwards
    - Root cause of both Move issues: a forward move into an occupied column built a push chain that always ran past position 1 and failed, so forward moves silently did nothing whenever a friendly fighter stood ahead — squeeze repositioning makes forward moves resolve as swaps and a full row can never block a move
    - `canMoveActor()` stayed compatible for the player picker and the enemy AI repositioning decisions
- Fixed — Initial music when transitioning to a new scene shouldn't fade in
    - `MusicPlayer._crossfadeTo` only fades the new track in when an audible song is playing; starting from silence (scene transitions, first launch, after stop_music) begins at full volume
- Mitigated — Random crashes in Shootouts rarely, might be happening when hovering or targeting a character
    - Cannot be reproduced to confirm (too obscure to force); hardened the likeliest culprits instead
    - Damage numbers no longer use the experimental threaded RichTextLabel (freed mid-text-layout under rapid spawns), and the animation sequencer no longer touches the acting actor's animations node after that actor died mid-act
    - If it still happens, note what the console printed right before the crash and re-add a specific entry
