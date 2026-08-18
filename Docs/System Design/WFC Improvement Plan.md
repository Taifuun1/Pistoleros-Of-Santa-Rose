# Wave Function Collapse — Improvement Plan

Companion to `Docs/WFC Review.md`. That document catalogues the bugs and
inefficiencies in the current implementation; this one is the concrete,
phased plan for getting the WFC to the best state it can be.

**Recommendation:** replace the current custom "grow-a-region + rescan-all-inputs"
solver with a **conventional overlapping-model WFC** (precomputed adjacency +
per-cell bitset wave + entropy heap + stack propagation), implemented as **pure
data classes** (`RefCounted`, no scene tree) so the collapse can run entirely on
the existing worker threads. A lighter "just fix the current code" track is
described at the end as a fallback, but the rewrite is smaller than it looks
(~300–400 lines total) and removes the whole class of bugs at once.

---

## 1. How generation is wired today (context for the plan)

```
LocationMap (_ready)
  └─ WFCInputCreation.initWFCGeneration([location])      # main thread, reads TileMaps
        → WaveFunctionCollapse.inputs[location] = [patterns...]   # cached in autoload
  └─ initWFCGenerationFinished()
        → LocationMapLayoutGeneration.generateMapLayout()  # list of empty chunks
        → generateNewChunk() ×3                            # kick off 3 idle generators

generateNewChunk()
  → ChunkGenerators/GenN.call_thread_safe("initGeneration", chunkPos, location)

GenN = LocationGeneration (extends AStar, PROCESS_THREAD_GROUP_SUB_THREAD)
  initGeneration()
    → WFCChunkGenerator.generateChunk(location, chunkPos)
        → instantiate WaveFunctionCollapse.tscn, generateChunk() -> set_process(true)
        → _process() steps ONE collapse per tick (on the sub-thread's process group)
        → generationCompleted.emit(tiles) → LocationGeneration.processTiles(tiles)
  processTiles(tiles)
    → ChunkProcessor commands (openBorders, exits, interactables, ...)
    → LocationMap.call_thread_safe("chunkFinished", chunkPos, data, name)   # back to main
```

Key facts that shape the design:

- **The collapse already runs off the main thread** (sub-thread process group),
  but it is spread across ~1000+ process ticks per 24×48 chunk. We want it to run
  as **one synchronous call** on the worker thread instead.
- **Inputs are computed once on the main thread** and cached in the
  `WaveFunctionCollapse` autoload. That is the only step that must touch
  `TileMap`/scene nodes; the solve itself is pure data.
- **Chunk seams are handled after WFC** by `ChunkProcessor` (openBorders/exits).
  So the solver contract is simply: `run(location, seed) -> Dictionary[Vector2i,int]`.
- The WFC classes extend `TileMap` but never use it during the solve (only
  `clear()` in the dead `trimGenerationEdges`). Nothing about the algorithm needs
  a node.

---

## 2. Target architecture

Three small, single-responsibility classes plus a thin adapter:

### 2.1 `WFCModel` (RefCounted) — immutable, built once per input set
Holds everything the solver reads and never mutates, so it is safe to share
across threads:

- `patterns: Array[PackedInt32Array]` — deduplicated 3×3 patterns (length 9).
- `weights: PackedFloat32Array` — occurrence count of each pattern (for weighted
  collapse and Shannon entropy).
- `patternCount: int`
- `centerTile: PackedInt32Array` — `centerTile[p] = patterns[p][4]`, the tile id a
  collapsed pattern outputs for its cell.
- `propagator: Array` — `propagator[dir][p] -> PackedInt32Array` of pattern indices
  compatible with `p` in direction `dir` (4 cardinal directions).
- `directions: Array[Vector2i]` = `[(1,0),(-1,0),(0,1),(0,-1)]` with
  `opposite: PackedInt32Array` for the reverse lookup.

### 2.2 `WFCModelBuilder` — builds a `WFCModel` from the TileMap inputs (main thread)
Folds in the useful parts of `WFCInputCreation.gd`:

1. Read each input `TileMap` into a 2D grid of tile ids (`get_cell_source_id`).
2. Slide a 3×3 window over interior cells → candidate patterns.
3. Apply rotations (and optionally reflections) — reuse `turnInput`.
4. Deduplicate, but **keep counts** → `weights`.
5. Precompute `propagator` once: for each ordered pair `(a, b)` and each direction,
   `b` is compatible after `a` iff the two 3×3 windows agree on their overlap.
   This is the expensive step, but it happens **once per location**, not per solve.

