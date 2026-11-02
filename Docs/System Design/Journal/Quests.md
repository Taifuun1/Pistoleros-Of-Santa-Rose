# Quests tab

The Journal's Quests tab tells the player which quests are active or completed, what has already happened, and what to do next. It also provides navigation from a current objective to the same quest target on the Overworld map.

**Status: stages 1–4 implemented; stage 5 automated validation complete, manual visual/controller review pending.** Typed definitions/catalog live in `Data/Quests/`, and `Globals/Quests.gd` owns validated catalog loading, runtime state, journal projections and the current-marker API, covered by `Tests/TestQuests.gd`. `UI/Journal/Tabs/QuestsTab.*` renders the read-only Active/Completed master/detail view against an injectable provider (`Tests/TestQuestsTab.gd`/`.tscn`). The shell wires `showOnMapRequested` to `Journal.showOnMap()`, and MapTab uses the real `Quests.getCurrentMapMarkers()` provider with quest/objective marker identity and exact `focusQuestTarget()` selection (`Tests/TestJournal.gd`, `Tests/TestOverworldMapTab.gd`). `Pistoleros Regroup` is authored in `Data/Quests/Definitions/PistolerosRegroup.tres`, registered in `Data/Quests/QuestCatalog.tres`, and advanced by end-of-cutscene quest shots in the five Pistoleros Regroup data files, covered by `Tests/TestQuestTriggers.gd`/`.tscn`. All five prologue Location scenes now exist and are chained Finch Pond → Pine Meadows → Great Fall Ridge → Blackberry Retreat → Littlehill Grove; Littlehill Grove has no onward exit yet. `Globals/Locations.gd::currentQuest` still selects location content.

## First-iteration decisions

- Support multiple known active quests and completed quests, with one current objective per active quest.
- Treat every active quest's current objective as current for Map purposes. There is no separate tracked-quest setting in this iteration.
- Build progress history from completed objectives in completion order. Do not add a second narrative-event feed yet.
- Keep the tab read-only. Gameplay advances quests through domain commands; the Journal never starts, completes, abandons, or resets them.
- Use a two-pane Active/Completed master list and quest detail view, with scrolling and keyboard/controller focus at 640×360.
- Keep runtime state in the `Quests` autoload across scene changes. Save/load integration waits for the save service; this iteration does not imply persistence across application restarts.

## Scope and requirements

### In scope

1. **Known quest list**
   - Show known active quests under **Active** and completed quests under **Completed**. Undiscovered quests and future objectives are not revealed.
   - Show a quest/state icon and title in each row. Use deterministic authored order, with stable quest id as a tie-breaker; do not depend on Dictionary iteration order.
   - Select an active quest by default. If none is active, select the first completed quest. Preserve the selected quest id across refreshes while that quest remains known.
   - Selection is UI-only. It does not change quest progress, choose a Map target, or mark anything as read.

2. **Quest details and progress**
   - Show the selected quest's title, active/completed state, and short summary.
   - For an active quest, prominently show **Next** with its current objective text.
   - Show **Progress** as completed objective entries in completion order, oldest first, so the player can reconstruct what happened.
   - For a completed quest, retain the full progress history, show a completed state instead of a next objective, and provide no current-target action.
   - Do not show upcoming objective text, hidden conditions, cutscene scripts, rewards, level/rarity, or implementation ids as quest progress.

3. **Current objective and Map navigation**
   - Provide **Show on map** only for an active current objective with a non-empty stable `target_id`.
   - Route the action through `Journal.gd`; the Quests tab must not instantiate, find, or manipulate Map nodes.
   - Select and focus the exact corresponding current quest marker. Merely selecting a quest in the list must not pan the Map or alter its markers.
   - Use the same authoritative quest state as the Map's `getCurrentMapMarkers()` provider. Never infer targets from objective text, `Locations.currentQuest`, cutscene names, or actor positions.

4. **Live, authoritative state**
   - Read quest projections from the quest service on activation and when its state changes while the tab is active.
   - Refresh the details after objective advancement or quest completion without duplicating history entries or retaining a completed objective as current.
   - Keep only UI selection/focus state in the tab. Do not maintain a second quest journal, progress history, or save representation.
   - Opening, browsing, refreshing, or closing the Journal must not advance triggers, consume events, change RNG, or otherwise mutate gameplay.

