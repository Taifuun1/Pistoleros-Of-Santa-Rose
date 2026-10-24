# Dynamic Overworld spawns

Zone-driven visual parties for the Overworld: weighted party selection, multi-actor groups, dynamic positions, and chunk-scoped cleanup.

This is a design doc: it describes the intended design, and the implementation may lag behind it. The source feature is `Docs/Features and Issues.md` ("Rework Overworld spawns to be dynamic"). **Status: proposed; not implemented.**

## Requirements

- Spawn parties according to the **Zone of the chunk being populated**, not hand-authored actor spawn points.
- Use one authoritative `ZoneData` dataset for Zone dimensions across **all** components; no consumer-specific geometry copies or fallbacks.
- Support different party definitions, including animals and people, and allow a party to contain multiple actors.
- Give party definitions different relative spawn rates.
- Keep these actors **visual only**: no player interaction, events, Shootouts, collision, or gameplay rewards.
- Populate and clean up parties without leaking nodes as chunks load and unload.
- Keep random selection deterministic under an injected seed so spawn logic can be tested headlessly.

## Non-goals and boundaries

- This system does not replace `OverworldEvents`. The existing event system is driven by distance travelled by `PlayerOverworldActor`; visual parties must not call it.
- A visual party is not an encounter definition and cannot launch a Shootout. Encounter and region-pool work remains separate (see `Docs/System Design/Shootout/Encounters.md`).
- Party actors do not need wandering, pathfinding, or player avoidance in the first pass. "Dynamic" refers to party choice, composition, position, timing, and cleanup. Idle animation is sufficient.
- Visual parties are transient. Do not serialize their nodes, positions, RNG state, or lifetimes into save data. Loading or re-entering the Overworld starts a fresh population.
- Do not add human-party content before its animation assets exist. The data format supports any actor type, but content validation must reject missing animation scenes.

## Current state

The existing implementation is fixed spawn points with independent per-actor rolls:

1. `Overworld/Overworld.gd::setChunk()` reads a chunk root script's `spawnPoints` Dictionary. For each actor it creates an `OverworldSpawnpoint`, using the **first** entry in `tiles` as its fixed world position.
2. `Overworld/Overworld.tscn` has a 10-second `Timers/SpawnPointTimer`. Its timeout calls `checkActorSpawns()`, which calls `checkForSpawn()` on every loaded spawn point and restarts the timer.
3. `Overworld/OverworldSpawnpoint.gd` rolls `randi() % 100 < spawnChance` and spawns until its own `maximumSpawns` is reached. There is no Zone table, party-level selection, global/Zone population budget, or lifetime.
4. Every spawn uses `Actors/Overworld/OverworldActor.tscn`. `initOverworldActor()` resolves `Animations/Overworld/{type}/{name}Animations.tscn`, plays `Idle`, attaches a shadow, and assigns an indexed node name.
5. `removeFarawayObjects()` frees a spawn point after its chunk leaves the loaded radius. The spawn point's `_on_tree_exiting()` then frees the actor names it recorded. Live actors are otherwise not culled by distance or time.
6. The only concrete spawn content is the three-rabbit point in `Overworld/Overworld Chunks/#8#16.gd`. The scene currently has an `Actors/Animals` container but no general people container.
7. There is no shared gameplay Zone service. The current chunk-band definitions live in `Data/Music/MusicData.gd`, and `MusicPlayer.zone_for_chunk()` resolves them. The bands are explicitly provisional.

Additional constraints from the current chunk loader:

- `Overworld.gd` retains the player's current chunk plus `getAdjacentChunks()` (the surrounding eight chunks). `currentlyLoadedChunks` contains only those neighbours, so active-chunk checks must include `currentChunk` separately.
- Chunk scenes are parsed asynchronously. `loadedChunkCells` means a chunk was handled, while `presentChunkCells` means its queued cells have actually been written to `MergedTiles`. Spawn placement should use only present chunks when it needs to inspect terrain.
- Chunk scripts are instantiated as bare data scripts and are not added to the scene tree. They remain useful for Locations, but should no longer define visual spawn points.
- `isOverworldObjectLoaded(actorName, "Spawnpoints")` uses substring matching on node names. This legacy deduplication should disappear with spawn points rather than be reused for generated parties.

