
# Features and Issues

Markdown file for listing miscellaneous features and issues.

## Features

- Rework Overworld spawns to be dynamic
    - Spawns are not static, but instead based on Zone
    - Different parties can spawn, animals, people etc.
    - Groups of multiple actors can spawn
    - Different spawns have different spawn rates
    - Spawns are only visual, they don't interact with the player
- Journal
    - Houses all information, quests, map, character stats, inventory and equipment, settings
    - Tabs for each category
    - Each category is a separate feature
        - Overworld map
            - Shows the Overworld map with the current player location
            - Shows points of interest, which are Locations
            - Shows current quest targets, which are always key points on the map
            - Explore viability of generating map from chunk data, instead of separately drawing a sprite
            - Sprites
                - Map sprite?
                - Location icons
                - Player icon
                - Current quest icon
        - Quests
            - Show current and completed quests
            - Show progress of current quest, with info on what has happened and what to do next
            - Sprites
                - Quest icon
                - Current quest icon
                - Active and completed quests icon
        - Character stats
            - Show all relevant character stats
            - Sprites
                - Character icon
                - Character model if there is space
                - Icons for stats
        - Inventory and equipment
            - Show inventory and look at and manage characters equipments
            - Drop items
            - Inventory space
                - Similar to Darkest Dungeon, a maximum amount of items can be carried
                - Some items stack, some are unstackable
                - Loot, supplies, and equipment all share the same inventory
                - Goal is to make the player make decisions on what items to carry and what to leave
            - Equipment management
                - Each character must be able to be selected and their equipment managed
                - Character and equipment stats need to displayed
                - Each equipment can only go to a single slot, so likely one-click equipment switch is best
        - Settings
            - Sound and video settings
            - Game settings
            - Save management
            - What other settings are needed?
- Location vendors
    - Vendors and buildings that can be entered need a floating icon
    - General store
        - Buy supplies for the next trip
    - Bank
        - Store equipment from inventory for later use
    - Newspaper office
        - Find info on enemy parties in the current Zone, and tips for Shootouts

## Issues

### Open

(none)

### Fixed

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
