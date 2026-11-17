# Location vendors — code-level design and implementation plan

This document implements [Location vendors](Location%20Vendors.md). It describes intended code, not existing behavior. **Status: patches 1–6 implemented and patch 7 partially implemented (shared Zone catalog, deterministic item RNG, pricing/data schemas, atomic Party commerce, deterministic vendor stock, shared Bank and save snapshots, the proximity interaction layer, vendor rooms with safe return navigation, the persistent VendorMenu modal shell, the shop/Bank views with their production interiors, map discovery with Inventory map use plus hidden/revealed Overworld markers, Zone newspaper reports projected from the shared encounter pools, and the patch 7 persistence audit plus content-gate lint). The full `Tests/RunAll.gd` suite passes 50/50.** Patch 7's remaining work is content blocked on art/world data (vendor NPC art, further Zone encounters, reachable secret caches) plus the manual 640×360 acceptance pass, and both are recorded in the patch 7 section below.

## Current state and constraints

- `Globals/Party.gd` owns `money`, the 24-slot shared `inventory`, equipped gear, and item commands. `InventoryRules.planAdd()` validates and plans additions, and normal `Party.addItems()` still accepts partial overflow for loot. Patch 2 added exact all-or-nothing commerce/transfer/consume commands alongside that loot behavior.
- `Party.inventoryChanged`/`equipmentChanged`/`moneyChanged` and the atomic commerce commands are implemented (patch 2). Equipped items remain outside `inventory`, which naturally excludes them from sales and Bank deposits.
- `Globals/ItemGeneration.gd` creates complete self-contained rolled weapon/equipment Dictionaries and resolves rarity through `Quests`. Every random helper now accepts an injected `RandomNumberGenerator` (patch 1), while the no-RNG path keeps the previous global behavior.
- `Data/Items/ItemCatalog.gd` supports `consumable`, `resources` and `map`; combat consumables require a `combatId`, while maps require a validated `reveal_map` effect (patch 1).
- `Nodes/Item Stats/ItemStats.*`, `UI/Journal/ItemSlotButton.*`, and `UI/Journal/Tabs/InventoryTab.*` provide item presentation and interaction conventions to reuse.
- `SceneManager` owns the current scene, fade transitions, persistent Journal layer, inventory policy, and shared `ModalPauseCoordinator`. `SceneManager.tscn` places the Journal on layer 5 and transitions on layer 10. Vendor UI belongs in a new layer between them.
- `Location/Entities/Interactable/Interactable.gd` polls `INTERACT`, assumes `PlayerActor`, pauses that player, and frees itself. It is gathering/minigame-specific and must not be reused unchanged for persistent vendor actors or doors.
- Pregenerated Locations such as `Location/Locations/Lazysprings/Lazysprings.tscn` contain a static `Entities/Actors/PlayerActor` and currently have no vendor-return initializer. Quest Locations use `BaseLocation.gd` and a Dictionary `Locations.currentLocation`; Overworld/pregenerated entry uses a String. Vendor navigation must preserve both forms rather than introduce a third.
- The shared `Data/Overworld/ZoneData.gd`/`OverworldZoneCatalog` catalog is implemented (patch 1); `MusicData` now contains only Zone-id-keyed track lists and vendor code consumes canonical ids rather than its own geometry.
- Region encounter pools: the shared pool loader and the real `canyon` pool with its `CanyonRats`/`CanyonRatNest` encounters landed in patch 6, so a Zone report is now projected from production data. The remaining Zones still have no authored pool/copy and are reported as unavailable rather than fabricated; the section in [Encounters](Shootout/Encounters.md) tracks that.
- `Overworld Map` currently treats all manifest Locations as visible and has only Location, player, and quest overlays. Hidden/revealed markers require additive manifest metadata and a discovery provider.
- Save support does not exist yet. All new state lives in domain services and `Vendors`/`Locations` already expose validated export/import/reset snapshots rather than hiding state in menu nodes.

## Architecture

```text
VendorDoor / VendorActor
        | stable vendorId, activation only
        v
SceneManager ------------------> VendorRoom.tscn + authored interior
  | owns return context             | actor opens menu; no automatic opening
  | owns VendorLayer + modal        |
  v                                 v
VendorMenu <---- read snapshots / commands ----> Vendors autoload
  |                                               | stock + shared Bank
  |                                               | deterministic generator
  |                                               v
  |                                          Party autoload
  |                                          money + inventory + equipment
  |
  +--> NewspaperReportBuilder --> shared Zone + encounter-pool data

Journal Inventory -- Use map --> Discovery autoload --> Party exact consumption
Journal Map <------ revealed marker provider --------+
```

### Responsibilities

| Component | Responsibility | Must not do |
|---|---|---|
| `Party` | Atomic money/inventory mutations and item transfer commands | Know vendor catalogs, prices, stock, rooms, or reports |
| `Vendors` | Vendor snapshots, buy/sell commands, per-vendor stock, one shared Bank | Render UI, derive Zone geometry, or edit `Party` fields directly |
| `VendorStockGenerator` | Seeded creation and pricing of rolled offers | Run on menu refresh or use global RNG |
| `VendorPricing` | Integer buy/sell valuations from authored data | Live in buttons or trust a UI-supplied total |
| `Discovery` | Secret definitions, revealed ids, map-use orchestration, marker projection input | Grant loot, teleport, or consume a map before validation |
| `SceneManager` | Room entry/return, VendorLayer, modal/pause/music and Journal exclusion | Own stock or item collections |
| `VendorMenu` | Selection, quantity, confirmations, display, focus | Calculate prices or mutate domain Dictionaries |
| `NewspaperReportBuilder` | Read-only Zone report projection | Pick an actual encounter or infer reports from visual spawns |
| `Locations` | Explicit trail-departure id/signal and existing Location state | Infer departure from every transition to Overworld |

### Cross-cutting invariants

1. UI receives deep-copied snapshots. No UI callback writes `Party.money`, `Party.inventory`, stock offers, or the Bank directly.
2. Domain commands re-resolve vendor, offer, and item ids and recalculate authoritative prices. UI totals are display only.
3. Purchase validation completes before any commit. Insufficient money/space, malformed items, stale offers, and unavailable data leave money, inventory, stock, signals, and RNG unchanged.
4. Sale and Bank commands affect one existing gear instance at a time. They preserve every rolled field; Bank transfer also preserves `instanceId`.
5. Commands are synchronous and idempotent against stale repeats: a second activation sees a missing offer/item and returns a stable failure without another mutation.
6. Random stock is keyed by `vendorId + trailDepartureId`. Menu/room/scene entry never advances that id.
7. Zone ids are canonical snake_case ids from shared `ZoneData`. There is no newspaper or equipment fallback Zone.
8. No hidden target is baked into the base map PNG. Visibility is an overlay/runtime decision.

## File plan

### Create