## Target architecture

Use a **pure spawn planner** plus a thin scene adapter:

| Component | Responsibility |
| --- | --- |
| `Data/Overworld/ZoneData.gd` | Shared Zone chunk bands and default Zone; no music or spawn content |
| `Data/Overworld/SpawnData.gd` | Per-Zone spawn cadence, population caps, and weighted party tables |
| `Overworld/OverworldZoneCatalog.gd` | Pure `zoneForChunk(chunk)` lookup over `ZoneData` |
| `Overworld/OverworldSpawnDirector.gd` | Seeded RNG, eligibility checks, weighted party choice, position candidates, and lifetime decisions; no scene-tree or autoload access |
| `Overworld/Overworld.gd` | Supplies loaded chunks/player visibility, instantiates returned party plans, owns party nodes, and despawns them |
| `Actors/Overworld/OverworldActor.tscn` / `.gd` | One non-interactive visual actor, initialized with actor name/type and local formation offset |

The director should be a `RefCounted`, matching the project's headless-testable manager convention. It returns plain Dictionaries; it does not instantiate nodes, query `MusicPlayer`, read `Overworld`, or find nodes through `get_tree()`. `Overworld.gd` remains responsible for all scene-tree operations.

### Scene ownership

Replace the legacy spawn hierarchy with:

```text
Overworld
├── Locations
├── Actors (y-sorted)
│   ├── PlayerOverworldActor
│   └── VisualSpawns (y-sorted)
│       └── VisualParty{partyId} (Node2D, one generated party)
│           ├── Fluffy Rabbit{actorId}
│           └── Fluffy Rabbit{actorId}
└── Timers
    └── VisualSpawnTimer
```

A party root makes cleanup atomic and removes the need for per-type roots or node-path searches. The actor's `type` is still needed to resolve its animation path; it does not need to determine its parent. Each generated member receives a unique indexed name, but runtime logic uses the party id/root, not string searches.

`Overworld.gd` owns a `partiesById` Dictionary. Each record contains:

```gdscript
{
    "definitionId": "rabbit_pair",
    "zone": "canyon",
    "chunk": Vector2i(8, 16),
    "actorCount": 2,
    "expiresAt": 73.5,             # monotonic planner time in seconds
    "despawnWhenHidden": false,
    "node": visualPartyRoot,
}
```

Keep `Overworld.overworldActorIdCount` if indexed actor names remain useful. Remove `overworldSpawnpointIdCount` with the old spawn-point implementation. Party ids can be local to the current Overworld scene because parties are not persisted.

## Single shared Zone dataset

`Data/Overworld/ZoneData.gd` is the **sole authoritative source of Overworld Zone dimensions for every component**. Extract the existing `zones` and `default_zone` values from `MusicData` without changing their current geography:

```gdscript
# Data/Overworld/ZoneData.gd
extends RefCounted

var data = {
    # Inclusive chunk-coordinate corners; first match wins.
    "zones": [
        { "zone": "ghost town", "min": Vector2i(10, 0), "max": Vector2i(10, 3) },
        # Move the remaining existing bands here unchanged.
    ],
    "default_zone": "canyon",
}
```

This is one shared dataset, not a spawn-specific copy:

- `MusicData` must remove `zones` and `default_zone`. `MusicPlayer.zone_for_chunk()` delegates to `OverworldZoneCatalog`; only track lists remain in music data.
- `OverworldSpawnDirector` resolves Zones through the same catalog. `SpawnData` may key tables by Zone id, but must never contain chunk bounds, a default Zone, or another geometry fallback.
- Every other current or future Zone consumer—encounters, item generation, quests, maps, and newspaper information—uses the same catalog and `ZoneData`. Consumers store/reference Zone ids, never their own copies of Zone dimensions.
- Tests inject a replacement dataset into the catalog and pass that same catalog to every consumer under test. They must not maintain separate music/spawn Zone fixtures that can disagree.
- Changing Zone geography requires editing only `ZoneData.gd`; all consumers then observe the same boundaries. A consumer must not fall back to private bands when the shared data has no match.

