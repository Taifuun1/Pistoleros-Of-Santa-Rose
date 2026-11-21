# Content and balance catalog

This is the authoring map for the systems described in `Docs/System Design`, verified against the current implementation on 2026-11-15. It covers their directly connected narrative, event, item, and minigame content sources as well. Paths below use Godot's project-absolute `res://` form.

Companion documents: [Implementation gaps](Implementation%20Gaps.md) records unfinished work; [System coherence](System%20Coherence.md) defines the contracts needed between these extension points.

## Authoring rules

- Most combat content is a GDScript exposing `var data = {...}`. `Globals/Shootout.gd::loadDataFolder()` loads only immediate `*.gd` children of each registered folder and keys entries by **`data.name`**, not filename; a duplicate `data.name` silently overwrites the earlier file, so `Tests/TestContentLint.gd` rejects it. The legacy `Data/Shootout/Moves/Pistolero.gd` shape (`var moves`) is not registered and should not be copied.
- Quest definitions are typed Resources (`.tres`), the Overworld map manifest is generated, and Party members are currently initialized in code. These are deliberately different workflows.
- Stable ids connect systems. Zone ids, item `definitionId`s, item `instanceId`s, vendor ids, encounter paths/names, loot-table names, quest/objective ids, and Location ids must not be renamed casually.
- A definition existing on disk does not make it reachable or functional. Encounters need a launcher/pool, items need an acquisition/loadout path, actors need data and animation scenes, and vendors need both catalog and scene placement. Content must also respect the explicit On/Off Trail state: Off Trail permits town-to-town Overworld travel and quest progression, but disables non-town Location access, attrition mechanics, and loot from every source.
- Basic weapon attacks are not a content path for either side. Author offensive actions as Moves (`attack_ability` where the Cylinder applies); the current enemy-AI basic `Attack` branch is legacy behavior to remove.
- Do not hand-edit `res://Data/Overworld/OverworldMapData.tres`, `res://Assets/Journal/OverworldMap.png`, or `res://Assets/Journal/OverworldMapOverview.png`; regenerate them after changing their sources.
- Run focused content tests and then `godot --headless --path . --script res://Tests/RunAll.gd`. `Tests/TestContentLint.gd` is the production content lint (duplicate names, reference and canonical-Zone resolution, Trail-gated reward and non-town Location-access producers); run it before committing content. For map changes also run `godot --headless --path . --script res://Tools/GenerateOverworldMap.gd -- --check` after regenerating.

## 1. Shared world, Zone, event, and narrative datasets