| Path | Purpose |
|---|---|
| `Data/Vendors/VendorCatalog.gd` | Stable vendor definitions, fixed general offers, rolled-stock rules, room paths, parent Location and Zone ids |
| `Data/Vendors/VendorPricing.gd` | Pure integer gear valuation and sale quotes |
| `Data/Vendors/NewspaperData.gd` | Per-Zone headlines/editorial and general Shootout tips; no enemy-stat copies |
| `Data/Overworld/SecretMapData.gd` | Map definitions and hidden Location/secret-item targets |
| `Data/Shootout/EncounterPoolData.gd` | Validated regular encounter-pool schema per Zone; production pools stay empty until real content is authored |
| `Data/Shootout/EncounterPools/*.gd` | Optional per-Zone pool data files when content is authored (patch 6) |
| `Globals/Vendors.gd` | Autoload stock/Bank state and commerce/transfer commands |
| `Globals/Discovery.gd` | Autoload revealed ids, atomic map use, save snapshots |
| `Vendors/VendorStockGenerator.gd` | Seeded pure-ish offer generation through injected item generator/RNG |
| `Vendors/NewspaperReportBuilder.gd` | Read-only party/report projection |
| `Location/Locations/PregeneratedLocation.gd` | Shared optional `playerPosition` initializer for pregenerated vendor parents |
| `Location/Vendors/VendorRoom.tscn` + `.gd` | Generic vendor-room loader and return handling |
| `Location/Vendors/Interiors/*.tscn` | Authored room art, collision, actor spawn, and exit |
| `Location/Entities/Vendor/VendorDoor.tscn` + `.gd` | Exterior entry interaction and floating icon |
| `Location/Entities/Vendor/VendorActor.tscn` + `.gd` | Persistent NPC interaction and floating icon |
| `Location/Entities/Vendor/VendorExit.tscn` + `.gd` | Explicit room exit |
| `Nodes/Floating Icon/FloatingIcon.tscn` + `.gd` | Shared icon, optional bob animation, and prompt anchor |
| `Nodes/Interaction/LocationInteractionDirector.gd` | Registers proximity targets and chooses one closest target per `INTERACT` press |
| `UI/Vendors/VendorMenu.tscn` + `.gd` | Shared modal shell and vendor-type views |
| `UI/Vendors/VendorItemRow.tscn` + `.gd` | Reusable selectable offer/inventory/Bank row |
| `Tests/TestVendors.gd` | Commerce, stock reset/determinism, validation, Bank, and failure atomicity |
| `Tests/TestVendorStock.gd` | Seeded RNG, offer identity/type/Zone, and no-reroll checks |
| `Tests/TestDiscovery.gd` | Map use, duplicate/invalid reveals, marker payloads, snapshot isolation |
| `Tests/TestNewspaper.gd` | Zone reports, party projection, no-fallback and malformed-data behavior |
| `Tests/TestVendorUI.gd` | Modal lifecycle, focus, selection, confirmations, empty states, command de-duplication |
| `Tests/TestVendorNavigation.gd` | Door→room→menu→return flows for pregenerated and generic Locations |

### Modify

- `project.godot`: register `Vendors` and `Discovery` after their data dependencies; keep service construction independent of tree order. No new interaction action is needed because `INTERACT` exists.
- `Globals/Party.gd`, `Globals/InventoryRules.gd`: exact purchase/sale/transfer commands, `moneyChanged`, map item support, and deep-copy snapshots.
- `Globals/ItemGeneration.gd`, `Data/Items/WeaponData.gd`, `EquipmentData.gd`, `LegendaryData.gd`: injected RNG and authored base values; preserve current default generation behavior for loot/tests.
- `Data/Items/ItemCatalog.gd`: functional supply/boost definitions and `map` definitions with `stackLimit = 1`, `droppable`, sprites, and `effect = {"kind": "reveal_map", "mapId": ...}`. Require `combatId` only for actual combat consumables.
- `Globals/Locations.gd`: `trailDepartureId`, `trailDeparted(departureId)`, and `departForTrail()`. The explicit town exit calls this once before changing to Overworld; other Overworld transitions do not.
- `Nodes/Scene Manager/SceneManager.gd` and `.tscn`: `vendor_room` registry entry, return context, persistent `VendorLayer` on layer 6, menu open/close, Journal exclusion, and vendor-room inventory policy.
- `Globals/HelperFunctions.gd`: thin routing helpers for consistency; F6 vendor navigation without SceneManager must report that return navigation is unsupported rather than direct-load and lose context.
- `Location/Locations/Lazysprings/Lazysprings.tscn` and initial town scripts: placed doors and shared pregenerated return-spawn initializer. Do not change `currentLocation` to a new wrapper type.
- `UI/Journal/Tabs/InventoryTab.*`: a **Use** action for map items through an injectable discovery provider, with reason display and confirmation that identifies the map’s reveals.
- `UI/Journal/Tabs/MapTab.gd`: discovery provider/signal, hidden-Location filtering, secret-item markers, and inclusion in POI cycling/selection.
- `Tools/OverworldMapBaker.gd`, `Tools/GenerateOverworldMap.gd`, `Data/Overworld/OverworldMapData.gd`: carry optional `map_visibility` and `secret_id` metadata through generation and runtime validation. Regenerate the manifest without changing the base terrain bake.
- `Docs/System Design/Testing.md`: add the new suites and record actual verification after implementation.

## Data contracts

### Vendor catalog

Use script data, matching the project’s existing `Data/` convention:

```gdscript
var vendors = {
    "lazysprings_gunsmith": {
        "vendorId": "lazysprings_gunsmith",
        "kind": "gun", # general | gun | equipment | bank | newspaper
        "displayName": "Lazysprings Gunsmith",
        "parentLocationId": "Lazysprings",
        "zoneId": "canyon",
        "roomScene": "res://Location/Vendors/Interiors/LazyspringsGunsmith.tscn",
        "stock": {"mode": "rolled", "itemType": "weapon", "count": 6},
    },
    "lazysprings_general": {
        "vendorId": "lazysprings_general",
        "kind": "general",
        "displayName": "Lazysprings General Store",
        "parentLocationId": "Lazysprings",
        "zoneId": "canyon",
        "roomScene": "res://Location/Vendors/Interiors/LazyspringsGeneral.tscn",
        "stock": {"mode": "fixed", "offers": [
            {"offerId": "paregoric", "definitionId": "paregoric", "unitPrice": 20},
        ]},
    },
}
```

`VendorCatalog.validate()` checks unique/matching ids, known kinds and Zone ids, valid positive prices/counts, existing room scenes, fixed-offer definition ids, correct rolled item types, and newspaper pool references. `parentLocationId` is an identity/reference, not Zone geometry. Display names never serve as keys. General fixed offers have stable `offerId`s so UI selection and tests do not depend on array position.

### Rolled offers and Party items

A rolled offer is:

```gdscript
{
    "offerId": "lazysprings_gunsmith:3:0", # vendor:departure:index
    "item": {},                            # complete generated gear; no inventory instanceId yet
    "unitPrice": 125,                      # frozen when the offer is generated
}
```

Do not regenerate an item from a snapshot or store only its base definition; affixes, stats, names, sprites, and rarity are part of the offer. A generated `baseValue` is pricing metadata resolved from authored base data, not a second source of combat stats. Quest-bound content may set `sellable = false`; ordinary gear defaults to true.

`ItemCatalog` adds `map` to its supported/stackable types. Map definitions carry an `effect` Dictionary and do not require `combatId`. `InventoryRules.STACKABLE_TYPES` includes `map`, while `GEAR_TYPES` remains exactly `weapon` and `equipment`. Cross-data tests validate that every `reveal_map` effect resolves a map definition and every target resolves uniquely in `SecretMapData`.

### Secrets

```gdscript
var maps = {
    "canyon_cache_map": {
        "mapId": "canyon_cache_map",
        "targetIds": ["hidden_mercy_gulch", "canyon_cache_01"],
    },
}
var targets = {
    "hidden_mercy_gulch": {
        "targetId": "hidden_mercy_gulch", "kind": "location",
        "displayName": "Mercy Gulch", "icon": "secret_location",
    },
    "canyon_cache_01": {
        "targetId": "canyon_cache_01", "kind": "secret_item",
        "displayName": "Buried cache", "icon": "secret_item",
        "chunk": Vector2i(8, 17), "tile": Vector2i(20, 40),
    },
}
```

Location targets resolve their coordinates from the generated map manifest by stable Location id. Secret-item targets use authored `chunk + tile` and the shared coordinate/projection helpers; they never duplicate projected image coordinates. Authored chunk Location entries gain optional `map_visibility = "secret"` and `secret_id`; absent metadata retains today’s always-visible behavior. Secret items must also have reachable world interaction content before their map is offered as complete content.

### Newspaper data

`Data/Shootout/EncounterPools/*.gd` contains only regular Zone encounter references and weights for the future encounter launcher. `NewspaperReportBuilder` reads those same encounter files and their enemy actor data. `NewspaperData` supplies `zoneId`, headline, introductory editorial, optional encounter-specific tips, and general tips. Do not copy enemy compositions into newspaper text. Quest-only encounters are excluded unless a pool entry explicitly marks their report as public.

## Domain APIs and algorithms

### Party transaction extensions