`OverworldZoneCatalog.zoneForChunk(chunk)` preserves the current first-inclusive-band-wins behavior and shared default fallback:

```gdscript
func _init(zoneData: Dictionary = {}) -> void
func zoneForChunk(chunk: Vector2i) -> String
```

The production catalog loads `ZoneData.gd` by default. Update `Docs/System Design/Music player.md` to identify it as the source of Zone geography.

The spawn director resolves **each candidate anchor chunk's Zone**, rather than using only the player's current Zone. This lets parties just across a Zone boundary use their own table and avoids changing an existing party's definition when the player crosses a boundary.

## Pathfinding assessment

**Verdict: current pathfinding is sufficient for the stationary visual parties in this design only because they do not move. It is not sufficient for moving or wandering Overworld parties.**

The current code does not provide an Overworld navigation solution:

- `Overworld/` and `Actors/Overworld/` contain no AStar graph, `NavigationRegion2D`, or `NavigationAgent2D` setup. `OverworldActorBase` only supplies a speed field, and spawned actors currently play `Idle` without following paths.
- `Nodes/AStar/AStar.gd` is Location-specific. It iterates `HelperVariables.locationChunkSize`, uses Location tile ids for walkability, and calls `HelperFunctions.isOutSideTileMap()`, which also uses Location bounds. Those rules cannot be applied unchanged to 64×64 streamed Overworld chunks or Overworld source/atlas terrain identities.
- The helper's point-id formula assumes non-negative local coordinates. Overworld chunk/template coordinates can be negative, so a future global graph needs a collision-free signed-coordinate id scheme.
- `Actors/Location/LocationActor.gd` uses a `NavigationAgent2D`, and prebuilt Location scenes provide navigation polygons. The Overworld scene has no corresponding navigation region.
- `Tilesets/OverworldTileset.tres` defines physics collision polygons, not an AStar graph or baked navigation mesh. Player collision therefore does not give parties a route around blocked terrain.

**Decision for this refactor:** keep parties stationary and do not add pathfinding, wandering, or a movement controller. This avoids coupling the spawn refactor to a new streaming-navigation system.

If ambient movement is added later, it needs a separately tested Overworld navigation layer: incrementally add/remove walkable cells as chunks become present/unloaded, connect cells across chunk seams, use the same terrain classification as spawn placement, support signed global cell ids, convert isometric cell paths through the shared coordinate helpers, and repath or stop safely when a route leaves the loaded area. Party-level movement must also define how followers preserve formation; simply giving each actor the Location AI would not satisfy these requirements.

## Spawn data

Use one data file initially; split per-Zone tables into a folder only if the file becomes difficult to maintain. Follow the existing `var data = {...}` content-file convention.

```gdscript
# Data/Overworld/SpawnData.gd — illustrative values, to be balanced
extends RefCounted

var data = {
    "tick_seconds": 10.0,
    "position_attempts": 12,
    "offscreen_margin_pixels": 32.0,
    "minimum_player_distance": 96.0,
    "zones": {
        "canyon": {
            "spawn_chance": 0.35,
            "max_parties": 4,
            "max_actors": 12,
            "parties": [
                {
                    "id": "rabbit_single",
                    "weight": 3.0,
                    "max_alive": 2,
                    "lifetime_seconds": [45.0, 90.0],
                    "members": [
                        { "type": "Animals", "name": "Fluffy Rabbit", "count": 1 },
                    ],
                },
                {
                    "id": "rabbit_pair",
                    "weight": 1.0,
                    "max_alive": 1,
                    "lifetime_seconds": [60.0, 120.0],
                    "members": [
                        { "type": "Animals", "name": "Fluffy Rabbit", "count": 2 },
                    ],
                },
            ],
        },
        # Zones with no entry intentionally spawn nothing.
    },
}
```

### Field contracts

