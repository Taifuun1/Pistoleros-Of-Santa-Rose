# Wave Function Collapse — Code & Algorithm Review

Scope: `Location/Location Generation/Wave Function Collapse/*` plus the driver
`Globals/WaveFunctionCollapse.gd`, `WFCChunkGenerator.gd`, `WFCInputCreation.gd`.

This is an **overlapping-model WFC** using flattened 3×3 patterns
(`PackedInt32Array` of length 9). Inputs are generated from `TileMap`
templates, deduplicated, and rotated 4×. Generation runs one collapse step per
rendered frame from `_process`.

The implementation works, but there are several correctness bugs, a number of
hot-path performance problems, and structural issues that make it hard to
maintain. Items are ordered roughly by impact.

---

## 1. Correctness bugs

### 1.1 `getPartialPatternForTile` looks up `_testTiles` with the wrong key (likely bug)
`WFCPatternProcessingFunctions.gd`:

```gdscript
for _x in range(-1, 2):
    for _y in range(-1, 2):
        var _checkedTile = Vector2i(_tile.x + _x, _tile.y + _y)
        if _testTiles != null and _testTiles.has(Vector2i(_x, _y)):   # <-- relative offset
            _partialPattern[_i] = _testTiles[Vector2i(_x, _y)]
        elif _generatedTiles.has(_checkedTile):
            _partialPattern[_i] = _generatedTiles[_checkedTile]
```

`_testTiles` (i.e. `_tilesToBeChanged`) is keyed by **absolute** positions
everywhere else it is produced/consumed (`addToTilesToBeChanged`,
`isPatternFull`, `getNewEdgeTiles`, `isTileLegible`). Here it is queried with the
**relative** offset `Vector2i(_x, _y)` ∈ {-1,0,1}². So the pending-changes branch
essentially never fires (except by accident near the grid origin), which defeats
the whole "single match" constraint-propagation pass in
`checkForEdgeTilesWithASingleMatch`. It should be:

```gdscript
if _testTiles != null and _testTiles.has(_checkedTile):
    _partialPattern[_i] = _testTiles[_checkedTile]
```

### 1.2 `doesMatchesHavePattern` compares the wrong operand
`WFCPatternProcessingFunctions.gd`:

```gdscript
func findAllPartialPatternMatches(_partialPattern) -> Array:
    var _matches = []
    for _inputPattern in inputs:
        var _match = isPartialPatternAMatch(_partialPattern, _inputPattern)
        if _match and !doesMatchesHavePattern(_partialPattern, _matches):  # <-- _partialPattern
            _matches.append(_inputPattern)
    return _matches
```

The dedupe check tests whether `_partialPattern` (which contains `-1`
wildcards) is already in `_matches`. A wildcard pattern will never equal a full
input, so `doesMatchesHavePattern` always returns `false` and does nothing
useful. If dedupe were actually intended it should test `_inputPattern`.
Because inputs are already deduplicated at creation time
(`checkIfInputIsAlreadyAnInput`), the correct fix is simply to **remove the
call** — it only adds an O(matches) inner loop per input, turning this hot
function into O(N·M) for no benefit:

```gdscript
if isPartialPatternAMatch(_partialPattern, _inputPattern):
    _matches.append(_inputPattern)
```

### 1.3 No contradiction handling / no propagation update of neighbours
When a cell is collapsed, the `matches` cached on **existing** neighbouring
edge tiles are never re-filtered (`getMatchesForEdgeTiles` only computes matches
when `matches == null`). In a real WFC, collapsing a cell must reduce the
candidate set (entropy) of its neighbours — that is the "propagation" step. Here
entropy values go stale, so:
- the lowest-entropy selection is based on outdated counts, and
- contradictions are only discovered lazily via `isTileLegible`, where the tile
  is dropped into `nonLegibleTiles` and later back-filled with tile `0`
  (`fillEmptyGenerationTiles(0)`).

This is a design decision (fail-soft instead of backtracking), but it means the
output can contain patches of the fallback tile and is not guaranteed to respect
the adjacency constraints. Worth documenting explicitly, and ideally replacing
with real propagation (see §4).

### 1.4 Dead / fragile guards
- `WaveFunctionCollapse.gd` `_process`: `if _tile == null: return` can never
  trigger — `getRandomLowestEntropyEdgeTile` always returns an element when
  `edgeTiles` is non-empty (and would instead **crash** on
  `edgeTiles.front().matches.size()` if `front().matches` were ever `null`).
- `getRandomLowestEntropyEdgeTile` assumes `edgeTiles` is kept perfectly sorted
  and every element already has non-null `matches`. This invariant is only
  maintained by ordering side effects in `_process`; a small refactor can break
  it silently.
- `fillEmptyGenerationTiles(_fillTile, _fillEdges = null)` has a trailing
  `if _fillEdges != null: pass` — dead code.