```gdscript
signal moneyChanged

# items: Array[Dictionary] complete items without UI-only fields.
# totalPrice: nonnegative integer authoritative price for the whole batch.
func completePurchase(items: Array, totalPrice: int) -> Dictionary

# instanceId: existing carried gear id; unitPrice: positive integer quote.
func completeSale(instanceId: String, unitPrice: int) -> Dictionary

# Gear transfer retains the complete item and its existing instanceId.
func transferGearOut(instanceId: String) -> Dictionary
# item: complete validated gear Dictionary with a unique existing instanceId.
func transferGearIn(item: Dictionary) -> Dictionary

# expectedType prevents a caller from consuming an item under the wrong effect.
func consumeItem(instanceId: String, expectedType: String) -> Dictionary
```

All commands require inventory data and `inventoryManagementAllowed`; transitions and blocked scenes fail closed. Stable reasons include `data_unavailable`, `management_unavailable`, `invalid_price`, `insufficient_money`, `insufficient_capacity`, `invalid_item`, `unknown_item`, `not_equipment`, `duplicate_instance_id`, `invalid_quantity`, and `wrong_item_type`.

`completePurchase()`:

1. Validate price and available funds before planning.
2. Call `InventoryRules.planAdd()` with the existing inventory/counter.
3. Require a successful plan and an empty `overflow`; partial acceptance is failure here, unlike loot.
4. Commit the candidate inventory, next instance counter, and `money -= totalPrice` together.
5. Emit `inventoryChanged` and `moneyChanged` once after the commit and return the public accepted result plus `totalPrice`.

`completeSale()` resolves one existing `weapon`/`equipment` entry, validates its positive integer quote, removes exactly that entry, credits money, and emits both signals after mutation. `Vendors`, not Party, enforces the specialist store category and `sellable` policy. No Party command accepts a UI-calculated total for an array of separate sales.

`transferGearOut()` validates gear and removes it, returning a deep copy. `transferGearIn()` validates the complete gear, checks one free occupied-stack slot, and rejects duplicate ids across both carried inventory and every member’s equipment. It appends the original item without passing through id allocation. These commands are used only after the Bank service validates the other collection; they emit no signal on failure.

`consumeItem()` validates an existing stack of `expectedType` and decrements/removes exactly one. It is not a generic effect dispatcher. Map validation and reveal happen in `Discovery`, which is the only first-iteration caller.

Add a small public gear-validation helper to `InventoryRules` rather than duplicating its complete rolled-item checks in Party/Bank. Existing `addItems()`, loot overflow, equip, and drop behavior remains unchanged.

### Pricing

`VendorPricing` resolves base values by item `definitionId` from `WeaponData`, `EquipmentData`, or `LegendaryData`, then applies authored rarity and affix value rules using integer arithmetic:

```text
gearValue = baseValue × rarityMultiplier + authoredAffixValueSum
buyPrice  = max(1, round(gearValue × vendorBuyMarkup))
sellPrice = max(1, floor(gearValue × globalSellRatio))
```

The initial `globalSellRatio` must be below `1.0`; exact numbers are balance data. A rolled offer freezes its `unitPrice`. A sale quote is recalculated from the carried item and same rules, so generated shop items cannot be bought and immediately sold for profit. Missing base/rarity/affix value data is a content error and blocks the offer/quote; it never silently becomes a free or priceless transaction. General offers use their explicit catalog `unitPrice` and are not sold back in this iteration.

### Vendors service

```gdscript
signal vendorChanged(vendorId: String)
signal bankChanged
signal departureStockChanged(departureId: int)

# Returns a deep-copied vendor/offer/money/capacity view; may lazily create stock.
func getVendorSnapshot(vendorId: String) -> Dictionary
# quantity: positive integer; ignored neither by domain nor UI.
func buy(vendorId: String, offerId: String, quantity: int) -> Dictionary
func sell(vendorId: String, instanceId: String) -> Dictionary
func getBankSnapshot() -> Dictionary
func deposit(instanceId: String) -> Dictionary
func withdraw(instanceId: String) -> Dictionary
func getNewspaperReport(vendorId: String) -> Dictionary
func exportState() -> Dictionary
func importState(state: Dictionary) -> Dictionary
```

The service owns `_stockByVendor`, `_bank`, `_baseSeed`, `_activeDepartureId`, and a reentrancy guard. Tests inject catalog, Party, Discovery, item generator, report builder, and seed. Production resolves autoloads by path, matching current project seams.

A shop snapshot also contains an `eligibleSell` array of deep-copied `{instanceId, item, salePrice}` rows for that specialist, plus unavailable/protected rows with display reasons. The UI never derives its own quote. Bank and newspaper snapshots omit irrelevant shop arrays.

### Stock generation and trail departure

Extend item-generation entry points and private random helpers with an optional `rng: RandomNumberGenerator`. When absent, preserve existing global-RNG behavior; when present, use it for family/base/zone pool selection, affix choice and values, damage, and sprite choice. Do not call global `seed()` or `randomize()` for vendors.

For each rolled vendor, lazily create stock once per departure:

1. Resolve the vendor and current `Locations.trailDepartureId`.
2. Derive and store a 64-bit seed from injected `_baseSeed`, departure id, and stable `vendorId`; use a documented deterministic integer hash, not wall-clock time or scene instance ids.
3. Seed a local `RandomNumberGenerator`, generate exactly the authored count with `itemType` and `zoneId`, and price each complete item.
4. Assign `{vendorId}:{departureId}:{index}` offer ids and store the complete offers plus `departureId` and `stockSeed`.
5. Return deep copies. Subsequent snapshots return the stored offers without invoking the generator.

`Locations.departForTrail()` increments `trailDepartureId` once and emits `trailDeparted`. `Vendors` clears all rolled stock, updates `_activeDepartureId`, and emits `departureStockChanged`; fixed catalogs, money, inventory, Bank, and discovered secrets do not reset. Every vendor read/command also synchronizes the departure id defensively, so a missed UI refresh cannot use old stock. The explicit town departure interaction calls this before `HelperFunctions.changeScene("overworld")`. Cutscene, quest, Vamoose, minigame, and vendor-room transitions never call it.

### Buy and sell

`buy()` runs under `_commandInProgress` and returns `command_in_progress` to nested/repeated callbacks:

1. Synchronize departure, resolve vendor kind and current offer by id, and validate quantity. Rolled gear requires exactly one.
2. Build the item from the authoritative offer. Fixed stackables use `ItemCatalog.makeStackable(definitionId, quantity)`; rolled gear deep-copies the stored generated item.
3. For maps, reject `already_revealed` when every target is known and `already_owned` when an unrevealed copy is already carried. General snapshots hide owned/exhausted map offers.
4. Compute `totalPrice` from the stored/catalog unit price, never a UI argument.
5. Call `Party.completePurchase([item], totalPrice)`. On failure, change nothing else.
6. On success, remove a rolled offer from stock; fixed offers remain. Emit `vendorChanged(vendorId)` once and return the accepted result.

`sell()` resolves the vendor and current Party snapshot, rejects the wrong specialist category and `sellable = false`, recalculates the quote, then calls `Party.completeSale()`. Success emits `vendorChanged`. Sold gear is discarded by design and never appended to stock or Bank. UI confirmation is not a substitute for these checks.

Party/Vendor signals can arrive while a command is finishing. The UI defers refresh until the command returns; the service guard prevents signal-driven reentrant purchases. Consequently a double-click cannot observe and buy the same still-present offer during the small window before rolled-stock removal.

### Shared Bank

`getBankSnapshot()` returns deep copies of `_bank` and carried gear only. Both preserve their array order and use `instanceId` as selection identity.

- **Deposit:** validate the carried item is gear, call `transferGearOut()`, append the returned item to `_bank`, then emit `bankChanged`. No capacity, price, or RNG work occurs.
- **Withdraw:** resolve the stored item by id, verify there is no duplicate id in Party, and call `transferGearIn()` while the item remains safely in `_bank`. Only after success remove it from `_bank` and emit `bankChanged`. Full inventory or invalid data leaves both collections unchanged.
- Validate on import that every stored item is complete gear, has a unique nonempty id, and does not collide with Party inventory/equipment. Bank state is global to the service, not keyed by `vendorId`.

### Save/New Game snapshots

`Vendors.exportState()` includes format version, base seed, active departure id, every rolled vendor’s stock seed and complete remaining offers, and the Bank array. `Discovery.exportState()` includes format version and sorted revealed ids. Imports validate the entire payload and cross-references before committing; malformed imports leave current state unchanged. Loading restores offers directly and must not call the generator. `Locations.trailDepartureId` is included by the future save coordinator so stock cannot be associated with the wrong cycle. New Game calls explicit reset methods on all three services and Party rather than relying on autoload recreation.

