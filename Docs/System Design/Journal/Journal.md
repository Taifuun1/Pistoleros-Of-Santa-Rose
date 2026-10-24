# Journal system

The Journal is the game's central information and management interface: Overworld map, quests, character stats, inventory/equipment, and settings in one tabbed shell.

This is a high-level design overview. Each tab is a separate feature with its own implementation and detailed design. **Status: proposed; no Journal implementation exists yet.**

## Goals

- Give the player one consistent place to find journey information and manage the party.
- Keep tab content independent: a tab can be implemented, tested, or disabled without rewriting the others.
- Present live authoritative game state rather than maintaining Journal-specific copies of quests, items, stats, or player position.
- Use the existing pixel-art UI language and `Assets/UI/UI.tres`, at the project's 640×360 reference viewport.
- Support mouse and keyboard/controller navigation from the start rather than making each tab mouse-only.

## Current state and dependencies

- There is no Journal scene, input action, tab framework, or Overworld map.
- `Globals/Party.gd` already owns party members, persistent HP/injuries, money, and a basic `inventory` Array. Equipment management, stack limits, dropping, and inventory commands still need their own design.
- `Globals/Quests.gd` currently contains only main-quest level/rarity. `Globals/Locations.gd::currentQuest` is a string used for scene selection, not a quest journal or map-target model.
- Settings and save management do not yet have an authoritative settings/save service.
- Existing popup scenes establish reusable UI conventions (`PanelContainer`, `ScrollContainer`, shared theme, close button), while `SceneManager` provides a persistent root above changing gameplay scenes.
- `Docs/Map Outline.aseprite` is a visual reference, not a runtime map or authoritative source of world geometry.

The Journal shell must not wait for every underlying feature. Tabs can show an intentional empty/unavailable state while their systems are built, but placeholder data must not be presented as live state.

## User experience

- Toggle the Journal with a dedicated `TOGGLE_JOURNAL` action (suggested default: `J`). `ui_cancel` closes it or backs out of a tab's current secondary panel first.
- The Journal opens as a modal overlay without replacing the current gameplay scene or triggering Scene Manager loading/fades.
- The first version pauses single-player gameplay while open. Opening/closing must be idempotent and must not unpause a game that was already paused for another reason.
- Do not open during Scene Manager transitions. Initially allow it in the Overworld and normal Locations; Cutscene, Shootout, minigame, and main-menu availability should be an explicit per-scene policy, not an accidental side effect.
- Remember the selected tab for the current application session. On open, refresh its content; on tab change, refresh only the newly visible tab.
- Close restores input/focus to the underlying scene. Journal controls consume their input so the same key/click cannot also move, interact, or select a combat target.
- Destructive actions such as dropping items, overwriting saves, or resetting settings require confirmation. Unsaved settings behavior belongs to the Settings design, not an ad hoc close handler in the shell.

## Scene and code architecture

`SceneManager` should own a persistent `JournalLayer` (`CanvasLayer`) below its transition layer. The Journal scene is instantiated once and hidden, so scene switches do not destroy its tab state.

```text
SceneManager (input/toggle policy)
├── CurrentScene                         # pausable gameplay
├── JournalLayer (CanvasLayer)
│   └── Journal (Control, process always while open)
│       ├── Dim/InputBlocker
│       └── PanelContainer
│           └── VBoxContainer
│               ├── Header / CloseButton
│               ├── TabBar
│               └── TabContentHost
└── TransitionLayer                      # remains above Journal
```

Use a `TabBar` plus one content host rather than relying on `TabContainer`'s built-in child visibility if tabs need lazy instantiation. `Journal.gd` owns tab registration, selection, modal input, and lifecycle. Each tab is a separate `Control` scene with a small contract:

```gdscript
func refreshTab() -> void       # Re-read authoritative state; no arguments tied to Journal internals.
func setTabActive(active: bool) # Start/stop listeners, markers, or animations.
func canCloseTab() -> bool      # Optional guard for a modal sub-flow; normally true.
```

Instantiate a tab on first selection and cache it thereafter. Only the active tab subscribes to live update signals or performs periodic work. Tabs must not find each other through node paths; cross-feature actions go through typed/data-level APIs or Journal-level navigation requests.

Pause ownership needs a small shared modal/pause coordinator rather than every popup independently toggling `get_tree().paused`. If `SceneManager` handles Journal input while paused, its processing mode must remain active while `CurrentScene` is explicitly pausable; do not accidentally make all gameplay children process always through inheritance.

## Tabs