- `tick_seconds`: time between planner ticks. One timer drives all Zones; there are no per-party Timer nodes.
- `spawn_chance`: probability of attempting one party **per represented Zone per tick**, after that Zone's population-cap check. Range `0.0` to `1.0`.
- `weight`: relative selection weight among eligible parties in that Zone. It is not a percentage. In the example, if both definitions are eligible, `rabbit_single` has a 75% conditional chance and `rabbit_pair` 25%; multiplying by `spawn_chance` gives their unconditional chances for that tick.
- `max_parties` / `max_actors`: caps for active parties whose anchor chunks belong to that Zone. Also enforce both caps globally with optional top-level `max_parties` / `max_actors` if later profiling or content requires it.
- `max_alive`: active instances of this party definition in its Zone. Optional; default to no definition-specific limit beyond Zone caps.
- `lifetime_seconds`: inclusive minimum/maximum lifetime rolled once when the party is created. Equal values are allowed. Omit it only for a party intentionally lasting until chunk unload.
- `members`: ordered list of actor name/type/count entries. Expand counts into a concrete member list before placement. `count` must be a positive integer; mixed actor types and mixed species/people are valid.
- `position_attempts`: bounded number of candidate positions per chosen party. Failure to place a party consumes that Zone's roll and waits until the next tick; never loop until a random valid position happens to appear.

Validate data once when initializing the director. Reject non-finite or negative weights, negative counts/caps, reversed lifetimes, duplicate party ids within a Zone, empty expanded member lists, and party sizes larger than `max_actors`. A missing Zone entry means intentionally no spawns; malformed present data should warn with the Zone/party id and skip only the invalid entry. Tests should make malformed content fail loudly even if production warns and skips.

## Tick and selection algorithm

Use one director-owned `RandomNumberGenerator`. Call `randomize()` once for normal play; tests pass a fixed seed. Do not use global `randi()`/`randf()` and do not reseed each tick.

Suggested public API (exact typing can follow implementation needs):

```gdscript
# Pure planning; partyRecords contains data, not Node references.
func planTick(
    loadedChunks: Array,
    partyRecords: Array,
    nowSeconds: float,
    placementContext: Dictionary
) -> Array

# Each returned plan is data only:
# {
#     "partyId": int, "definitionId": String, "zone": String,
#     "chunk": Vector2i, "anchor": Vector2,
#     "members": [{ "type": String, "name": String, "offset": Vector2 }],
#     "expiresAt": float,
# }
```

`placementContext` supplies pure facts needed for candidate validation: present chunk cells/terrain, reserved tiles, current visible world rectangle, and player world position. The director must not acquire these through the scene tree itself.

For each tick:

1. Deduplicate `currentChunk + currentlyLoadedChunks` before passing them to the director. Include only chunks with `presentChunkCells` for terrain-aware placement.
2. Group those chunks by `zoneForChunk(chunk)`. Process Zones in sorted id order and chunks in sorted `(x, y)` order before making RNG calls, so results do not depend on Dictionary iteration order.
3. For each represented Zone, skip if there is no table or either Zone population cap is full.
4. Roll `spawn_chance` once. On success, filter out parties blocked by `max_alive` or by the remaining actor budget. If none remain, stop processing that Zone for this tick.
5. Select one party by weight from the **eligible** definitions. Recompute the weight total after filtering; otherwise a blocked high-weight entry would incorrectly suppress all other parties.
6. Expand its members and roll its lifetime once. Try at most `position_attempts` candidate anchor chunks/tiles from the Zone's loaded chunks. Return a plan only after the anchor and every formation offset pass validation.
7. Add at most one party per Zone per tick. Update population accounting when the scene accepts the complete party, not when the plan is returned.

This produces ongoing variety without a burst that immediately fills every cap. If faster initial population is desired, run the same normal tick once after Overworld initialization; do not use a separate initial-spawn algorithm.

## Dynamic placement and formations

### Chunk/tile to world conversion

Extract the existing spawn-point coordinate formula into one helper and use it for all candidate anchors:

```gdscript
func chunkTileToWorld(chunk: Vector2i, tile: Vector2i) -> Vector2:
    return Vector2(map_to_local(chunk)) \
        - Vector2(32 * 24, 32 * 6) \
        + $OverworldTileChunkTemplate.map_to_local(tile)
```