5. **Input, readability, and states**
   - Support mouse and keyboard/controller selection, scrolling, and **Show on map**. Expose the quest list through `getFocusTarget()` so the shell's TabBar-down handoff works; `ui_cancel` follows the shell's existing back-out behavior.
   - Use the shared theme and 12px UI font at the 640×360 reference viewport. Long titles, summaries, objective text, and histories scroll or wrap; never shrink text to fit.
   - Distinguish active, current, and completed states with icons plus text/shape, not color alone. Hover tooltips may supplement but cannot replace visible labels or focus behavior.
   - Show **No quests yet** when the valid journal is empty, and **Quest data unavailable** when state cannot be read. Neither state may contain sample quests or placeholder objectives presented as live data.

### Out of scope for this iteration

- Accepting, abandoning, restarting, or manually tracking quests.
- Quest filters, categories, search, main/side-quest presentation, or a separate tracked-quest HUD.
- Branching objectives, parallel objectives within one quest, counters, optional objectives, failure/retry states, or timed objectives.
- Narrative-only log entries unrelated to completed objectives. The model can be extended later without making the UI parse dialogue.
- Reward display/claiming and links to Inventory or Character.
- Location/dungeon maps, routes, moving-actor targets, fast travel, or quest-target tracking on foot.
- Save/load format, migration of existing cutscene flags, and cross-application persistence.
- Bulk conversion of existing cutscene data into quests. Initial live content should be a small, explicitly wired vertical slice.

## User experience and layout

Use a master/detail layout rather than nested tabs, so Active and Completed remain part of one straightforward focus order:

```text
QuestsTab (Control)
├── ContentView (HBoxContainer)
│   ├── QuestListPanel (PanelContainer)
│   │   └── QuestListScroll (ScrollContainer)
│   │       └── QuestList (VBoxContainer)
│   │           ├── ActiveHeader
│   │           ├── ActiveQuestRows       # Buttons created by script
│   │           ├── CompletedHeader
│   │           └── CompletedQuestRows    # Buttons created by script
│   └── QuestDetailPanel (PanelContainer)
│       └── DetailLayout (VBoxContainer)
│           ├── TitleLabel
│           ├── QuestStateLabel
│           ├── SummaryLabel
│           ├── NextPanel                 # hidden for completed quests
│           │   └── NextLayout (VBoxContainer)
│           │       ├── NextHeader (CurrentQuestIcon + "Next")
│           │       ├── NextLabel
│           │       └── ShowOnMapButton
│           └── ProgressScroll (ScrollContainer)
│               └── ProgressLayout (VBoxContainer)
│                   ├── ProgressHeader
│                   └── ProgressEntries   # rows created by script
└── StateView (CenterContainer)           # hidden when ContentView is usable
    └── StateLayout (VBoxContainer)
        ├── TabSprite
        └── StateMessageLabel
```

The list should take roughly one third of the usable width, leaving most space for readable quest text. Exact dimensions and art are an implementation/visual-review concern. Empty section headers may be omitted, but Active precedes Completed whenever both exist.

The next objective remains visually distinct from history. Completed steps use completed-state icons; the current objective uses the current-quest icon. The detail view must not display a fake empty next objective for completed quests.

On refresh, retain selection, focus, and scroll positions where practical. If the selected quest is no longer known, use the default selection rule rather than displaying stale details. Quest updates should rebuild only the affected presentation where practical, but correctness and authoritative re-reading take priority over fine-grained UI caching.

### QuestsTab script contract

The static containers, labels, buttons, and state views above live in `QuestsTab.tscn`; only quest rows and history entries are built dynamically. Do not call `JournalTab.showStateMessage()` after building this scene because it frees all root children. Toggle `ContentView`/`StateView` and set `StateMessageLabel` instead.

`QuestsTab.gd` exposes this test and integration surface:

```gdscript
signal showOnMapRequested(request: Dictionary)

var questProvider: Node = null # Fake provider in tests; null means /root/Quests.
var _selectedQuestId := ""
var _entriesById: Dictionary = {}
var _questRows: Dictionary = {} # quest_id -> Button
var _connectedProvider: Node = null

func refreshTab() -> void
func setTabActive(tabActive: bool) -> void
func getFocusTarget() -> Control
```