| Tab | Responsibility | Dependencies / detailed design |
| --- | --- | --- |
| **Map** | Generated Overworld map, player marker, Location POIs, current quest key-point markers; pan/zoom and marker inspection | [Overworld Map](Overworld%20Map.md); Overworld position provider; quest map-marker API |
| **Quests** | Active/current and completed quests, progress history, what happened, and the next objective | Real quest definitions/state and progress events; current quest targets shared with Map |
| **Character** | Select a party member and inspect base/effective stats, HP/injuries, class, Rodeo, and relevant modifiers | `Party`; shared stat/equipment calculation so values match Shootouts |
| **Inventory & Equipment** | Shared limited inventory, stacking/unstackable items, supplies/loot/equipment, dropping, character selection, one-click valid-slot equipment swaps, stat comparison | `Party.inventory`; item instance model; equipment/slot and inventory command APIs |
| **Settings** | Audio/video, gameplay options, input/accessibility as needed, and save management | Persistent settings service; save service; apply/revert and confirmation flows |

The tab designs own their detailed layouts and sprites. The Journal overview only reserves consistent header, tab navigation, scrolling, tooltips, confirmation, empty-state, and controller-focus behavior.

## State and cross-tab contracts

- **Read authoritative state.** `Party`, future quest/settings/save services, and the Overworld position provider remain owners. The Journal does not copy their mutable state into tab-specific save data.
- **Mutate through commands.** Equipment, dropping, settings, and save operations call domain APIs and refresh from the result. Buttons must not directly edit nested Dictionaries in several places.
- **One quest-target source.** The Quests tab and Map consume the same current objective data. Map markers resolve only stable key-point/Location ids; they do not infer targets from quest text or `Locations.currentQuest`.
- **Map navigation request.** Selecting “Show on map” asks `Journal.gd` to select Map and pass a target id. It does not make the Quests tab instantiate or manipulate map nodes.
- **Refresh only while visible.** Domain signals may mark a cached tab dirty while hidden; reload it on next activation rather than rebuilding every tab on every state change.
- **No hidden gameplay.** Opening the Journal cannot advance quests, generate loot, change encounter RNG, move actors, or consume supplies.

## Visual and asset direction

Use the shared 12px UI font/theme, parchment/panel styling, short labels, tooltips, and keyboard/controller focus indicators. Scrolling is required for long quest text, stats, inventory, and settings; avoid shrinking text to fit.

Expected asset groups:

- Journal frame/background and tab icons: Map, Quests, Character, Inventory/Equipment, Settings.
- Map base generated from chunk data; separate Location, player, and current-quest icons.
- Quest state/current objective icons.
- Character portraits/icons, optional model presentation, and stat icons.
- Item/equipment slot, stack, selected-character, and comparison indicators.
- Standard focused/hover/disabled/confirm states and any settings/save icons.

Asset layout should be validated at 640×360 with integer viewport scaling. Long text and icon hit areas must remain usable without relying on hover alone.

## Files and implementation order

**Shell (create):**

- `UI/Journal/Journal.tscn` and `Journal.gd`.
- `UI/Journal/Tabs/` for independent tab scenes/scripts.
- `Tests/TestJournal.gd` for shell lifecycle, tab navigation, and input/pause behavior with fake tab/domain providers.

**Integration (modify):**

- `Nodes/Scene Manager/SceneManager.tscn` and `.gd` for the persistent Journal layer and open/close policy.
- `project.godot` for `TOGGLE_JOURNAL` and any explicit map/navigation actions.
- Domain globals only to expose their proper state/commands, not to implement Journal UI.

Suggested order:

1. Shell, modal/pause coordination, input/focus, lazy tabs, and empty states.
2. [Overworld Map](Overworld%20Map.md), including generated base data and player/POI markers; quest markers follow the quest API.
3. Quests, with shared objective/map-target contracts.
4. Character stats using the same effective-stat calculations as combat.
5. Inventory and equipment, after their capacity/item/slot rules are specified.
6. Settings and save management, reusing applicable settings UI in the main menu.

## Testing and acceptance

- Toggle/open/close repeatedly and across scene changes without duplicate instances, signal connections, focus loss, or input leaking to gameplay.
- Pause is restored to its previous state; blocked scenes/transitions cannot open the Journal.
- Lazy tabs instantiate once, hidden tabs do no periodic work, and stale tabs refresh on activation.
- All tabs work at 640×360 with long content, scrolling, keyboard/controller focus, and empty/unavailable data.
- Domain mutations go through commands and failed/cancelled actions leave state unchanged.
- Quest “Show on map” selects the same target marker; Map and Quests never disagree about current objectives.
- Each detailed tab doc adds its own data, generation, and interaction tests.

## Open decisions

- Exact scenes beyond Overworld/Locations that permit Journal access, especially Shootouts and minigames.
- Controller glyph/focus conventions and whether tab shortcuts should be global or remappable.
- Which settings apply immediately versus through Apply/Revert, and the save-management flow.
- Whether Character shows a static portrait, rendered model, or only stats when space is limited.
- Final tab order and art direction; these do not block the shell or Map implementation.
