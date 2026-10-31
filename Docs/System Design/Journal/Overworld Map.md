# Overworld map

The Journal's Overworld map shows the world, the player's current/last known position, Location points of interest, and current quest targets. This doc focuses on generating the base map from authoritative chunk data and keeping live markers aligned with it.

This is a design doc: it describes intended behavior, and implementation may lag behind it. **Status: steps 1–5 implemented — shared `OverworldChunkReader`/`OverworldCoordinates`/`OverworldMapProjection`, explicit `WorldData`, `MapTileStyles`, the headless bake tool with the checked-in `Assets/Journal/OverworldMap.png` and `Data/Overworld/OverworldMapData.tres` manifest (fingerprint + `--check`), and the Journal map tab (`UI/Journal/Tabs/MapTab.*`: fit/pan/zoom, constant-size markers, generated POIs). The exact live/last-known player provider (step 6) and the quest key-point API (step 7) are pending; the placeholder palette art pass is still pending.**

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
3. Rasterize a small isometric `Image` without rendering the actual world.
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
- The live player is `$Actors/PlayerOverworldActor`. The `Overworld` autoload has `spawnChunk`/`spawnTile`, but these are not consistently updated when entering Locations. A last-known-position provider is required for a correct marker outside the Overworld.
- `Quests.gd` has no active/completed quest or objective-target model. `Locations.currentQuest` is only a scene-selection string. The map needs a future quest map-marker API and must not parse quest text or cutscene names.
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
| `UI/Journal/Tabs/OverworldMapTab.tscn` / `.gd` | Pan/zoom, player/POI/quest overlays, focus and tooltips |

`WorldData` is world topology, for example `chunk_grid = Rect2i(0, 0, 12, 24)`. It does not duplicate `HelperVariables.overworldChunkSize` or any `ZoneData` bands. The generator iterates that explicit rectangle and reports every present/missing/decode-failed chunk.

The generated resource should contain data equivalent to:

```gdscript
{
    "format_version": 1,
    "texture": "res://Assets/Journal/OverworldMap.png",
    "image_size": Vector2i(2304, 1152), # actual value derived from projected bounds
    "map_origin": Vector2(...),          # normalizes projected shared-cell coordinates
    "pixels_per_cell": Vector2(1.0, 0.5),
    "chunk_grid": Rect2i(0, 0, 12, 24),
    "source_fingerprint": "...",
    "locations": [
        {
            "id": "Lazysprings",
            "display_name": "Lazysprings",
            "chunk": Vector2i(8, 17),
            "tile": Vector2i(20, 36),
            "icon": "location",
        },
    ],
}
```

