# Flairs

Flairs are a flashy pop-up before a Shootout starts. The flair itself is a one-word flavour text with a texture background that ends with an exlamation point. Flairs signal the start of a Shootout. A flair flies in from the side as a Shootout is initiated, hangs on the screen for a few seconds, and flies off again. The flair should pop-up before the scene is transitioned to the Shootout. Only after will the scene transition. The flair should signal energy, so it should be fast, and have some effects.

The texts for the flairs are in [Names.md](../../Names.md).

## Code design

### Ownership and scene structure

The flair is part of the **scene transition**, not the Shootout scene. `SceneManager` owns and plays it before `_swapScene()`; putting it in `Shootout/Shootout.tscn` would make it appear only after the transition and would let combat initialization race the popup.

Create `UI/Flair/Flair.tscn` with `Flair.gd`:

```text
Flair (Control, full rect, mouse_filter = IGNORE)
└── Motion (Control)
    ├── Background (NinePatchRect)
    └── Text (RichTextLabelExtended)
```

- `Motion` is the only node animated by the entrance/exit tween. `Background` supplies the textured, resizable backing; `Text` uses the shared UI font and remains centered for both one-word and multiword quest flairs.
- Add a `FlairLayer` (`CanvasLayer`, layer 9) to `Nodes/Scene Manager/SceneManager.tscn`, below the existing `TransitionLayer` (layer 10) and above `JournalLayer` (layer 5). The flair therefore appears over the outgoing scene, while the subsequent fade can still cover it.
- `SceneManager` instantiates at most one flair per Shootout launch and frees it after its exit animation. The flair does not pause the tree, capture input itself, or remain alive into the Shootout.
- Set `fadeRect.mouse_filter = Control.MOUSE_FILTER_STOP` before playing the flair so clicks cannot reach the outgoing scene during the wait. The existing `_fadeIn()`/abort paths restore input afterward.

### Flair data and selection

