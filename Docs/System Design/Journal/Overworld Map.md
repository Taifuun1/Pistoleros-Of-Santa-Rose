# Overworld map

The Journal's Overworld map shows the world, the player's current/last known position, Location points of interest, and current quest targets. This doc focuses on generating the base map from authoritative chunk data and keeping live markers aligned with it.

This is a design doc: it describes intended behavior, and implementation may lag behind it. **Status: steps 1–6 implemented plus baseline hardening — shared `OverworldChunkReader`/`OverworldCoordinates`/`OverworldMapProjection`, explicit `WorldData`, `MapTileStyles`, the headless bake tool with the checked-in `Assets/Journal/OverworldMap.png` and `Data/Overworld/OverworldMapData.tres` manifest (fingerprint + `--check`), the Journal map tab (`UI/Journal/Tabs/MapTab.*`: fit/pan/zoom, constant-size markers, generated POIs), and the exact live/last-known player provider (`Globals/Overworld.gd::getOverworldMapPosition()`, re-entry unified). Hardening adds coordinate-map ownership/disposal, malformed-chunk rejection, fail-closed runtime manifest validation, POI projection checks and complete MapTab view disposal. Orientation is resolved: the shipped map uses the gameplay-aligned projection recorded as `map_orientation` in manifest format version 2. The terrain palette is now authored rather than sampled and follows the authored per-row reference [Tileset Classification](Tileset%20Classification.md) (rocks, cliffs, forest, swamp, water, tracks, fences). Fit-scale readability is handled by a generated overview LOD that the map tab uses while zoomed out, and the map is fully operable by mouse, keyboard and controller (pan, zoom, fit, center, POI cycling) with the map filling the tab and the shortcut buttons overlaid. The second review's iteration step 1 is implemented: re-entry reseeds from the tile map's containing cell, and exact world/cell conversion uses an explicit cell+fraction pair instead of an invertible-looking packed fraction. Iteration step 2 is implemented too: the Journal wires TabBar-down to the map's exposed focus target, `ui_cancel` backs out to tab switching before closing, and the real-shell tests cover controller pan and tab navigation at 640×360. Iteration step 3 makes every generator mode fail closed: decode errors, `--require-complete`, `--strict`, palette collapse/unknown keys and invalid CLI input all exit nonzero, invalid input refuses to bake or write, and a subprocess suite locks the exit codes and output preservation. Iteration step 4 removes the remaining test-process leaks: MusicPlayer shuts its streams/tweens/timer down explicitly, SceneManager loads scenes synchronously in headless runs, Overworld disposes its streaming caches and skips background preloading in headless mode, and the Journal/Encounters tests free the tabs, actors and script instances they own. The quest key-point API (step 7) is still pending.**

Quest marker identity and “Show on map” navigation are implemented (Quests stage 3): MapTab reads `Quests.getCurrentMapMarkers()`, keys badges by `quest_id:objective_id`, focuses the exact requested badge through `focusQuestTarget()`, and refreshes from `questStateChanged` only while active. The shell forwards the Quests tab's request through `Journal.showOnMap()`.

## Requirements

- Show the complete Overworld, not only currently streamed chunks.
- Show the current player position while in the Overworld and the last known Overworld position while inside a Location.
- Show every map-visible Location as a point of interest.
- Show current quest targets, which are always stable key points on the map rather than arbitrary moving actors.
- Generate the base map from chunk data so terrain edits do not require repainting a separate world sprite.
- Keep player, Location, and quest overlays outside the baked image so they can change without regeneration.
- Fit the Journal at 640×360, with readable icons, pan/zoom, tooltips, and keyboard/controller operation.

The first version is a full-world Journal map, not a minimap. Fog of war, fast travel, route finding, Location/dungeon maps, visual-party markers, and quest-target tracking of moving parties are out of scope.

## Viability verdict

**Generating the map from chunk data is viable and recommended.** Use a **deterministic, headless, build-time semantic raster bake**:

1. Read every authored chunk scene and its baked tile cells.
2. Convert tile source/atlas identities to a deliberate map palette and feature style.
3. Rasterize a small projected `Image` without rendering the actual world.
4. Save a PNG plus projection/Location metadata as checked-in generated assets.
5. Load only those assets at runtime; add live markers separately.

Do not instantiate the whole Overworld or regenerate the map when the Journal opens. Do not treat raw tile-texture colors as a finished map palette. A small authored classification table is still required, but it is substantially less duplicated work than maintaining world geometry in a second sprite.

## Current data and constraints

### World and chunk data

- `Data/Music/MusicData.gd` documents a **12×24 chunk grid** (`x = 0..11`, `y = 0..23`); the explicit declaration now lives in `Data/Overworld/WorldData.gd`.
- `HelperVariables.overworldChunkSize` is **64×64 tiles**. A complete grid therefore contains **768×1536 = 1,179,648 tile cells**.
- `Overworld/Overworld.tscn` uses a large isometric chunk TileMap (`1536×384`), while `MergedTiles` and `OverworldTileChunkTemplate` use the isometric `24×12` tileset.
- The baked `layer_0/tile_data` decode lives in the shared `Overworld/OverworldChunkReader.gd` (extracted from `Overworld.gd`, which now calls it); it returns flat records of `[cellX, cellY, sourceId, atlasX, atlasY, alternative]`. Raw `.tscn` text parsing must not be duplicated.
- `chunkToBaseCell()` (in `Overworld/OverworldCoordinates.gd`, extracted from the old `getChunkBaseCell()`) converts a chunk into shared template-grid coordinates. The decoder's local-to-shared cell conversion includes a `- Vector2i.ONE` offset that must remain in the shared implementation. Note: Godot 4.7's isometric transform is **staggered** (map basis u = (24, 0), v = (+/-12, 6) by row parity), so every conversion goes through the real tile map transforms rather than hand math; chunk base cells form a plain `64*chunk - 1` lattice and the full declared grid spans exactly 768x1536 shared cells.
- At runtime, `MergedTiles` contains only the current chunk and eight neighbours. Chunk scenes are parsed ahead within radius two, but most of the world is not loaded. `MergedTiles` alone therefore cannot produce a complete map.
- The 274 current chunk scenes total roughly 21 MiB of text. **14 of the 288 grid positions have no scene**: `(0,0)-(0,4)`, `(1,0)-(1,4)`, `(7,23)`, and `(8,21)-(8,23)`. Generation must report these and leave them transparent; it must not invent tiles.

### Locations, player, and quests

- Seven current chunk scripts define `locations`: Donnafolk Caves, Bandit Camp, Clearsprings, Twin Creek Mines, Gold Run, Lazysprings, and Clearwater Grove. Each entry has a name, local `tiles`, and `pregenerated`; the first tile is the current Overworld entrance anchor. Donnafolk Caves was once attached to chunks (2,22)/(2,23) as well (duplicate declarations — a data bug, fixed); the manifest still dedupes defensively in case multi-chunk locations ever become intentional.
- `Overworld.gd::setChunk()` instantiates chunk scripts as bare data objects. The same reader can collect Location anchors for a map manifest without adding chunk scenes to the tree.
- The live player is `$Actors/PlayerOverworldActor`. The `Overworld` autoload now owns the exact live/last-known state (`getOverworldMapPosition()`, `registerLivePlayer()`, `clearLivePlayer()`, `storeLastKnownPlayerPosition()`); `spawnChunk`/`spawnTile` stay the re-entry contract and are reseeded from the exact position whenever it is stored, so there is one position instead of three.
- `OverworldChunkStreamCache.dispose()` clears the scene/cell caches on Overworld exit and `Overworld._exit_tree()` releases its coordinates/reader references. Background chunk preloading is a runtime-only optimization and is skipped in headless runs, because `ResourceLoader`'s threaded tasks are not joined before a test process quits.
- `Quests.gd` exposes authoritative active/completed state and `getCurrentMapMarkers()` (Quests stages 1–3, covered by `Tests/TestQuests.gd` and `Tests/TestOverworldMapTab.gd`). `Locations.currentQuest` is only a scene-selection string. MapTab's default provider now reads the Quests autoload and must not parse quest text or cutscene names.
- Zone geometry must come only from the shared `ZoneData.gd`/catalog defined in `Docs/System Design/Overworld Spawns.md`. The map must not add another copy if Zone shading or labels are added.

### Art and UI

- `Docs/Map Outline.aseprite` is a 2880×2160 visual reference. It is not exported as the current runtime map and should not become a second authoritative geometry source.
- Existing map-specific Location/player/quest icons were not found. They remain required assets.
- The Journal shell and shared UI behavior are defined in [Journal](Journal.md).

## Generation approaches evaluated

| Approach | Assessment | Decision |
| --- | --- | --- |
| Maintain a hand-drawn world sprite | Best direct art control, but every chunk/road/river edit can make it stale; comparing it with authoritative geometry is manual | Keep `Map Outline.aseprite` as style reference only; not the base-geometry source |
| Instantiate every chunk in a large `SubViewport` and capture it | Reuses exact tile art, but produces noisy miniature actors/objects, needs a very large world render, couples output to camera/filter settings, and loads all scenes at once | Reject for the Journal map; useful only as a debug visualization |
| Decode the whole world at runtime on first Journal open | Always current, but repeats offline work, loads roughly 1.18 million cells/274 scenes, risks a long stall, and complicates missing/error handling | Reject; use a checked-in bake and stale-asset check |
| One color per chunk | Tiny and useful for Zone/biome readability, but 12×24 cells lose roads, rivers, coastlines, and precise terrain shape | Optional overview/LOD, not the only base map |
| Semantic per-tile raster generated offline | Preserves chunk geometry, allows a clean palette and headless output, supports exact marker projection, and keeps runtime cheap | **Recommended** |
| Draw every tile as polygons in `Control._draw()` each frame | Avoids a texture but repeats over a million draw primitives and makes zoom/pan needlessly expensive | Reject; cache raster output instead |

A semantic bake does not mean the map must look like the gameplay TileMap. Map symbolism should favor biome color, water/road readability, and uncluttered silhouettes over individual decorative tiles.

## Recommended architecture

| Component | Responsibility |
| --- | --- |
| `Data/Overworld/WorldData.gd` | Authoritative chunk-grid rectangle and chunk directory; not Zone geometry |
| `Overworld/OverworldChunkReader.gd` | Shared `PackedScene` tile/script decoding used by streaming and the generator |
| `Overworld/OverworldCoordinates.gd` | Shared chunk/local-tile/shared-cell/world-position conversions |
| `Data/Overworld/MapTileStyles.gd` | Authored source/atlas identity to map color/feature/priority rules |
| `Tools/GenerateOverworldMap.gd` | Headless full-world bake, validation, coverage report, and stale check |
| `Overworld/OverworldMapProjection.gd` | Pure shared-cell/continuous-world-position to generated-image transforms |
| `Data/Overworld/OverworldMapData.tres` | Generated texture reference, projection bounds, source fingerprint, and Location manifest |
| `Assets/Journal/OverworldMap.png` | Generated base image; no dynamic markers baked in |
| `Assets/Journal/OverworldMapOverview.png` | Generated fit-scale LOD of the base image (4×4 cells per pixel) |
| `UI/Journal/Tabs/OverworldMapTab.tscn` / `.gd` | Pan/zoom, player/POI/quest overlays, focus and tooltips |