A provider implements `isQuestDataAvailable()`, `getQuestJournalEntries()`, and `questStateChanged(questId)`. `_resolveQuestProvider()` returns the injection or the autoload only while inside the tree. Activation connects once and stores `_connectedProvider`; deactivation and `_exit_tree()` disconnect it. `_onQuestStateChanged(_questId)` refreshes only while active.

`refreshTab()` performs this sequence:

1. Resolve the provider and show **Quest data unavailable** if it is missing or unavailable.
2. Read and defensively validate the entry array. Skip malformed rows with warnings; if the selected entry is malformed, show the unavailable detail state rather than stale content.
3. Rebuild Active/Completed rows in provider order using a shared `ButtonGroup`. Rows are focusable `Button`s with left-aligned icon/text, full-title tooltips, and a `pressed` connection bound to `quest_id`.
4. Preserve `_selectedQuestId` when still valid; otherwise select the first active entry, then the first completed entry, then no selection.
5. Render title, state, summary, current objective, and history. Hide `NextPanel` for completed entries and hide `ShowOnMapButton` when `target_id` is empty.
6. Restore list/detail scroll values and focused row when those Controls still exist. If selection disappeared, focus the replacement only when focus was already inside this tab.

`getFocusTarget()` returns the selected quest row, or the first row if no selected row exists; it returns `null` for empty/unavailable states. Wire row-right focus to `ShowOnMapButton` when visible and otherwise to the focusable `ProgressScroll`; wire their left focus back to the selected row. Rely on standard `ui_accept`, scrolling, and shell cancel behavior—no new input actions.

Pressing **Show on map** constructs a new request Dictionary from the selected current objective and emits `showOnMapRequested`. It does not call `Quests` commands or retain a Map reference. `canCloseTab()` stays inherited and `true`.

## Authoritative quest model

### Authored resources

Use typed Resources rather than anonymous cutscene-style Dictionaries. Objective Resources are sub-resources of each quest `.tres`; the catalog is the only runtime loading entry point.

`Data/Quests/QuestObjectiveDefinition.gd`:

```gdscript
extends Resource
class_name QuestObjectiveDefinition

@export var objective_id: String = ""
@export_multiline var objective_text: String = "" # Next text.
@export_multiline var history_text: String = ""   # Added after completion.
@export var map_target_id: String = ""             # Optional manifest id.
```

`Data/Quests/QuestDefinition.gd`:

```gdscript
extends Resource
class_name QuestDefinition

@export var quest_id: String = ""
@export var title: String = ""
@export_multiline var summary: String = ""
@export var sort_order: int = 0
@export var objectives: Array[QuestObjectiveDefinition] = []

func validate() -> Array[String]
func objectiveIndex(objectiveId: String) -> int # -1 when absent.
```

`Data/Quests/QuestCatalog.gd` and `Data/Quests/QuestCatalog.tres`:

```gdscript
extends Resource
class_name QuestCatalog

@export var definitions: Array[QuestDefinition] = []

func validate() -> Array[String]
```

Validation returns all human-readable errors, not only the first. Require at least one objective per quest; non-empty trimmed text; unique `quest_id` values across the catalog; unique `objective_id` values within a quest; and `quest_id`/`objective_id` values accepted by `String.is_valid_identifier()`. Use snake_case by convention. `sort_order` need not be unique. Map-target existence is checked against `OverworldMapData` in the production-data test, keeping the Resources independent of map generation.

Initial quest Resources live in `Data/Quests/Definitions/`, for example `PistolerosRegroup.tres` when that content is wired. Test quests are built in memory and are not added to the production catalog.

### Runtime ownership and commands

`Globals/Quests.gd` remains an autoloaded `Node` and gains:

```gdscript
signal questStateChanged(questId: String)

const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const CATALOG_PATH := "res://Data/Quests/QuestCatalog.tres"

var _definitions: Dictionary = {} # quest_id -> QuestDefinition
var _states: Dictionary = {}      # quest_id -> mutable state Dictionary
var _dataAvailable := false

func _ready() -> void
func loadCatalog(catalog: QuestCatalog) -> bool
func isQuestDataAvailable() -> bool
func startQuest(questId: String) -> bool
func completeCurrentObjective(questId: String, objectiveId: String) -> bool
```