Store the result: `WaveFunctionCollapse.models[location] = model`.

### 2.3 `WFCSolver` (RefCounted) — the algorithm, pure data, one per chunk
Constructed with `(model: WFCModel, gridSize: Vector2i, seed: int)`. Local mutable
state only:

- `wave` — per cell, a bitset over pattern indices (see §4 for representation).
- `compatible[cell][pattern][dir]` — support counts (Gumin optimization) so
  propagation is O(changed) instead of rescanning.
- `sumWeights`, `sumWeightLogWeights`, `entropy` per cell — for lowest-entropy
  selection.
- `stack` — banned `(cell, pattern)` pairs awaiting propagation.
- `rng: RandomNumberGenerator` — seeded, **per solver** (no global `randi()`).

Public API:

- `run() -> Dictionary` — observe/propagate loop; on contradiction, restart with a
  new seed up to `MAX_ATTEMPTS`; returns `Dictionary[Vector2i,int]` or a fallback.
- Internals: `observe()`, `propagate()`, `ban(cell, pattern)`, `collapse(cell)`,
  `getOutput()`.

### 2.4 Adapter: `WFCChunkGenerator` becomes a thin, synchronous call
No scene instance, no `_process`, no signal:

```gdscript
func generateChunk(location: String, chunkPos: Vector2i) -> Dictionary:
    var model = WaveFunctionCollapse.models[location]
    var seed = WFCSolver.makeSeed(location, chunkPos, WaveFunctionCollapse.baseSeed)
    var solver = WFCSolver.new(model, WaveFunctionCollapse.gridSize, seed)
    return solver.run()
```

`LocationGeneration.initGeneration` then does:

```gdscript
func initGeneration(selectedChunk: Vector2i, generatedLocation: String):
    ...
    var tiles = $WFCChunkGenerator.generateChunk(generatedLocation, selectedChunk)
    processTiles(tiles)
```

Because `initGeneration` is invoked via `call_thread_safe` on a node in a
`PROCESS_THREAD_GROUP_SUB_THREAD`, the whole `run()` executes on the worker
thread, and `processTiles` → `chunkFinished` marshals back to main exactly as it
does now.

---

## 3. The algorithm (conventional overlapping WFC)

Standard Gumin-style loop:

1. **Init.** Every cell's wave = all patterns allowed. Precompute per-cell
   `entropy` and per-`(cell,pattern,dir)` support counts from the propagator.
2. **Observe.** Pick the cell with the lowest positive entropy (ties broken with a
   tiny random noise, as Gumin does). If all cells are collapsed → done. Collapse
   the chosen cell to a single pattern chosen by `weights`; ban all its other
   patterns.
3. **Propagate.** Pop `(cell, pattern)` from the stack; for each direction, for
   each neighbour, decrement the support count for patterns that relied on the
   banned pattern; when a count hits 0, ban that neighbour pattern (push it). This
   touches only affected cells.
4. **Contradiction.** If a ban empties a cell's wave, abort this attempt.
5. **Repeat** observe/propagate until all cells are collapsed.
6. **Output.** `output[Vector2i(x,y)] = model.centerTile[collapsedPattern(x,y)]`.