Candidate local tiles are in `Vector2i(0, 0)` through `HelperVariables.overworldChunkSize - Vector2i.ONE` (currently 64×64). To inspect the corresponding merged tile, preserve the chunk decoder's offset: `getChunkBaseCell(chunk) + tile - Vector2i.ONE`. Add comments/tests for this conversion rather than introducing a second isometric coordinate formula.

### Candidate acceptance

An anchor is valid only when:

- Its chunk is still present and belongs to the Zone being populated.
- Its tile exists in `MergedTiles` and satisfies the party's terrain rule.
- It is outside the current viewport's world rectangle grown by `offscreen_margin_pixels`, and at least `minimum_player_distance` from the player.
- Every actor's formation position passes the same bounds/terrain checks and does not overlap another member or a reserved Location tile.

Start with an allow-all-ground terrain policy for the existing rabbit content. Do **not** guess that atlas/source ids represent water or roads. When content needs terrain restrictions, add an explicit tile-classification table keyed by the merged tile's source/atlas identity and optional `terrain` tags on party definitions. Missing classification should reject the candidate with a useful content warning, not silently spawn in unsuitable terrain.

Record Location-reserved chunk tiles while `setChunk()` already reads chunk `locations` data. At minimum, exclude the authored Location entry tiles. Expand this to full Location footprints if that metadata becomes available; do not perform physics overlap queries for these non-colliding visuals.

### Group offsets

Generate deterministic local formation offsets from the expanded member index. A small row/arc around the anchor is sufficient initially; offsets are local pixel positions, not extra RNG rolls. For example, space members 16 pixels apart on alternating sides of the anchor and center the row:

```text
member index:     0       1       2       3
local offset:  (-8, 0)  (8, 0)  (-24, 0) (24, 0)
```

Validate the whole formation before accepting the plan. If it does not fit, try another anchor; never drop members just to make a party fit. Formation polish can later be data-driven without changing party selection or ownership.

## Spawning and cleanup

### Atomic scene creation

`Overworld.gd` applies each plan as one transaction:

1. Re-check that the anchor chunk is still loaded and the caps still allow the party.
2. Create the party `Node2D` at the anchor.
3. For each planned member, instantiate `OverworldActor.tscn`, validate/load its animation scene, and initialize it with the member's local offset.
4. If any member fails, free the entire party root and emit one warning identifying the party and asset. Do not count a partial party or leave already-created siblings behind.
5. Only after every member succeeds, attach the populated root under `Actors/VisualSpawns` and register the record in `partiesById`.

Avoid adding partially initialized actors to the live tree. In particular, `Overworld.overworldActorIdCount` may increase for a rolled-back instantiation, which is harmless; ids are uniqueness tokens, not population counts.

### Lifetime and off-screen despawn

At each tick, mark parties whose `expiresAt <= nowSeconds`. Despawn an expired whole party only when none of its actors is visible within the viewport plus the despawn margin. If it is visible, set `despawnWhenHidden = true` and check again on later ticks/process updates. This prevents actors disappearing in front of the player while guaranteeing eventual cleanup after they leave view.

Always despawn the whole party immediately when its anchor chunk is no longer in `currentChunk + currentlyLoadedChunks`, regardless of lifetime or visibility. Call this cleanup during the existing chunk-crossing path after `currentlyLoadedChunks` is updated. Also clear all party records/nodes and stop the timer when the Overworld scene exits; do not search actors by name or rely on a sibling node's `_on_tree_exiting()` order.

Use a monotonic seconds accumulator driven by the spawn timer/process rather than wall-clock time. Scene reloads reset it because visual parties are not persisted.

### Visibility conversion

Use the actor's canvas transform to test its world origin in viewport coordinates, e.g. `actor.get_global_transform_with_canvas().origin`, against `get_viewport().get_visible_rect()` grown by the configured margin. Account for each member, not just the party anchor. Add a small sprite/extent margin if large animation sprites can remain visible after their origin leaves the viewport.