`_ready()` loads `CATALOG_PATH` once. `loadCatalog()` is the initialization/test seam: validate the complete catalog before exposing it. On success, populate definitions, clear runtime state, and set `_dataAvailable = true`; on failure, clear both and set it to `false`. A missing, wrongly typed, or invalid catalog is unavailable; do not run with a partially loaded story. An empty valid catalog is available and produces the **No quests yet** UI. Tests instantiate `Quests.gd` without adding it to the tree, then call `loadCatalog()` with an in-memory catalog, avoiding production autoload state.

A state entry has exactly this shape:

```gdscript
{
    "status": STATUS_ACTIVE, # or STATUS_COMPLETED
    "current_objective_id": String, # empty after quest completion
    "completed_objective_ids": [],  # ordered; no duplicates
}
```

`startQuest()` fails without changing state when data is unavailable, the definition is absent, or the quest is already known. On success it creates an active state at objective zero and emits `questStateChanged` once.

`completeCurrentObjective()` requires an active state and an exact current-objective id match. On success it appends that id, then either advances `current_objective_id` or marks the final objective's quest completed and clears the current id. It emits once. Unknown, duplicate, out-of-order, and already-completed calls return `false` without mutation or a signal. These two methods are the only first-iteration mutation commands; there is no generic UI-accessible Dictionary editor.

`Locations.currentQuest` remains a location scene-selection string. `Cutscene.playedCutscenes` is not objective state, and `currentMainQuestLevel` remains unchanged and outside the journal projection.

### Gameplay trigger boundary

For the initial cutscene-driven slice, extend the existing shot interpreter in `Cutscenes/Cutscene.gd` rather than scanning played-cutscene flags. Add shot object `"quest"`, dispatched to `_playQuestShot(data: Dictionary)`, with these payloads:

```gdscript
{ "object": "quest", "data": {
    "action": "start",
    "quest_id": "pistoleros_regroup",
}}

{ "object": "quest", "data": {
    "action": "complete_objective",
    "quest_id": "pistoleros_regroup",
    "objective_id": "find_gwyneth",
}}
```

The handler validates the action/required ids and calls only `Quests.startQuest()` or `Quests.completeCurrentObjective()`. A rejected command logs a content warning with its ids; it does not retry, mutate other state, or block the cutscene. Like the existing camera/music shots, the quest shot leaves `wait` and `playerAction` unchanged and returns without calling `advanceScene()` itself; the existing `_process` loop advances exactly once on the next tick after either success or rejection. It does not load scenes or change `Locations.currentQuest`. Other gameplay systems may call the same commands directly later; the Journal never emits these shots itself.

### Read APIs and projections

```gdscript
func getQuestJournalEntries() -> Array[Dictionary]
func getCurrentMapMarkers() -> Array[Dictionary]
```

`getQuestJournalEntries()` projects known states onto their definitions:

```gdscript
{
    "quest_id": String,
    "title": String,
    "summary": String,
    "status": "active" | "completed",
    "sort_order": int,
    "history": [{ "objective_id": String, "text": String }],
    "current_objective": {
        "objective_id": String,
        "text": String,
        "target_id": String, # empty when there is no Map target
    },                      # empty Dictionary for a completed quest
}
```

History text comes from each completed objective's `history_text`; current text comes from `objective_text`. Upcoming objectives are absent. Sort quests by `(sort_order, quest_id)` before returning, and sort each history by `completed_objective_ids`, not definition order alone. Build new Dictionaries/Arrays for every result so mutating a returned projection cannot alter service state.

`getCurrentMapMarkers()` implements the existing [Overworld Map](Overworld%20Map.md) contract:

```gdscript
{
    "quest_id": String,
    "objective_id": String,
    "target_id": String,
    "icon": "quest_current",
}
```

Iterate in the same deterministic quest order. Include only active current objectives with non-empty `map_target_id`; completed quests and targetless objectives produce no entry. Both read APIs derive from `_states` on every call—neither caches a separate projection. Unavailable data returns empty arrays, while `isQuestDataAvailable()` lets the Quests UI distinguish that case from a valid empty journal.

## Map navigation contract

A marker's identity is `(quest_id, objective_id)`; `target_id` is only its resolvable Location/key-point anchor. Multiple current objectives may share an anchor, and a Location marker may occupy it too.

`QuestsTab.gd` declares and emits:

```gdscript
signal showOnMapRequested(request: Dictionary)

# Emitted payload; all three values are copied from the selected projection.
{
    "quest_id": String,
    "objective_id": String,
    "target_id": String,
}
```

