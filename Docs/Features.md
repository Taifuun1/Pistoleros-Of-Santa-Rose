
# Features

Markdown file for listing first-iteration features.

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