Spawning is allowed only outside this padded viewport. Consequently, parties appear by the player travelling toward them or after an off-screen lifetime refresh, never by popping into view at the timer tick.

## Visual-only actor contract

Refactor the spawned `OverworldActor` into a lightweight `Node2D` visual (or remove/disable its `CollisionShape2D` and all collision masks if retaining `CharacterBody2D` temporarily). Do not change `PlayerOverworldActor`, which still needs `CharacterBody2D` movement and collision.

A spawned visual actor:

- Loads and loops its existing Overworld `Idle` animation and shadow.
- Has no `Area2D`, collision layer/mask, input handlers, interactable group, or player detection.
- Has no `process_event_result()` stub and no reference to `OverworldEvents`, `Shootout`, `Locations`, quests, inventory, or rewards.
- Cannot block the player or other actors and cannot trigger Location `body_entered` transitions.
- Is parented only beneath its visual party root and is never registered as a gameplay actor.

The distance-based event popup and Shootout encounter launch flows must remain unchanged.

## Overworld integration

In `Overworld/Overworld.gd`:

- Create/configure `OverworldZoneCatalog` and `OverworldSpawnDirector` during initialization.
- Replace `createSpawnPoint()`, `checkActorSpawns()`, `_on_animal_spawn_point_timer_timeout()`, and the `Spawnpoints` branch of `removeFarawayObjects()` with director planning, party application, and party cleanup methods.
- Keep `Locations` chunk-script handling unchanged. Delete only the `spawnPoints` handling in `setChunk()` and retain reserved-tile metadata needed by placement.
- Rename the scene timer and signal to visual-spawn terminology. Disable autostart and start it after the initial player position/chunks are established to avoid a tick against incomplete initialization.
- Run one normal planning tick after initialization if immediate off-screen population is wanted, then use the configured timer cadence.
- On chunk crossing, use the existing order as the integration point: update current/loaded chunks, unload old chunks, despawn parties outside the new loaded set, then notify music. Spawn rolls remain timer-driven.

Do not perform director work on the chunk-loading worker path. Background resource parsing stays as-is; director planning and scene creation run on the main thread.

## Files to create / modify / remove

**Create**

- `Data/Overworld/ZoneData.gd` — shared Zone bands, moved unchanged from music data initially.
- `Data/Overworld/SpawnData.gd` — Zone tables and initial rabbit party definitions.
- `Overworld/OverworldZoneCatalog.gd` — shared pure chunk-to-Zone resolver.
- `Overworld/OverworldSpawnDirector.gd` — seeded planning, weighted selection, caps, placement, and expiry decisions.
- `Tests/TestOverworldSpawns.gd` — headless data/planner tests and scene-lifecycle checks where needed.

**Modify**

- `Overworld/Overworld.gd` and `Overworld/Overworld.tscn` — scene adapter, timer, visual party root, cleanup, and coordinate/placement helpers.
- `Actors/Overworld/OverworldActor.gd` and `.tscn` — visual-only actor contract.
- `Overworld/Overworld Chunks/#8#16.gd` and `.tscn` — remove the legacy rabbit `spawnPoints` block; detach/remove the script if the chunk then has no other data.
- `Globals/Overworld.gd` — remove `overworldSpawnpointIdCount`; retain only counters still used by the new actor naming.
- `Data/Music/MusicData.gd` and `Globals/MusicPlayer.gd` — consume shared Zone geography; keep music decisions separate.
- `Docs/System Design/Music player.md` — update the Zone-data source.
- `Tests/TestMusicPlayer.gd` — preserve Zone behavior with the shared catalog/injected test data.

**Remove after references are gone**

- `Overworld/OverworldSpawnpoint.gd` and `Overworld/OverworldSpawnpoint.tscn` (plus generated `.uid` files as applicable).

## Testing

### Headless planner tests

`Tests/TestOverworldSpawns.gd`, run with `godot --headless --script res://Tests/TestOverworldSpawns.gd`, should cover:

- Single Zone source: first matching inclusive band wins; out-of-range chunks use the shared `default_zone`; music, spawns, and other consumers sharing an injected catalog return identical Zone ids; consumer data contains no private Zone dimensions/fallbacks.
- Seeded repeatability: same data, seed, chunks, records, and time produce identical plans; different Dictionary insertion orders do not change results.
- Weighted choice: with no caps blocking entries, a seeded distribution is reasonably close to relative weights; zero-weight entries never spawn.
- Chance semantics: `spawn_chance = 0` never spawns and `1` attempts one party per eligible Zone per tick.
- Eligibility: `max_alive`, Zone actor cap, and Zone party cap are enforced; blocked definitions are removed before weights are normalized.
- Group composition: counts expand correctly, mixed name/type entries survive planning, a multi-actor party counts as one party and N actors, and no partial group is returned.
- Population scope: each loaded chunk uses its own Zone table; the current chunk is included; one chunk cannot be processed twice.
- Placement: attempts are bounded, only present chunks are used, padded on-screen/player-near/reserved/invalid-terrain candidates are rejected, and all member offsets must fit.
- Lifetimes: expiry uses the rolled lifetime, visible expired parties are deferred, hidden expired parties despawn, and chunk unload always despawns the whole group.
- Content validation: duplicate ids, invalid weights/counts/lifetimes, unknown actor animation paths, and parties larger than the actor cap are diagnosed.
- Rollback: an invalid member asset frees the whole unregistered party and leaves population counts unchanged.
- Repeated chunk load/unload and scene exit leave no `VisualParty*` nodes, stale records, timers, or warnings from sibling cleanup order.

Use small fake chunk/placement contexts for planner tests instead of loading the entire Overworld. Add focused scene tests only for coordinate conversion, node ownership, visibility, and rollback.

### Manual checks

1. Start near the existing canyon rabbit area. Confirm no legacy fixed triple-rabbit point remains and new parties appear only after travelling toward off-screen spawn positions.
2. Stand still through several ticks. Confirm Zone caps hold, no actor pops into or out of view, and off-screen expired parties are eventually replaced using the weighted table.
3. Cross a Zone boundary. Confirm each side retains its own party table and music still changes exactly once using the shared Zone lookup.
4. Cross chunk boundaries repeatedly and enter/leave a Location. Confirm whole parties clean up, no actors survive in unloaded chunks, and node counts do not grow indefinitely.
5. Walk through visual actors. Confirm there is no collision, prompt, click behavior, event popup, Location transition, or Shootout.
6. Verify multi-actor groups stay together for their entire lifetime and use their intended formation/animation/shadow rendering.

## Implementation order

1. Make `ZoneData.gd` the sole Zone-dimension dataset and test the shared catalog; switch every existing consumer (currently music) without changing geography or behavior.
2. Add spawn data validation and the seeded pure director; test weighted selection, eligibility, caps, and group expansion before scene integration.
3. Add coordinate/placement helpers and tests using small chunk contexts.
4. Convert spawned actors to visual-only and implement atomic party creation/ownership in `Overworld.gd`.
5. Add timer ticks, lifetime/off-screen despawn, and chunk-unload cleanup.
6. Replace the rabbit chunk spawn point with Zone table content; remove legacy spawn-point scripts/scene references.
7. Run headless planner/music regression tests, then perform the manual boundary, visibility, and cleanup checks.

## Decisions and open content work

Decided by this design: `ZoneData.gd` alone supplies Zone dimensions to every component. Parties are transient, selected per anchor-chunk Zone, weighted after eligibility filtering, capped at both party and actor level, spawned off-screen as complete groups, and despawned off-screen or on chunk unload. They never participate in gameplay interactions. Parties remain stationary; current Location pathfinding is not an Overworld movement solution.

Still content/balance work rather than architecture blockers:

- Final Zone geography in `ZoneData.gd` (the existing bands remain provisional).
- Initial rates, lifetimes, population caps, and off-screen/player-distance margins.
- Terrain classification and which party definitions may use each terrain tag.
- People and additional animal animation assets and their party compositions.
- Formation art/polish and whether future ambient wandering justifies a separate streaming Overworld navigation design.
