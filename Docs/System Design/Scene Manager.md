# Scene manager system

Scene manager is a node for switching scenes during gameplay. The node acts as a base scene for loading all the other scenes. A loading screen is shown when switching scenes if the scene takes time to load. Scene switching also has a built-in fade transition. The node should reside in the Nodes folder.

## Scenes to switch

The scene manager should at least be able to handle these scenes:

- Overworld
- Cutscenes
- Fight
- WFC generation
- Locations
- Main menu

## Implementation plan

### 1. Current state

Scene switching is currently done with direct `get_tree().change_scene_to_file()` / `change_scene_to_packed()` calls scattered across the codebase:

- `Overworld/Overworld.gd` — `enterLocation()` switches to pregenerated locations (`res://Location/Locations/{name}/{name}.tscn`) and WFC-generated locations (`res://Location/Location Generation/{name}/{name}.tscn`).
- `Location/Location Generation/LocationMapBase.gd` — `checkIfChangeChunk()` switches back to `res://Overworld/Overworld.tscn` when leaving a generated location through the top border.
- `Location/Locations/BaseLocation.gd` — switches to `res://Cutscenes/Cutscene.tscn` and `res://Location/Locations/Location.tscn`.
- `Cutscenes/Cutscene.gd` — switches to `res://Location/Locations/Location.tscn` after a cutscene.
- `Minigames/Poker/Poker.gd` — switches back to `res://Overworld/Overworld.tscn`.
- `Game/Test/LocationTest.gd` and `Game/Test/OverworldTest.gd` — test scenes using `change_scene_to_packed()`.

There is no main menu scene yet — `project.godot` currently points `run/main_scene` directly at `res://Overworld/Overworld.tscn`. A basic loading screen already exists at `UI/Loading/Loading.tscn` (a `Control` with a centered "Loading" label) and can be reused.

### 2. Files to create

Following the existing node folder conventions (e.g. `Nodes/Exit/`, `Nodes/Dynamic Sprite/`):

- `Nodes/Scene Manager/SceneManager.tscn` — the scene manager scene.
- `Nodes/Scene Manager/SceneManager.gd` — the scene manager script.
- `UI/Main Menu/MainMenu.tscn` + `UI/Main Menu/MainMenu.gd` — a new main menu scene (does not exist yet), with at minimum "New Game" / "Continue" / "Quit" buttons.

### 3. Scene structure

`SceneManager.tscn` layout:

```
SceneManager (Node)                    # root, script: SceneManager.gd
├── CurrentScene (Node)                # container; the active scene is instanced as a child of this
└── TransitionLayer (CanvasLayer)      # layer = 10, always on top of gameplay
    ├── FadeRect (ColorRect)           # full-rect, black, modulate.a = 0, mouse_filter = ignore
    └── LoadingScreen (instance of UI/Loading/Loading.tscn)  # hidden by default
```

- The root is a plain `Node` so the manager is scene-type agnostic (all managed scenes are `Node2D`/`Control` roots).
- `TransitionLayer` is a `CanvasLayer` so the fade and loading screen render above any scene content regardless of the active scene's own canvas layers.
- `FadeRect` covers the whole viewport (full-rect anchor preset) and starts fully transparent.
- The existing `UI/Loading/Loading.tscn` is instanced under `TransitionLayer` and hidden by default. It can later be extended with a progress bar bound to `ResourceLoader.load_threaded_get_status()` progress.

### 4. Scene registry

`SceneManager.gd` holds a registry mapping logical scene keys to resource paths, so callers never hardcode paths:

```gdscript
const SCENES := {
	"main_menu": "res://UI/Main Menu/MainMenu.tscn",
	"overworld": "res://Overworld/Overworld.tscn",
	"cutscene": "res://Cutscenes/Cutscene.tscn",
	"fight": "res://Fight/Fight.tscn",
	"location": "res://Location/Locations/{location}/{location}.tscn",            # pregenerated
	"wfc_location": "res://Location/Location Generation/{location}/{file}.tscn",  # WFC generation
}
```

- Location paths are resolved with the same formatting rules currently used in `Overworld.gd:enterLocation()` (pregenerated locations keep whitespace in the folder name; WFC locations strip whitespace for the file name).
- An optional `change_scene_to_path(path)` fallback handles one-off scenes (e.g. test scenes) that are not in the registry.

### 5. Public API

```gdscript
signal scene_change_started(scene_key)
signal scene_changed(scene_key)

func change_scene(scene_key: String, context := {}) -> void
func change_scene_to_path(scene_path: String, context := {}) -> void
func get_current_scene() -> Node
```

- `context` is an optional `Dictionary` passed through to the new scene (e.g. `{ "location": "Clearwater Grove", "pregenerated": false }` from `enterLocation()`, or spawn data for the overworld). The manager sets matching properties / calls an optional `init(context)` method on the new scene root if it has one, replacing the current pattern of setting autoload state (`Locations.currentLocation`, `Overworld.spawnChunk`, `Overworld.spawnTile`) before switching.
- Only one transition can run at a time; calls made while a transition is in progress are ignored (with a `push_warning`).

### 6. Transition flow

`change_scene()` performs the following steps:

1. **Guard** — return early if a transition is already running or the key is unknown.
2. **Fade out** — tween `FadeRect.modulate.a` from 0 → 1 over ~0.3 s and await completion. Input is effectively blocked because the opaque `FadeRect` (temporarily `mouse_filter = stop`) covers the screen.
3. **Start threaded load** — call `ResourceLoader.load_threaded_request(scene_path)`. All managed scenes benefit, but this is especially important for WFC generation scenes and large pregenerated locations, which are the heaviest to load.
4. **Loading screen fallback** — poll `ResourceLoader.load_threaded_get_status()` each frame:
   - If the load finishes before the fade-out completes (or within a short grace period, ~0.2 s), never show the loading screen — fast switches (cutscenes, fight, main menu) just get the fade.
   - If the load is still in progress after the grace period, show `LoadingScreen` and keep polling until `THREAD_LOAD_LOADED`, optionally updating a progress indicator from the `progress` array.
   - On `THREAD_LOAD_FAILED` / `THREAD_LOAD_INVALID_RESOURCE`, `push_error()`, fade back in, and abort.
5. **Swap scenes** — `ResourceLoader.load_threaded_get(scene_path)` to get the `PackedScene`, instantiate it, free the old child of `CurrentScene` (`queue_free()`), and `add_child()` the new instance. Apply `context` (set `Locations.currentLocation` etc. via the new scene's `init()` where applicable).
6. **Fade in** — hide `LoadingScreen`, tween `FadeRect.modulate.a` from 1 → 0, restore `mouse_filter = ignore`, emit `scene_changed`.

The whole flow is a single `async` function; callers use `SceneManager.change_scene(...)` without awaiting (fire-and-forget), matching how `change_scene_to_file` is used today. Because the manager no longer relies on `get_tree().change_scene_to_*`, the deferred-call workarounds (`call_deferred("change_scene_to_file", ...)`) can be dropped — the manager defers the actual node swap internally when called from a physics callback (e.g. `body_entered` in `Exit.gd` / location areas).

### 7. Project configuration

- Set `run/main_scene="res://Nodes/Scene Manager/SceneManager.tscn"` in `project.godot`.
- On `_ready()`, the scene manager loads the initial scene: the **main menu** in release runs, with an exported `initial_scene` key (default `"main_menu"`) so development runs can still boot straight into `"overworld"`.
- The scene manager is **not** an autoload — it is the root of the scene tree, per the design ("acts as a base scene for loading all the other scenes"). Other scenes access it via `get_tree().root.get_node("SceneManager")` or a small helper in `HelperFunctions`.

### 8. Migration of existing scene switches

Replace every direct `change_scene_to_*` call:

| File | Current call | Replacement |
|---|---|---|
| `Overworld/Overworld.gd` (`enterLocation`) | `call_deferred("change_scene_to_file", location path)` | `SceneManager.change_scene("location" / "wfc_location", { "location": locationName })` |
| `Location/Location Generation/LocationMapBase.gd` (`checkIfChangeChunk`) | `call_deferred("change_scene_to_file", overworld)` | `SceneManager.change_scene("overworld")` (spawn chunk/tile still set via `Overworld` autoload beforehand) |
| `Location/Locations/BaseLocation.gd` | `change_scene_to_file(cutscene / location)` | `SceneManager.change_scene("cutscene")` / `("location", ...)` |
| `Cutscenes/Cutscene.gd` (`_on_area_2d_body_entered`) | `change_scene_to_file(location)` | `SceneManager.change_scene("location", ...)` |
| `Minigames/Poker/Poker.gd` | `change_scene_to_file(overworld)` | `SceneManager.change_scene("overworld")` |
| `Game/Test/*.gd` | `change_scene_to_packed(...)` | keep as-is, or route through `change_scene_to_path()` for consistency |

`Nodes/Exit/Exit.gd` keeps working unchanged — it calls `exitLocation` on the location root, which will internally call the scene manager instead of `change_scene_to_file`.

### 9. Main menu

- Create `UI/Main Menu/MainMenu.tscn` (a `Control` following the existing `UI/` structure, using `UI/UITheme.tres`) with buttons:
  - **New Game** → `SceneManager.change_scene("cutscene", { "cutscene": <intro cutscene> })` or straight to `"overworld"` until the intro cutscene is wired up.
  - **Continue** → loads save data (when saving exists), then `change_scene("overworld")`. Disabled until save support lands.
  - **Quit** → `get_tree().quit()`.
- The main menu becomes the default `initial_scene`, making it the game's entry point.

### 10. Testing

- Add `Nodes/Scene Manager/Test/SceneManagerTest.tscn` + `.gd` (following the existing `*/Test/` pattern) that:
  - Switches through the full loop: main menu → overworld → pregenerated location → overworld → WFC location → overworld → cutscene → fight, asserting `get_current_scene()` matches the requested key after each `scene_changed` signal.
  - Asserts the fade runs (check `FadeRect.modulate.a` reaches 1 before swap and 0 after).
  - Asserts the loading screen appears for a slow load (can be simulated by pointing the manager at a large scene) and stays hidden for fast loads.
  - Asserts a second `change_scene()` call during an active transition is ignored.
- Manual smoke test: run the project from the main menu and walk into a location from the overworld (the `enterLocation` path), then exit a WFC location through the top border (the `checkIfChangeChunk` path).

### 11. Implementation order

1. Create `SceneManager.tscn` / `SceneManager.gd` with registry, fade, threaded loading, and loading screen (steps 3–6).
2. Point `run/main_scene` at the scene manager with `initial_scene = "overworld"` (keeps current boot behavior while migrating).
3. Migrate all `change_scene_to_*` call sites (step 8) and verify each flow manually.
4. Create the main menu scene and switch `initial_scene` to `"main_menu"` (step 9).
5. Add the automated scene manager test (step 10).
6. Polish: progress bar on the loading screen, configurable fade duration/color per scene, optional fade-to-white for cutscene transitions.