When `Journal.gd` instantiates a tab, it checks `has_signal("showOnMapRequested")` and connects the signal once to `showOnMap()`. Lazy instantiation and `setTabDefinitions()` replacement therefore need no per-refresh signal wiring. The Quests tab never receives a Journal or Map reference.

Replace the shell's target-only method with:

```gdscript
func showOnMap(request: Dictionary) -> bool:
    if !isOpen:
        return false
    for key in ["quest_id", "objective_id", "target_id"]:
        if str(request.get(key, "")).is_empty():
            return false
    selectTab("map")
    var mapTab: Control = _tabInstances.get("map")
    if mapTab == null or !mapTab.has_method("focusQuestTarget"):
        return false
    return mapTab.focusQuestTarget(request)
```

Keep `MapTab.focusTarget(targetId: String)` unchanged for Location/POI navigation. Add a separate quest-specific path:

```gdscript
func focusQuestTarget(request: Dictionary) -> bool
func _questMarkerKey(questId: String, objectiveId: String) -> String
func _defaultQuestMarkerProvider() -> Array[Dictionary]

var questStateSource: Node = null          # Optional test injection.
var _connectedQuestStateSource: Node = null
```

`_startRuntime()` resolves the injected source or `/root/Quests`, connects `questStateChanged` once to `_onQuestStateChanged()`, and stores the source. `_stopRuntime()` disconnects and clears it. `_onQuestStateChanged(_questId: String)` calls `_refreshQuestMarkers()` only while active and built. Source replacement during a rebuild disconnects the old source first.

- `_questMarkerKey()` returns `questId + ":" + objectiveId`; `_questMarkers` uses that key, never `target_id`. Resource validation guarantees that neither identity component contains the separator. Each marker also stores all three ids as metadata for inspection/tests.
- `_refreshQuestMarkers()` rejects empty/non-identifier quest or objective ids, empty targets, and duplicate marker keys with warnings. It resolves `target_id` through `mapData.resolveLocation()` and creates no marker on failure.
- `focusQuestTarget()` validates the request, finds only the exact quest marker, centers/selects it, and returns `true`. It returns `false` without moving the map when absent; it never falls back to a Location or to another objective at the same anchor.
- `_defaultQuestMarkerProvider()` looks up `/root/Quests` only when the tab is inside the tree, checks `getCurrentMapMarkers()`, and returns an empty array when unavailable. An injected `questMarkerProvider` remains the test path.
- `MapTab.refreshTab()` remains the marker-refresh boundary. Selecting Map after a quest update re-reads the provider; no Quests-to-Map signal or cross-tab node path is introduced. A quest update while Map is active also calls `_refreshQuestMarkers()` through the same autoload `questStateChanged` connection lifecycle used for other runtime listeners, with no polling.

The navigation action is ephemeral: it does not track a quest, persist selection, advance progress, center the player, enter a Location, or close the Journal.

## Refresh lifecycle and failure behavior

- `refreshTab()` re-reads the full projection and reconciles the current selection. `setTabActive(true)` connects the quest-state signal once; `setTabActive(false)` disconnects it. No polling is needed.
- Activation always re-reads state, so a hidden tab needs no hidden signal work or mutable copy. Repeated opens and tab switches must not duplicate rows, connections, or focus handlers.
- An active update refreshes both the list and details, then preserves focus/scroll where practical. Objective advancement immediately changes Next and Progress; quest completion immediately removes Show on map.
- Map refreshes quest markers from the same state. The two tabs need not signal each other directly.
- A missing provider or unreadable journal shows **Quest data unavailable**. A valid empty array shows **No quests yet**.
- Invalid individual quest data logs its stable id and must not expose stale, partial, or invented details. Valid other quests may remain available; an invalid selected entry uses the unavailable detail state.
- An active quest with no resolvable current objective shows a data warning rather than a misleading next step. A current objective without any map target is still valid and simply has no Show on map button.
- `canCloseTab()` remains true: this iteration has no modal editing or confirmation flow.

## Visual and asset direction

Reuse `Assets/UI/UI.tres`, the Journal panel language, and `Assets/Journal/QuestsIcon.png`. The required state assets are present:

- `Assets/Journal/CurrentQuestIcon.png` — the Next objective badge and Map's `QUEST_CURRENT_ICON`.
- `Assets/Journal/CompletedQuestIcon.png` — completed quest rows and completed history entries.