`WorldData` is world topology, for example `chunk_grid = Rect2i(0, 0, 12, 24)`. It does not duplicate `HelperVariables.overworldChunkSize` or any `ZoneData` bands. The generator iterates that explicit rectangle and reports every present/missing/decode-failed chunk.

The generated resource should contain data equivalent to:

```gdscript
{
    "format_version": 2,
    "texture": "res://Assets/Journal/OverworldMap.png",
    "map_orientation": 1,                # OverworldMapProjection.ORIENTATION_ALIGNED
    "image_size": Vector2i(3072, 1536),  # derived from the projection bounds
    "map_origin": Vector2(...),          # normalizes projected shared-cell coordinates
    "pixels_per_cell": Vector2(4.0, 1.0),
    "chunk_grid": Rect2i(0, 0, 12, 24),
    "source_fingerprint": "...",
    "locations": [
        {
            "id": "Lazysprings",
            "display_name": "Lazysprings",
            "chunk": Vector2i(8, 17),
            "tile": Vector2i(20, 36),
            "cell": Vector2i(530, 1122),
            "image_position": Vector2(2128, 1124),
            "icon": "location",
        },
    ],
}
```

A typed `Resource` is preferable to an untyped Dictionary at runtime, but the fields are the contract. Player/quest state and current Zone are deliberately absent. `format_version` lets the loader reject incompatible generated metadata rather than silently misplacing markers. `format_version` and `map_orientation` use sentinel defaults (`0` / `ORIENTATION_UNSET`) so the generated `.tres` always records them instead of falling back to a class default.

## Shared chunk reading

Extract the existing scene-state decoding from `Overworld.gd` into a reader rather than writing a second parser in `Tools`:

```gdscript
func readChunk(chunk: Vector2i, packedScene: PackedScene) -> Dictionary
# {
#   "cells": PackedInt32Array, # same six-int records as the live chunk cache
#   "locations": Array[Dictionary],
#   "errors": Array[String],
# }
```

- `Overworld.gd` continues to own threaded requests, nearby-scene caches, cell-operation budgets, and `MergedTiles`; the reader only decodes a ready `PackedScene`.
- The generator loads one chunk at a time in sorted `(x, y)` order, reads it, and releases it before the next where possible. It does not call `Overworld.setAdjacentChunks()` or populate the live merged layer.
- Both consumers must share signed 16-bit decoding, the base-cell calculation, and the `-Vector2i.ONE` correction. A generator that produces different cells from live streaming is a test failure.
- Chunk scripts remain bare data instances and are freed after reading. Locations should be normalized to global shared-cell coordinates in the manifest, while retaining `chunk` + `tile` for diagnostics.
- Missing scenes are coverage holes, not decode failures. Malformed tile/script data is an error and should not be silently replaced with plausible terrain.

## Coordinate system and projection

Marker correctness depends on using one coordinate pipeline for baking and runtime. Do not calculate player icons from `currentChunk` alone and do not maintain a separate “map orientation” formula.

### Shared world coordinates

Extract the current formulas into `OverworldCoordinates.gd`, initialized with the actual chunk/template map transforms:

```gdscript
func chunkToBaseCell(chunk: Vector2i) -> Vector2i
func chunkTileToCell(chunk: Vector2i, tile: Vector2i) -> Vector2i:
    return chunkToBaseCell(chunk) + tile - Vector2i.ONE

func chunkTileToWorld(chunk: Vector2i, tile: Vector2i) -> Vector2
func cellToWorld(cell: Vector2i) -> Vector2
func worldToCell(worldPosition: Vector2) -> Vector2i
func worldToCellAndFraction(worldPosition: Vector2) -> Dictionary
func cellAndFractionToWorld(cell: Vector2i, fraction: Vector2) -> Vector2
func worldToCellFraction(worldPosition: Vector2) -> Vector2
```

`chunkTileToWorld()` is the existing spawn-point formula (`chunk map_to_local - Vector2(32*24, 32*6) + template.map_to_local(tile)`), folded into the shared cell so it can never drift from the map anchors. `cellToWorld()` uses the merged/template tile transform. Both live spawning and the map generator must call these helpers rather than copying the constants.

For smooth player motion, `worldToCellFraction()` cannot use `local_to_map()`, which snaps to an integer cell. Build a `Transform2D` from the actual map basis:

```gdscript
var origin = tileMap.map_to_local(Vector2i.ZERO)
var xBasis = tileMap.map_to_local(Vector2i(1, 0)) - origin
var yBasis = tileMap.map_to_local(Vector2i(0, 1)) - origin
var cellFromLocal = Transform2D(xBasis, yBasis, origin).affine_inverse()
var cellFraction = cellFromLocal * localPosition
```

Convert the player's global position into `MergedTiles` local space first. `worldToCell()` returns the actual containing integer cell through `local_to_map()` and is the only world-position input used to reseed re-entry. `worldToCellAndFraction()` returns that cell plus the offset on the cell's own u/v basis, and `cellAndFractionToWorld()` is its exact inverse; this pair is the authoritative sub-cell contract because the staggered grid's per-cell parallelograms overlap and a packed `Vector2` cannot be inverted unambiguously. `worldToCellFraction()` remains a convenience numeric coordinate for the affine map projection only; its value must never be floored to recover a tile.

Implementation note: because the 4.7 isometric transform is staggered (not affine), the fraction is solved on each cell's actual u/v basis instead of one global `Transform2D`. Signed offsets, both row parities, exact axis-half boundaries and row/column crossings are covered by projection tests through the cell+fraction pair. The numeric projection coordinate may still shift at row crossings, which is why it is not an inverse contract. `chunkTileToWorld()` is defined through the cell (`cellToWorld(chunkTileToCell())`), and every live anchor now uses it: the player spawn, the spawn points and the location collision areas (`Overworld.gd` keeps no inline offset formulas of its own).

### Image projection

`OverworldMapProjection` maps a shared cell `(u, v)` through an integer working basis and then an integer downsample. Both implemented orientations share that machinery, the inverse transform, and the marker anchors:

```text
isometric: working = (u - v, u + v)   image = working / (1, 2)   # x = u - v, y = (u + v) / 2
aligned:   working = (4u, v)          image = working / (1, 1)   # x = u, y = v / 4
```

**`ORIENTATION_ALIGNED` is the shipped orientation** (`SHIPPED_ORIENTATION`). In the Overworld `+u` is screen right and `+v` is screen down, and one chunk is spaced 1536×384 world pixels — a 4:1 ratio. Aligned therefore reproduces the world's on-screen silhouette at a 2:1 image ratio, with no 45° rotation: pressing right moves the marker right and pressing down moves it down. `ORIENTATION_ISOMETRIC` keeps the classic diamond for comparison and is selectable with `--orientation=isometric`; the manifest records whichever was baked, so the runtime never guesses.

`map_origin` is stored in generated metadata. The same class handles integer cells and fractional cell coordinates plus the inverse needed for mouse picking/centering; all values stay continuous and markers never use rounded raster pixels.

Rasterization writes a lossless working surface and then downsamples once:

- **Isometric:** each cell writes a 2×1 footprint — its lattice pixel `(u − v, u + v)` plus the `(x + 1, y)` parity hole, which no other cell's lattice pixel can claim — so the surface tiles densely instead of leaving every-other-column stripes. The final image is a vertical 1/2 `Image.INTERPOLATE_BILINEAR` resize.
- **Aligned:** each cell writes a 4×1 block at `(4u, v)`; 4×1 blocks tile the surface exactly, so the downsample is the identity and the bake is lossless end to end.

The working size, per-cell footprint, and downsample are projection details (not runtime metadata); the final image only needs `cell_min`/`cell_max`, `map_orientation`, `map_origin`, and `pixels_per_cell`.

Bounds derive from the **full declared world grid**, including currently missing chunks, so adding a missing edge chunk never shifts the image or any marker. With 768×1536 cells the shipped aligned image is **3072×1536 pixels** (`4 × 768` wide, `1 × 1536` tall), and the retained isometric variant is 2304×1152. RGBA8 storage is about 18.9 MiB for the aligned bake before PNG compression or mipmaps — acceptable for a build-time asset; increase scale only if zoom evidence requires it.

The aligned shape also removes wasted pixels: the isometric diamond leaves roughly half of its 2304×1152 image transparent, while the aligned rectangle is almost entirely world. At the same fit box that gives terrain noticeably more screen area.

Location anchors use `chunkTileToCell(chunk, tiles[0])` and then the same projection. The player uses `worldToCellFraction()` and the same projection, so both remain aligned at every pan/zoom level. Marker icons anchor their bottom-center/feet point to the projected position; their texture dimensions do not affect world coordinates.

### Projection tests required before generation

- Both orientations cover every world-grid corner with their footprint unclipped; cell footprints never overlap and a full chunk tiles its working area exactly.
- Adjacent local tiles across each chunk seam produce adjacent global cells, with no duplicated row/column or one-cell gap.
- `chunkTileToWorld()` agrees with `cellToWorld(chunkTileToCell())` for known anchors, including Lazysprings `(8,17)/(20,36)` and the initial player spawn `(8,12)/(40,38)`.
- Fractional player world positions round-trip exactly through `worldToCellAndFraction()`/`cellAndFractionToWorld()` for signed `±u`/`±v` offsets, exact axis-half boundaries, row/column crossings and both staggered row parities. `worldToCell()` agrees with the TileMap's containing cell, `worldToCellFraction()` stays consistent with the pair, and re-entry preserves the containing cell rather than flooring the numeric fraction.
- Negative shared-cell coordinates project correctly.
- `+u` always moves right and `+v` always moves down in image space for the shipped aligned orientation.
- Unknown orientation ids/names are rejected; `cellForGrid()` defaults to the shipped orientation.
- The same projection transforms baked POIs and live markers; there is no UI-only correction offset.

## Semantic tile styling

Tile source/atlas identity is stable generator input; decorative texture pixels are not a reliable map legend. `MapTileStyles.gd` maps `(sourceId, atlasX, atlasY)` to `{ "color", "feature", "priority" }`, where `feature` is one of `ground | water | forest | swamp | mountain | cliff | track | powerline | structure`. Rocks and cliffs are separate features (cliffs are the darker impassable ones), and the linear tiles are separate too: **train tracks** are `track` and **power lines** are `powerline` — there are no road tiles in the tilesets yet.