## Map discovery

### Discovery service

```gdscript
signal discoveryChanged

# instanceId: carried map item; effect and targets are resolved from data.
func useMap(instanceId: String) -> Dictionary
func isRevealed(targetId: String) -> bool
func getRevealedSecretMarkers() -> Array
func exportState() -> Dictionary
func importState(state: Dictionary) -> Dictionary
```

`Discovery` owns `_revealedIds`, the secret catalog, a validated `OverworldMapData` reference, and its own command guard. `useMap()`:

1. Resolve the Party inventory entry by `instanceId`; require `itemType == "map"` and a valid `reveal_map` effect.
2. Resolve the complete map definition and **all** target ids before mutation. Reject unknown/duplicate targets or unsupported kinds.
3. Validate every Location target against the manifest’s matching `secret_id`, and every secret-item `chunk + tile` through shared coordinates/projection and map bounds. One invalid target rejects the whole use.
4. Compute unrevealed target ids. Return `already_revealed` without consumption if empty.
5. Call `Party.consumeItem(instanceId, "map")`; on failure reveal nothing.
6. Add all newly revealed ids in authored order, emit `discoveryChanged` once, and return consumed/revealed ids.

No asynchronous step or failing operation follows consumption. Signal-driven UI refreshes defer until the guarded command completes, just as for purchases. Already revealed targets in a partially revealed map remain revealed; only new ids are added. Using a map never creates an item reward or changes player position.

`getRevealedSecretMarkers()` returns deep-copied target data only for revealed ids. Missing map data produces an unavailable map overlay, not markers at `(0,0)` or an arbitrary corner. General-store snapshots query the same service to hide owned maps and maps whose targets are exhausted.

### Journal Inventory integration

Add **Use** beside Equip/Drop only when the selected projected item has a supported out-of-combat effect. For a map, the confirmation lists the target display names and explains that one copy will be consumed. `InventoryTab` calls an injected `itemUseProvider.useMap(instanceId)`; production resolves `/root/Discovery`. Existing Equip/Drop continue through Party. A later general item-use service can replace this provider without moving reveal state into Inventory.

The tab handles `already_revealed`, `already_owned`, `unknown_item`, `invalid_map`, `management_unavailable`, and data errors with readable text. Cancel, inspection, snapshot reads, and failed use leave Party and Discovery unchanged.

### Journal Map integration

- Extend generated Location records with optional `map_visibility` and `secret_id`; default missing metadata to `always` for backward compatibility. The map generator carries metadata but does not bake visibility or icons into terrain.
- `MapTab` accepts `discoveryProvider` and `discoveryStateSource` injections, defaulting to `/root/Discovery`. Connect only while active and disconnect on deactivation/exit, following `questStateSource` lifecycle.
- Hide manifest Locations marked `secret` unless their `secret_id` is revealed. Always-visible Locations are unaffected.
- Merge `getRevealedSecretMarkers()` with existing Location markers. Convert secret-item `chunk + tile` to cell/image positions with `OverworldCoordinates.chunkTileToCell()` and the existing `OverworldMapProjection`; validate bounds before creating a marker.
- Give secret Locations and secret items distinct icons/selection text. Rebuild the combined left-to-right/top-to-bottom POI focus order after any discovery change so keyboard/controller cycling includes every visible marker exactly once.
- Reveals add information only. Selecting a marker does not enter a Location, grant loot, set a quest, or alter discovery.

## Newspaper reports

```gdscript
# zoneId: canonical ZoneData id; providers are injectable read-only data sources.
func buildReport(zoneId: String, encounterPools, actorResolver, newspaperData) -> Dictionary
```

Return a view model such as:

```gdscript
{
    "success": true, "available": true, "reason": "", "zoneId": "canyon",
    "headline": "...",
    "parties": [{
        "encounterId": "rat_ambush", "name": "Rat Ambush", "kind": "dustup",
        "composition": [{"actorName": "Squeaky Rat", "count": 3, "characterClass": "..."}],
        "damageTypes": ["lead"], "mechanics": ["..."], "tips": ["..."],
    }],
    "generalTips": ["..."],
}
```

The builder reads the pool for exactly the requested Zone, resolves each encounter’s nested `teams`, aggregates repeated enemy actor references into counts, and projects only authored/readable combat information. Encounter-specific `mechanics` and `tips` must correspond to implemented behavior. It performs no weighted roll and does not inspect `MusicPlayer.currentZone`, visual parties, or live spawn state.

Unknown Zone, missing pool, malformed encounter, or missing actor data returns a stable error with no substitute report. A valid Zone with no public encounters returns `success = true`, `available = false`, and the intentional **No local intelligence available** state. Reports have no money, inventory, discovery, or RNG side effects.

## Location interaction and navigation

### Proximity targets and floating icons

Add the player to a `location_player` group in `PlayerLocationActor._ready()`. New vendor doors, actors, and exits register with one `LocationInteractionDirector` in their Location/room scene. Each target supplies its Area2D overlap state, activation position, prompt text, and an `activated` signal.

On a non-echo `INTERACT` press in `_unhandled_input()`, the director selects the closest eligible overlapped target by distance to the player, with registration order as a deterministic tie-break, marks input handled, and emits only that target. It does not poll every target’s `_physics_process()`, pause the player, or free the target. Paused scenes cannot activate world targets. The director shows the prompt only for the current best target.

`FloatingIcon` is a non-colliding Node2D with a Texture2D and optional AnimationPlayer bob. Door and vendor scenes choose different icons and anchor them above their art. Icons do not determine interaction distance; collision and prompt state remain in the target. Existing gathering `Interactable.gd` remains unchanged until a separate migration, avoiding regressions to one-shot minigame objects.

### Room entry and return

Add `SCENES["vendor_room"] = "res://Location/Vendors/VendorRoom.tscn"`. `SceneManager.enterVendorRoom(vendorId, returnPosition)`:

1. Reject transitions, nested vendor rooms, unknown vendors, and calls from a menu/Journal modal.
2. Capture `_vendorReturnContext`: current `sceneKey`, a deep copy of `Locations.currentLocation` in its existing String or Dictionary form, and the door-authored safe `returnPosition`.
3. Call `change_scene("vendor_room", {"vendorId": vendorId})`.

`VendorRoom.gd::initScene(context)` resolves the room path from `VendorCatalog`, instantiates the authored interior beneath its entity root, and connects its vendor/exit targets. The vendor actor calls `SceneManager.openVendor(vendorId)` only on interaction. `VendorRoom.tscn` itself supplies the common interaction director, player spawn, and VendorLayer integration; interior scenes supply art, collision, actor location, and exit location.

Current SceneManager flow adds the new scene (and therefore runs `_ready()`) before `_applyContext()` calls `initScene()`. VendorRoom `_ready()` must initialize only context-independent shell nodes and show a loading/unavailable state; final interior loading and interaction registration occur in `initScene()`. Pregenerated return placement may safely adjust the already-created static player in its later `initScene()` call.

`SceneManager.exitVendorRoom()` restores the captured scene/context. For a generic quest Location, update the copied `currentLocation.playerPosition` as `BaseLocation` already expects. For a pregenerated Location, pass `playerPosition` separately; a small shared `PregeneratedLocation.gd::initScene(context)` places `Entities/Actors/PlayerActor`. This avoids changing the global String/Dictionary contract. Migrate only vendor-parent pregenerated scripts to that base initially.

Retain `_vendorReturnContext` until the parent scene finishes loading. A failed entry load clears pending vendor entry state while retaining the parent; a failed return load leaves the vendor room and its return context intact. Clear the context only after successful return. The safe spawn must be outside door collision/activation geometry, and interaction uses press edges rather than held state, preventing immediate re-entry.

`HelperFunctions` may expose thin routing helpers for consistency, but vendor F6 fallback must show an explicit unsupported-navigation warning if no SceneManager/return context exists; it must not pretend that a direct scene load preserves the return flow.

## Modal, UI, and audio

### Scene structure