- `_process` computes `_generatedChunk` (x/y × 50) and then never uses it;
  `generationCompleted.emit(generatedTiles)` ignores it, and the signal is
  declared as `(tile, toTile, areaSize)` but emitted with a single Dictionary.
  The signal signature does not match its usage.

---

## 2. Performance / efficiency

### 2.1 One collapse per frame in `_process` (biggest win)
Generation is driven at one step per rendered frame. For a 24×48 grid that is
~1000+ frames (tens of seconds at 60 fps) for a single chunk, and it is coupled
to frame rate. Options, best first:

1. **Run the whole solve in a loop** (optionally on a worker thread — the
   project already has a `MultiThreading` autoload with a mutex) and emit
   `generationCompleted` when done. `TileMap`/scene-tree access must stay on the
   main thread, but the collapse itself operates on plain Dictionaries/Arrays,
   so it can be threaded and only the final `processTiles` touches nodes.
2. If you want to keep it incremental for a progress bar, **budget by time**:
   run steps in a `while` loop until ~4–6 ms elapse, instead of exactly one.

### 2.2 `findAllPartialPatternMatches` is a full linear scan every call
This is the core hot path. It iterates **all** input patterns and does a 9-way
compare for each, and it is called for every edge tile every frame plus inside
the single-match loop. Improvements:
- Remove the `doesMatchesHavePattern` inner loop (§1.2).
- **Cache matches per edge tile** and only *reduce* them on propagation instead
  of recomputing from scratch (§4). Recomputing the full match set from all
  inputs is O(N) where it should be O(current_candidates).
- If you keep the scan, index inputs by the known cells. E.g. group input
  patterns by `(centerValue)` or build, per cell index and per tile value, the
  set of inputs having that value — then intersect only the relevant sets.

### 2.3 Pervasive deep copies (`duplicate(true)`)
`addToTilesToBeChanged`, `addToTilesToBeCheckedForEdgeTiles`,
`getEdgeTilesForTile`, and `checkForEdgeTilesWithASingleMatch` all start with
`something.duplicate(true)` on growing Dictionaries/Arrays, and several of these
run inside the `while _i < 5` loop in `doesTileHaveLegibleInputs`, which itself
runs per candidate match per tile per frame. Deep-copying the working set on
every iteration is O(n) churn that dominates runtime as the region grows. Prefer
mutating a single working structure and, if you need rollback on failure, snapshot
only once (or record a change-list to undo), not on every call.

### 2.4 O(n) linear searches that should be O(1) hash lookups
- `edgeTiles` is an `Array` of `edgeTile` objects, repeatedly searched by
  position with `helperFunctions.checkIfArrayOfClassesHasValue(...)` (a linear
  scan) in `isTileLegible`, `getEdgeTilesForTile`, `getNewEdgeTiles`,
  `getRandomLowestEntropyEdgeTile`. Store edge tiles in a
  `Dictionary` keyed by `Vector2i` position for O(1) membership/insert/remove.
- `nonLegibleTiles` is an `Array` queried with `.has()` (O(n)). Make it a
  `Dictionary` used as a set (`{pos: true}`) for O(1) membership.

### 2.5 Full re-sort of `edgeTiles` every frame
`edgeTiles.sort_custom(sortToLowestEntropy)` runs after each collapse — O(n log n)
per step, O(n² log n) overall. Since you only need the *minimum* entropy, use a
priority queue / binary heap keyed on `matches.size()`, or bucket edge tiles by
entropy value and pop from the lowest non-empty bucket. Combined with proper
propagation (§4), entropy changes become local and cheap to maintain.

### 2.6 Small allocations in hot loops
- `createNewPattern()` builds a length-9 array by appending `-1` nine times on
  every `getPartialPatternForTile` call. Use `var p = PackedInt32Array(); p.resize(9); p.fill(-1)`.
- `getPartialPatternForTile` allocates two `Vector2i` per cell; with the §1.1 fix
  you only need `_checkedTile`.

---

## 3. Code quality / maintainability

- **`Vector2i` vs `Vector2` mismatch.** `WFCConstants.adjacentTileDirections` is a
  `PackedVector2Array` filled with `Vector2i(...)` literals — the ints are stored
  as floats and later re-cast. Use `const adjacentTileDirections: Array[Vector2i] = [...]`.
  Also `adjacentTileDirections` includes `(0,0)`, and `isPatternFull` checks
  `_tileCount == 9` — i.e. it treats the center as one of the 9. That works but is
  a subtle coupling; a comment would help.
- **Stateless helpers instantiated per WFC instance.** `WFCConstants` and
  `WFCHelperFunctions` are loaded with `.new()` and held as `@onready` members,
  even though they hold no state. Make their functions `static` (call as
  `WFCHelperFunctions.isTileInsideGrid(...)`) or fold them into a single utility.
  `@onready var x = preload(...)` should be `const x = preload(...)` — `preload`
  is already resolved at parse time, so `@onready` adds nothing.