**The palette is authored, not sampled.** The original prototype averaged each tile's bottom pixel band, which for these atlases is the isometric tile's *dirt front face* — Grasslands therefore rendered in the canyon's orange and every source collapsed to one flat color. The shipped table is built from deliberate art direction:

```gdscript
const SOURCE_GROUND := { 1: Color("d08a3a"), 3: Color("86a03a"), ... }   # biome ground per source
const FEATURE_COLORS := { FEATURE_WATER: Color("2f6f9f"), ... }          # shared feature colors
const TERRAIN_FEATURES := { "train tracks": FEATURE_ROAD, ... }          # tileset terrain authoring
const SOURCE_ROW_FEATURES := { 2: { 1: FEATURE_MOUNTAIN, ... } }         # audited atlas rows
const SOURCE_RANGE_FEATURES := { 3: { 0: [[0, 2, FEATURE_GROUND], ...] } } # mixed rows split by tile
const KEY_FEATURE_OVERRIDES := { ... }                                   # per-key exceptions
const KEY_COLOR_OVERRIDES := { ... }                                     # per-key color exceptions
```

Every tile that exists in the tileset is classified, in order, by:

1. an explicit per-key override,
2. the tileset's own terrain authoring (`water`, `train tracks`, `powerlines`, `fences` — terrain and walkability stay separate concerns),
3. the audited per-source atlas-row table (rock/boulder bands, vegetation bands, water bands),
4. otherwise the source's biome ground color.

Because coverage is derived from the tileset, a newly added tile always has a style; only genuinely unknown keys (a tile removed from the tileset but still referenced) fall back to the conspicuous magenta development color and are reported by the generator.

Current classification, verified by `--palette-report` (whole-world bake counts). The authored per-row reference is [Tileset Classification](Tileset%20Classification.md), which is the source of truth for what each tileset row depicts:

| Source | Classification |
| --- | --- |
| 0 Overworld Locations | not in the doc; prop tiles (ground/rocks/water/structures), 18 cells total |
| 1 Grande Cañón | 96% grass, 4% rocks (row 2) and cliffs (row 3) |
| 2 Rocky Hills | 55% grass (rows 1, 4), 45% rocks (rows 2, 5) and cliffs (row 3 solid tiles) |
| 3 Grasslands | 45% grass, 44% forest (rows 1-3), 10% swamp (row 10), 1% water (rows 9, 11), plus fences and powerlines |
| 4 Prairie | 76% grass, 23% forest (row 3 tiles 1-6, 10), 1% rocks (row 2) and cliffs (row 3 tiles 7-9) |
| 5 Wild West | 99% grass, plus rocks (row 2), forest (row 3 tiles 5-9), train tracks (row 4), powerlines (row 6), water (rows 5, 7) |
| 6 Snowy Mountains | 61% snowy ground, 39% rocks (row 2) and cliffs (row 4 tiles 1-3), tents (row 3 tiles 1-4), water (row 4 tiles 4-5) |

Whole-world feature totals: ground ≈806k cells, forest ≈126k, cliff ≈84k, mountain ≈80k, swamp ≈21k, water ≈3.7k, track 400, structure 306, powerline 166.

Rows that mix features are split by tile range in `SOURCE_RANGE_FEATURES` (for example Grasslands row 1 is tiles 1-3 grass, 4-11 forest, tile 12 a cliff), so a row does not have to be classified as a whole. Rocky Hills' green rows are **grass**, not forest — its forest-looking tiles are grass-covered rock.

Rules:

- `--palette-report` prints per-source key/style counts, the dominant style share, per-feature cell shares, the top keys, and a feature summary. It flags any source where every encountered key collapses to one style — the check the flat Grande Cañón/Rocky Hills regions failed — and exits nonzero when it finds a collapsed source or an unknown key.
- Do not average whole 24×48 source textures automatically: transparent pixels, tall props, animation frames, and the dirt front faces produce misleading colors. Average-color experiments inform the authored table (`--survey` prints them alongside the authored result) but never ship as the palette.
- Use ground/biome fills as the base, with explicit water and linear-feature styles. Terrain sets describe only powerlines/train tracks/fences/water and are not a complete map classification, so the atlas-row table covers rock, vegetation, and structure bands.
- Optional coast/road outlines are generated from neighboring cell styles after all cells are read. They must be computed deterministically, not painted manually.
- Optional Zone tint/borders read the shared Zone catalog and include `ZoneData` in the source fingerprint. They are polish, not required for the first bake.
- `Docs/Map Outline.aseprite` can guide palette, border, paper treatment, and labels. Decorative Journal frames may be hand-drawn independently because they contain no authoritative geography.

## Bake pipeline

`Tools/GenerateOverworldMap.gd` should be a `SceneTree` script that runs without opening the game or a rendering window:

```sh
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --check
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --require-complete
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --preview --orientation=aligned
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --palette-report
```

### Exit status and fail-closed policy

Every mode shares one exit-status policy:

- **Exit 0 only when the requested mode's validation passes.** A normal bake, `--check`, `--survey`, `--palette-report` and `--preview` all report decode failures, bake errors, out-of-grid cells and invalid Location anchors as nonzero.
- `--require-complete` is nonzero while any declared chunk is missing; `--strict` is nonzero on unstyled tile keys or overlapping seam cells.
- `--palette-report` is nonzero when any source collapses to a single style or any encountered key has no authored style.
- **Invalid CLI input fails before any work.** An unknown argument or unknown `--orientation=` name exits nonzero and refuses to bake or write, rather than warning and continuing with the shipped orientation.
- **Writes only happen after validation passes.** Normal generation writes the PNGs/manifest only at exit 0, and `--preview` writes its `.godot` composites only at exit 0. Missing chunks alone are still coverage holes, not errors, unless `--require-complete` is requested.

`Tests/TestOverworldMapCli.gd` runs each mode as a real child process and asserts the exit codes, the failure messages, and that no mode changes the committed generated outputs (18 checks).

### Regenerating the checked-in map

Run these commands from the project root with the Godot 4.7 executable on `PATH` (or substitute its full executable path):

1. After changing chunk scenes/scripts, shared coordinates/projection, orientation, or `MapTileStyles.gd`, run the normal generator command above. It bakes in memory and writes `Assets/Journal/OverworldMap.png` and `Data/Overworld/OverworldMapData.tres` only when their contents changed. Do not edit either generated output manually.
2. If the PNG dimensions changed (orientation or scale change) — or an output PNG is brand new and not imported yet — reimport before testing: `godot --headless --path . --import`, or open the project in the editor. `MapTab` validates the imported texture size against `image_size`/`overview_image_size`, and the manifest can only reference an imported texture, so a brand-new output needs an import pass followed by a second generator run.
3. Read the console report. Check present/missing/failed chunk counts, unknown styles, out-of-grid cells, seam overlaps, the Location list and the overview size before accepting the output. The current baseline is 274 present chunks, 14 intentional holes, seven Locations, 37 known seam overlaps, and a 192×384 overview.
4. Run `--check` to verify that both committed outputs match a fresh bake. A fingerprint-only mismatch still requires regeneration after shared bake/coordinate code changes.
5. Use `--strict` when checking for unknown styles and seam overlaps. It currently fails intentionally on the 37 known overlaps. Use `--require-complete` only when the 14 missing chunks are no longer intentional; it is expected to fail against the current world.
6. When new tile keys need classification, `--survey` prints encountered source/atlas keys, counts, terrain tags, sampled tile colors and the authored result. Treat its averaged colors as diagnostic input only; the shipped palette is authored in `MapTileStyles.gd`.
7. After touching the palette or tileset, run `--palette-report`. It lists per-source key/style counts, dominant style share, per-feature cell shares and the top keys, and fails loudly on any source that collapses to a single style or on unknown keys.
8. To compare orientation candidates, run `--preview --orientation=isometric` and `--preview --orientation=aligned`. This writes `res://.godot/overworld_map_preview_<orientation>.png`, a `_fit.png` composite at the real 640×360 Journal fit scale, and leaves the committed outputs untouched. The shipped orientation is `OverworldMapProjection.SHIPPED_ORIENTATION` (currently aligned); changing it requires a normal regeneration because the manifest records it.
9. Inspect the PNG and then the actual Journal at 640×360, including fit and close zoom. Source-PNG inspection alone does not validate fit-scale readability. Commit the regenerated PNG and manifest together; retain the PNG import metadata, changing it only when import settings intentionally change.

The game does not run these commands. They are development/build-time steps, not runtime recovery procedures.

### Inputs and outputs

Inputs are `WorldData`, every declared chunk path, chunk scripts, `MapTileStyles`, the selected orientation, the shared coordinate/reader version, and `ZoneData` only if Zone styling is enabled. Outputs are:

- `Assets/Journal/OverworldMap.png` (RGBA8, transparent outside world/holes).
- `Assets/Journal/OverworldMapOverview.png` (RGBA8) — the fit-scale LOD of the same map, one pixel per 4×4 cells.
- `Data/Overworld/OverworldMapData.tres` (texture, projection, grid, fingerprint, POIs).
- A console coverage report; optionally a small generated text report for CI diagnostics.

The PNG, resource, and Godot import metadata are checked in. The game never runs the tool and does not need every chunk scene loaded to show the Journal.

### Algorithm

1. Load world/style data and construct the theoretical full-grid cell bounds and image projection. Initialize an empty RGBA8 `Image` and a `PackedInt32Array` of `768 × 1536` style ids (zero = no cell).
2. For each chunk in sorted order, report missing or load/decode it through `OverworldChunkReader`. Convert each cell to a shared cell, then to a zero-based full-grid index using the generated grid origin.
3. Resolve source/atlas/alternative to an integer style id and store it in the typed style array. A second write to an occupied index is reported as an authoring overlap and resolved deterministically (the later chunk in sorted order wins) — the current world data carries 37 such seam overlaps, invisible in live streaming because the merged layer simply overwrites; `--strict` fails on them. Out-of-grid cells are also errors.
4. Collect Location entries, validate unique ids/non-empty tiles, and project their first entrance tile. Preserve a generic visible Location icon by default until per-Location map metadata exists.
5. After every chunk is read, write each present cell once to the working image with `Image.set_pixel()` using the working projection above, then downsample to the final image with `Image.INTERPOLATE_BILINEAR`. Do not use viewport drawing or texture sampling.
6. Aggregate the style grid into the overview LOD (see below) and build the manifest, source fingerprint and outputs; print counts for present/missing chunks, present cells, unknown styles, POIs, image bounds, overview size and output paths.