A typed `Resource` is preferable to an untyped Dictionary at runtime, but the fields are the contract. Player/quest state and current Zone are deliberately absent. `format_version` lets the loader reject incompatible generated metadata rather than silently misplacing markers.

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
func worldToCellFraction(worldPosition: Vector2) -> Vector2
```

`chunkTileToWorld()` is the existing spawn-point formula (`chunk map_to_local - Vector2(32*24, 32*6) + template.map_to_local(tile)`). `cellToWorld()` uses the merged/template tile transform. Both live spawning and the map generator must call these helpers rather than copying the constants.

For smooth player motion, `worldToCellFraction()` cannot use `local_to_map()`, which snaps to an integer cell. Build a `Transform2D` from the actual map basis:

```gdscript
var origin = tileMap.map_to_local(Vector2i.ZERO)
var xBasis = tileMap.map_to_local(Vector2i(1, 0)) - origin
var yBasis = tileMap.map_to_local(Vector2i(0, 1)) - origin
var cellFromLocal = Transform2D(xBasis, yBasis, origin).affine_inverse()
var cellFraction = cellFromLocal * localPosition
```

Convert the player's global position into `MergedTiles` local space first. This preserves sub-cell movement and uses Godot's real isometric transform instead of assuming an offset.

Implementation note: because the 4.7 isometric transform is staggered (not affine), `worldToCellFraction()` solves the fraction on each cell's actual u/v basis instead of one global `Transform2D`; cell centers round-trip exactly and fractions are exact within a cell (they may wobble a fraction of a cell on row crossings). `chunkTileToWorld()` is defined through the cell (`cellToWorld(chunkTileToCell())`); the legacy anchor formulas still embedded in `Overworld.gd` (location collisions, the initial spawn) intentionally stay untouched until the player-position unification step.

### Image projection

For a shared-cell coordinate `(u, v)`, the recommended final-image projection is:

```text
projected.x = u - v
projected.y = (u + v) * 0.5
image coordinate = projected - map_origin
```

`map_origin` is stored in generated metadata. The pure `OverworldMapProjection` implements this for both integer cells and fractional cell coordinates, plus the inverse needed for mouse picking/centering. These remain continuous floating-point coordinates; markers never use rounded raster pixels. The image uses transparent padding outside the world's isometric outline.

Rasterization uses a separate lossless working surface so fractional final `y` coordinates do not cause cell overwrites:

```text
working pixel = Vector2i(u - v, u + v) - working_origin
```

Write one **2×1 footprint per source cell** to the working image: the cell's lattice pixel `(u − v, u + v)` plus the `(x + 1, y)` pixel next to it. The lattice only hits pixels whose x and y share parity (half the surface); the `x + 1` neighbor is the parity hole of exactly one cell (no other cell's lattice pixel can claim it), so the working image tiles densely. Painting only the lattice pixels left transparent every-other-column stripes that survived the downsample as vertical lines in the final PNG. After all cells and neighbor-based features are complete, resize only the vertical axis by 1/2 using `Image.INTERPOLATE_BILINEAR` to produce the final image. With identical horizontal/vertical padding, `map_origin = Vector2(working_origin.x, working_origin.y * 0.5)`. The working image/origin and resize algorithm are generator details, not runtime metadata. This gives approximately two final pixels per cell without collisions or a lossy “round every cell directly to final pixels” step.

Derive bounds from the **full declared world grid**, including currently missing chunks. Otherwise adding a missing edge chunk would unexpectedly shift the image and every marker. With 768×1536 cells at this scale, the derived image is **2304×1152 pixels** (computed and asserted by the projection, roughly `(768 + 1536) × 1` wide and `× 0.5` tall):

- Width: `(768 + 1536) × 1 = 2304`.
- Height: `(768 + 1536) × 0.5 = 1152`.

The generator should calculate and assert this from its projection rather than hardcode the result. RGBA8 storage is about **10.1 MiB** before PNG compression or mipmaps, which is reasonable for a Journal asset; larger output scales should wait for evidence that zoom requires them.

Location anchors use `chunkTileToCell(chunk, tiles[0])` and then the same projection. The player uses `worldToCellFraction()` and the same projection, so both remain aligned at every pan/zoom level. Marker icons anchor their bottom-center/feet point to the projected position; their texture dimensions do not affect world coordinates.

### Projection tests required before generation

- All four world-grid corners project inside the image with no clipped world-outline edge; every fixture cell writes a unique working pixel.
- Adjacent local tiles across each chunk seam produce adjacent global cells, with no duplicated row/column or one-cell gap.
- `chunkTileToWorld()` agrees with `cellToWorld(chunkTileToCell())` for known anchors, including Lazysprings `(8,17)/(20,36)` and the initial player spawn `(8,12)/(40,38)`.
- Fractional player world positions round-trip through local/cell/map transforms within a small epsilon.
- Negative shared-cell coordinates and all four isometric neighbor directions project correctly.
- The same projection transforms baked POIs and live markers; there is no UI-only correction offset.

## Semantic tile styling

Tile source/atlas identity is stable generator input; decorative texture pixels are not a reliable map legend. `MapTileStyles.gd` should map `(sourceId, atlasX, atlasY)` to fields such as:

```gdscript
Vector3i(4, 6, 2): {
    "color": Color("82735a"),
    "feature": "mountain", # ground | water | road | mountain | forest | structure
    "priority": 30,          # used by optional overview aggregation
},
```

Optional overrides can include `alternative` if flipped/animated alternatives need different treatment. A style should describe the map representation, not copy the source texture. The keying should be reusable by the future terrain classifier in the spawn design; terrain/walkability rules and map color must not be inferred from each other.

Rules:

- Every encountered source/atlas key appears in a coverage report. Unknown keys get a conspicuous development fallback and are listed once; `--check` should fail on unknown styles once the initial palette is complete.
- Do not average whole 24×48 source textures automatically: transparent pixels, tall props, animation frames, and tiny details produce misleading colors. Average-color experiments may inform a prototype, not final semantics.
- Use ground/biome fills as the base, with explicit water and linear-feature styles. Terrain sets currently describe features such as powerlines/train tracks and are not a complete map classification.
- Optional coast/road outlines are generated from neighboring cell styles after all cells are read. They must be computed deterministically, not painted manually.
- Optional Zone tint/borders read the shared Zone catalog and include `ZoneData` in the source fingerprint. They are polish, not required for the first bake.
- `Docs/Map Outline.aseprite` can guide palette, border, paper treatment, and labels. Decorative Journal frames may be hand-drawn independently because they contain no authoritative geography.

## Bake pipeline

`Tools/GenerateOverworldMap.gd` should be a `SceneTree` script that runs without opening the game or a rendering window:

```sh
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --check
godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --require-complete
```

### Inputs and outputs

Inputs are `WorldData`, every declared chunk path, chunk scripts, `MapTileStyles`, the shared coordinate/reader version, and `ZoneData` only if Zone styling is enabled. Outputs are:

- `Assets/Journal/OverworldMap.png` (RGBA8, transparent outside world/holes).
- `Data/Overworld/OverworldMapData.tres` (texture, projection, grid, fingerprint, POIs).
- A console coverage report; optionally a small generated text report for CI diagnostics.

The PNG, resource, and Godot import metadata are checked in. The game never runs the tool and does not need every chunk scene loaded to show the Journal.

### Algorithm

1. Load world/style data and construct the theoretical full-grid cell bounds and image projection. Initialize an empty RGBA8 `Image` and a `PackedInt32Array` of `768 × 1536` style ids (zero = no cell).
2. For each chunk in sorted order, report missing or load/decode it through `OverworldChunkReader`. Convert each cell to a shared cell, then to a zero-based full-grid index using the generated grid origin.
3. Resolve source/atlas/alternative to an integer style id and store it in the typed style array. A second write to an occupied index is reported as an authoring overlap and resolved deterministically (the later chunk in sorted order wins) — the current world data carries 37 such seam overlaps, invisible in live streaming because the merged layer simply overwrites; `--strict` fails on them. Out-of-grid cells are also errors.
4. Collect Location entries, validate unique ids/non-empty tiles, and project their first entrance tile. Preserve a generic visible Location icon by default until per-Location map metadata exists.
5. After every chunk is read, write each present cell once to the working image with `Image.set_pixel()` using the working projection above. Add deterministic neighbor-based outlines/features, then vertically downsample to the final image with `Image.INTERPOLATE_BILINEAR`. Do not use viewport drawing or texture sampling.
6. Build the manifest and source fingerprint, save outputs, and print counts for present/missing chunks, present cells, unknown styles, POIs, image bounds, and output paths.

The typed style grid is about 4.5 MiB rather than a Dictionary with over a million entries. It also makes neighbor/coast calculations straightforward. Missing chunks remain zero/transparent. `--require-complete` turns any missing declared chunk into failure; ordinary generation and `--check` still report the current 14 holes without blocking incremental world work.

### Determinism and stale detection

- Sort chunks, style keys, and POIs before output. Never depend on filesystem or Dictionary iteration order.
- The source fingerprint covers sorted chunk paths/content (including additions/deletions), chunk scripts, world/style data, generator/projection/reader versions, and shared Zone data when used.
- Normal generation writes only when output changed. `--check` performs the same bake in memory/temporary output and fails if the committed PNG or metadata differs, so manual edits to generated output are also detected.
- Decode errors, out-of-grid cells, invalid Location anchors, and projection failures always fail. Overlapping seam cells are reported and resolved deterministically (see the algorithm); `--strict` treats them as failures. Unknown style policy is configurable during palette development and strict afterward.
- A useful CI command is `--check`; add `--require-complete` only when missing chunks are no longer intentional.

The first visual prototype should generate the complete base and inspect it beside `Map Outline.aseprite` at actual Journal fit scale before investing in labels or decoration. If fine detail becomes noise, adjust palette/aggregation rather than increasing runtime work. An optional later overview can aggregate 4×4 cells by dominant ground style while preserving high-priority roads/water; it must use the same projection metadata or a clearly versioned LOD transform.

### Import and filtering

Generate mipmaps for the base PNG so fit-to-window downsampling does not shimmer or erase all terrain contrast. Use filtered/mipmap display for the zoomed-out base and nearest sampling at integer close-zoom levels if that reads better. Marker textures stay nearest-filtered and are not mipmapped with the base. Validate actual readability in the 640×360 Journal rather than judging the source PNG at 100%.

## Runtime map scene

A regular clipped `Control` is sufficient; no `SubViewport` is needed unless later effects require one.

```text
OverworldMapTab (Control)
└── MapPanel
    ├── MapClip (Control, clip_contents = true)
    │   └── MapContent (Control)
    │       ├── BaseMap (TextureRect)
    │       └── MarkerLayer (Control)
    │           ├── LocationMarkers
    │           ├── QuestMarkers
    │           └── PlayerMarker
    ├── MapControls (zoom out, zoom in, fit, center player)
    └── MarkerTooltip / SelectionPanel