- **Duplicated equality/creation logic.** `isPartialPatternAMatch`,
  `arePatternsEqual`, and `checkIfInputsAreEqual` are near-duplicates;
  `createNewPattern`, `createInputPattern`, and `createInputGrid` likewise. The
  code also carries two representations of a pattern (nested `Array` during input
  creation, flat `PackedInt32Array` at runtime) with parallel helpers. Pick one
  canonical representation and one set of comparators.
- **Typed variables / return types.** Most parameters are untyped (`_tile`,
  `_pattern`, `matches`, `inputs`...). Adding static types (`Vector2i`,
  `PackedInt32Array`, `Array[EdgeTile]`, `Dictionary`) both documents intent and
  lets the GDScript compiler emit faster typed instructions.
- **`EdgeTile` should be a typed class with a real constructor.** Currently it is
  an inner `class edgeTile` with a `setValues()` method and untyped fields. Prefer
  a top-level `class_name EdgeTile` with typed `position: Vector2i` and
  `matches: Array` and an `_init(pos, matches := [])`. Also unify the naming —
  the file/class/var mix `edgeTile`, `EdgeTile`, `edgeTiles`.
- **Tight coupling via `$"../.."`.** `WaveFunctionCollapse.gd` connects
  `generationCompleted` to `$"../.."` and `WFCInputCreation` connects to
  `$"../.."` too. Hard-coded relative node paths are brittle; pass the target in
  via `generateChunk(...)`/`initWFCGeneration(...)` or use a signal the parent
  connects to, so the WFC node doesn't need to know its position in the tree.
- **`generatedChunk` chunk-offset math** in `_process` (× 50) is dead and looks
  left over from a scrolling/streaming experiment; remove or wire it up.
- **`trimGenerationEdges()` is commented out** at its only call site. Decide
  whether the 1-tile border is needed and either keep it (documented) or delete.

---

## 4. Recommended algorithmic redesign (overlapping WFC done conventionally)

The current approach re-derives candidate sets by scanning all inputs and grows
"tiles to be changed" regions with repeated deep copies. The standard overlapping
WFC is both simpler and much faster:

1. **Precompute adjacency once per input set.** For each ordered pair of pattern
   indices `(a, b)` and each of the 4 (or 8) directions, record whether `b` may
   sit next to `a` (their overlap agrees). Store as
   `Array[Array[PackedInt32Array]]` or bitsets. This is done once, not per solve.
2. **Wave = per-cell candidate set.** Represent each cell's possibilities as a
   bitset over pattern indices (a `PackedInt32Array`/`int` bitmask, or a boolean
   array). Entropy = popcount.
3. **Observe:** pick the cell with lowest entropy (min-heap / entropy buckets),
   collapse it to a single pattern chosen by weight (pattern frequency in the
   inputs — you already dedupe, but keeping counts gives nicer distributions).
4. **Propagate:** push the changed cell on a stack; for each neighbour, remove
   patterns no longer supported by the collapsed cell's remaining options; if a
   neighbour's set changed, push it too. This touches only affected cells and is
   the correct, cheap replacement for §2.2/§2.5's rescans.
5. **Contradiction:** if any cell's set becomes empty, either restart with a new
   seed or backtrack. Keep the current fail-soft fallback if determinism/perf
   matters more than strictness, but make it explicit.

Benefits vs. the current code: no per-frame full rescans, no deep copies, local
entropy updates, O(1) edge/set membership, and a clear place to plug weights and
backtracking. Bitset propagation for a 24×48 grid with a modest pattern count is
easily sub-millisecond, so it can run synchronously (or once on a thread) rather
than being spread across ~1000 frames.

---

## 5. Quick wins (low risk, high value)

These can be done without the full redesign:

1. Fix the `_testTiles` key bug (§1.1).
2. Remove the `doesMatchesHavePattern` call in `findAllPartialPatternMatches` (§1.2).
3. Convert `edgeTiles` and `nonLegibleTiles` to `Dictionary` sets keyed by
   `Vector2i` (§2.4).
4. Replace per-frame `sort_custom` with a lowest-entropy bucket/heap (§2.5).
5. Drive the solve in a time-budgeted loop (or a thread) instead of one step per
   frame (§2.1).
6. Make `WFCConstants`/`WFCHelperFunctions` static and `const`-preload them (§3).
7. Delete dead code: `_tile == null` guard, `_generatedChunk`×50 block,
   `fillEmptyGenerationTiles` trailing `pass`, and fix the
   `generationCompleted` signal signature (§1.4).
8. Add static types on the hot functions (`getPartialPatternForTile`,
   `isPartialPatternAMatch`, `findAllPartialPatternMatches`, `isPatternFull`).