The typed style grid is about 4.5 MiB rather than a Dictionary with over a million entries. It also makes neighbor/coast calculations straightforward. Missing chunks remain zero/transparent. `--require-complete` turns any missing declared chunk into failure; ordinary generation and `--check` still report the current 14 holes without blocking incremental world work.

### Overview LOD (fit-scale readability)

Per-cell coloring is faithful but reads as speckle at whole-world fit scale, because the tileset interleaves ground/forest/rock variants for visual variety and a fit-scale cell is well under one screen pixel. The bake therefore also writes `Assets/Journal/OverworldMapOverview.png`: one output pixel per **4×4 cells**, chosen deterministically from that block:

- **Thin, absolute features win with any presence** — `water`, `track`, `powerline` — so rivers and the rail/power lines survive generalization instead of being averaged away.
- **Area features** (`forest`, `swamp`, `mountain`, `cliff`, `structure`) need `LOD_AREA_SHARE` (30%) of the block, so scattered foliage does not flood the plains.
- Among qualifying features the higher style **priority** wins (cliff over forest, structure over everything), and the block's most common style within that feature supplies the color.
- Blocks with less than `LOD_MIN_FILL_SHARE` (25%) real cells stay transparent, so missing chunks keep their shape.

The overview shares `map_origin` and the detailed map's image coordinate space: its drawn scale is `image_size / overview_image_size` (currently `3072×1536` detailed over `192×384` overview = 16×4), so markers and POIs never move when the runtime switches between them. `--preview` writes a fit-scale composite of both textures for side-by-side review.

### Determinism and stale detection

- Sort chunks, style keys, and POIs before output. Never depend on filesystem or Dictionary iteration order.
- The source fingerprint covers sorted chunk paths/content (including additions/deletions), chunk scripts, world/style data, generator/projection/reader versions, and shared Zone data when used.
- Normal generation writes only when output changed. `--check` performs the same bake in memory/temporary output and fails if either committed PNG or the metadata differs, so manual edits to generated output are also detected. Manifest texture references are compared by resource path, so a manifest that lost or re-pointed them is stale.
- Decode errors, out-of-grid cells, invalid Location anchors, and projection failures always fail. Overlapping seam cells are reported and resolved deterministically (see the algorithm); `--strict` treats them as failures. Unknown style policy is configurable during palette development and strict afterward.
- A useful CI command is `--check`; add `--require-complete` only when missing chunks are no longer intentional.

The first visual prototype should generate the complete base and inspect it beside `Map Outline.aseprite` at actual Journal fit scale before investing in labels or decoration. Fine detail that becomes noise at fit scale is handled by the overview LOD above rather than by increasing runtime work.

### Import and filtering

Generate mipmaps for the base PNG so fit-to-window downsampling does not shimmer or erase all terrain contrast. Use filtered/mipmap display for the zoomed-out base and nearest sampling at integer close-zoom levels if that reads better. Marker textures stay nearest-filtered and are not mipmapped with the base. Validate actual readability in the 640×360 Journal rather than judging the source PNG at 100%.

## Runtime map scene

A regular clipped `Control` is sufficient; no `SubViewport` is needed unless later effects require one.

```text
OverworldMapTab (Control)
└── MapPanel
    ├── MapClip (Control, clip_contents = true, fills the tab)
    │   └── MapContent (Control)
    │       ├── BaseMap (TextureRect: detailed map or overview LOD)
    │       └── MarkerLayer (Control)
    │           ├── LocationMarkers
    │           ├── QuestMarkers
    │           └── PlayerMarker
    ├── MapControls (zoom out, zoom in, fit, center player — overlaid on the map)
    └── MarkerTooltip / SelectionPanel
```

The map fills the whole tab content area; the shortcut buttons are a small overlay in the top-left corner rather than a separate row, so no map space is spent on chrome.

`MapContent` holds base texture and marker positions in image coordinates. Pan changes its position; zoom changes its scale around the cursor/focus point. Fit scale is `min(availableWidth / imageWidth, availableHeight / imageHeight)`. Clamp zoom and keep the map within sensible pan bounds while allowing its edges to be reached.

Markers should remain a consistent **screen-space size** rather than shrinking with the base texture. Recompute each marker's position from map coordinates after pan/zoom and counter-scale its icon, or keep icons in a separate screen-space overlay fed by the projection. Focus/hover targets likewise remain usable at fit scale.

`BaseMap` swaps between the detailed map and the overview LOD: the overview is used while `_mapScale <= _fitScale * 2.5` and the detailed texture above it, so the zoomed-out view shows generalized terrain instead of speckle and the zoomed-in view shows per-tile detail. The overview is drawn at `image_size / overview_image_size`, so both textures occupy the same coordinate space and the switch is invisible to markers. `BaseMap` is `MOUSE_FILTER_IGNORE`; the map clip owns all map input.

Initial behavior:

- First open fits the whole map and makes the player icon visually distinct (for example, a subtle pulse). “Center player” switches to a useful close zoom.
- Mouse drag pans (implemented as a per-frame cursor poll — “left held over the map” arms the drag — because grabbed press/motion `gui_input` delivery proved unreliable across engine grab semantics); wheel/buttons zoom. Keyboard/controller can pan, zoom, fit, center, and cycle POIs: arrows/D-pad pan, `MAP_ZOOM_IN`/`MAP_ZOOM_OUT` (`=`/`-`, controller shoulders) zoom, `MAP_POI_NEXT`/`MAP_POI_PREV` (`]`/`[`, controller Y/X) cycle Locations in image order through `focusTarget()`, `MAP_CENTER_PLAYER` (`C`, controller A) centers on the player, and `F` fits (controller: zoom out to the minimum, which clamps at fit). Shortcut buttons and markers use `FOCUS_NONE` so focus traversal never hops between them, and the focused map clip consumes map input through `gui_input`. Shell focus handoff: the Journal points the TabBar's down focus neighbour at the tab's `getFocusTarget()` (the map clip), so D-pad down enters map panning; `ui_cancel` from the map returns focus to the TabBar while keeping the Journal open, and the next `ui_cancel` closes it. An unhandled-input fallback still drives the map when focus sits elsewhere, so map actions work from the TabBar. Map input must not leak to player movement or Journal tab shortcuts.
- POI names can use hover/focus/selected labels instead of displaying every label at once. Add a legend only if the final icon set is not self-explanatory.
- A quest “Show on map” request selects the tab, centers the target, and focuses/pulses the exact quest/objective marker through the Quests design's dedicated navigation path without altering quest state.

## Live data and markers

### Player position provider

**Implemented** (step 6) in `Globals/Overworld.gd` — a small Overworld-owned provider API rather than the map searching `current_scene` every frame:

```gdscript
func getOverworldMapPosition() -> Dictionary
# {
#   "valid": bool,
#   "world_position": Vector2, # in the shared Overworld/MergedTiles frame
#   "is_live": bool,           # false when retained after leaving the Overworld
# }
```

- While the Overworld is active, the scene registers `$Actors/PlayerOverworldActor` (`registerLivePlayer()` in `init()`, placed through `chunkTileToWorld()`) and the provider returns its exact `global_position` live.
- When the Overworld leaves the tree — `enterLocation()` or any other transition — `Overworld.gd::_exit_tree()` calls `clearLivePlayer()`, which stores the exact last known position first (`_exit_tree` covers every destruction path, not just location entry). Registration on first entry also initializes the state from the spawn placement; before any entry the provider falls back to the `spawnChunk`/`spawnTile` anchor.
- `spawnChunk`/`spawnTile` remain the re-entry contract, but every store reseeds them from the exact position's actual containing cell (`cellToChunkTile(worldToCell(...))`), so re-entry and the marker share one position instead of three. Unification is tile-centered: sub-tile offsets are not part of the re-entry contract, so re-entry places the player at the containing tile's center — never a stale/default spawn or a neighboring tile produced by flooring a signed marker fraction.
- The map refreshes a live marker at a modest rate (10 Hz) only while its tab is active. A stationary/last-known marker needs no polling.
- If no valid position exists, the player marker is hidden and reported as an empty state; it never defaults to `(0,0)` or the map corner.

### Location POIs

Load POIs from generated `OverworldMapData`, not from currently loaded `$Locations` nodes. The manifest covers the whole world and survives scene changes. All current Locations are visible initially; there is no fog/discovery filter until that feature is explicitly designed.

The existing Location name is the initial stable id. Before renaming a Location, introduce/maintain a stable id rather than matching display text. Optional per-Location fields such as `map_visible`, `icon`, and `map_label` belong with its chunk Location data and flow through the generator. Unknown icons fall back to the generic Location icon with a content warning.

POIs never bake into the PNG. Selecting one shows its name and basic type; it does not teleport, enter the Location, or set a quest target.

### Current quest targets

The quest system should expose an array so the UI does not assume there can only ever be one marker. The [Quests tab design](Quests.md) defines the shared state and quest/objective-aware navigation contract:

```gdscript
func getCurrentMapMarkers() -> Array
# [{
#   "quest_id": String,
#   "objective_id": String,
#   "target_id": String,  # stable Location/key-point id
#   "icon": "quest_current",
# }]
```

- Only current/active objectives produce markers; completed objectives do not.
- `target_id` resolves through the generated Location/key-point manifest. Quest data does not duplicate map coordinates.
- Targets are always key points, per the feature requirement. Do not accept enemy-party nodes, arbitrary actor paths, cutscene scene names, or free-moving positions.
- Unknown/inactive targets produce a quest-data warning and no marker. They must not move the player icon or appear at `(0,0)`.
- If a quest marker shares a Location anchor, keep the Location icon at the anchor and layer the quest badge above it. Both remain independently selectable through `focusTarget()` (Location/POI) and `focusQuestTarget()` (exact quest/objective), with the current quest visually prioritized.
- The Quests tab and Map consume the same authoritative current-objective state. `Locations.currentQuest` and `Quests.currentMainQuestLevel` are not sufficient substitutes.

MapTab now reads `Quests.getCurrentMapMarkers()` by default and keys badges by `quest_id:objective_id`, so multiple objectives may share one target without overwriting each other. Unknown, malformed, or duplicate entries are rejected without creating an origin marker. An injected `questMarkerProvider` remains the test seam; do not hardcode introductory quest targets in the map tab.

## Runtime refresh and failure behavior

- On tab activation, validate `format_version`, texture, projection, and manifest once; build POI markers; refresh quest markers; connect the quest-state signal source; then refresh the player marker.
- On deactivation/scene exit, disconnect quest signals and stop timers/tweens. Repeated Journal opens must not duplicate markers or listeners.
- Player/quest updates change only markers, never the base texture or generated resource.
- A missing/corrupt generated asset shows a readable “Map data needs regeneration” state and logs the tool command. Do not attempt a blocking full-world runtime bake as a fallback.
- Pan/zoom, marker hit testing, and labels operate in one transform space. Add automated screen-coordinate tests rather than tuning icon offsets manually at one zoom.