| Source | Content and balance owned here | Consumers and authoring notes |
|---|---|---|
| `res://Data/Overworld/ZoneData.gd` | Six canonical snake_case Zone ids, display names, the ASCII chunk map (`zone_map` rows + `legend` + map dims), `default_zone` | Sole Zone-geometry source. Geography is a drawn map: one character per chunk, parsed by `res://Overworld/OverworldZoneCatalog.gd` into a chunk→Zone lookup (music, equipment, vendors, newspapers, and encounter pools consume ids only; future spawns and launchers must too). Do not add Zone geometry to consumers. The canonical set: five progression Zones (`whispering_pines_reach` starting, then `rocky_hills`, `snowy_mountain`, `prairie`, `swamp`) plus the non-progression `wild_west` mid-map Zone. The other progression Zones keep generic names until canonically named; the drawn boundaries are placeholders until the owner redraws them on the map. |
| `res://Data/Overworld/WorldData.gd` | 12×24 world grid, chunk-scene path format, chunk-map tile size, shared tileset path | Changes world topology and map generation. `HelperVariables.overworldChunkSize` separately owns the 64×64 tiles per chunk. |
| `res://Overworld/Overworld Chunks/#{x}#{y}.tscn` | Terrain tiles for each chunk | Author in the Overworld tileset. 274 chunk scenes currently exist inside the declared grid; missing chunks are coverage holes, not automatic grid changes. |
| `res://Overworld/Overworld Chunks/#{x}#{y}.gd` | Optional per-chunk `locations` and legacy `spawnPoints` Dictionaries | A Location entry has `tiles`, `pregenerated`, and optional `isTown`, `map_visibility: "secret"` plus `secret_id`. Keep its dictionary key stable: it becomes the map/quest/discovery Location id. Legacy `spawnPoints` uses actor `type`, first tile, percent `chance`, and `maximum`; it is scheduled for replacement, not the future party-table format. |
| `res://Data/Overworld/MapTileStyles.gd` | Source/atlas tile to semantic feature and authored color/priority mappings; overrides | Affects the baked map only, not collision. Update alongside terrain art/tileset changes and keep `Journal/Tileset Classification.md` accurate. |
| `res://Data/Overworld/OverworldMapData.gd` and generated `OverworldMapData.tres` | Manifest schema/validation plus generated projection, fingerprints, overview LOD and normalized Location entries | The `.tres` is read-only generated output. Location POIs, secret visibility and quest target resolution come from here; the `.gd` defines format version 2 and resolution rules. |
| `res://Data/Overworld/SecretMapData.gd` | Map ids to ordered `targetIds`; secret Location or `secret_item` target definitions | Location targets resolve through the generated manifest. Secret-item targets instead carry `chunk` and `tile`. Reveal data grants no loot and moves no player; world content must be authored separately. |
| `res://Data/Music/MusicData.gd` | Zone/Location/menu/shop/Shootout playlists, per-encounter and per-Zone combat music, outcome stingers | Track id is the OGG path below `res://Assets/Music` without `.ogg`. Encounter `music` overrides the encounter-name registry, then encounter `zone`, then the launching request `zoneId`, then the default fight playlist. Zone geography does not belong here. |
| `res://Data/Events/GenericEvents.gd` and `GrasslandEvents.gd`, `ForestEvents.gd`, `DesertEvents.gd`, `SwampEvents.gd`, `CanyonEvents.gd` | Event display name, body text, `image_type`, optional music, choice labels and explicit choice `outcome` Dictionaries | `Globals/OverworldEvents.gd` merges generic and canonical-Zone pools. A choice with only a legacy `result` string is disabled as unavailable; reachable choices must carry `outcome.kind` (`none` or `encounter`). |
| `res://Globals/OverworldEvents.gd` | Event cadence, canonical Zone event-pool mapping and production RNG | `MINIMUM_EVENT_DISTANCE = 1.0`, `EVENT_CHANCE_PER_TICK = 0.15`, `ZONE_EVENT_FILES` and `rng` are code-side balance/cadence. Zone lookup goes through `OverworldZoneCatalog`; never add chunk rectangles here. |
| `res://Overworld/OverworldEventOutcomeResolver.gd` | Explicit event choice outcome validation/execution | Supported kinds are `none` and `encounter`. Encounter outcomes may name an `encounter` path or a `poolZone` resolved through `EncounterPoolData.selectEncounter()`. Unknown or legacy outcomes fail closed and the popup disables them. |
| `res://Data/Location Generation/*.gd` | Per-generated-Location `generationVariables`, weighted `chunkGenerationTypes.chance`, noise maps/cutoffs, tile transforms, interactable species/type/count/tile rules | Current production files cover Clearwater Grove, Donnafolk Cave, and West Field Mines. Operations are consumed by the Location generation/ChunkProcessor pipeline; validate every referenced noise resource and interactable animation. |
| `res://Data/Quests/QuestDefinition.gd`, `QuestObjectiveDefinition.gd`, `QuestCatalog.gd` | Typed schemas for linear quests and objectives | Objective fields are `objective_id`, current/history text, and optional `map_target_id`. Definitions have `quest_id`, title, summary, sort order, and ordered objectives. |
| `res://Data/Quests/Definitions/*.tres` and `QuestCatalog.tres` | Authored quests and catalog registration | A new quest needs both a definition Resource and a catalog entry. Only Pistoleros Regroup is currently registered. Map targets must name generated manifest Location ids. |
| `res://Data/Cutscenes/{Arc}/{Name}.gd` | Cutscene setting/next Location, actors, ordered camera/wait/animation/move/dialog/particles/music/quest shots | Quest shots call `start` or `complete_objective` with canonical quest/objective ids. Ninety-three cutscene scripts currently exist; add corresponding setting scenes, actor animations, and played-cutscene/transition wiring where required. |
| `res://Globals/Cutscene.gd` and `res://Globals/Locations.gd` | Current cutscene/Location selection, played-cutscene flags, authoritative On/Off Trail state, Town context, last Town, trail departure counter, minigame points/materials | These are session-state owners, not general content catalogs, and each exposes a versioned save snapshot (`STATE_FORMAT_VERSION`). `startTrail()` is the only Trail start/stock-reset command; `enterTown()` records the last resupply Town, ends an active Trail and (through `townEntered`) applies recovery once — it is also Vamoose's Town destination command; `enterOverworld()` clears the Town context for the Off-Trail Town exit and never starts or ends a Trail. `canAccessLocation()`, `canApplyAttrition()` and `canGrantLoot()` are the shared gates. Town classification is authored per Overworld Location entry via `isTown`. Authored cutscene names live in `PLAYED_CUTSCENES_DEFAULT`; the save payload always contains those keys. |
| `res://Globals/NewGameCoordinator.gd` | New Game reset order across domains (Party, Quests, Locations, Overworld, Cutscene, OverworldEvents, Vendors, Discovery, PokerMoney, Poker) | `SceneManager.startNewGame()` owns modal/context cleanup and the Overworld transition; each domain resets through its own `resetForNewGame()`. New Game always starts Off Trail. |
| `res://Globals/SaveGame.gd` | The only disk save (autoload `SaveGame`): payload version, migration steps, save path, checkpoint policy | One JSON payload per `COMMIT_ORDER` (`party`, `quests`, `locations`, `cutscene`, `vendors`, `discovery`, `overworld`) plus `formatVersion`/`savedAt`. `SAVE_FORMAT_VERSION` is 2; `LEGACY_FORMAT_VERSION` 1 is the pre-service payload and `MIGRATION_STEPS` maps each source version to its upgrade function. `DEFAULT_SAVE_PATH` is `user://savegame.json` with `.tmp`/`.bak` siblings. Domain payloads are authored by each domain's own `exportState()`; keep new persistent state inside an existing domain rather than adding a second writer. |

## 2. Combat and actor datasets