Use the existing `ActiveQuestIcon.png` for active quest-list rows. `InactiveQuestIcon.png` has no first-iteration role because inactive/undiscovered quests are not shown. Do not ship Active/Inactive as substitutes for the decided Current/Completed states. Icons supplement visible state text and must remain legible at the reference viewport.

Use normal Button/Control focus indicators on quest rows and Show on map. Focused rows scroll into view. Tooltips can show a full long title, but controller users must be able to read the title in the detail panel without hover. No new global input actions are required beyond the shell's existing navigation and accept/cancel conventions.

## Implementation plan

Implement as five reviewable patches. Stages 1–3 deliver the complete system against an empty production catalog and fake test data; stage 4 adds real progression only after its content trigger points are approved. No stage presents fixture quests as live state.

### Stage 1 — Quest definitions and authoritative state ✅

**Status: implemented.** `Tests/TestQuests.gd` passes directly and through `Tests/RunAll.gd`, including the production catalog availability check.

**Create**

- `Data/Quests/QuestObjectiveDefinition.gd`
- `Data/Quests/QuestDefinition.gd`
- `Data/Quests/QuestCatalog.gd`
- `Data/Quests/QuestCatalog.tres` — initially valid and empty.
- `Tests/TestQuests.gd`

**Modify**

- `Globals/Quests.gd`

**Work**

1. Implement typed Resource validation and objective lookup. Keep test fixtures in the test script.
2. Implement catalog loading/availability, state ownership, `startQuest()`, `completeCurrentObjective()`, deterministic journal projections, current markers, and `questStateChanged`.
3. Preserve `currentMainQuestLevel`; do not change `Locations.currentQuest`, cutscene playback, scene selection, or save behavior.

**Tests / done criteria**

- Run `godot --headless --path . --script res://Tests/TestQuests.gd`.
- Cover all validation failures, empty/invalid catalog availability, start rejection, every linear transition, final completion, duplicate/out-of-order calls with unchanged state/no signal, deterministic ordering, history text, targetless objectives, multiple active quests, and deep-copy isolation.
- The production catalog loads as available and empty; no live quest starts implicitly.

### Stage 2 — Required icons and read-only Quests tab ✅

**Status: implemented.** `Tests/TestQuestsTab.tscn` passes, the production catalog renders **No quests yet**, and the updated `TestJournal` real-tab checks pass.

**Create**

- `Assets/Journal/CurrentQuestIcon.png`
- `Assets/Journal/CompletedQuestIcon.png`
- `Tests/TestQuestsTab.gd` and `Tests/TestQuestsTab.tscn`

**Replace / modify**

- `UI/Journal/Tabs/QuestsTab.tscn`
- `UI/Journal/Tabs/QuestsTab.gd`

**Work**

1. Build the static ContentView/StateView layout in the scene with shared theme, wrapping labels, and scrolling detail/list regions that fit the existing 560×280 Journal panel at the 640×360 viewport.
2. Implement provider resolution, active-only signal connection, defensive entry validation, dynamic row/history creation, selection/defaulting, Next/completed states, and the navigation signal.
3. Implement focus handoff, row/detail focus neighbours, focus/scroll restoration, and clean deactivation/destruction. Use the three decided icon roles; do not use sample data outside tests.

**Tests / done criteria**

- Run `godot --headless --path . res://Tests/TestQuestsTab.tscn`.
- Use a fake `Node` provider to cover Active/Completed grouping, selection, long content, no history, targetless Next, completed quests, valid empty versus unavailable, malformed entries, live updates, and repeated activation without duplicate connections.
- Verify mouse and keyboard/controller operation, focus return/cancel behavior through a real Journal smoke case, and readable layout at 640×360. With the empty production catalog, the real tab shows **No quests yet**.

### Stage 3 — Journal navigation and live Map markers ✅

**Status: implemented.** `TestOverworldMapTab` (120 checks) and `TestJournal` (109 checks) pass, including the real-shell Quests → Journal → Map flow.

**Modify**

- `UI/Journal/Journal.gd`
- `UI/Journal/Tabs/MapTab.gd`
- `Tests/TestJournal.gd`
- `Tests/TestOverworldMapTab.gd`

**Work**