```text
SceneManager
├── CurrentScene
├── JournalLayer (5)
├── VendorLayer (6)
│   └── VendorMenu (Control, process_mode = ALWAYS, hidden)
└── TransitionLayer (10)
```

`SceneManager` injects its existing `ModalPauseCoordinator` into `VendorMenu`. `openVendor()` is allowed only in `vendor_room`, outside transitions, and while the Journal is closed. The menu acquires pause once, pushes `MusicData.shop_tracks` once, shows the requested vendor view, and grabs its initial focus. `canOpenJournal()` and `toggleJournal()` reject an open vendor menu; vendor actors cannot open while the Journal is open.

`closeVendor()` cancels any confirmation first, releases pause exactly once, pops exactly the matching shop-music entry, releases focus, and hides the menu. `_on_scene_change_started()` closes it before every transition. `VendorLayer` remains below fade/loading UI. Add `vendor_room` to `journalAllowedScenes` so inventory is available after the vendor menu closes; SceneManager still disables all inventory mutation during transitions.

Do not set `tree.paused` directly in menu code and do not pair music push/pop in separate unrelated callbacks. Nested pause owners retain the coordinator’s previous-pause semantics. Unavailable vendor data displays inside the modal with a working Close action rather than leaving gameplay paused without UI.

### VendorMenu views

Create the shell and each view once; refresh data in place rather than rebuilding the modal hierarchy. Use static shared chrome and reusable dynamic rows:

```text
VendorMenu
└── CenterContainer/PanelContainer/VBoxContainer
    ├── Header: VendorName, Money, Capacity, CloseButton
    ├── ContentHost
    │   ├── ShopView: Buy/Sell tabs where applicable, OfferList, ItemStatsHost,
    │   │             Quantity controls, PriceTotal, Buy/SellButton
    │   ├── BankView: CarriedGearList, StoredGearList, ItemStatsHost,
    │   │             Deposit/WithdrawButton
    │   └── NewspaperView: Zone/Headline, ReportScroll, empty/error label
    ├── StatusLabel
    └── ConfirmationOverlay (hidden except final sale)
```

Split `ShopView`, `BankView`, and `NewspaperView` into sibling scripts/scenes if their refresh logic becomes independently sizable; the shell owns only vendor selection, modal state, and confirmation. Rows store `offerId` or `instanceId`, never an array index as command identity. `ItemStats` renders the same rolled item dictionary used by the transaction. General stores show Buy only; gun/equipment stores add Sell; Banks and newspapers do not show irrelevant shop tabs.

- Header capacity comes from `Party.getInventorySnapshot()` and money updates through `moneyChanged`; inventory changes refresh lists through existing signals plus `vendorChanged`/`bankChanged`.
- Stackable quantity controls have minimum/maximum bounds, direct keyboard/controller operation, and an updated authoritative unit-price × quantity display. Gear locks quantity to one.
- Sale confirmation includes complete item name and exact quoted proceeds. Confirm calls `Vendors.sell()` once; cancel leaves state unchanged. Purchases and Bank transfers need no destructive confirmation, but buttons disable while a command is active.
- Domain failures map to concise status text. Refresh after a result and preserve selection by stable id; if absent, choose the next row, then previous, then show the empty state.
- `ui_cancel` closes a confirmation first, otherwise closes the menu. Focus is explicitly wired between tabs, lists, quantity/action controls, and Close. Do not rely on hover for item names, prices, or errors.
- Newspaper rows are read-only rich text within a ScrollContainer; no purchase/sale controls or hidden random roll occurs.
- Validate long rolled names, maximum quantities, empty stock/Bank/report states, and all five vendor types at 640×360 with integer scaling.

## Zone and encounter prerequisites

Implement the shared `Data/Overworld/ZoneData.gd`/`OverworldZoneCatalog` step already specified in `Overworld Spawns.md` before wiring vendor content. Migrate music to canonical Zone ids while retaining display names and current geography. Vendor definitions and equipment generation consume those same ids; newspaper reports resolve their Zone directly from `VendorCatalog`, not MusicPlayer state.

Author `Data/Shootout/EncounterPools` as the shared region-pool contract from `Encounters.md`. The future encounter launcher and `NewspaperReportBuilder` must read the same files. Do not create a second newspaper-only enemy-party catalog. Until real pools exist, tests use small injected fixtures and production displays the explicit unavailable state; do not ship `RatAmbush` as every Zone’s newspaper report.

## Implementation plan

Land the following as reviewable patches. Run focused tests and the existing full suite at each gate; do not build UI on failing domain behavior.

### ✅ Patch 1 — Shared ids, data, and deterministic generation (implemented)

1. ✅ Implement the shared Zone catalog prerequisite and migrate music without changing geography or track behavior.
2. ✅ Add injected RNG throughout `ItemGeneration`, retaining existing defaults and passing current item-generation/loot tests.
3. ✅ Add authored base/rarity/affix values and `VendorPricing`; item and map definitions cover the functional Shootout consumables plus a real reveal map, with cross-data validation. Boost definitions land with their mechanics in patch 4 rather than shipping no-op purchases.
4. ✅ Define `VendorCatalog` (production vendors empty until real rooms exist), `SecretMapData`, and the shared encounter-pool schema. Tests supply fixtures; unavailable production content stays explicitly unavailable.

**Implemented files:** `Data/Overworld/ZoneData.gd`, `Overworld/OverworldZoneCatalog.gd`, `Data/Vendors/VendorCatalog.gd`, `Data/Vendors/VendorPricing.gd`, `Data/Overworld/SecretMapData.gd`, `Data/Shootout/EncounterPoolData.gd`, `Tests/TestZoneCatalog.gd`, `Tests/TestVendorData.gd`, plus injected RNG/value/map support in item generation, item data, `ItemCatalog`, `InventoryRules`, `MusicData` and `MusicPlayer`.

**Gate:** ✅ data lint rejects unknown ids/assets/Zones, bad prices, invalid maps, and wrong stock types. ✅ Identical injected seeds produce identical rolled items and leave the global RNG stream untouched. ✅ Music, generation, inventory and loot suites pass; the full suite is 41/41.

### ✅ Patch 2 — Atomic commerce, departure stock, and Bank domain (implemented)

1. ✅ Add Party’s exact purchase/sale/transfer/consume commands and `moneyChanged` without changing loot’s partial-overflow semantics.
2. ✅ Implement `VendorStockGenerator`, the `Vendors` stock snapshots/commands, explicit `Locations.departForTrail()` and reentrancy protection.
3. ✅ Implement the shared Bank and validated export/import/reset snapshots for Vendors and the departure counter (`Locations.restoreTrailDepartureId`).
4. ✅ Add `TestVendors` and `TestVendorStock` with fake collaborators before any UI calls these APIs.

**Implemented files:** `Globals/Vendors.gd`, `Vendors/VendorStockGenerator.gd`, Party commerce/transfer/consume commands and `moneyChanged` in `Globals/Party.gd`, shared gear validation in `Globals/InventoryRules.gd`, trail-departure state in `Globals/Locations.gd`, the `Vendors` autoload registration, and `Tests/TestVendors.gd`/`Tests/TestVendorStock.gd`. Newspaper reports remain an explicit `data_unavailable` boundary until patch 6.

**Gate:** ✅ all transaction failure cases are atomic; ✅ repeated/reentrant commands cannot duplicate effects; ✅ stock survives export/import without regeneration and resets only on explicit departure; ✅ Bank transfer preserves complete items/ids and rejects full/duplicate states; ✅ malformed imports commit nothing. Full suite: 43/43.

### ✅ Patch 3 — Interaction, rooms, navigation, and modal shell (implemented)

1. ✅ Interaction director, floating icons and persistent door/actor/exit targets built on a shared `LocationInteractable` proximity base; the closest-target tests cover echo/held input and selection switching as the player moves.
2. ✅ Generic vendor-room loading (`vendor_room` scene key), `PregeneratedLocation.initScene()` return spawning, preserved String/Dictionary `currentLocation` context, and failed-entry/failed-return context handling in `SceneManager`.
3. ✅ `VendorLayer`/`VendorMenu` hidden shell with the shared pause coordinator, Journal exclusion, shop-music push/pop, close/cancel, and scene-transition cleanup.
4. ✅ One production door and interior in Lazysprings behind the real `lazysprings_general` catalog entry; entering the room never auto-opens the menu. Door/actor/exit route through `HelperFunctions`, so a direct (F6) run reports unsupported navigation instead of losing the return context. A door's marker is the entrance tile its floating icon points at and its activation circle is centred on that marker, so returning spawns the player exactly under the indicator; the prompt reappears immediately, but activation needs a fresh INTERACT press, so returning never re-enters the room by itself.