## Files to create / modify

**Shared data and generation**

- `Data/Overworld/WorldData.gd` — declared 12×24 world-grid rectangle and chunk directory.
- `Data/Overworld/MapTileStyles.gd` — semantic source/atlas map styling.
- `Docs/System Design/Journal/Tileset Classification.md` — authored per-row reference for what each tileset row depicts (1-based rows).
- `Overworld/OverworldChunkReader.gd` — shared chunk scene/script decoder, extracted from `Overworld.gd`.
- `Overworld/OverworldChunkStreamCache.gd` — chunk scene/cell caches, background-parse bookkeeping, the budgeted merged-layer write queue and bounded eviction, extracted from `Overworld.gd`.
- `Overworld/OverworldCoordinates.gd` — shared chunk/tile/cell/world transforms, also reusable by dynamic spawns.
- `Overworld/OverworldMapProjection.gd` — pure generated-image transforms.
- `Tools/GenerateOverworldMap.gd` — headless bake/check/report tool.
- `Assets/Journal/OverworldMap.png` and import metadata — generated base.
- `Assets/Journal/OverworldMapOverview.png` and import metadata — generated fit-scale LOD.
- `Data/Overworld/OverworldMapData.tres` — generated projection and POI manifest.
- Location/player/current-quest icons under `Assets/UI/Journal/` or the existing icon folder.

**Runtime UI and providers**

- `UI/Journal/Tabs/OverworldMapTab.tscn` and `.gd` — display, transforms, markers, focus, and tooltips.
- `project.godot` — `MAP_ZOOM_IN`/`MAP_ZOOM_OUT`/`MAP_POI_NEXT`/`MAP_POI_PREV`/`MAP_CENTER_PLAYER` actions (keyboard + controller).
- `Overworld/Overworld.gd` and `Globals/Overworld.gd` — shared reader/coordinates integration and exact last-known player position.
- `Globals/Quests.gd` — `getCurrentMapMarkers()` and `questStateChanged`, shared with the Quests tab (implemented in Quests stages 1–3).
- `Docs/System Design/Journal/Journal.md` — shell integration remains the parent design.

**Tests**

- `Tests/TestOverworldMapProjection.gd` — coordinates, bounds, seams, fractional positions, both orientations' footprints/inverses, and headless map ownership.
- `Tests/TestOverworldMapGeneration.gd` — small synthetic chunks, malformed tile data, authored-palette classification/coverage, plus real-data coverage/report checks.
- `Tests/TestOverworldMapTab.gd` — markers, pan/zoom, providers, orientation/manifest validation, the committed artifact contract, disposal/rebuild and failure states with fake data.
- `Tests/TestOverworldChunkStream.gd` — the extracted streaming caches: queue replacement/drain, budgeted writes, queued erase of an unloaded chunk, the unload rule, cache bounds over a long traversal, and the shared-anchor collision diamond.

## Testing and acceptance

### Generator and data

- The shared reader returns identical cells for representative chunks whether called by streaming or the generator; no second decoder exists.
- All 288 declared chunk positions are reported. The current 274 present/14 missing counts are understood, missing cells are transparent, and `--require-complete` fails.
- Synthetic fixtures cover empty chunks, malformed data, duplicate seam cells, unknown tiles, alternatives, negative coordinates, and duplicate/empty Location anchors.
- Two unchanged bakes produce byte-equivalent PNG/metadata. Chunk, style, script, and coordinate changes trigger `--check`; unrelated dynamic player/quest state does not.
- Output bounds remain stable when an edge chunk changes from missing to present.
- Every encountered tile has a style in strict mode; roads/water and world silhouettes are inspected at actual fit scale.
- The current seven Location anchors are present exactly once (multi-chunk declarations dedupe to the first) and match their chunk/tile data.

### Runtime

- Player/POI/quest markers align with the same world anchor at fit, maximum zoom, and after panning; fractional player movement is smooth.
- Entering a Location preserves the exact last Overworld marker; returning does not reset it to a stale/default spawn.
- Current quest changes add/remove only the correct key-point markers. Completed/unknown targets produce no origin marker.
- Marker sizes/hit areas remain usable at every zoom; overlapping Location/quest targets can both be focused.
- Repeated Journal/tab activation creates no duplicate markers, timers, signal connections, or full-world chunk loads.
- Mouse and keyboard/controller can pan, zoom, fit, center, and inspect markers at 640×360 without input leaking to gameplay.
- Missing/stale generated data shows the regeneration error state rather than crashing or stalling on a runtime bake.

### Manual visual review

Compare the generated silhouette and major features with `Map Outline.aseprite` and actual gameplay. Inspect each Zone, current missing edges, rivers/roads, Lazysprings/Clearwater Grove, and the initial player spawn. Use `--preview --orientation=isometric|aligned` when judging the map's shape, because the preview writes a fit-scale composite at the real 640×360 Journal size. This review validates map art/readability, not coordinate correctness; the automated projection tests remain authoritative for alignment.

## Implementation order