[Names.md](../../Names.md#shootout-flair-names) is the content source. Mirror its three lists as `Shootout.FLAIR_POOLS` in `Globals/Shootout.gd`, keyed by `dustup`, `showdown`, and `quest`; do not maintain a second, differently spelled set of flavor names in the Shootout scene.

Encounter metadata controls selection:

| Field | Type | Behavior |
| --- | --- | --- |
| `flair` | `String`, optional | Exact authored override. Use this for scripted quest text. |
| `flairPool` | `String`, optional | `dustup`, `showdown`, or `quest`; defaults to `kind`. |
| `flavor` | `String`, optional | Legacy alias for `flair`, retained while existing encounters use it. |

Add `Shootout.resolveFlairText(encounterData: Dictionary) -> String`. It uses the explicit override when present, otherwise picks uniformly from the resolved pool. Unknown or empty pools fall back to `dustup`; empty text falls back to `Shootout!`. Append `!` only when the selected string does not already end in one—the entries in `Names.md` already include their punctuation.

`SceneManager` loads the same encounter resource that `Shootout._ready()` will consume through `Shootout.pendingEncounter`, falling back to the existing `RatAmbush.gd` debug encounter. Move the default encounter path to a shared `Shootout.DEFAULT_ENCOUNTER_PATH` constant so selection and combat initialization cannot disagree about the default. Loading the resource for the flair does **not** consume or clear `pendingEncounter`; the Shootout scene retains that responsibility.

Resolve and display the text exactly once. Remove the current `flavorName`/`pickFlavorName()` start-banner path from `Shootout/Shootout.gd`; otherwise a random override can be rolled twice and a second popup can appear after combat starts. Directly running `Shootout.tscn` in the editor remains a combat-debug path and does not synthesize a pre-transition flair.

### Transition integration

Extend `SceneManager.change_scene_to_path()` without changing its public signature or requiring callers to await it. The transition guard must be set **before** the first flair await:

```gdscript
transitioning = true
scene_change_started.emit(sceneKey)
fadeRect.mouse_filter = Control.MOUSE_FILTER_STOP

if sceneKey == "shootout":
	var encounterData = Shootout.loadPendingEncounterData()
	var flair = FlairScene.instantiate()
	flairLayer.add_child(flair)
	await flair.play(Shootout.resolveFlairText(encounterData))
	flair.queue_free()

await _swapScene(scenePath, context, sceneKey)
```

`Shootout.loadPendingEncounterData()` is a small autoload helper shared by this code and `Shootout._ready()`: it resolves `pendingEncounter` or `DEFAULT_ENCOUNTER_PATH`, loads the data, and leaves consumption/reset of the pending path to the Shootout scene.

This preserves the existing order for non-Shootout scenes and gives Shootouts the following lifecycle:

1. Lock further transitions and close any active Journal through the existing `scene_change_started` signal.
2. Play the complete flair over the outgoing scene.
3. Free the flair, then run the existing threaded load, scene swap, and fade.
4. Initialize combat only when the Shootout scene is added; `scene_changed` still emits after the fade-in.

A load failure after the flair uses the existing `_abortTransition()` path and returns to the outgoing scene. No flair-specific callback is allowed to start another scene change.

### Animation contract

`Flair.gd` exposes one async entry point and one completion signal:

```gdscript
signal finished

func play(text: String) -> void:
	# Set the label, compute viewport-relative positions, build one tween,
	# await that tween's completion, then emit finished.
```

Use exported durations so tests can shorten the sequence without changing production timing. Initial values: **0.18 s entrance**, **1.4 s hold**, and **0.16 s exit**. Compute positions from `get_viewport_rect().size` and the fully laid-out `Motion.size`, rather than hardcoded screen coordinates:

- Start fully beyond the left edge, ease out to the horizontal center with `TRANS_CUBIC`, and finish just above the vertical center.
- Add a small overshoot/scale punch on arrival (for example scale `1.08` settling to `1.0`) and a brief rotation or brightness accent. Keep effects on `Motion` so the text and texture move together.
- Hold without motion, then ease in fully beyond the right edge. `finished` means the exit has completed, not merely that the hold has ended.
- Kill any existing tween before `play()` and reject a concurrent second play. `queue_free()` is owned by `SceneManager`, not by the animation callback, so the completion await has one clear lifecycle owner.

All decorative effects must be optional visual polish; correctness depends only on the single tween completing and emitting `finished`.

### Files to create / modify

**Create**

- `UI/Flair/Flair.tscn` and `UI/Flair/Flair.gd` — textured text, animation, and completion signal.
- `Tests/TestFlairs.tscn` and `Tests/TestFlairs.gd` — scene-based lifecycle and selection tests with autoloads available.

**Modify**

- `Nodes/Scene Manager/SceneManager.tscn` / `SceneManager.gd` — persistent flair layer and pre-swap await.
- `Globals/Shootout.gd` — canonical pools, default encounter path, encounter-loading helper, and text resolver.
- `Shootout/Shootout.gd` — consume the shared encounter helper and remove the old in-combat start banner.
- `Data/Shootout/Encounters/*.gd` — use `flair` and, for quest-specific pools, `flairPool`; legacy `flavor` remains supported during migration.

### Testing

`Tests/TestFlairs.gd` should use shortened durations and cover:

- Every pool exactly mirrors its corresponding list in `Names.md`; explicit `flair` and legacy `flavor` overrides win over random selection, and existing `!` punctuation is not doubled.
- `kind` selects the matching default pool, `flairPool = "quest"` selects quest text even for a Showdown, and invalid pools/empty text use their fallbacks.
- On a Shootout launch, the outgoing scene remains current and `transitioning` remains true until `Flair.finished`; the Shootout is current only after the exit and normal transition complete.
- Two launch requests during a flair produce one flair and one scene swap. Non-Shootout transitions do not instantiate a flair.
- The flair is freed before combat initialization, and a failed scene load releases the transition guard and restores input.

Manually verify at the 640×360 game viewport that the longest quest flair fits its texture, the entrance and exit never leave clipped residue on screen, the full animation reads before the fade, and no combat UI or banner duplicates it afterward.