| Source | Content and balance owned here | Consumers and authoring notes |
|---|---|---|
| `res://Globals/Party.gd::party` | Live party members: HP/base HP, core/offense/defense/resistance stats, injury fields, Rodeo, class, four activated moves, `beltReservations` (`{instanceId, combatId, quantity}`), character Magazine, seven equipment slots | Party members referenced by an encounter use this live data. Belt entries reference carried consumable stacks and are resolved to combat names at fight setup. Only Walker Langley is currently initialized; adding a full party requires member data here, not only an actor file. |
| `res://Data/Actors/{type}/{name}.gd` | Non-Party actor stats, HP, speeds, Rodeo/class/loadout/Magazine/weapon, optional `ai` block | Encounter names resolve to `res://Data/Actors/{type}/{ActorNameWithoutSpaces}.gd` across `Animals`, `Bandits` and `Named People`. Commit 17 adds the Whispering Pines Reach bandits (Pistolero, Bobtail Guard, Dust Whisperer, Line Rider, Whiskey Bulldozer) and the main-party data files (Aiyana, Gwyneth Remington, Manuel Cárdenas, Morrison Branson — the production Party still only initializes Walker Langley, so encounters reference these files directly). The `ai` profile (`archetype`, `pickFromTop`, per-family `weights`, `preferredColumns`, `script`) is validated by the content lint; Squeky rat authors the wide Dust-up proof (`pickFromTop: 3`) and the bandits profile the support/tank roles. |
| `res://Data/Actors/ActorAnimationRegistry.gd` + `Globals/ActorAnimationService.gd` | The commit-17a data registry and builder service (fully implemented since commit 19) | New content authors animation states as data instead of duplicating `*Animations.tscn` scenes: sheet path, frame size or whole-sheet, frame count, step, loop, `idleByWeapon` (default Idle otherwise), per-state `normalMap` and the `"runtime": "overworld"` kind (Sprite2D + CanvasTexture + looping tracks for Overworld wanderers). The service builds the runtime in code with one cached `SpriteFrames` + `AnimationPlayer` library per actor id; spawn-index suffixes are stripped for the lookup; unknown actors/states degrade with a warning, and the legacy-scene merge/fallback remains only for future unregistered actors (all migrated legacy scenes are deleted). `FrameData` remains the combat hit-frame read. |
| `res://Data/Items/AffixData.gd` + `Globals/CombatStatRegistry.gd` | Affix stat values/kinds, prefix/suffix pools, and the one per-affix decision record (`AFFIX_DECISIONS`: kind, generation eligibility, consumer/exclusion reason) | Generation pools roll only registry-eligible stats; vendor pricing reads the same record and fails closed on unknown stats. Excluded stats (turnOrder, mxEn, lassoDamage, lootGems, liquidSkullDuration, negativeEffectDurationReduction, poisonAffliction, bleedAffliction) keep value records so legacy items stay sellable but cannot re-enter a roll. The content lint audits the table against `AffixData` with broken-fixture teeth. |
| `res://Data/Shootout/Classes/*.gd` | Class `name`, Magazine, `beltSpace`, Sand defense, explosive base, canonical `moves` grants, non-runtime `futureAbilities` backlog | Five classes exist. Commit 17 moved the implemented Bobtail Guard, Dust Whisperer, Line Rider and Bottle Courage Bulldozer prose into executable `moves` grants (Venom Shot, Cylinder Drop, Mark Target; Open Vein, Bleed Cleanse, Toxin Throw, Poison Cleanse, Type Mark, Weaken, Piercing Coat; Poison Cleanse, Sharpened Spurs; Bottle Up, Cylinder Boost, Duck Down); only the two position-disruption designs (no move op yet) remain in `futureAbilities`. Grants resolve through `Globals/CombatLoadoutProjector.gd` with the four-Move cap; legacy `abilities` prose fails the lint. |
| `res://Data/Shootout/Moves/*.gd` | Move `name`, `category` (`ability`, `attack_ability`, `duck`), base amount/scaling, side, positions, effect operations, animations | Registered by exact `data.name`; actor `moves` must match it. Attack abilities advance the Cylinder; Ducks and utility abilities do not. All weapon attacks for both teams are authored through Moves (`Scratch.gd` is the rat's attack); no basic-attack definition or AI-only basic attack should be added. |
| `res://Data/Shootout/Items/*.gd` | Combat-item name, healing/amount/effects, side/positions, animations | `ItemCatalog.definitions[].combatId` must exactly match this `data.name` for carried consumables. Combat currently consumes names from an actor's belt array, not shared inventory stacks. |
| `res://Data/Shootout/Rodeos/*.gd` | Passive `trigger`, conditions, effects, level `scaling` | Six definitions exist. Actor Rodeo lookup is case-normalized. Supported operations include stat/position/heal/loot/effect/cylinder/hit-quality behavior; unsupported operations warn and skip. |
| `res://Data/Shootout/AI/*.gd` | Optional boss priority rules with HP conditions and act/target selectors | Loader support exists, but the directory and production boss scripts do not. Actor `ai` selects archetype, preferred columns, aggression, and script. |
| `res://Data/Shootout/Encounters/*.gd` | Encounter name, dustup/showdown kind, flavor, background, optional zone/music, loot table/enablement, win condition, nested teams | Each actor entry lists unique positions 1–4. Party-named actors use live Party data; other actors load from `Data/Actors`. `loot: false` reserves payout for quest completion. `LittlehillApproach.gd` is the authored prologue quest encounter and carries no combat loot table; `RatAmbush.gd` is only the direct-scene debug encounter. Commit 17 adds the Whispering Pines Reach encounters (`PinesPatrol`, `PinesWaylay`, `PinesStandoff` — a Showdown fielding the tank/support/rider classes against three Pistoleros). Production launch goes through `EncounterRequest`/`SceneManager`. |
| `res://Data/Shootout/EncounterPools/{zone}.gd` | Per-Zone weighted encounter paths and `newspaperPublic` flags | Filename is the canonical Zone id. The same pool drives gameplay selection and newspaper projection. Authored pools: `wild_west.gd` (Canyon Rats weight 3, Canyon Rat Nest weight 1) and `whispering_pines_reach.gd` (Whispering Pines Patrol weight 3, Whispering Pines Waylay weight 2, Whiskey Bend Standoff weight 1; commit 17). |
| `res://Data/Shootout/EncounterPoolData.gd` | Pool loading, merging, public-entry filtering, cross-data validation and seeded weighted `selectEncounter()` | `loadProductionPools()` reads immediate pool scripts and uses each filename as its Zone id. Use `validateAuthoredPools()` for new content; malformed pool files/entries must not silently disappear. Gameplay selection takes an injected RNG for determinism. |
| `res://Shootout/EncounterRequest.gd` | Validated launch contract: encounter path, canonical Zone, source/sourceId, origin, progression and Trail snapshot, optional seed | Built by `SceneManager.launchShootout()` or event outcomes. Rejects missing encounter data, non-canonical Zones, unknown sources, malformed Trail snapshots and negative seeds. |
| `res://Data/Shootout/LootTables/*.gd` | Table name, progression `band`, money chance/range, roll count, weighted consumable/gear/resource entries and rarity pools | `lootTable` on an encounter must match `data.name`. Stackables use `ItemCatalog.definitionId`. Authored tables: the early `Rats` table and the commit-17 `Bandits` table for the Whispering Pines Reach parties. Band selection is not implemented, while encounter-Zone propagation into generated equipment is implemented (commit 4) and Off-Trail loot stays empty. |
| `res://Globals/Shootout.gd` | Team/act constants, screen coordinates for four columns per side, flavor lists, data-folder registry, single pending `EncounterRequest` handoff | Add new data folders to `loadData()` when introducing a new content type. `shootoutPositions` is layout/balance code, not per-encounter data. |
| `res://Globals/FrameData.gd` | Weapon-family animation hit frames | Revolver/rifle hit frame 5, scratch hit frame 3. Every new weapon/animation family needs a valid frame and matching animation content. |

## 3. Items, equipment, vendors, and discovery

| Source | Content and balance owned here | Consumers and authoring notes |
|---|---|---|
| `res://Data/Items/ItemCatalog.gd` | Stackable `consumable`, `resources`, and `map` definitions: stable id, type, combat id/effect, display data, stack limit, droppable flag, sprite | Shared by loot, inventory, vendors, and Discovery. Current definitions are Paregoric, Doctor's Kit (`multi_heal`, `MultiHeal.gd` `positions.type: multi` so one belt use heals every living ally), and Canyon Cache Map. Add a combat definition for every consumable and reveal data for every map. |
| `res://Data/Items/WeaponData.gd` | Family Magazine patterns and position ranges, rollable weapon bases/sprites, per-base economic values, optional `grantedMoves` | Weapon base damage is currently rolled from the family's `AffixData` range, not authored per base. Every new base needs a unique id, sprites, and `baseValues` entry. Family-level Magazine/range entries cover all bases in that family. `grantedMoves` (Cattleman: `Sharp Shot`) is copied onto rolled instances and joins the loadout projection. |
| `res://Data/Items/EquipmentData.gd` | Six non-weapon equipment slots, generic bases/base stats, slot sprite pools, Zone/town equipment, `dropsAnywhere`, optional `beltSpace`, optional `grantedMoves`, economic values | Zone entries currently provide flavor/base identity; generation applies generic slot base stats. Every new definition needs a positive `baseValues` entry. Canonical Overworld equipment uses Zone ids from `ZoneData`. `grantedMoves` joins the loadout projection like weapon grants. |
| `res://Data/Items/AffixData.gd` | Per-rarity affix ranges, display metadata/kind/category, prefix and suffix pools | Every non-legendary generated item receives one prefix and one suffix. Many authored stats do not yet affect combat; `Globals/CombatStatRegistry.gd` marks each path `fully_supported`/`display_only`/`unsupported` and gates effect stat modifiers. Values are initial placeholders. |
| `res://Data/Items/LegendaryData.gd` | Thirteen fixed legendary items, family/slot, base damage, stats, sprite/lore, economic values | Created explicitly through `ItemGeneration.generateLegendary(key)`; no production loot/quest award currently calls it. Fixed stats have the same supported-mechanics limits as affixes. |
| `res://Globals/ItemGeneration.gd` | Rarity display names, base/affix assembly, loot rolling, optional injected RNG | Default rarity comes from `Quests.currentMainQuestLevel.rarity`, currently static common. Loot supports money, catalog consumables/resources, and generated gear. |
| `res://Data/Vendors/VendorCatalog.gd` | Stable vendor id/kind/name, parent Location and Zone, interior scene, fixed offers/prices or rolled stock type/count | Current five vendors are all in Lazysprings. Kinds are `general`, `gun`, `equipment`, `bank`, `newspaper`. Catalog data alone does not place doors/NPCs. |
| `res://Data/Vendors/VendorPricing.gd` | Rarity multipliers, value per affix point by kind, buy markup 1.0, sell ratio 0.25 | Base values live with item datasets. Sale ratio must remain between zero and one; tests should preserve the no-arbitrage bound. |
| `res://Data/Vendors/NewspaperData.gd` | Zone headline/editorial, general tips, per-encounter tips keyed by encounter file basename | Contains prose only. Enemy composition is projected from shared encounter pools and actor data. Authored copy: `wild_west` and `whispering_pines_reach` (commit 18); tips for unpublished encounters fail validation, and Zones without copy correctly report newspaper data unavailable. |
| `res://Vendors/VendorStockGenerator.gd` | Deterministic rolled-stock seed composition and offer ids | Stock seed derives from base seed, explicit trail-departure id, and vendor id. Vendor Zone is passed into equipment generation. |
| `res://Globals/Vendors.gd` | Shared Bank, stock persistence/reset, transaction guard, `MAX_PURCHASE_QUANTITY = 9999`, versioned snapshots | Runtime domain, not an authoring catalog. Purchases/sales/transfers revalidate through Party and InventoryRules. |
| `res://Globals/Discovery.gd` | Revealed target ids, atomic map use, versioned discovery snapshots | A map can be consumed only after all targets validate. Reveal state and vendor stock are save-ready, but no application save service consumes them yet. |
| `res://Globals/Party.gd` and `res://Globals/InventoryRules.gd` | 24 occupied-stack slots, stable instance allocation, stacking/capacity, atomic commerce/equipment rules, belt reservation commands (`reserveBeltItem`/`unreserveBeltItem`/`getBeltSnapshot`), one-shot fight consumption commit, Vamoose whole-stack removal with reservation reconciliation, and the versioned Party snapshot | Equipped gear is outside carried inventory and the Bank lives in Vendors, so neither is part of Vamoose's carried-stack loss. Belt entries reference carried stacks and count against effective belt space by entry, not reserved quantity. Loot intentionally accepts partial overflow when On Trail; Off Trail generates/applies no loot. Commerce and transfers are all-or-nothing. |

## 4. Scene and node extension points

| Node/scene | How it carries content or balance |
|---|---|
| `res://Overworld/Overworld.tscn` | Current `Locations`, `Spawnpoints`, `Actors/Animals`, player, and 10-second legacy spawn timer. The dynamic-spawn design instead proposes `Actors/VisualSpawns/VisualParty*` and one `VisualSpawnTimer`; those nodes/director/data do not exist yet. |
| `res://Actors/Shootout/ShootoutActor.tscn` | Shared fighter instance. Combat actors additionally need `res://Animations/{actorType}/{ActorNameWithoutSpaces}Animations.tscn`; weapon idle and `FrameData` hit frames must exist. After commit 17a those animation sets resolve through the shared registry/service instead of hand-edited scenes. No per-encounter scene subclass is needed. |
| `res://Actors/Overworld/OverworldActor.tscn` | Shared visual actor. Requires `res://Animations/Overworld/{type}/{ActorNameWithoutSpaces}Animations.tscn` with `Idle`; missing animation aborts the spawn. |
| `res://Shootout/Shootout.tscn` and `res://Shootout/UI/*.tscn` | Shared combat field, acts, turn strip, Cylinder/effect displays, HP and result UI. Encounter backgrounds/actors come from data; multi-target presentation and pre-transition Flair remain incomplete. |
| `res://Nodes/Scene Manager/SceneManager.gd` and `.tscn` | `SCENES` registry, initial scene, fade/loading delays, allowed-Journal scenes, persistent Journal/Vendor layers, encounter launch/return context. Add a registry key for a new scene type; a pre-transition FlairLayer is designed but absent. |
| `res://UI/Journal/Journal.tscn` and `res://UI/Journal/Tabs/*.tscn` | Shared Map/Inventory/Quests/Character/Settings presentation. New domain content normally requires no new tab nodes; add only genuinely new interaction/views. Settings is intentionally unavailable. |
| `res://Location/Entities/Vendor/VendorDoor.tscn` | Exterior entry. Set `vendorId`, optional `returnOffset`, prompt and kind icon. Place beneath a Location with a `LocationInteractionDirector`. |
| `res://Location/Vendors/VendorRoom.tscn` | Generic shell with player, director, and `VendorExit`; loads the catalog interior and its `PlayerSpawn`. Reuse rather than duplicating this shell per shop. |
| `res://Location/Vendors/Interiors/*.tscn` | Interior art/collision, `PlayerSpawn` Marker2D, and `VendorActor` with matching `vendorId`/prompt. The same vendor id must connect catalog, exterior door, and interior actor. |
| `res://Location/Entities/Trail/TrailDeparture.tscn` | Explicit interaction used in a Town to call `startTrail()` exactly once and enter the Overworld. Starting a Trail enables attrition and permits non-town Locations and loot; Town entry ends the Trail through `Locations.enterTown()`, while incidental Overworld or vendor-room transitions do neither. |
| `res://Location/Entities/Town/TownExit.tscn` | Off-Trail Town exit. Placed in a Town interior (Lazysprings) to leave through `Locations.enterOverworld()` without starting or ending a Trail, keeping quests and town-to-town travel reachable Off Trail. Prompt defaults to **Leave town**; place it one activation area (~36px) away from the `TrailDeparture` so the two exits never share a target. |
| `res://Nodes/Interaction/LocationInteractionDirector.tscn` and `LocationInteractable.gd` | Closest-target selection, fresh INTERACT activation, prompt. New persistent Location interactions should derive from the base target and use `location_interactables`/`location_player` conventions, not the older self-freeing Interactable. |
| `res://Location/Locations/{Name}/{Name}.tscn` | Pregenerated world content. Use `PregeneratedLocation.gd::initScene()` when vendor-safe player return positioning is needed. A secret Location still needs playable content after its marker is revealed. |
| `res://Location/Locations/{Quest}/{Location}/*.tscn` and `res://Cutscenes/Cutscene.tscn` | Quest setting scenes, exits and cutscene triggers. Quest progress belongs in cutscene quest shots, while `Locations.currentQuest` currently selects the setting path. |
| `res://Location/Location Generation/Wave Function Collapse/WFCInputCreation.tscn` and input template scenes | WFC source TileMaps used to build reusable models. Generated Location scenes assemble layout, solver, ChunkProcessor, player/exits and optional PlayerReveal. |
| `res://Shaders/PlayerRevealController.tscn` and `RevealableObject.gd` | Add controller to a Location and initialize it with the player; mark occluding objects `revealable` or attach the component. Per-material radius, softness, minimum alpha and enabled state are presentation knobs. |
| `res://UI/OverworldEvent/OverworldEventPopup.tscn` | Generic event presentation; no per-event scene needed. `image_type` maps to a shared icon. Outcome execution belongs outside this popup. |
| `res://Minigames/Poker/Poker.tscn`, `res://Minigames/Poker/Card.tscn` | Four-seat layout, card slots and actions. `Globals/Poker.gd` owns 52 cards, AI personalities and default players; `Poker.gd` owns blind/timing/hand-size constants. New table sizes require both data and scene path changes. |
| `res://Minigames/Bear Hunt/*.tscn` and `res://Minigames/Gold Rush/*.tscn` | Minigame-specific layouts and object scenes. Their scripts contain spawn/timing/speed/score constants; `Locations.minigamePoints` and `collectedPanningMaterials` carry results. |

## 5. Balance knobs currently living in code

These values are implemented and tunable, but changing them requires a code edit. Promote a value to a dataset only when content authors need to vary it by encounter, Zone, item, or difficulty; avoid creating a second copy of a shared constant.

| Source | Implemented knobs |
|---|---|
| `res://Globals/Party.gd` | Provisional New Game money 1000; inventory capacity 24; flee injury 20%; default injury rate 4; fighters start at effective max HP with no persistent knockout state; Vamoose stack loss 15% of occupied stacks rounded up with a minimum of one (`VAMOOSE_STACK_LOSS_FRACTION`); Party/New Game snapshot format version 1 (`STATE_FORMAT_VERSION`). |
| `res://Globals/SaveGame.gd` | Save payload version 2 (`SAVE_FORMAT_VERSION`); legacy payload version 1 (`LEGACY_FORMAT_VERSION`); `MIGRATION_STEPS` per source version; save path `user://savegame.json` plus `.tmp`/`.bak`; Overworld-boundary checkpoint policy (`SceneManager.autosaveEnabled`). Integral JSON numbers are normalized back to ints on read, because JSON has no int/float distinction. |
| `res://Shootout/ShootoutTurnManager.gd` | Initiative random roll 0–4; Showdown flee threshold turn 10. |
| `res://Shootout/ShootoutCylinderManager.gd` | Miss/Graze/Hit/Critical multipliers 0/0.5/1/1.5; all-Hit fallback; Cylinder length 2–6. |
| `res://Shootout/ShootoutEffectManager.gd` | Piercing/decrease stack limit 4; poison retains 65% per Round (35% wear-off); unconsumed marks expire after 2 Rounds. |
| `res://Shootout/ShootoutEnemyAI.gd` | Pick from top 2 scored acts; kill bonus 50; archetype/scoring calculations and Dust-up/Showdown behavior currently shared. |
| `res://Actors/BaseActor.gd` | Four-move cap, melee fallback base damage 2, unknown-class belt space −1 (uncapped). |
| `res://Shootout/Shootout.gd` | Between-act pause 0.4 s, reposition slide 0.3 s, Rodeo beat 0.25 s, targeting tint; combat flow timings. |
| `res://Globals/MusicPlayer.gd` | Playlist switch fade 1.5 s, tail fade 3 s, silent floor −60 dB. |
| `res://Overworld/OverworldChunkStreamCache.gd` | Preload radius 2 chunks and merged-cell write budget 8192 operations per frame; performance rather than game difficulty. |
| `res://Globals/Overworld.gd` | Initial spawn chunk `(8,12)` and tile `(40,38)`; live/last-known player provider state. |
| `res://Globals/HelperVariables.gd` | 64×64 Overworld chunk tiles, 24×48 Location chunk tiles, 24×12 isometric tile size, adjacent directions; coordinate/layout constants shared by generation and placement. |
| `res://Nodes/Scene Manager/SceneManager.gd` | Fade 0.3 s, loading-screen delay 0.2 s, main-menu initial scene, Journal scene allowlist. |
| `res://Tools/OverworldMapBaker.gd` | Overview 4×4-cell blocks, 25% minimum fill, 30% area share for non-linear features; map readability tuning. |
| `res://Shaders/PlayerRevealController.gd` | Runtime reveal radius 70, softness 10, minimum alpha 0. |
| `res://Minigames/Poker/Poker.gd` | Blind 5, four-card flushes, five-card straights, animation/showdown timings. AI `raiseLimit` values live in `Globals/Poker.gd`. |
| Bear Hunt and Gold Rush scripts | Durations, speeds, spawn intervals/caps, score values, drop rates and playfield bounds are constants in each minigame script, not a shared balance file. |

### Decided rules that supersede current implementation values

- `Death Injury and Retreat.md` is canonical for HP/knockouts: fighters start each Shootout at max HP, with no persistent knockout debuffs; MxHP attrition applies only while On Trail. Commit 4 removed the legacy knockout duration/debuff constants; they must not be reintroduced.
- Bleed combines stack counts, with two stacks equal to one damage; healing removes stacks. The current highest-stack-only tick is not the target behavior.
- Vamoose removes half of money and **15% of occupied carried stacks**, rounded up with a minimum of one while inventory is non-empty (the named `Party.VAMOOSE_STACK_LOSS_FRACTION` constant inside the decided 10–20% range; inject the RNG for deterministic tests). Removed stacks stay whole, selection is deterministic for a seeded RNG, and equipped items and the Bank are never part of that loss.
- `hp_below` win conditions are per-actor, including boss thresholds; side-total HP is not the target contract.
- Zone-tied equipment not dropping from Shootouts is not intentional. Encounter/pool Zone must flow into loot generation so `dropsAnywhere: false` works for both vendors and combat loot. `EncounterRequest` and `Shootout.encounterZoneId` now carry that Zone; generation still needs to consume it.
- Poker's four-card flush and every-player blind still require an explicit house-rule decision before economy balancing.

## 6. Content addition recipes

### Add an enemy and a regular Zone encounter

1. Add `res://Data/Actors/{type}/{ActorName}.gd` with complete stats, weapon, class/Rodeo/loadout/Magazine and optional AI data. Author its animation states as a registry entry (`Data/Actors/ActorAnimationRegistry.gd`) and add any required `FrameData` entry — no per-actor animation scene since commit 19.
2. Add a Move/Rodeo/combat-item definition first if the actor references a new one; ids must match `data.name` exactly.
3. Add an encounter under `res://Data/Shootout/Encounters`, with unique positions and no more than four actors per side. Set kind, background, win condition, Zone/music and loot behavior explicitly.
4. Add or reference a loot table. Add new item definitions/base values before referencing them.
5. Register the encounter path and weight in `res://Data/Shootout/EncounterPools/{zone}.gd`. The filename must be a canonical Zone id.
6. If it is public newspaper content, add matching `NewspaperData.zones[zone].encounterTips[EncounterFileBasename]`. Set `newspaperPublic: false` for secret encounters.
7. Add validation for actor/animation references and pool selection. Gameplay can then launch it through an event `encounter` outcome (`poolZone` or explicit `encounter` path); quest/ambush callers should build an `EncounterRequest` through `SceneManager.launchShootout()`.

### Add an Overworld event and choice outcome

1. Add the event to `GenericEvents.gd` or the matching `{Zone}Events.gd`. The file is selected only through `OverworldEvents.ZONE_EVENT_FILES`; an unmapped Zone falls back to generic events only.
2. Give every reachable choice an explicit `outcome` Dictionary plus a stable `result` id. `{"kind": "none"}` closes with flavor only. `{"kind": "encounter", "poolZone": "wild_west"}` selects from that Zone's authored pool; `{"kind": "encounter", "encounter": "res://..."}` names an encounter directly.
3. Keep `image_type`, optional `music` and `text` consistent with the supported popup fields.
4. Legacy result-only choices remain disabled; migrate them by adding an outcome instead of adding more result strings.
5. Add a `TestEncounterFlow`-style check for any new outcome kind before it becomes reachable.

### Add a Move, Duck, Rodeo, or boss AI rule

1. Create the appropriate `data` script in Moves, Rodeos, or AI. Ducks stay in Moves with `category: "duck"`.
2. Use only implemented effect/Rodeo operations and target selectors. Supply valid position ranges, amounts/durations/scaling, and animation paths where applicable.
3. Reference the exact definition name from actor/Party data. Class `abilities` alone does not activate a Move.
4. Add a manager/resolver test for every new operation, not only a data-load test. Test player and AI legality, death cleanup, and animation hit behavior.

### Add a carried consumable or resource

1. Add its stackable definition to `ItemCatalog`, including unique `definitionId`, stack limit, type, display data and sprite.
2. For a consumable, add `Data/Shootout/Items/{Name}.gd` and set the catalog `combatId` to its exact `data.name`; implement effects and animations.
3. Add acquisition through a loot-table `definitionId`, a fixed vendor offer, or a quest reward. Set prices/weights/quantities explicitly. Loot and quest rewards are generated only On Trail; vendor purchases in Town are transactions, not a way to bypass the Off-Trail loot ban.
4. Assign a carried consumable through the Journal Inventory tab's To Belt action or `Party.reserveBeltItem(memberKey, instanceId, quantity)`. Belt entries reference the owned stack; enemy actor `items` arrays remain separate enemy content and are not a second Party source.

### Add or change a Party belt reservation

1. The item must already be an owned `consumable` with a non-empty catalog `combatId`; maps, resources and gear are rejected.
2. Use `Party.reserveBeltItem(memberKey, instanceId, quantity)`; the command validates member, ownership, type, `combatId`, quantity <= owned minus already-reserved, management policy and effective belt space (`belt_full`).
3. Belt space counts reservation entries, not reserved quantity. A reservation may hold quantity > 1 and projects that many combat uses at fight start.
4. Successful combat uses are recorded as `{instanceId, combatId, quantity: 1}` and committed once; removing the stack from inventory, dropping it or consuming all units reconciles the reservation away automatically.
5. Add a `Tests/TestBeltOwnership.gd`-style check for any new reservation rule and keep enemy actor belts name-based.

### Add a weapon or equipment base

1. Add a unique base id/name/sprites to `WeaponData.weaponFamilies` or the appropriate generic/Zone pool in `EquipmentData`.
2. Add its positive economic value to that file's `baseValues`. For equipment, specify slot, `dropsAnywhere`, Zone and optional `beltSpace` correctly.
3. Tune family Magazine/range in `WeaponData`; add affix ranges/pools in `AffixData` only when their mechanics are supported. Add fixed legendary stats/lore/value to `LegendaryData` and an explicit award path.
4. Verify the generator, inventory/equipment preview, combat projection, vendor quote, and save round-trip. Do not treat a generated affix's display text as proof that it works.

### Add a quest and map objective

1. Create a typed QuestDefinition Resource with ordered objective subresources and stable quest/objective ids.
2. Register it in `QuestCatalog.tres`. Set `map_target_id` only to a stable Location id present in the generated map manifest.
3. Add quest start/current-objective completion shots to relevant cutscenes, or place a `QuestEncounterTrigger` in its owning Location for a Shootout objective. Register the authored encounter path and canonical Zone on the trigger; SceneManager's acknowledged victory result owns the only completion command.
4. If completion changes Party level, rarity, Rodeo, rewards, or the next quest arc, wire that through one progression service; these effects are not automatic today.
5. Test unknown/duplicate/out-of-order triggers, Journal history, map marker identity, completion, and scene return. Add save migration once quest persistence exists.

### Add a vendor building

1. Add a `VendorCatalog` entry with stable vendor id, kind, parent Location id, canonical Zone id, interior scene, and valid fixed/rolled stock rules. Add fixed item prices or rolled count/type as appropriate.
2. Create the interior with art/collision, `PlayerSpawn`, and `VendorActor.vendorId` matching the catalog. Reuse `VendorRoom.tscn` as the outer shell.
3. Place `VendorDoor` in the parent Location with the same vendor id, safe return offset, prompt and icon. Ensure that Location has one interaction director and a grouped player.
4. For gun/equipment stock, ensure every possible generated base and affix has pricing data. For newspapers, author the Zone pool and prose. Banks need no stock.
5. Test door → room → NPC → menu → close → exit → same-door return, transaction atomicity, stock stability, departure-only reroll, and keyboard/controller layout. Add a `TrailDeparture` only where an explicit new Trail should begin in a Town, and verify that Off-Trail Location access and reward interactions remain blocked.

### Add a secret map and its destination

1. Add the map item to `ItemCatalog` with `itemType: "map"`, stack limit 1, and `effect: {kind: "reveal_map", mapId: ...}`.
2. Add the map/target ids to `SecretMapData`. For a secret Location, add `map_visibility: "secret"` and the same `secret_id` to its chunk script; for a secret item, author chunk/tile coordinates.
3. Regenerate the map so the manifest contains the secret Location. Add a vendor offer or other acquisition path.
4. Build the actual reachable destination/cache and its reward interaction. Discovery only reveals markers; it never grants the reward or makes an empty Location playable.
5. Test invalid/already-revealed consumption, inventory capacity, marker projection, scene reachability, reward claim, and save restore.

### Change a Zone, terrain, or music

1. Redraw Zone boundaries only in `ZoneData`'s `zone_map` rows (add a legend entry when a Zone id is renamed); audit equipment, encounter pools, newspaper copy, vendor Zone ids and music for renamed ids. Every grid chunk stays explicitly zoned — `default_zone` only answers chunks outside the map.
2. Author chunk terrain/scripts and update `WorldData` only when world topology changes. Add playable scenes for new Location entries.
3. Update `MapTileStyles` and the tileset classification reference for changed tile art/semantics.
4. Add the OGG and track id to the proper `MusicData` playlist. Do not reintroduce Zone rectangles into music or events.
5. Regenerate both map textures/manifest, run the map `--check`, and verify music, encounters, equipment and newspapers at every changed boundary.

### Add a generated Location

1. Author input TileMaps and register them through the WFC input-creation scene so `WFCModelBuilder` can construct the immutable model.
2. Add a `Data/Location Generation` file with generation variables, weighted chunk types, noise resources, transforms and interactable counts.
3. Create the generated Location scene with layout/generation/ChunkProcessor, player, exits, collisions and any PlayerReveal setup. Add its Overworld chunk Location entry.
4. Run solver and integration scenes, inspect border seams and reachability, and regenerate the Overworld map manifest.

## 7. Designed surfaces that are not ready for content yet

- `Data/Overworld/SpawnData.gd`, `OverworldSpawnDirector.gd`, and the `VisualSpawns` hierarchy are only specified in [Dynamic Overworld spawns](Overworld%20Spawns.md). Do not author the proposed party schema expecting it to run; the current system still uses legacy per-chunk `spawnPoints`.
- [Flairs](Shootout/Flairs.md) specifies `Shootout.FLAIR_POOLS`, a `UI/Flair` scene and a SceneManager layer. None exists; current flavor text is an in-combat banner with separate pools.
- Shared-inventory belt editing and event outcome kinds beyond `none`/`encounter` still need their domain contracts before content can be considered functional. Equipment-granted Moves (commit 11), save-slot management and Settings (commits 14–15), and secret-cache reward claims (commit 16) are now implemented and no longer block content.

## 8. Content review checklist

For every content addition, verify:

1. **Identity:** stable ids are unique, correctly cased, and consistent across every reference.
2. **Reachability:** a launcher, pool, acquisition path, scene entrance, or quest trigger can actually reach it.
3. **Mechanics:** every displayed stat/effect/choice has a runtime implementation; no-op content is not presented as working.
4. **Assets:** actor animations, icons, backgrounds, noise resources, music and hit frames exist and match naming conventions.
5. **Cross-system behavior:** inventory capacity, Party ownership, Zone lookup, quest/map targets, prices, newspapers and return navigation remain coherent.
6. **Trail gating:** On/Off Trail state is tested explicitly. Off Trail still allows town-to-town movement and quests, but rejects non-town Location access, attrition changes, and Shootout/event/quest/minigame/secret loot.
7. **Persistence:** runtime state has a defined New Game/reset and save/import policy; transient visual parties and combat nodes are not serialized.
8. **Validation:** focused tests cover malformed references and real behavior, the full suite passes, generated map outputs are current, and a 640×360 manual pass covers new UI/world content.