**Contradiction policy:** restart with `seed + attempt` up to `MAX_ATTEMPTS`
(e.g. 10). If still failing, fall back to filling uncollapsed cells with the
lowest-index / most-common tile (mirrors today's `fillEmptyGenerationTiles(0)`)
so a chunk always returns *something*. Backtracking (snapshotting the wave) is
possible later if guaranteed constraint-satisfaction becomes necessary, but
restart is simpler and adequate for tile maps of this size.

---

## 4. Data-structure choices (the actual efficiency win)

- **Wave as a bitset.** If `patternCount <= 64`, use one `int` (64-bit) per cell:
  `wave: PackedInt64Array` of length `W*H`. Membership/ban/popcount are single
  instructions. If it can exceed 64, use `k = ceil(patternCount/64)` words per
  cell (a flat `PackedInt64Array` of length `W*H*k`). Given 3×3 windows over small
  tilesets with 4–8 symmetries, expect tens to low-hundreds of patterns, so plan
  for the multi-word path but optimize the 1-word case.
- **Support counts** `compatible` as a flat `PackedInt32Array` indexed
  `((cell * patternCount) + pattern) * numDirs + dir`. Avoids nested `Array`
  allocations and is cache friendly.
- **Entropy selection** via approximate Shannon entropy (Gumin) or a simple
  candidate-count heap. A min-heap or entropy buckets replaces the current
  per-frame `sort_custom` (§2.5 of the review).
- **Propagation stack** as a `PackedInt32Array`/`Array` of encoded `(cell,pattern)`
  ints, reused across the solve (no per-step allocation).
- **Output** built once at the end.

Net effect vs. today: no `duplicate(true)` deep copies, no O(n) `Array` scans for
edge tiles, no per-frame full re-sort, and no rescanning all inputs per cell —
propagation is proportional to the number of eliminations.

---

## 5. Threading plan (make the collapse fully parallel)

Goal: the three generators solve three chunks truly concurrently, each on its
worker thread, with zero shared mutable state.

1. **Build models once, on the main thread.** During `initWFCGeneration`, build a
   `WFCModel` per location and store it in `WaveFunctionCollapse.models`. After
   this point the model is treated as **immutable** (read-only), so it can be read
   by many threads without locks. (Godot refcount ops are atomic; reads of an
   unmutated `RefCounted` across threads are safe.)
2. **Solve synchronously on the worker thread.** Each `LocationGeneration` calls
   `WFCChunkGenerator.generateChunk(...)` → `solver.run()` and gets the dict back
   in one call. Remove the `WaveFunctionCollapse.tscn` node and all `_process`
   stepping.
3. **Per-solver RNG.** Each solver owns a `RandomNumberGenerator` seeded from
   `(baseSeed, location, chunkPos)`. Do **not** call the global `randi()`/`randf()`
   from worker threads (not guaranteed thread-safe and creates contention).
4. **No scene-tree access in the solver.** The solver only reads the model and
   writes its own arrays. All node work stays in `processTiles`/`ChunkProcessor`,
   which already marshals back to the main thread via `call_thread_safe`.
5. **Drop the mutex from the solve path.** `MultiThreading.mutex` is only needed
   in `WFCModelBuilder` while it instantiates/reads TileMap nodes (scene tree).
   The solve needs no mutex because it shares nothing mutable.
6. **Determinism.** Seeding per chunk makes generation reproducible (huge for
   debugging) and independent of thread scheduling order.

---

## 6. Correctness fixes folded into the rewrite

The rewrite eliminates these by construction, but list them so nothing is lost:

- Wrong relative/absolute key in `getPartialPatternForTile` (Review §1.1) — gone;
  no partial-pattern rescans.
- No-op `doesMatchesHavePattern` dedupe (Review §1.2) — gone.
- Stale neighbour entropies / missing propagation (Review §1.3) — replaced by real
  support-count propagation.
- Dead guards, unused chunk-offset math, mismatched `generationCompleted` signal
  signature (Review §1.4) — removed with the node.
- `Vector2i`/`Vector2` confusion, per-instance stateless helpers, duplicated
  equality/creation helpers, untyped hot functions (Review §3) — folded into
  typed model/solver code.

---

## 7. Phased delivery

Each phase is independently testable and leaves the game runnable.

**Phase 0 — Safety net (before touching anything).**
- Add a headless test scene / script that generates N chunks for a location and
  asserts: every cell has a value, values are within the tileset id range, and no
  exceptions. Capture current wall-clock time per chunk as a baseline.

**Phase 1 — Model builder (no behaviour change yet).**
- Implement `WFCModel` + `WFCModelBuilder`; build alongside the existing
  `WFCInputCreation` and log pattern count, weights, and propagator size.
- Verify pattern set matches what `WFCInputCreation` currently produces (same
  dedupe + rotations).

**Phase 2 — Solver, run single-threaded.**
- Implement `WFCSolver.run()` and wire `WFCChunkGenerator.generateChunk` to call
  it synchronously (temporarily on the main thread for easy debugging).
- Validate output dict format against `transformWFCTilesToMapTiles`
  (tile ids 0–3 for Clearwater Grove) and that `ChunkProcessor`/openBorders still
  work.

**Phase 3 — Move onto the worker threads.**
- Route the solve through `LocationGeneration.initGeneration` on the sub-thread;
  confirm 3 chunks generate concurrently, RNG is per-solver, and `chunkFinished`
  still marshals to main. Delete `WaveFunctionCollapse.tscn` and the old
  `_process` solver.

**Phase 4 — Tune & clean up.**
- Add weighted collapse + Shannon entropy, contradiction restart, fallback fill.
- Delete dead code: `WFCPatternProcessingFunctions.gd`, `EdgeTile.gd`,
  `WFCConstants.gd`, `WFCHelperFunctions.gd`, `WaveFunctionCollapse.gd`,
  `trimGenerationEdges`, `_generatedChunk` math.
- Benchmark vs. the Phase 0 baseline.

**Phase 5 — Optional extras.**
- Reflection symmetry toggle, per-tile weight overrides, edge/border seeding for
  biome transitions, backtracking for guaranteed completion, a debug visualiser.

---

## 8. Files to add / modify / remove

**Add**
- `Location/Location Generation/Wave Function Collapse/WFCModel.gd`
- `Location/Location Generation/Wave Function Collapse/WFCModelBuilder.gd`
- `Location/Location Generation/Wave Function Collapse/WFCSolver.gd`

**Modify**
- `Globals/WaveFunctionCollapse.gd` — add `models: Dictionary`, `baseSeed`, keep
  `gridSize`.
- `Location/Location Generation/Chunk Generation/WFCChunkGenerator.gd` — synchronous
  `generateChunk(...) -> Dictionary`.
- `Location/Location Generation/LocationGeneration.gd` — call solver + `processTiles`.
- `Location/Location Generation/LocationMap.gd` — build models in
  `initWFCGeneration` step.

**Remove (Phase 4)**
- `WaveFunctionCollapse.gd`, `WaveFunctionCollapse.tscn`,
  `WFCPatternProcessingFunctions.gd`, `WFCBaseClass.gd`, `EdgeTile.gd`,
  `WFCConstants.gd`, `WFCHelperFunctions.gd`, and `WFCInputCreation.gd`
  (its useful logic moves into `WFCModelBuilder`).

---

## 9. Testing & benchmarking

- **Unit-ish:** propagator symmetry (`b ∈ propagator[dir][a]` ⇔
  `a ∈ propagator[opposite(dir)][b]`); output ids within range; deterministic
  output for a fixed seed.
- **Stress:** generate many chunks per location, count contradiction restarts and
  fallback fills; a high fallback rate signals too-strict inputs or too-few
  patterns.
- **Perf:** time `run()` per chunk (expect sub-few-ms for 24×48 with modest
  pattern counts vs. the current ~1000 frames), and confirm 3 concurrent solves
  don't serialize (no shared locks).
- **Visual:** compare generated maps before/after for the same location to make
  sure the aesthetic is preserved or improved.

---

## 10. Risks & mitigations

- **Pattern count > 64** → use multi-word bitsets; keep a fast path for ≤64.
- **Over-constrained inputs → frequent contradictions** → weighted collapse,
  restart, and fallback fill; consider adding reflections to grow the pattern set.
- **Thread safety regressions** → keep the model strictly read-only after build;
  never touch nodes in the solver; per-solver RNG; run Phase 2 single-threaded
  first to isolate algorithm bugs from threading bugs.
- **Output/format drift** → Phase 2 validates the dict against
  `transformWFCTilesToMapTiles` and the `ChunkProcessor` pipeline before threading.

---

## Appendix A — Minimal-refactor fallback (if a rewrite is not desired now)

If you want to keep the current solver, apply these in order (from the review) for
most of the benefit with the least churn:

1. Fix the `_testTiles` key bug (`_checkedTile` instead of `Vector2i(_x,_y)`).
2. Delete the `doesMatchesHavePattern` call in `findAllPartialPatternMatches`.
3. Store `edgeTiles` and `nonLegibleTiles` as `Dictionary` sets keyed by `Vector2i`.
4. Replace the per-frame `sort_custom` with a lowest-entropy bucket/heap.
5. Stop deep-copying working sets every call; mutate one structure, snapshot once
   if rollback is needed.
6. Replace one-step-per-`_process` with a time-budgeted `while` loop (or run the
   whole solve synchronously on the worker thread as in §5).
7. `const`-preload and make `WFCConstants`/`WFCHelperFunctions` static; add types.

This does **not** fix the missing-propagation design issue (stale entropy /
fail-soft holes), which is why the conventional rewrite is the recommended path.