**Implemented files:** `Nodes/Interaction/LocationInteractionDirector.gd` (+`.tscn`) and the shared `Nodes/Interaction/LocationInteractable.gd`; `Nodes/Floating Icon/FloatingIcon.gd` (+`.tscn`); `Location/Entities/Vendor/VendorDoor|VendorActor|VendorExit.gd` (+`.tscn`); `Location/Vendors/VendorRoom.gd` (+`.tscn`) and `Location/Vendors/Interiors/LazyspringsGeneralStore.tscn`; `Location/Locations/PregeneratedLocation.gd`; `UI/Vendors/VendorMenu.gd` (+`.tscn`); `VendorLayer`, return context and Journal rules in `Nodes/Scene Manager/SceneManager.gd`/`.tscn`; vendor routing helpers in `Globals/HelperFunctions.gd`; the Lazysprings door; `Tests/TestVendorNavigation.gd`/`TestVendorUI.gd` with the `Location/Locations/Test/VendorNavigationTest` fixture.

**Gate:** ✅ `TestVendorNavigation` and `TestVendorUI` prove door→room→interaction→modal→close→exit→same-door return for both Location forms, closest-only activation, spawns outside the target activation reach, the direct-run unsupported-navigation report, safe failed entries, and balanced pause/music on every exit path. ✅ Existing SceneManager/Journal suites pass. Full suite: 45/45.

### ✅ Patch 4 — Shop and Bank UI plus first functional content (implemented)

1. ✅ `VendorMenu` is a real modal shell: header (vendor name, money, capacity, Close), Buy/Sell tabs where the kind sells, reusable `VendorItemRow` rows keyed by `offerId`/`instanceId`, `ItemStats` details for the selected row, quantity steppers with unit-price × quantity totals, disabled rows carrying their reason, empty-state labels and explicit focus wiring. Sales require a confirmation naming the complete item and the exact proceeds; cancels, rejections and failures leave state untouched.
2. ✅ `BankView` lists carried and stored gear side by side with separate Store/Withdraw actions; the Bank stays the shared service and transfers preserve item instance ids.
3. ✅ All five kinds map to their view: general (fixed offers, Buy only), gun and equipment (rolled stock plus Sell), bank, and newspaper. The newspaper view renders the documented report shape when data exists and otherwise shows the intentional unavailable state; report data itself arrives in patch 6.
4. ✅ Authored content: Lazysprings general store, gunsmith, outfitter and bank interiors behind real catalog entries, exterior doors with kind icons, and the town’s explicit `TrailDeparture` interaction that calls `Locations.departForTrail()` exactly once before leaving for the Overworld. Doors and the trail departure share one convention: the marker is the tile the floating icon points at and the activation circle is centred on it, so returning stands the player exactly under the indicator. No boost/explosive/magazine offers were added: their mechanics do not exist yet. The general store’s reveal map stays authored from patch 1; its Inventory **Use** action lands with `Discovery` in patch 5, so until then the purchase only occupies a slot.

**Gate:** ✅ `TestVendorUI` drives buy/sell/Bank/newspaper flows through injected fixtures (quantity bounds, exhausted offers, readable failure text, confirmation cancel/confirm, empty states, focus). ✅ `TestVendorNavigation` proves the placed doors resolve catalog entries and interiors, return spawns sit at the doorway outside activation geometry, and rolled stock survives close/reopen but resets after the explicit departure. ✅ No UI code writes Party/Vendors state directly; every command passes stable ids and the domain revalidates. Mouse/keyboard/controller traversal is wired through explicit focus neighbours, with the 640×360 visual pass still recorded manually. Full suite: 45/45.

**Implemented files:** `UI/Vendors/VendorMenu.gd` (+`.tscn`) rebuilt around the kind views, new `UI/Vendors/VendorItemRow.gd` (+`.tscn`), `Location/Vendors/Interiors/LazyspringsGunsmith|LazyspringsOutfitter|LazyspringsBank.tscn`, the production `lazysprings_gunsmith`/`lazysprings_outfitter`/`lazysprings_bank` entries in `Data/Vendors/VendorCatalog.gd`, the placed doors and kind icons in `Location/Locations/Lazysprings/Lazysprings.tscn`, `Location/Entities/Trail/TrailDeparture.gd` (+`.tscn`), the `iconTexture` overrides on `VendorDoor`/`VendorActor`, and the extended `Tests/TestVendorUI.gd`/`Tests/TestVendorNavigation.gd`.

### ✅ Patch 5 — Maps and discovery (implemented)

1. ✅ `Discovery` autoload (registered before `Vendors`) owns revealed target ids, map use and snapshots: every target resolves before anything mutates, one invalid target rejects the whole use, `already_revealed` refuses without consuming, consumption goes through `Party.consumeItem(instanceId, "map")`, and one `discoveryChanged` signal fires per successful use. `getMapUsePreview()` feeds the Journal confirmation with the map's target names. Inventory gained a **Use** action (shown only for supported out-of-combat effects) with a confirmation naming the map's reveals and stating that one copy is consumed, plus readable text for `already_revealed`/`already_owned`/`invalid_map`/`unknown_item`/`management_unavailable`.
2. ✅ The Overworld baker carries optional `map_visibility`/`secret_id` metadata into the manifest (sparse: always-visible entries keep their old shape, and a half-authored secret is a generation error). `MapTab` hides manifest Locations marked `secret` until their secret id is revealed, overlays revealed secret items with their own glyph, gives both distinct selection text, and rebuilds the left-to-right/top-to-bottom POI cycle so each visible marker appears exactly once. Always-visible Locations are unaffected; reveals never grant loot or move the player.
3. ✅ `Gold Run` is authored as the production secret Location (its chunk entry carries `map_visibility: "secret"` + `secret_id`), so `canyon_cache_map` reveals real, reachable world content — the Location keeps its working entrance and scene. The base terrain bake is byte-identical; only the manifest's location cells changed, and `--check` reports the committed outputs current. Production secret *items* stay empty: their marker pipeline is implemented and fixture-tested, but the world still has no reachable cache interaction, so none is offered.
4. ✅ `Tests/TestDiscovery.gd` (new) plus `TestVendorData`, `TestInventoryTab` (Use flow) and `TestOverworldMapTab` (hidden/revealed filtering, secret-item overlay, POI cycling and signal lifecycle) coverage.

**Implemented files:** `Globals/Discovery.gd`, the `Discovery` autoload entry in `project.godot`, lazy Discovery resolution in `Globals/Vendors.gd`, `map_visibility`/`secret_id` support in `Tools/OverworldMapBaker.gd`/`Data/Overworld/OverworldMapData.gd` (`resolveSecretLocation`, `isSecretLocation`), the secret-target lint in `Data/Overworld/SecretMapData.gd`, the secret authoring in `Overworld/Overworld Chunks/#3#14.gd`, the regenerated `Data/Overworld/OverworldMapData.tres`, discovery filtering/markers in `UI/Journal/Tabs/MapTab.gd`, the Use action and confirmation in `UI/Journal/Tabs/InventoryTab.gd`/`.tscn`, the updated map description in `Data/Items/ItemCatalog.gd`, and `Tests/TestDiscovery.gd` plus the extended Inventory/map/data suites.

**Gate:** ✅ a valid map consumes exactly one copy and reveals only its targets, atomically; ✅ duplicate, malformed-target, out-of-chunk and unknown-instance uses consume and reveal nothing; ✅ ordinary Locations stay visible while secret ones appear on reveal; ✅ secret markers project through the shared coordinates and join the POI cycle exactly once, with time-bounded signal lifecycle; ✅ import/export round-trips reveals without granting content. `GenerateOverworldMap.gd -- --check` reports the committed outputs current. Full suite: 47/47.

### ✅ Patch 6 — Newspaper reports (implemented)