```

`MapContent` holds base texture and marker positions in image coordinates. Pan changes its position; zoom changes its scale around the cursor/focus point. Fit scale is `min(availableWidth / imageWidth, availableHeight / imageHeight)`. Clamp zoom and keep the map within sensible pan bounds while allowing its edges to be reached.

Markers should remain a consistent **screen-space size** rather than shrinking with the base texture. Recompute each marker's position from map coordinates after pan/zoom and counter-scale its icon, or keep icons in a separate screen-space overlay fed by the projection. Focus/hover targets likewise remain usable at fit scale.

Initial behavior:

- First open fits the whole map and makes the player icon visually distinct (for example, a subtle pulse). “Center player” switches to a useful close zoom.
- Mouse drag pans (implemented as a per-frame cursor poll — “left held over the map” arms the drag — because grabbed press/motion `gui_input` delivery proved unreliable across engine grab semantics); wheel/buttons zoom. Keyboard/controller can pan, zoom, fit, and center. Arrow keys always pan the map: shortcut buttons and markers use `FOCUS_NONE` so focus traversal never hops between them, a focused map clip consumes the arrows through `gui_input`, and an unhandled-key fallback pans when focus sits elsewhere (the shell TabBar still consumes arrows for tab switching by design). Map input must not leak to player movement or Journal tab shortcuts.
- POI names can use hover/focus/selected labels instead of displaying every label at once. Add a legend only if the final icon set is not self-explanatory.
- A quest “Show on map” request selects the tab, centers the target, and focuses/pulses its marker without altering quest state.

## Live data and markers

### Player position provider

Add a small Overworld-owned provider API rather than letting the map search `current_scene` every frame:

```gdscript
func getOverworldMapPosition() -> Dictionary
# {
#   "valid": bool,
#   "world_position": Vector2, # in the shared Overworld/MergedTiles frame
#   "is_live": bool,           # false when retained after leaving the Overworld
# }
```

- While the Overworld is active, the provider reads `$Actors/PlayerOverworldActor.global_position` and converts it into the shared frame.
- Before `enterLocation()` or another scene transition destroys the Overworld, it stores the exact last known position in the `Overworld` autoload. Initialize that state from `spawnChunk`/`spawnTile` on first entry.
- Existing `spawnChunk`/`spawnTile` can remain the re-entry contract, but they are not a substitute for exact marker state because most Location entries currently do not update them. Unify re-entry and last-known state where practical rather than adding a third conflicting position.
- The map refreshes a live marker at a modest rate (for example 10 Hz) only while its tab is active. A stationary/last-known marker needs no polling.
- If no valid position exists, hide the player marker and report an empty state; never default the icon to `(0,0)` or the map corner.

### Location POIs

Load POIs from generated `OverworldMapData`, not from currently loaded `$Locations` nodes. The manifest covers the whole world and survives scene changes. All current Locations are visible initially; there is no fog/discovery filter until that feature is explicitly designed.

The existing Location name is the initial stable id. Before renaming a Location, introduce/maintain a stable id rather than matching display text. Optional per-Location fields such as `map_visible`, `icon`, and `map_label` belong with its chunk Location data and flow through the generator. Unknown icons fall back to the generic Location icon with a content warning.

POIs never bake into the PNG. Selecting one shows its name and basic type; it does not teleport, enter the Location, or set a quest target.

### Current quest targets

The quest system should expose an array so the UI does not assume there can only ever be one marker:

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
- If a quest marker shares a Location anchor, keep the Location icon at the anchor and offset/raise the quest badge. Both remain available in the tooltip/focus cycle, with the current quest visually prioritized.
- The Quests tab and Map call the same API. `Locations.currentQuest` and `Quests.currentMainQuestLevel` are not sufficient substitutes.

Until that API exists, ship the base map/player/POIs with an empty quest-marker list; do not hardcode introductory quest targets in the map tab.

## Runtime refresh and failure behavior

- On tab activation, validate `format_version`, texture, projection, and manifest once; build POI markers; connect player/quest providers; then refresh.
- On deactivation/scene exit, disconnect signals and stop timers/tweens. Repeated Journal opens must not duplicate markers or listeners.
- Player/quest updates change only markers, never the base texture or generated resource.
- A missing/corrupt generated asset shows a readable “Map data needs regeneration” state and logs the tool command. Do not attempt a blocking full-world runtime bake as a fallback.
- Pan/zoom, marker hit testing, and labels operate in one transform space. Add automated screen-coordinate tests rather than tuning icon offsets manually at one zoom.

## Files to create / modify

**Shared data and generation**

- `Data/Overworld/WorldData.gd` — declared 12×24 world-grid rectangle and chunk directory.
- `Data/Overworld/MapTileStyles.gd` — semantic source/atlas map styling.
- `Overworld/OverworldChunkReader.gd` — shared chunk scene/script decoder, extracted from `Overworld.gd`.
- `Overworld/OverworldCoordinates.gd` — shared chunk/tile/cell/world transforms, also reusable by dynamic spawns.
- `Overworld/OverworldMapProjection.gd` — pure generated-image transforms.
- `Tools/GenerateOverworldMap.gd` — headless bake/check/report tool.
- `Assets/Journal/OverworldMap.png` and import metadata — generated base.
- `Data/Overworld/OverworldMapData.tres` — generated projection and POI manifest.
- Location/player/current-quest icons under `Assets/UI/Journal/` or the existing icon folder.

**Runtime UI and providers**

- `UI/Journal/Tabs/OverworldMapTab.tscn` and `.gd` — display, transforms, markers, focus, and tooltips.
- `Overworld/Overworld.gd` and `Globals/Overworld.gd` — shared reader/coordinates integration and exact last-known player position.
- Future quest state/API — current objective key-point markers shared with the Quests tab.
- `Docs/System Design/Journal/Journal.md` — shell integration remains the parent design.

**Tests**

- `Tests/TestOverworldMapProjection.gd` — coordinates, bounds, seams, fractional positions, and screen transforms.
- `Tests/TestOverworldMapGeneration.gd` — small synthetic chunks plus real-data coverage/report checks.
- `Tests/TestOverworldMapTab.gd` — markers, pan/zoom, providers, refresh, and failure states with fake data.

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

Compare the generated silhouette and major features with `Map Outline.aseprite` and actual gameplay. Inspect each Zone, current missing edges, rivers/roads, Lazysprings/Clearwater Grove, and the initial player spawn. This review validates map art/readability, not coordinate correctness; the automated projection tests remain authoritative for alignment.

## Implementation order

1. ✅ Extract/test `OverworldChunkReader` and `OverworldCoordinates` without changing live streaming behavior; add explicit `WorldData`. (`Tests/TestOverworldMapGeneration.gd` keeps the original decode as its oracle; `SceneManagerTest` covers live streaming.)
2. ✅ Build projection tests and a small semantic-style fixture generator. Validate full-grid bounds and chunk seams before reading the entire world. (`Tests/TestOverworldMapProjection.gd`, synthetic bake fixtures in `Tests/TestOverworldMapGeneration.gd`.)
3. ✅ Implement the headless bake/report and an initial complete tile palette. Generate the full map, inspect fit-scale readability, and adjust the art rules. (`Tools/GenerateOverworldMap.gd` + `Tools/OverworldMapBaker.gd`; the palette is the survey-generated prototype — the fit-scale art review is still pending.)
4. ✅ Add generated metadata/POIs, deterministic fingerprints, `--check`, and checked-in outputs. (`Data/Overworld/OverworldMapData.tres` — typed manifest; `--check` compares committed PNG + manifest against a fresh in-memory bake; the fingerprint covers chunk scenes/scripts, the tileset, world/style data and the shared bake code.)
5. ✅ Add the Journal map tab, fit/pan/zoom, constant-size markers, and generated POIs. (`UI/Journal/Tabs/MapTab.gd`/`.tscn` + `Tests/TestOverworldMapTab.gd`; the player marker runs on the injectable position provider, whose default is the Overworld autoload's last-known spawn until step 6.)
6. Add exact live/last-known player state and unify it with Overworld re-entry where practical.
7. Add the quest key-point API and markers when quest state lands; keep Quests/Map on the same objective source.
8. Run generator/runtime tests and the manual world/art review before adding optional Zone shading, overview LOD, or decorative polish.

## Decisions and remaining questions

Decided: the base is generated from chunk data offline, geometry is authoritative, dynamic markers are separate, full-grid bounds include missing chunks, and runtime never decodes the whole world. A semantic tile palette is required; raw tile screenshots and per-frame polygon rendering are not the approach.

Remaining art/product choices do not block the architecture:

- Final palette, coast/road outlines, and whether a separate coarse overview improves fit-scale readability.
- Location label density, icon variants, player pulse/orientation, and maximum useful zoom.
- Whether discovery/fog is ever desired; the current requirement shows Locations without it.
    - No discovery or fog
- Stable non-Location key-point authoring if future quest targets are not Locations.
- Whether decorative output should imitate `Map Outline.aseprite` more closely through generated borders/paper treatments.