1. Connect `showOnMapRequested` during tab instantiation and implement Dictionary-based `Journal.showOnMap()`. Preserve lazy tab creation and existing close/focus behavior.
2. Add quest/objective marker keys and metadata, `focusQuestTarget()`, strict provider-entry validation, the real autoload provider, and active-only `questStateChanged` listening. Keep Location `focusTarget()` and all terrain/player behavior intact.
3. Point `QUEST_CURRENT_ICON` at the new Current icon. Update every existing fake marker fixture to include unique `quest_id`/`objective_id` values and change target-based assertions to identity-based assertions.
4. Extend POI/marker overlap handling so focusing a quest badge does not select its same-anchor Location. Keep marker image coordinates anchored to the manifest target.

**Tests / done criteria**

- Run `godot --headless --path . res://Tests/TestOverworldMapTab.tscn` and `godot --headless --path . res://Tests/TestJournal.tscn`.
- Cover two quests at one target, two objectives at one anchor across refresh, same-anchor Location/quest selection, malformed/duplicate entries, unknown targets, focus failure without map movement, provider replacement, active signal refresh, and listener cleanup.
- Add one real-shell Quests → Journal → Map test with injected providers: pressing the button selects Map and focuses the exact marker without changing quest state. Existing Journal and Map regression checks must still pass.

### Stage 4 — Cutscene command shot and approved real quest slice ✅

**Status: implemented.** Confirmed mapping: Finch Pond starts the quest; Pine Meadows → `find_gwyneth`; Great Fall Ridge → `find_aiyana`; Blackberry Retreat → `find_manuel`; Littlehill Grove → `find_morrison` then `regroup_pistoleros_of_santa_rose`. All five data files carry the end shots, the catalog loads the quest, and `Tests/TestQuestTriggers.tscn` passes. Great Fall Ridge's incorrect Pine Meadows cutscene reference, the stale `playedCutscenes` keys, and the missing Blackberry Retreat/Littlehill Grove Location scenes were repaired; the prologue now chains through all five locations.

**Create / modify**

- `Data/Quests/Definitions/PistolerosRegroup.tres` and `Data/Quests/QuestCatalog.tres`
- `Cutscenes/Cutscene.gd` for the generic quest-shot dispatcher/handler
- Only the approved `Data/Cutscenes/Pistoleros Regroup/*.gd` files containing trigger shots
- `Tests/TestQuestTriggers.gd` and a scene runner for the interpreter/autoload path
- `Tests/TestQuests.gd` for production catalog/map-target validation

**Work**

1. Implement and test the non-blocking quest shot independently of the new content. Invalid actions/ids warn and advance exactly once; valid shots call only the domain commands.
2. Author the approved quest Resource, register it in the catalog, and insert explicit start/complete shots at the reviewed story boundaries.
3. Validate every production `map_target_id` against the committed `OverworldMapData.tres`; use no coordinates in quest Resources.

**Tests / done criteria**

- Run the quest, trigger, Journal, and Map suites. Exercise start, each advancement, repeated shot delivery, final completion, and a cutscene continuing after an invalid shot.
- In a live playthrough, the Journal shows real history/Next at each approved boundary, all current objectives appear on Map, and completion removes the current target without removing history.

### Stage 5 — Integration review and full validation

**Status: automated validation complete; manual visual/controller review pending.** Full `RunAll` finished 32/33: every Quest, Journal, Map, trigger, and scene-chain suite passed; the only failure is the pre-existing, unrelated `TestActorShadow` VERTICAL padding/offset check, which reproduces standalone and touches no files changed by this feature. The stage-5 progression test replays all five production cutscene shots and asserts the completed quest, ordered five-entry history, six change signals, empty current markers, and no duplicate history on a repeated final shot.

1. ✅ Run all focused suites, then `godot --headless --path . --script res://Tests/RunAll.gd` (32/33; unrelated `TestActorShadow` baseline failure).
2. ⏳ Perform the manual 640×360 mouse/keyboard/controller review, including long text, empty/unavailable states, current/completed icons, repeated Journal opens, scene changes, Show on map, and final quest completion.
3. ✅ Automated checks confirm no save persistence is claimed, no gameplay input leaks while the Journal is open, and hidden tabs retain no active listeners/periodic work.
4. ✅ Status lines updated; content/save follow-ups recorded below.

### Manual prologue playthrough

Two practical ways to exercise the slice:

1. **Cutscene-only route (fastest, no SceneManager):** open `Cutscenes/Cutscene.tscn` and run the current scene. The Cutscene autoload defaults to arc `Pistoleros Regroup`, name `Finch Pond`, so the intro cutscene plays and then falls back to the Finch Pond Location. Walk north through the exits to trigger Pine Meadows, Great Fall Ridge, Blackberry Retreat, and Littlehill Grove in order. Journal/SceneManager transitions are not active on this route.
2. **Full-shell route:** open `Nodes/Scene Manager/SceneManager.tscn`, temporarily set the root's `initial_scene` to `cutscene`, and run the current scene. This keeps the Journal, fade transitions, and SceneManager policy active. Set it back to `main_menu` afterwards.

Quest state starts only when the Finch Pond cutscene's final shot runs. Starting at a later Location (or skipping that cutscene) leaves `find_gwyneth` current, so later `complete_objective` shots warn and reject. `Cutscene.playedCutscenes` is in-memory only and resets each run, so all five cutscenes replay.

## Testing and acceptance

### Domain and data

- Validate unique, non-empty quest/objective ids; valid definition ordering; non-empty display/objective/history text; and current-objective references. Validate every non-empty `map_target_id` against the generated map manifest without copying coordinates into quest data.
- Starting a quest exposes only its current objective, not future objectives. Completing objectives appends history in order and advances Next exactly once.
- Duplicate or out-of-order trigger delivery leaves state unchanged. Completing the final objective produces a completed projection, preserves all history, and removes its current marker.
- Multiple active quests produce the expected current-marker array; objectives without targets and completed quests produce none.
- Journal projections cannot mutate service internals. Reading them has no gameplay side effects.

### Quests tab

- Active and Completed sections, deterministic ordering, default selection, selection preservation, progress text, Next, and completed details match fake-provider fixtures.
- Empty, unavailable, invalid-entry, no-active-quest, no-history, and no-map-target states are distinct and readable; no sample data appears as live state.
- Long titles/text and many quests/history entries remain usable at 640×360 with mouse and keyboard/controller scrolling and visible focus.
- TabBar-down enters the quest list; cancel returns to shell chrome before closing. Input does not leak to gameplay or switch shell tabs while navigating quest content.
- Repeated activation and live updates do not duplicate rows/signals or lose the selected valid quest. Hidden tabs do no periodic work.
- Browsing and Show on map never mutate quest state.

### Shared Map flow

- Show on map selects Map and focuses the exact `(quest_id, objective_id)` badge, including when two quest markers share a target or a quest target shares a Location anchor.
- Advancing/completing a quest changes both the Quests details and current Map markers from the same state; the tabs never disagree about Next or current targets.
- Unknown/inactive targets produce no origin marker and no false successful-focus claim. The existing Map base/player/POI behavior remains unchanged.

### Manual review

Inspect a real active quest before and after several objective transitions, then a completed quest. Review text wrapping, history length, icons, focus visibility, and Show on map at actual 640×360 scale. Confirm that application restart behavior is not presented as saved persistence until save integration exists.

## Remaining decisions and follow-ups

- **Manual visual/controller sign-off:** stage 5 automated validation is complete, but the real 640×360 mouse/keyboard/controller pass (long text, icons, repeated Journal opens, scene changes, Show on map, final completion) still needs a human review.
- **Unrelated baseline failure:** `Tests/TestActorShadow.gd` fails its VERTICAL shadow padding/offset checks standalone; it is untouched by this feature and should be handled separately.
- **Littlehill Grove onward transition:** the prologue now ends in Littlehill Grove with no exit. Decide how/when the party transitions to Lazysprings (and whether that also marks the quest complete or starts the next arc).
- **Map targets:** all five production objectives currently use an empty `map_target_id`, so no quest marker appears on the map. Decide later whether any objective should point at a manifest Location/key-point; Pine Meadows/Finch Pond are not map-manifest ids.
- **Resolved — current versus tracked:** all active current objectives appear on Map. If clutter later becomes a problem, design tracking separately rather than overloading list selection.
- **Resolved — icons:** create distinct Current and Completed icons; use Active for active list rows as specified above.
- **Future history granularity:** completed objectives are the only first-iteration entries. Narrative-only events require a later design and must not be inferred from played cutscenes.
- **Future quest rules:** branching/parallel objectives, counters, optional/failed quests, categories, and rewards require review before extending the linear state model.
- **Future persistence:** save format, New Game reset, and migration from cutscene flags belong with the save-service design.