1. ✅ Authored the real shared Zone pool (`Data/Shootout/EncounterPools/canyon.gd`) plus its genuine encounters (`CanyonRats`, `CanyonRatNest`, both against the authored Squeky rat actor) and the per-Zone copy in `Data/Vendors/NewspaperData.gd` (headline, editorial, per-encounter tips, general tips). `EncounterPoolData.loadProductionPools()` merges every authored pool file, so the future encounter launcher and the newspaper read the same data.
2. ✅ `NewspaperReportBuilder.buildReport(zoneId, encounterPools, actorResolver, newspaperData)` resolves exactly the requested Zone's public entries, aggregates repeated enemy actor references into counts, projects name/kind/composition/damage types/mechanics/tips, and performs no roll, no mutation and no fallback. `Vendors.getNewspaperReport()` resolves the vendor's own Zone through it, and the read-only newspaper view renders the editorial, each party, wrapped tips and the general-tips block inside its scroll region, with the intentional unavailable state for Zones that publish nothing.
3. ✅ `Tests/TestNewspaper.gd` (new) covers the production lint, exact-Zone resolution, composition aggregation against the authored enemy teams, quest/private exclusion, determinism, side-effect and RNG isolation, and every failure state; `TestVendorData` lints the authored pools and copy, `TestVendors` proves the service boundary, and `TestVendorUI` renders both a published report and an unpublished Zone.

**Implemented files:** `Vendors/NewspaperReportBuilder.gd`, `Data/Vendors/NewspaperData.gd`, `Data/Shootout/EncounterPools/canyon.gd`, the `CanyonRats`/`CanyonRatNest` encounters, `EncounterPoolData.loadProductionPools()`/`validateAuthoredPools()`, the newspaper collaborators and report wiring in `Globals/Vendors.gd`, the `lazysprings_gazette` catalog entry with its interior/door, the newspaper rendering in `UI/Vendors/VendorMenu.gd`, and `Tests/TestNewspaper.gd`.

**Gate:** ✅ reports resolve the parent Location's Zone from the vendor definition and the shared pool, with no Zone fallback; ✅ compositions aggregate repeated enemies to the authored counts and match the real actor data; ✅ private/quest entries never reach a report; ✅ reporting is deterministic, mutates neither pools nor copy, and never advances the RNG; ✅ an unpublished Zone (and the debug `RatAmbush` encounter) is never presented as local news. Full suite: 48/48.

### ⏳ Patch 7 — Content completion, persistence audit, and release verification (partially implemented)

1. ⏳ **Content:** all five kinds are authored and placed in Lazysprings (general store, gunsmith, outfitter, bank, gazette) with real prices/stock counts, working interiors and one production Zone report. The remaining authoring is blocked on **art and world content, not code**: every vendor actor still shares the `Character_24px` sprite, only the `canyon` Zone has a real pool and copy (further Zones need authored encounters and actor animation sets), and production secret *items* still have no reachable cache interaction to reveal. No incomplete offer ships — `TestVendorContent` fails the run if a fixed offer cannot deliver its effect.
2. ✅ **Persistence audit:** `Tests/TestVendorPersistence.gd` (new) drives the documented coordinator order end to end. A real session (stack purchase, map purchase → reveal, Bank deposit, rolled stock, explicit trail departure) is exported as one payload, restored into a fresh session, deep-compared, and re-exported byte-identically. It pins the legacy coordinator seams: invalid or partial vendor/discovery/departure payloads leave their live services untouched, and the New Game resets clear stock/Bank/reveals/departure while deliberately leaving Party untouched. The real Save/Continue path is now implemented by `Globals/SaveGame.gd`; `TestSaveGame` and `TestSaveRestart` additionally prove rollback, migration and process-restart persistence.
3. ✅ **Docs:** this plan, `Location Vendors.md`, `Testing.md` and `Inventory and Equipment.md` now state actual results, and every high-level acceptance criterion carries recorded evidence.
4. ⏳ **Verification:** the full `Tests/RunAll.gd` suite passes **50/50** (patch 7 added `TestVendorPersistence` and `TestVendorContent`). The manual pass is reduced below to what automation cannot judge and remains outstanding.