1. ✅ Extract/test `OverworldChunkReader` and `OverworldCoordinates` without changing live streaming behavior; add explicit `WorldData`. (`Tests/TestOverworldMapGeneration.gd` keeps the original decode as its oracle; `SceneManagerTest` covers live streaming.)
2. ✅ Build projection tests and a small semantic-style fixture generator. Validate full-grid bounds and chunk seams before reading the entire world. (`Tests/TestOverworldMapProjection.gd`, synthetic bake fixtures in `Tests/TestOverworldMapGeneration.gd`.)
3. ✅ Implement the headless bake/report and an initial complete tile palette. Generate the full map, inspect fit-scale readability, and adjust the art rules. (`Tools/GenerateOverworldMap.gd` + `Tools/OverworldMapBaker.gd`; the palette is the survey-generated prototype — the fit-scale art review is still pending.)
4. ✅ Add generated metadata/POIs, deterministic fingerprints, `--check`, and checked-in outputs. (`Data/Overworld/OverworldMapData.tres` — typed manifest; `--check` compares committed PNG + manifest against a fresh in-memory bake; the fingerprint covers chunk scenes/scripts, the tileset, world/style data and the shared bake code.)
5. ✅ Add the Journal map tab, fit/pan/zoom, constant-size markers, and generated POIs. (`UI/Journal/Tabs/MapTab.gd`/`.tscn` + `Tests/TestOverworldMapTab.gd`; the player marker runs on the injectable position provider, whose default is the Overworld autoload's last-known spawn until step 6.)
6. ✅ Add exact live/last-known player state and unify it with Overworld re-entry where practical. (`Globals/Overworld.gd` provider + `Overworld.gd` registration/`_exit_tree` snapshot; `OverworldCoordinates.cellToChunkTile()` reseeds `spawnChunk`/`spawnTile` from the exact position; live spawn placement now uses `chunkTileToWorld`. Covered by `Tests/TestOverworldMapTab.gd` and the scene-run checks in `Nodes/Scene Manager/Test/SceneManagerTest.gd`.)
7. ✅ Quest key-point API and Map wiring complete (Quests stages 1–3): `Quests.getCurrentMapMarkers()`, the real default provider, `quest_id:objective_id` marker identity, exact `focusQuestTarget()`, and active `questStateChanged` refresh, covered by `Tests/TestQuests.gd`, `Tests/TestOverworldMapTab.gd` and the real-shell navigation check in `Tests/TestJournal.gd`.
8. ✅ Baseline hardening (coordinate-map ownership/disposal, malformed-chunk rejection, fail-closed manifest validation, complete MapTab disposal, regenerated manifest, 69 MapTab checks).
9. ✅ Resolve map orientation. `OverworldMapProjection` now shares one integer-basis working surface between `ORIENTATION_ISOMETRIC` (unchanged 2304×1152 diamond) and `ORIENTATION_ALIGNED` (3072×1536, `+u` right / `+v` down, matching the Overworld's 4:1 chunk spacing). The manifest records `map_orientation` at format version 2, the runtime rebuilds from it and rejects unknown values, `--orientation=`/`--preview` generate side-by-side candidates at real fit scale, and both orientations are covered by projection tests. **Aligned is shipped** after the fit-scale comparison; isometric remains selectable for in-game sign-off. (`Tests/TestOverworldMapTab.gd` is at 72 checks; `--check` is current.)
10. Next: fit-scale outlines/LOD, non-mouse input, streaming/coordinate hardening, and quests. Revisit whether to delete the unused orientation after in-game sign-off.
11. ✅ Author the semantic terrain palette. `MapTileStyles` now builds a complete table from deliberate biome ground colors plus shared feature colors, classified by per-key overrides → tileset terrain authoring → audited atlas rows → biome ground, instead of sampling each tile's dirt front face. `--palette-report` audits per-source style spread, dominant share, features and top keys and flags collapsed sources; tests assert distinct biome colors, distinct Grande Cañón/Rocky Hills keys (classification and baked pixels), terrain-tag precedence and full tileset coverage. The regenerated map no longer paints Grasslands in canyon orange, Snowy Mountains as water blue, or Rocky Hills as flat gray.
12. ✅ Follow-up palette audit (forest and Snowy Mountains rock). Verified against the actual chunks rather than the atlases alone: the pine-forest chunks are built from Rocky Hills row 3 (green foliage) and Wild West row 2 (bushes), which were classified as ground, and Snowy Mountains' 48,866-cell crystal row was flat ice. The row table now maps those to `forest` and `mountain`, corrects the Grasslands/Wild West water rows, and the report shows forest ≈260k cells (29 keys) with no collapsed source. Tests cover Rocky Hills/Wild West forest, Snowy Mountains rock, and the water rows.
13. ✅ Rewrite the classification from the authored reference. [Tileset Classification](Tileset%20Classification.md) (written from the sprites) replaced the atlas-row guesses: Rocky Hills' green rows are grass, Grasslands rows 1-3 and Prairie/Wild West/Snowy partial rows are forest, Grande Cañón row 3 and Rocky Hills row 5 are rocks/cliffs, Grasslands row 10 is a new `swamp` feature, and Snowy Mountains rows 2/4 are rocks/cliffs with a water split. `SOURCE_RANGE_FEATURES` allows a single row to split by tile range (Grasslands row 1 = 3 grass, 8 forest, 1 cliff). Tests assert every documented split plus the swamp/water/rock distinctions.
14. ✅ Split rocks/cliffs and the linear features. `cliff` is its own feature (darker than `mountain`) for Grande Cañón row 3, Rocky Hills row 3 solid tiles, Prairie row 3 tiles 7-9, Snowy Mountains row 4 tiles 1-3 and the tall Grasslands tile; the former `road` feature is replaced by `track` (train tracks) and `powerline` (power lines), since no road tiles exist yet. Corrections from the authored doc applied: Prairie row 3 tile 10 is grass, Snowy Mountains row 4 is 3 cliffs + 2 water animation frames, Wild West row 3 tiles 5-9 stay forest, Rocky Hills row 3 tile 10 is grass. Tests cover each new feature and the corrected splits.
15. ✅ Overview LOD for fit-scale readability. `OverworldMapBaker.bake()` can aggregate the style grid into an overview (one pixel per 4×4 cells) with the documented feature/priority/share rules; `GenerateOverworldMap` writes `Assets/Journal/OverworldMapOverview.png`, records it in the manifest, checks both PNGs in `--check`, and `--preview` writes a fit-scale composite of both. `MapTab` swaps between the overview and the detailed map at 2.5× fit scale, in one shared coordinate space so markers never move. Tests cover the aggregation rules, overview validation and the runtime switch.
16. ✅ Non-mouse operation and the overlaid-controls layout. The `MAP_*` actions add keyboard/controller zoom, POI cycling and center-on-player; POI cycling reuses `focusTarget()` and wraps in both directions; the map clip fills the whole tab with the shortcut buttons overlaid on its top-left corner. Tests cover wheel delivery, both zoom keys, controller shoulders, POI cycling order/wrap through the real input path, the layout, and focus behaviour.
17. ✅ Second-review iteration step 1 — containing-cell re-entry and the signed sub-cell contract. `OverworldCoordinates` adds `worldToCell()` (the TileMap's actual containing cell) and the exact `worldToCellAndFraction()`/`cellAndFractionToWorld()` pair; `worldToCellFraction()` is now documented as projection-only because the staggered grid's overlapping per-cell parallelograms make a packed `Vector2` non-invertible. `Globals/Overworld.gd` reseeds re-entry from `worldToCell()` instead of flooring a signed fraction. `Tests/TestOverworldMapProjection.gd` covers signed `±u`/`±v` offsets, exact axis-half boundaries, row/column crossings and both row parities; `Tests/TestOverworldMapTab.gd` adds an off-center exit/re-entry check (98 checks). The manifest was regenerated for the shared-code fingerprint change (both PNGs unchanged) and `--check` is current.
18. ✅ Second-review iteration step 2 — Journal-to-map controller focus handoff. `MapTab.getFocusTarget()` exposes the map clip, `Journal._wireTabFocus()` points the TabBar's down focus neighbour at the active tab's target (and the target's up neighbour back at the TabBar), and `ui_cancel` from focused tab content returns focus to the TabBar before a later `ui_cancel` closes the Journal. `Tests/TestJournal.gd` exercises the real shell at 640×360: D-pad down enters the map, D-pad pans without switching tabs, back returns to tab switching, and closing from the TabBar still works (95 checks). `Tests/TestOverworldMapTab.gd` covers the focus-target contract (100 checks).
19. ✅ Second-review iteration step 3 — fail-closed generator CLI. `Tools/GenerateOverworldMap.gd` now tracks invalid CLI input (`_cliError`) and refuses to bake or write on an unknown argument/orientation; all modes share `_commonExitCode()` (decode failures and `--require-complete`) and `--palette-report` returns failure for collapsed sources or unknown keys. `--preview` writes its `.godot` composites only on a clean validation, and normal generation still writes only at exit 0. `Tests/TestOverworldMapCli.gd` runs each mode as a real child process and asserts exit codes, failure messages and unchanged committed outputs (18 checks); `Tests/TestOverworldMapGeneration.gd` directly covers palette collapse/unknown-key failure.
20. ✅ Second-review iteration step 4 — clean test-process exits. `Globals/MusicPlayer.gd` adds `shutdown()` (stop players, release streams, kill tweens) and owns its fade-before-end as a stoppable `Timer` node; `SceneManager` loads scenes synchronously in headless runs so no threaded loader outlives the process; `OverworldChunkStreamCache.dispose()` and `Overworld._exit_tree()` drain/release the streaming caches and reader/coordinate references, and background chunk preloading is skipped in headless runs; `Journal.setTabDefinitions()` frees replaced tabs immediately; and `TestJournal`/`TestEncounters` free the tabs, fake actors and encounter script instances they own. SceneManager (15 checks), Journal (95 checks), Music and Encounters all exit without leak warnings, and the streaming suite remains at 48 checks.

## Decisions and remaining questions

Decided: the base is generated from chunk data offline, geometry is authoritative, dynamic markers are separate, full-grid bounds include missing chunks, runtime never decodes the whole world, and the Journal map uses the gameplay-aligned orientation (`ORIENTATION_ALIGNED`) rather than the 45°-rotated isometric diamond. A semantic tile palette is required; raw tile screenshots and per-frame polygon rendering are not the approach.

Remaining art/product choices do not block the architecture:

- Coast/road/mountain outlines and whether a separate coarse overview improves fit-scale readability.
- Location label density, icon variants, player pulse/orientation, and maximum useful zoom.
- Whether discovery/fog is ever desired; the current requirement shows Locations without it.
    - No discovery or fog
- Stable non-Location key-point authoring if future quest targets are not Locations.
- Whether decorative output should imitate `Map Outline.aseprite` more closely through generated borders/paper treatments.
- Whether the retained isometric orientation is worth keeping after in-game sign-off.
- Final palette values (the classification is settled; individual biome hues may still be tuned).

## Review

### Second review — 2026-11-01 (current)

The offline bake, generated artifacts, palette/LOD, projection, manifest validation, and MapTab lifecycle remain sound. The committed outputs pass `--check`, and every affected automated suite now exits without leak warnings. The only remaining work is the deliberately pending quest key-point API and optional polish.

#### Findings, in priority order

1. **High — off-center last-known positions could re-enter on the wrong tile.** `Globals/Overworld.gd::storeLastKnownPlayerPosition()` floored `worldToCellFraction()`. That fraction is solved around the actual containing cell's center and can be negative, so its floor was not necessarily the containing cell. A headless probe at initial-spawn cell `(550,804)` found that world offsets `(0,-1)` and `(-1,0)` still resolved to `(550,804)` through the TileMap but reseeded to `(550,803)` and `(549,804)` respectively. **Resolved in iteration step 1:** `OverworldCoordinates.worldToCell()` uses the real `local_to_map(to_local(...))`, and `storeLastKnownPlayerPosition()` reseeds `cellToChunkTile()` from it. The marker keeps the exact position, and the off-center scene-level exit/re-entry test now covers this case.
2. **High — the signed fractional inverse was not reliable on the staggered grid.** `OverworldCoordinates.cellFractionToWorld()` also floored its input, so it could select different row parity/basis from the cell used by `worldToCellFraction()`. The same probe measured a 12.8-pixel round-trip error at `(0,-3.2)` from a tile center. **Resolved in iteration step 1:** the overlapping per-cell parallelograms make a packed `Vector2` non-invertible, so the exact contract is now `worldToCellAndFraction()` + `cellAndFractionToWorld()` (cell plus local u/v offset), and `worldToCellFraction()` is documented as projection-only. Projection tests cover signed `±u`/`±v` offsets, exact axis-half boundaries, row/column crossings and both row parities.
3. **Medium — controller acceptance depended on an untested focus transition.** `Journal.open()` focuses the `TabBar`; the bar consumes arrows/D-pad for tab switching, while MapTab panned only through its focused clip or unhandled input. **Resolved in iteration step 2:** `MapTab.getFocusTarget()` exposes the map clip, `Journal` wires the TabBar's down focus neighbour to the active tab's target (and back up), and `ui_cancel` from focused tab content returns to the TabBar before closing. `Tests/TestJournal.gd` now covers D-pad down into the map, map panning without a tab change, the back-to-tabs path, and closing from the TabBar through the real shell at 640×360.
4. **Medium — diagnostic generator commands could report success after errors.** `--survey` and `--palette-report` returned before the normal bake/error gate and called `quit(0)` even when chunk decoding failed; collapsed-source findings only printed warnings, and unknown arguments/orientations warned and continued. **Resolved in iteration step 3:** all modes share `_commonExitCode()`, `--palette-report` fails on collapsed sources or unknown keys, invalid CLI input refuses to bake or write, and `--preview` writes only on a clean validation. `Tests/TestOverworldMapCli.gd` runs every mode as a real child process and asserts exit codes, failure messages and unchanged committed outputs; `Tests/TestOverworldMapGeneration.gd` covers the palette collapse/unknown-key failures directly.
5. **Medium — clean-exit acceptance failed outside the map-owned suites.** SceneManager, Journal, Music, and Encounters passed their assertions but exited with audio playbacks, pending tabs/nodes, script instances and loader objects still reported as leaked. **Resolved in iteration step 4:** `MusicPlayer.shutdown()` stops and releases players/tweens and owns its tail timer as a stoppable `Timer` node; SceneManager uses a synchronous headless load path; `OverworldChunkStreamCache.dispose()` and `Overworld._exit_tree()` release caches/readers and skip headless background preloading; `Journal.setTabDefinitions()` frees replaced tabs immediately; and the Journal/Encounters tests free the tabs, actors and script instances they own. All four suites now exit with no leak warnings (SceneManager 15, Journal 95, Music and Encounters all passing).
6. **Expected dependencies and polish remain.** Quest markers still await authoritative quest state and must use quest/objective identity, not only `target_id`. Location/player icons are still code-drawn placeholders, and there are no control hints. Neither changes the base-map architecture.

#### Visual and validation recheck

The aligned detailed and overview previews were regenerated and inspected at their real 640×360 fit scale. The overview is clearly more readable: biome masses, the northwestern river, mountain regions, and linear features survive, while detailed per-cell features become noise. Remaining speckle and hard biome boundaries are optional art polish. This preview review does not replace an in-game marker/focus sign-off.

Validation performed: projection (including the signed/parity cell+fraction checks), generation (including palette collapse/unknown-key failure checks), the subprocess CLI suite (18 checks), 48 streaming checks, 100 MapTab checks, and 95 Journal checks passed; `--check` passed with 274 present/14 missing chunks, seven Locations, 37 known seam overlaps, and no out-of-grid cells; `--palette-report` matched the documented feature totals with no collapsed source or unknown key; `--strict` failed only on the 37 overlaps and `--require-complete` failed on the 14 holes as expected; `--survey` and `--preview` exited 0 on the clean bake, and unknown arguments/orientations exited 1 without touching the committed outputs. SceneManager (15 checks), Journal (95 checks), Music and Encounters all pass and exit without ObjectDB, resource or CanvasItem-RID leak warnings.

#### Next iteration after this review

1. ✅ Fix containing-cell re-entry and the signed fractional transform contract first; add the missing parity/boundary tests and a scene-level off-center exit/re-entry test. (Implemented: `worldToCell()` + the exact `worldToCellAndFraction()`/`cellAndFractionToWorld()` pair, projection-only `worldToCellFraction()`, signed/parity/boundary projection tests, and the 98-check MapTab off-center exit/re-entry case.)
2. ✅ Specify and implement Journal-to-map controller focus handoff, then test pan and tab navigation through the real shell at 640×360. (Implemented: `MapTab.getFocusTarget()` + `Journal._wireTabFocus()`, `ui_cancel` back-out to the TabBar, and real-shell tests in `Tests/TestJournal.gd` covering D-pad entry, map panning without a tab change, back to tabs, and closing.)
3. ✅ Make all generator modes fail closed with meaningful exit statuses and regression-test the CLI behavior. (Implemented: shared `_commonExitCode()`, palette collapse/unknown-key failure, invalid CLI refusal before any bake/write, preview writes only on clean validation, `Tests/TestOverworldMapCli.gd` subprocess exit/output checks, and direct palette failure checks in `Tests/TestOverworldMapGeneration.gd`.)
4. ✅ Clean the remaining SceneManager/Journal/Music/Encounter exit leaks so the no-warnings acceptance criterion can gate changes. (Implemented: `MusicPlayer.shutdown()`/owned tail timer, headless synchronous SceneManager loads, `OverworldChunkStreamCache.dispose()` + Overworld reference release + headless preload guard, immediate tab freeing, and test-owned actor/script cleanup; all four suites now exit leak-free.)
5. Keep quests pending until authoritative objective state exists; then implement objective-keyed markers, overlapping-anchor badges, and shared Quests/Map provider tests.

### Previous review


### Overall assessment

The map has a sound technical foundation. The offline bake, shared coordinate pipeline, generated manifest, runtime markers, and player-position provider work together as designed. Orientation is now resolved: the shipped map uses the gameplay-aligned projection instead of the 45°-rotated diamond. The remaining gaps are semantic terrain styling, fit-scale feature readability, and complete keyboard/controller operation.

### Successful implementation

- **The generation architecture is correct.** The complete world is baked offline from authoritative chunk scenes. Opening the Journal only loads the generated PNG and manifest; it does not instantiate the Overworld or decode the world's cells at runtime.
- **Geometry has one authoritative pipeline.** `OverworldChunkReader`, `OverworldCoordinates`, and `OverworldMapProjection` are shared by streaming, generation, and markers. Chunk seams, grid bounds, known anchors, negative coordinates, and fractional round-trips are tested.
- **Orientation is a first-class, versioned transform.** One integer-basis projection implements the isometric diamond and the gameplay-aligned map; `map_orientation` is written to the manifest at format version 2, validated at runtime, and covered by projection tests for both variants. `--preview --orientation=` produces fit-scale candidates without touching committed outputs.
- **The terrain palette is authored and auditable.** `MapTileStyles` builds a complete table for every tileset tile from deliberate biome ground colors and shared feature colors, classified by per-key overrides → tileset terrain authoring → audited atlas rows → biome ground. `--palette-report` reports per-source style spread, dominant share, feature shares, top keys, collapsed sources and unknown keys.
- **World bounds and missing chunks are handled correctly.** The bake reports 274 present and 14 missing chunks, seven Locations, no failed chunks, and no out-of-grid cells. Missing chunks remain transparent without changing image bounds.
- **Generation is deterministic and maintainable.** The typed style grid is memory-efficient, outputs are checked in, the PNG uses mipmaps, and `--check` detects stale output. The 37 seam overlaps are reported and resolved deterministically rather than hidden.
- **The Journal view is functional.** Fit, pan, cursor-centered zoom, center-on-player, constant-size markers, POI selection, and missing-data states are implemented. Normal repeated activation does not duplicate markers or timers.
- **Player state is well integrated.** The Overworld registers its live actor, retains its exact last-known position on exit, and reseeds re-entry through the same coordinate pipeline. The marker distinguishes current and last-known positions.
- **The Overworld streaming approach remains appropriate.** Background scene parsing and budgeted merged-tile updates keep full-world map generation independent of the locally streamed world.
- **Map interaction works without a mouse.** The map fills the whole tab with the shortcut buttons overlaid on the map, and the `MAP_*` actions give keyboard and controller pan, zoom, fit, center and POI cycling (in image order, wrapping, through the same `focusTarget()` path as “Show on map”).
- **Automated assertions currently pass:** projection tests (both orientations), generation tests (authored palette, overview aggregation, malformed data), all 95 MapTab checks, and all 15 SceneManager checks. The map test processes exit without leaked TileMap/rendering resources.

### Visual review

The map tab renders correctly, and the Location and party-position indicators remain readable and visually distinct at a constant screen size.

**Orientation is resolved.** Comparing both shipped candidates at the real 640×360 fit scale showed a clear winner:

- The isometric diamond is rotated 45° from the Overworld, spends roughly half its image on transparent corners, and turns "right/down" movement into diagonals on the map.
- The aligned rectangle fills the map area, keeps `+u` right and `+v` down, and reproduces the Overworld's own 2:1 world silhouette. Terrain covers far more of the fit box, so both the landmass and per-chunk detail read better.

The aligned map is therefore the shipped orientation. The isometric transform is retained behind `--orientation=isometric` for in-game comparison and should be deleted after sign-off if it is not kept.

**Terrain semantics are resolved.** The previous palette sampled each isometric tile's dirt front face, so Grasslands rendered in the canyon's orange, Snowy Mountains read as water blue, and every source collapsed to one flat color. The authored palette fixes that at fit scale, and the follow-up audit restored the two features that were still missing:

- **Forest** follows the authored classification doc (Grasslands rows 1-3, Prairie row 3 tiles 1-6/10, Wild West row 3 tiles 5-9, Snowy Mountains row 3 tiles 5-9) — ≈126k cells. Rocky Hills' green rows are grass, not forest.
- **Rocks and cliffs are separate features.** Cliff tiles (Grande Cañón row 3, Rocky Hills row 3 solid tiles, Prairie row 3 tiles 7-9, Snowy Mountains row 4 tiles 1-3, the tall Grasslands tile) are ≈84k cells in a darker tone, distinct from the ≈80k rock cells.
- **Snowy Mountains' rock and cliff rows** are `mountain`/`cliff` rather than flat ice, and its water tiles are the two animation frames of one water tile.
- **Swamp** is a feature of its own (Grasslands row 10, 21k cells) with a color distinct from water and forest.
- **Linear tiles are split**: train tracks are `track` and power lines are `powerline` (there are no road tiles yet). Water follows the doc's rows (Grasslands 9/11, Wild West 5/7, Snowy 5, Rocky Hills 6) — ≈3.7k cells.

**Fit-scale readability is resolved by the overview LOD.** Per-cell coloring read as speckle at whole-world fit scale, so the bake now also writes a 192×384 overview (one pixel per 4×4 cells) that the tab uses while zoomed out. Thin features (water, track, powerline) survive with any presence, area features need 30% of their block, and higher priority wins ties — so rivers, the rail line and the power line still read, while forest, rock and swamp become solid masses instead of noise. The detailed 3072×1536 map is used above 2.5× fit, and both textures share the same coordinate space so markers never move.

Remaining polish (optional, not blocking): edge/coast outlines on the detailed map, and further palette hue tuning.

### Incomplete or unsuccessful parts

- **Map input polish.** Keyboard/controller operation is complete (arrows/D-pad pan, keys/shoulders zoom, `C`/A center, `]`/`[`/Y/X cycle POIs, `F` fits), but there are no on-screen control hints or legend yet.
- **Quest targets are not integrated yet.** This is an expected pending dependency, not a regression. Before integration, quest markers must be keyed by quest/objective identity rather than only `target_id`; the current dictionary would lose track of an earlier marker when multiple objectives reference the same Location. Overlapping Location and quest markers also need explicit selection and badge-offset behavior.
- **The tests do not cover every acceptance claim.** Malformed chunk records, manifest projection/POI validation, disposal and rebuild, chunk-crossing cache behavior and the shared anchors are now covered; the background-parse round trip, scene-level crossing orchestration, controller operation and arbitrary staggered-row movement still need stronger coverage.
- **The SceneManager scene-run suite still reports exit leaks.** Its 15 checks pass, but the process emits 25 ObjectDB and four resource warnings. These are separate from the map-owned resources fixed in this iteration and need their own cleanup pass.

Resolved in baseline hardening: the manifest is regenerated and `--check` is current; `MapTab._isMapDataValid()` validates projection metadata and POIs; markers recompute from shared cells; `_disposeView()` stops and frees timers/tweens/views; malformed chunk data is rejected without partial rendering; map tests exit without leaked TileMap/rendering resources.

Resolved in coordinate and lifecycle hardening (step 6): location collisions, spawn points and the player spawn all place through `OverworldCoordinates.chunkTileToWorld()`, and the streaming caches are bounded by `OverworldChunkStreamCache.prune()` after every crossing (covered by `Tests/TestOverworldChunkStream.gd`).

### Validation notes

The review ran the projection, generation and streaming suites (`TestOverworldChunkStream`, 48 passed), the MapTab scene suite (95 passed), the SceneManager suite (15 passed), the music suite and the encounter suite, the generator, `--palette-report` and `--strict`. Ordinary `--check` reports the committed PNGs and manifest are current. `--strict` now fails **only** on the 37 documented seam overlaps — no tile key is unstyled. Both orientation candidates were generated with `--preview` and compared at 640×360 before selecting aligned, and `--preview` also writes the overview LOD composite used to judge fit-scale readability.

### Baseline hardening (implemented)

Step 1 is complete in this iteration:

- `OverworldCoordinates` now distinguishes maps it owns from maps it borrows. `makeHeadless()` sets `_ownsMaps`; `dispose()` frees both maps only in that case and is safe to call twice. Callers are `Tools/GenerateOverworldMap.gd::_run()`, `Globals/Overworld.gd::_exit_tree()`, `UI/Journal/Tabs/MapTab.gd::_exit_tree()`, the three map tests and `Nodes/Scene Manager/Test/SceneManagerTest.gd`.
- `OverworldChunkReader` decodes through `_readCells()`, which returns `{ "cells", "errors" }`, rejects non-`PackedInt32Array` tile data and any `tile_data.size() % 3 != 0`, and returns no cells on error. `readChunk()` stops before script decoding when cell decoding fails; `Overworld.gd::setChunk()` logs the errors with `push_error()` and marks the chunk handled rather than rendering a partial chunk or retrying malformed data every frame.
- `MapTab._isMapDataValid()` validates format version, non-empty texture and exact `image_size`, cell bounds ordering, recomputed projection size, `map_origin`, `pixels_per_cell`, non-empty `chunk_grid`, unique non-empty POI ids, POI value types, POI cells inside the projection, and `image_position == projection.cellToImage(cell)`. Invalid data fails closed to the regeneration state.
- Location and quest markers recompute `projection.cellToImage(location["cell"])` instead of trusting the baked image position; the manifest value remains a checked consistency field.
- `MapTab._disposeView()` stops runtime state, removes and frees its direct-child refresh timer and view, clears drag/tween state and rebuilds cleanly. `_exit_tree()` disposes the tab's headless coordinates.
- `MusicPlayer._ready()` and `Shootout.loadDataFolder()` free their instantiated script data objects (Node entries only), removing the remaining headless data-loader leaks.
- `Data/Overworld/OverworldMapData.tres` was regenerated; the PNG was byte-identical. Regression coverage added: owned/borrowed map disposal, malformed `tile_data` rejection, five invalid-manifest cases, POI/marker recomputation, and disposal/rebuild/data-failure lifecycle.

### Next iteration plan (code-level)

1. **✅ Restore a clean technical baseline.** Implemented as described above. Verification: `TestOverworldMapProjection.gd`, `TestOverworldMapGeneration.gd`, `TestOverworldMapTab.tscn` (72 checks), `SceneManagerTest.tscn` (15 checks), `RunAll.gd -- Music`, `RunAll.gd -- Encounters`, and `GenerateOverworldMap.gd -- --check` all pass.
2. **✅ Resolve map orientation before detailed art work.** Implemented:
   - `OverworldMapProjection` keeps `ORIENTATION_ISOMETRIC` and adds `ORIENTATION_ALIGNED`; both are pure integer-basis working transforms with one shared inverse, and `SHIPPED_ORIENTATION` selects aligned. `cellForGrid(coordinates, grid, tiles, orientation)` forwards the choice, `OverworldMapBaker._rasterize()` uses the projection's footprint/downsample instead of isometric constants, and unknown ids fail closed.
   - `OverworldMapData` is at `FORMAT_VERSION = 2` with `map_orientation` and sentinel defaults (`0`, `ORIENTATION_UNSET`) so the generated `.tres` always records both. `MapTab` rebuilds the projection from the manifest value and rejects unknown orientations and mismatched `pixels_per_cell`.
   - `Tools/GenerateOverworldMap.gd` accepts `--orientation=isometric|aligned` and `--preview`; preview writes `res://.godot/overworld_map_preview_<orientation>.png` plus a `_fit.png` composite at the real 640×360 Journal scale without touching committed outputs.
   - Tests cover corners, dense non-overlapping footprints, inverse/fractional round-trips, `+u`-right/`+v`-down, orientation parsing, and the isometric legacy numbers.
   - **Selected aligned:** it fills the fit box, keeps gameplay directions, and removes the diamond's transparent corners. The isometric variant is retained behind the flag for in-game sign-off; delete it afterwards if unused.
3. **✅ Audit and restore terrain semantics Zone by Zone.** Implemented:
   - `MapTileStyles` no longer samples textures. `SOURCE_GROUND` holds a deliberate biome color per tileset source, `FEATURE_COLORS`/`FEATURE_PRIORITIES` give every map feature one shared color and priority, `TERRAIN_FEATURES` maps the tileset's terrain authoring to features (shared with the generator's survey), `SOURCE_ROW_FEATURES` records the audited rock/vegetation/water/structure atlas rows per source, and `KEY_FEATURE_OVERRIDES`/`KEY_COLOR_OVERRIDES` carry explicit per-tile exceptions (Snowy vegetation tiles, the Grande Cañón rock formation).
   - `MapTileStyles.buildAuthoredStyles()` enumerates the shared tileset so every tile has a style; `featureForKey()` resolves override → terrain authoring → atlas row → biome ground.
   - `Tools/GenerateOverworldMap.gd -- --palette-report` prints per-source cell/style counts, dominant share, per-feature shares, the three top keys per source, a feature summary with colors, collapsed-source warnings and unknown keys. It exposed and fixed a real bug (row lookup used atlasX instead of atlasY, recoloring whole columns).
   - `TestOverworldMapGeneration.gd::testAuthoredPalette()` asserts distinct biome colors, distinct Grande Cañón and Rocky Hills keys (classification *and* baked pixels), terrain-tag precedence, and that the table covers every tileset tile.
   - Regenerated output: Grasslands is green instead of canyon orange, Snowy Mountains is pale ice instead of water blue, Rocky Hills is 45% rock / 55% grass rather than flat gray, and no source collapses to a single style.
4. **✅ Make preserved features readable at fit scale.** Implemented:
   - `OverworldMapBaker.bake()` accepts an `lodBlock` and returns an `overview` image: one output pixel per block, chosen by feature class (water/track/powerline win with any presence; forest/swamp/mountain/cliff/structure need `LOD_AREA_SHARE` = 30%), highest style priority among qualifying features, then the block's most common style for the color. Blocks under `LOD_MIN_FILL_SHARE` = 25% stay transparent.
   - `GenerateOverworldMap` bakes at `LOD_BLOCK = (4, 4)`, writes `Assets/Journal/OverworldMapOverview.png`, records `overview_texture`/`overview_image_size` in the manifest, and `--check` compares both PNGs; `--preview` writes a fit-scale composite of the detailed map and the overview.
   - `MapTab` validates the overview (size, exact divisor of `image_size`) and swaps `BaseMap` between the overview (≤2.5× fit) and the detailed texture, drawing it at `image_size / overview_image_size` so markers and POIs stay put. `BaseMap` is now input-transparent.
   - Tests cover aggregation (single water cell wins, sparse forest stays ground, dense forest wins, ground blocks stay ground, determinism, transparent missing chunks), overview validation, and the runtime texture switch at fit and after zooming in.
   - `OverworldMapData.matches()` now compares texture references by resource path, which also fixed a real bug: a manifest that lost its texture references was previously reported as "unchanged".
5. **✅ Complete non-mouse operation.** Implemented:
   - `project.godot` gains `MAP_ZOOM_IN` (`=`, controller right shoulder), `MAP_ZOOM_OUT` (`-`, controller left shoulder), `MAP_POI_NEXT` (`]`, controller Y), `MAP_POI_PREV` (`[`, controller X) and `MAP_CENTER_PLAYER` (`C`, controller A); D-pad/stick pan through the built-in `ui_*` actions.
   - `MapTab._handleMapInput()` is the single keyboard/controller entry point (actions first, then arrows, then the `F`/`C` keycodes) and is called from both the focused clip's `gui_input` and the tab's `_unhandled_input`, so the map still responds when focus sits elsewhere without double-applying.
   - `_buildPoiFocusOrder()` orders Locations by image position (left to right, then top to bottom) and `_focusRelativePoi()` wraps around, reusing `focusTarget()` so centering, selection and the label stay on one path. Markers and shortcut buttons keep `FOCUS_NONE`.
   - The map clip now fills the whole tab and the shortcut buttons overlay the map's top-left corner instead of taking their own row.
   - Tests: real wheel delivery over the base texture, both zoom keys, controller shoulder zoom (and zoom-out reaching fit), POI cycle order/wrap in both directions, the action keys and controller buttons cycling through the map input path, the map filling the tab, the controls overlaying it, and focus staying on the map.
6. **✅ Finish coordinate and lifecycle hardening.** Implemented:
   - `createSpawnPoint()`'s call site and `createCollisionWithPosition()` place through `_getCoordinates().chunkTileToWorld()`, and the collision diamond is built from the tile's own shared basis (`cellToWorld(cell + RIGHT/DOWN) - tileCenter`) instead of the old hand-mapped 4-point cloud, so an area covers exactly the tile it was authored for. No `map_to_local(chunk) - Vector2(32 * 24, 32 * 6)` offsets remain in `Overworld.gd`.
   - `OverworldChunkStreamCache` (new, `Overworld/OverworldChunkStreamCache.gd`) owns `chunkScenes`, `pendingChunkPaths`, `chunkCellDataCache`, `loadedChunkCells`, `presentChunkCells`, `pendingChunkLoads`, `cellOpQueue` plus the async parse/queue/unload/prune logic; `Overworld.gd` keeps the crossing decisions and delegates through thin wrappers, so the streaming bookkeeping is testable without a scene tree. The unload rule is shared (`OverworldChunkStreamCache.isKept()`, used by both `setAdjacentChunks()` and `removeFarawayObjects()`), `processCellOps()` takes an injectable budget, and `PRELOAD_RADIUS` now drives both `preloadChunkScenes()` and the kept set.
   - Bounded eviction: `pruneChunkCaches()` runs after every crossing (and after `init()`'s preload) and drops cached scenes/cell data outside the current chunk plus `PRELOAD_RADIUS` (25 chunks). Cell data for a chunk still present in the merged layer is always kept, because unloading needs it to erase.
   - Tests: `Tests/TestOverworldChunkStream.gd` covers per-chunk queue replacement and drain, budgeted partial writes with resume offsets, the queued erase of an unloaded chunk, the unload rule, cache bounds over 120 crossings, and the shared-anchor collision diamond for four anchors.
7. **Integrate quests only when authoritative quest state exists.**
   - Add `Quests.getCurrentMapMarkers() -> Array[Dictionary]` returning `{ "quest_id", "objective_id", "target_id", "icon" }` from active objectives; `MapTab._resolveQuestMarkerProvider()` should default to it and fall back to `[]` while quest state is a stub.
   - Change `MapTab._questMarkers` keys to `"{quest_id}:{objective_id}"`, keep `target_id` only for `mapData.resolveLocation()`, and add a per-marker `image_offset` meta consumed by `_layoutMarker()` so multiple objectives at one anchor stack as offset badges.
   - Extend `TestOverworldMapTab._fakeQuestMarkerProvider()` with two objectives targeting the same Location and assert both markers exist, stay independently selectable through `focusTarget()`, and survive refresh without duplication. Defer fog, Zone shading and decorative map treatments until readability and input acceptance pass.

### Next-iteration acceptance criteria

- The chosen orientation is understandable relative to gameplay, with every marker aligned at fit, maximum zoom, and after panning.
- The southern-left region retains intended terrain variation in the source PNG, and its important features remain identifiable at Journal fit scale.
- Mountains and the northwestern river are identifiable at 640×360 without zooming; no source collapses to one style merely because its variants shared a prototype color.
- Mouse, keyboard, and controller can pan, zoom, fit, center, and inspect POIs.
- Generated outputs pass `--check`, automated assertions pass, and test processes exit without resource-leak warnings.
- Live/last-known player behavior and all seven POIs remain correct after visual and coordinate changes.