**Gate:** ✅ no catalog entry claims an unsupported effect — `TestVendorContent` resolves every fixed offer against the real combat item set, the authored reveal data and the manifest, and rejects any offer whose item type cannot be delivered from a definition alone; ✅ every placed vendor resolves its catalog entry, interior, vendor actor and a safe spawn (30px from the exit marker, outside its 18px activation radius); ✅ every newspaper names a canonical Zone with authored copy *and* a published production pool, and an unpublished Zone never falls back; ✅ every acceptance criterion has automated evidence except the visual/feel steps listed as manual in [Acceptance evidence](#acceptance-evidence). Content the gate cannot invent — vendor art, other-Zone encounters, reachable secret caches — stays recorded as remaining work rather than papered over.

**Implemented files:** `Tests/TestVendorPersistence.gd` and `Tests/TestVendorContent.gd` (new), the `effect` merge in `Globals/InventoryRules.gd`, plus the documentation updates listed in item 3.

**Also fixed:** `InventoryRules.projectItem()` merged a definition's display metadata into the read-only projection but dropped `effect`, so a *purchased* map reached the Journal and `Discovery` without its authored reveal: the Inventory **Use** action could never appear for a real map and `useMap` answered `invalid_map`. Fixture tests had injected the effect directly and hidden it; the persistence audit caught it on its first run, and `TestVendorContent` now keeps every sold effect resolvable.

### Save coordinator contract

The shipped `Globals/SaveGame.gd` autoload owns this contract; see [System Coherence §8](System%20Coherence.md#8-save-continue-and-new-game-contract). `TestVendorPersistence` still guards the vendor/discovery seams, and `TestSaveGame`/`TestSaveRestart` check the coordinated disk save and real application restart.

1. **Collect** one payload per domain through each domain's `exportState()`: Party (including equipment, reservations and next instance number), Quests, Locations/Trail, Cutscene, Vendors/stock/Bank, Discovery and the Overworld provider position. Bank id, reveal-target and stock-cycle references must be consistent with Party and the Trail state, not restored independently.
2. **Validate before committing anything.** `SaveGame.validatePayload()` audits the whole key set and JSON-safe values, cross-resolves ids and verifies that `vendors.activeDepartureId` and every rolled stock entry use `locations.trailDepartureId`. Domain importers remain the validators for their own shapes and content references. A failure during commit rolls the already-committed domains back from captured snapshots.
3. **Commit in dependency order:** Party, Quests, Locations, Cutscene, Vendors, Discovery, then the Overworld position. `Vendors.importState()` still owns departure/stock synchronization; rolled stock never regenerates on import.
4. **Write atomically** through a verified temp file and one-generation backup. A malformed file or newer save version leaves the previous live session and any readable prior save intact.
5. **New Game and Continue use their own commands:** the save is not deleted by New Game; `SceneManager.continueGame()` restores the one valid payload and resumes through the Overworld. Vendor stock changes only through the explicit Trail start, not on load, scene entry or a vendor-room return.

## Verification

Run tests through the project’s standard isolated runner so new tests receive real exit codes and timeouts:

```sh
godot --headless --script res://Tests/RunAll.gd -- Vendor
godot --headless --script res://Tests/RunAll.gd -- Discovery
godot --headless --script res://Tests/RunAll.gd -- Newspaper
godot --headless --script res://Tests/RunAll.gd
```

Patch 7 added `TestVendorPersistence` (coordinator audit) and `TestVendorContent` (content gate); both run inside the full suite and in isolation with `-- Vendor`, `-- Content` or `-- Persistence`.

### Automated coverage matrix

| Area | Required cases |
|---|---|
| Catalog/data | Duplicate ids, unknown item/Zone/scene/encounter/map targets, nonpositive prices/counts, wrong gear kind, missing value/art, secret manifest mismatches |
| RNG/stock | Same seed/departure/vendor deep-equals; repeated snapshots make zero generator calls; different departure clears all rolled vendors; fixed offers/Bank/discovery unchanged; default loot generation remains compatible |
| Buy | Exact stack merge/new slots, full inventory, insufficient funds, stale offer, invalid quantity/item, map owned/revealed, fixed supply availability, rolled offer removal, repeated click/reentrancy |
| Sell | Weapon vs equipment policy, unsellable content, equipped/unknown item rejection, quote accuracy/no arbitrage, final one-time credit, no buyback stock |
| Bank | Deposit/withdraw round-trip deep equality and same id, shared across vendors, full withdrawal atomicity, non-gear rejection, duplicate-id rejection, order and snapshot isolation |
| Snapshots | Valid round-trip without generation, malformed whole-payload rollback, cycle consistency, New Game reset, no UI-owned state |
| Maps | Valid full/partial reveal, duplicate use, malformed target/map rollback, blocked scene policy, one consumption/signal, marker projection/order/filtering, no reward/teleport |
| Newspaper | Exact Zone, repeated-enemy counts, kind/damage/mechanics/tips, quest exclusion, empty pool, unknown/malformed data, no RNG or Party mutation |
| Interaction/navigation | Closest target only, held/echo input ignored, persistent NPC, both currentLocation forms, safe spawn, no nested room, failed load recovery, transition cleanup |
| UI/modal | All vendor kinds, empty/error states, selection after mutation, quantity bounds, confirmation cancel/confirm, focus/controller, pause/music ownership, Journal exclusion, no input leak |

Use deep state snapshots in failure assertions: money, inventory, equipment, Bank, stock, next instance id, revealed ids, RNG call count, and emitted signal count. Successful results alone do not prove atomicity. Follow the existing fake-provider pattern for UI tests and small data fixtures for report/planner tests rather than loading the entire Overworld.

### Acceptance evidence

Mapping of [Location Vendors](Location%20Vendors.md) acceptance criteria to what proves them today.

| # | Criterion | Evidence |
|---|---|---|
| 1 | Icon, deliberate entry, separate room, interactive vendor, safe return | `TestVendorNavigation` (real door→room→modal→exit→same-door return for both Location forms), `TestVendorContent` (all five vendors placed exactly once, actor present, spawn 30px from the exit marker), `TestOverworldLocations` |
| 2 | General store sells working supplies/maps; no partial purchase | `TestVendorData` (consumable combat ids, authored reveal data), `TestVendors` (atomic failure modes), `TestVendorContent` (no unsupported effect), `TestVendorPersistence` (buy → present → reveal in one session) |
| 3 | Deterministic rolled selections per type/Zone; only the bought offer is removed | `TestVendorStock`, `TestVendors`, `TestNewspaper` (Zone/pool composition) |
| 4 | Selections identical after close/reopen, re-entry and transitions; change only on trail departure | `TestVendors`, `TestVendorNavigation`, `TestVendorPersistence` (rolled stock exported/restored without regeneration) |
| 5 | Sales only for the correct unequipped category, confirmed, one exact credit | `TestVendors` (quote/no-arbitrage/atomicity), `TestVendorUI` (confirmation cancel/confirm) |
| 6 | One shared Bank stash; full rolled data and ids preserved; full inventory blocks withdrawal | `TestVendors` (round-trip identity, atomicity), `TestVendorUI`, `TestVendorPersistence` (Bank contents survive the round-trip) |
| 7 | Map use consumes one copy, reveals permanently, leaves ordinary Locations alone | `TestDiscovery` (valid/duplicate/invalid/malformed, one consumption and signal), `TestInventoryTab` (Use flow), `TestOverworldMapTab` (hidden/revealed filtering), `TestVendorContent` + `TestVendorData` (targets are authored secrets) |
| 8 | Newspaper reports the parent Zone accurately and free, never a fallback | `TestNewspaper` (composition, exclusions, `no_pool`), `TestVendorContent` (canonical Zone + copy + published pool per newspaper), `TestVendorUI` (rendered report and unavailable state) |
| 9 | Usable empty/error states, stable focus, mouse and keyboard/controller, readable at 640×360, no input leak | `TestVendorUI` (states, focus neighbours, label heights, 640×360 layout) — **visual review still manual** |
| 10 | Repeated commands, double-clicks, held input and scene changes cannot duplicate items/money, reroll stock or lock pause/music | `TestVendors` (re-entrancy), `TestVendorNavigation` (press-edge, not held/echo), `TestVendorUI` (pause/music push-pop balance, scene-change cleanup, Journal exclusion), `TestVendorPersistence` (validation-before-commit) |

### Manual acceptance pass

Automation now covers the data behaviour of every step below; what remains is what a person must judge on screen. Steps 3–8 and 10 need only their visual/feel half, and step 9 is manual only.

1. **Manual:** from a real Overworld run, enter the initial resupply Location and judge every placed building/NPC icon, prompt placement, closest-target choice and safe return against the art.
2. **Manual:** buy stacked supplies across stack limits with exactly enough/insufficient money and space; confirm the on-screen money/capacity figures and refusal text read correctly (the underlying atomicity is automated).
3. **Manual (visual half):** confirm the recorded gun/equipment stock, the sale confirmation wording and final proceeds read correctly; stock stability across reopen/re-entry and departure reset is automated.
4. **Manual (visual half):** compare deposited/withdrawn gear stats, affixes and names on screen; identity and atomicity are automated.
5. **Manual (visual half):** confirm the trail departure prompt and its one-shot reset feel right; quest/Vamoose/minigame transitions not resetting is automated.
6. **Manual (visual half):** inspect revealed markers with mouse and controller and revisit the target world content; consumption, filtering, ordering and no-reward/no-teleport are automated.
7. **Manual (visual half):** read a report on screen and compare its tone and layout with the real encounter behaviour; accuracy, exclusions and the no-fallback rule are automated.
8. **Manual (feel half):** hammer open/close/cancel with real input and alt-tabbing, including pre-existing pause states; balance and cleanup are automated.
9. **Manual only:** review all five vendor views, long item/report text, empty/sold-out states and confirmations at 640×360 with integer scaling and keyboard/controller only.
10. **Manual (Continue/New Game):** repeat a purchase, map reveal, Bank deposit and Trail start through Main Menu Continue, then start New Game through the product UI and verify initial stock/clears; schema validation and exact restart behavior are automated in `TestSaveRestart.tscn`.

## Remaining content decisions and risks

- Exact stock counts, price tables, sell ratio, and affix valuation need economy balancing. Keep them data-driven and test the no-arbitrage bound independently of final numbers.
- ✅ The initial town's **Leave for the trail** interaction is implemented as `TrailDeparture`, which calls `Locations.departForTrail()` exactly once for that explicit transition; incidental Overworld scene entries still must not reset random selections.
- ✅ The town also has an Off-Trail exit: `Location/Entities/Town/TownExit.tscn` (**Leave town**) leaves through `Locations.enterOverworld()` without starting a Trail, so the party can return to the Overworld, reach other Towns and run quests Off Trail. It shares the door/trail marker convention and sits one activation area away from the `TrailDeparture`; neither exit resets random selections. Covered by `Tests/TestTownExit.tscn`.
- Explosives, magazines, cigar packs, and secret caches require real mechanics/world content. They are content blockers for completion, not reasons to add no-op purchases: `TestVendorContent` fails the run if a fixed offer cannot deliver its effect.
- Shared Zone migration and real encounter pools are cross-feature dependencies. Do not fork their data to make vendor progress appear complete — `canyon` is the only authored Zone so far, and other Zones must report themselves unavailable.
- ✅ Vendor NPC art, bespoke interior art and enemy actor animation sets are the remaining authoring blockers for patch 7's content item; the placed content reuses existing art deliberately rather than shipping placeholder claims.
- Bank’s unlimited capacity is intentional for this iteration but should be playtested alongside the 24-slot carried inventory; change it only through a new design decision, not a UI-only cap.
- ✅ Save snapshots are audited end to end (`TestVendorPersistence`), including the ordered validate-before-commit coordinator contract. `Globals/SaveGame.gd` now coordinates Party and vendor/discovery payloads on disk; Party has its validated export/import, and `TestSaveGame` plus `TestSaveRestart` prove rollback, migration and application-restart behavior.
- This plan deliberately leaves existing gathering interactions, general fog of war, visual-party behavior, loot overflow, and non-vendor Location transitions unchanged.
- This plan deliberately leaves existing gathering interactions, general fog of war, visual-party behavior, loot overflow, and non-vendor Location transitions unchanged.
