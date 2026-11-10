# Inventory & Equipment tab

The Journal's Inventory & Equipment tab manages the party's shared carried items and each party member's equipped gear. It makes capacity and stacking visible, explains item effects, supports deliberate dropping, and provides a one-action equipment swap with an accurate stat preview.

**Status: patch 5 implemented — the Inventory & Equipment tab is complete for the first iteration.** The live feature covers the shared capacity-limited inventory, canonical seven-slot equipment with atomic swaps, the projected-stat preview, dropping with confirmation, and capacity-aware Shootout loot with an explicit overflow acknowledgment. The full automated suite passes (`Tests/RunAll.gd`, 37 tests) and the 640×360 visual review is recorded in [Patch 5](#patch-5--full-verification-and-documentation). Unsupported affix/ability mechanics remain documented combat gaps, not UI gaps.

## First-iteration decisions

- Use one shared, limited party inventory for unequipped supplies, consumables, resources/loot, weapons, and equipment. Equipped items and money do not consume inventory slots.
- Start with the approved **24 occupied-stack slots** and **Paregoric stack limit 5** as initial balance values. `Party` exposes capacity and item definitions expose stack limits; the UI never hardcodes either.
- Stack only items with the same stable definition id and compatible instance data. Weapons, armor, legendaries, and other rolled equipment are always unstackable.
- Use seven fixed equipment slots: **Weapon**, **Headwear**, **Bandana**, **Duster**, **Belt**, **Trousers**, and **Justins**. Every class can use every equipment type; an item maps to exactly one slot.
- Support replacement-only equipment swaps in this iteration. Selecting **Equip** sends the item to its predetermined slot and returns the previously equipped item to the vacated inventory position. Direct unequipping and drag-and-drop are deferred.
- Allow equipment management wherever this Journal tab is available: initially the Overworld and normal Locations, not Shootouts or scene transitions. Keep the policy injectable so Town-only equipment switching can be adopted later without rewriting the tab or command API.
- Show both an item's own stats and the selected character's projected effective stats. Preview and Shootout setup use the same calculator.
- Permit dropping some or all of a stack through one confirmation flow. Selection, inspection, comparison, and cancellation never mutate state.
- For the first loot flow, deterministically take what fits and require confirmation before leaving overflow. Replace this with player-selected loot in a later iteration.
- Keep per-character Shootout belt-loadout editing outside this iteration. An equipment swap that would make the current belt loadout invalid is rejected rather than silently truncating it.
- Keep runtime state in `Party` across scene changes. Save/load persistence belongs to the future save service.

## Scope and requirements

### In scope

1. **Shared inventory and capacity**
   - Show every carried stack/item, its icon, name, category, and quantity where applicable, plus **used / capacity**.
   - Count occupied stacks, not individual units. Empty inventory is valid and must not disable equipment inspection.
   - Fill existing compatible stacks before using empty slots, up to each definition's `stackLimit`.
   - Keep presentation order deterministic. New stacks append in acquisition order; removing a stack compacts the shared list. Manual rearrangement is not required.
   - Loot, supplies, and equipment all obey the same capacity rules. No category receives a hidden extra allowance.

2. **Item inspection**
   - Show a selected item's full name, icon, category, description, stack quantity/limit, and droppability.
   - For weapons, show family and base damage. For equipment, show its fixed slot. Show base stats, rolled affixes, flags, lore, and authored abilities when present.
   - Distinguish item modifiers from effective character stats. An affix on an item is not presented as a confirmed character delta unless the shared calculator supports it.
   - Long names and modifier lists remain readable in a scrolling detail pane without hover or text shrinking.

3. **Character and equipment selection**
   - Provide a focusable party-member selector using the existing Party member key as identity and actor name/icon as presentation.
   - Preserve the selected member across refreshes while that member remains in the party; otherwise choose the first available member.
   - Show the selected member's seven slots, including explicit empty slots, and a compact summary of relevant effective stats.
   - Selecting a member or inspecting an equipment slot is UI-only and cannot change a loadout.

4. **Equipment swap and comparison**
   - Enable **Equip** only for a valid inventory weapon/equipment item, a valid selected member, and an allowed management context.
   - Preview the item in its predetermined slot; there is no slot picker and no class/level restriction in this iteration.
   - Compare the currently equipped item with the candidate and show projected effective values with signed deltas for affected stats. Include weapon base damage/family and belt-space changes where relevant.
   - A successful swap is atomic: the candidate leaves the inventory, the old item enters it, and no extra free slot is required. Instance ids and rolled affixes remain intact.
   - Reject invalid, stale, unavailable, or belt-invalid requests without mutation. Show a readable reason next to the action, not only in a tooltip.

5. **Dropping**
   - Provide **Drop...** for droppable inventory items, including resources and unequipped gear. Equipped items cannot be dropped directly.
   - A confirmation names the item and selected quantity. Stackable items default to one and allow any quantity from one through the whole stack; unstackable items have fixed quantity one.
   - Confirm calls one domain command. Cancel, `ui_cancel`, Journal close, and tab switch before confirmation leave state unchanged.
   - Partial drops reduce quantity; full-stack drops remove the occupied slot. Item definitions may prohibit dropping for quest/story reasons, with that reason visible.

6. **Acquisition and full-inventory behavior**
   - Route loot and future vendor/quest grants through inventory commands rather than direct `inventory.append()` calls.
   - Return accepted and overflow quantities/items to the caller. Never silently delete overflow, bypass capacity, or auto-drop equipped items to make room.
   - Money is applied independently of item capacity.
   - The Shootout result flow must show items left behind because of capacity and require explicit confirmation before leaving them. Deterministic acquisition order determines what fits; the first iteration does not add a loot-selection miniscreen.

7. **Journal behavior and accessibility**
   - Use the existing lazy-tab lifecycle, injectable provider pattern, shared theme, and modal/pause coordination.
   - Support mouse, keyboard, and controller for member selection, slots, item selection, details, quantity, confirmation, Equip, and Drop.
   - Refresh from authoritative state on activation and after successful commands. Only the active tab subscribes to change signals; hidden tabs do no periodic work.

### Out of scope for this iteration

- Using consumables outside combat, or assigning/moving consumables between shared inventory and per-character Shootout belts.
- Activating/deactivating class or equipment abilities and resolving equipment-granted ability loadouts.
- Implementing combat mechanics for affixes that the Shootout pipeline does not yet support.
- Direct unequipping, drag-and-drop, manual slot rearrangement, sorting, filtering, search, comparison across multiple characters, and equipped-item dropping.
- Buying, selling, Bank storage, trading between characters, crafting, durability, weight, ammunition management, and ground-persistent dropped items.
- Save serialization/migration across application restarts, New Game reset, and a settings/save service.
- New item generation or balance work beyond the stable ids and inventory metadata needed by this feature.

## Inventory and item rules

### Capacity and stacking

`Party.inventory` remains the authoritative occupied-stack list. A UI projection may append empty cells up to `capacity`, but those cells are not separate state.

| Item kind | Stack identity | Initial rule |
| --- | --- | --- |
| Consumable / supply | Stable `definitionId` | Stack to the definition's `stackLimit`; identical combat behavior only |
| Resource / loot | Stable `definitionId` | Stack to its authored limit; quantity must be positive |
| Weapon / equipment | Unique `instanceId` | Always quantity one; never merge rolled or named items |
| Quest/story item | Definition-specific | Stack/drop rules authored explicitly; no inferred protection from its name |

The approved initial content values are **24 shared slots** and **Paregoric `stackLimit = 5`**. All definitions require a positive integer limit, with `1` meaning unstackable. Items with different rolled stats, names, lore, or other instance data never share a stack.

Each acquired stack receives a Party-assigned runtime `instanceId`; stackables also have a stable `definitionId`. Generation does not consume inventory identity or capacity, and opening/refreshing the Journal never generates ids, items, or RNG results. Projections returned to UI are deep copies or immutable-by-contract data.

### Acquisition transactions

An add operation normalizes the incoming item/quantity, merges compatible stacks in deterministic inventory order, then appends new stacks while capacity remains. Its result reports accepted quantities, affected instance ids, complete overflow data, and a stable reason code for invalid input.

Existing valid items must not be reordered or rewritten merely because a later item does not fit. Invalid input is rejected before mutation. A batch may accept earlier entries and return later overflow, but its result must describe every entry; callers cannot treat partial success as complete success.

`Party.applyLoot()` uses this command path and returns the item result while preserving its current money responsibility. The Shootout end flow retains overflow details for its **Leave overflow** confirmation. Cancelling that confirmation leaves the result screen open; it does not pretend the items were carried.

### Canonical equipment ownership

Each Party member owns an `equipment` Dictionary keyed by the seven canonical slot ids. A non-empty value is the complete rolled item instance, including its `instanceId`; empty slots contain `null`. An equipment instance exists in exactly one place: the inventory or one equipment slot.

The current `Party.party[*].weapon` combat shorthand and `ActorBase.equipment` keys (`hat`, `jacket`, `trousers`, `boots`) are legacy representations to adapt, not additional equipment owners. Enemy actor data may keep its existing combat shape. Party fight setup receives a projection of canonical equipment rather than reading Journal state.

Equipment swaps validate the item, member, slot, management availability, and current belt loadout before changing either collection. On success, the old equipped item occupies the candidate's former inventory index, preserving used capacity and deterministic placement. Signals emit only after the complete swap.

The legacy `Party.party[*].items` belt arrays remain Shootout loadout data for now; they are not silently copied into shared inventory. Belt editing and unifying those consumable references require a follow-up design. Until then, reducing effective belt space below the current loadout count fails the equipment command with **Belt loadout too large** instead of relying on `ActorBase.applyLoadoutLimits()` to truncate a fight copy.

## User experience

### Layout at 640×360

Use the existing 560×280 Journal panel and reserve the content area for two principal columns:

```text
[Walker] [Other member...]                  Inventory  8 / 24
[Weapon][Headwear][Bandana][Duster]      [slot][slot][slot][slot][slot][slot]
[Belt][Trousers][Justins]                [slot][slot][slot][slot][slot][slot]
Selected member: HP / key stats           [slot][slot][slot][slot][slot][slot]
                                          [slot][slot][slot][slot][slot][slot]
Equipment / inventory selection          Item details and effective-stat preview
                                         [Equip] [Drop...]
```

The left side contains a horizontal member selector, seven compact equipment buttons, and a scrollable six-column inventory grid. The right side is a scrolling detail/comparison pane with actions kept reachable below it. The exact container proportions are an implementation concern; long content must scroll rather than shrink the 12px font or push actions off-screen.

Implemented presentation (patch 4 remediation):

- **Party selector**: one icon button per member, using the same portrait naming as the Shootout Turn Order strip (`Assets/Icons/{ActorName}Icon.png`, placeholder fallback). The name stays in the button's tooltip; the buttons are 28×28 so several members fit without shrinking the panels.
- **Equipment slots**: a single row of seven compact cells (`EquipmentGrid.columns = 7`). Empty slots show the greyed slot art the Shootout HUD uses (`RevolverIconGrey`, `HatIconGrey`, `JacketIconGrey`, `BeltIconGrey`, `TrousersIconGrey`, `BootsIconGrey`; the bandana slot falls back to the placeholder icon until bandana art exists) instead of text labels, which never fit the cells and made the grid two rows tall at the inventory's expense. Filled slots show the item's own sprite at full opacity.
- **Item card (`Nodes/Item Stats/ItemStats.tscn`)**: a `NinePatchRect` whose margins pin the art's icon box (`patch_margin_left = 34`, `patch_margin_top = 37`, right/bottom 2), so the card fills the detail column and grows taller for wrapped text while the icon frame keeps its natural size. A stretched `TextureRect` scaled the whole art — including the icon box — into a sliver, so the item sprite (12×12 or 24×24) spilled outside its frame. The card reports only a content-derived minimum height (`_fitPanelToContent`) and never sets its own size, so the host container supplies the width. Because the wrapped height depends on that width, the card re-fits when the assigned width changes and re-measures for a bounded number of frames after each display; previously the labels kept the height of the old line count and drew on top of each other at narrow widths.
- **Sprite scaling (`UI/TextureFit.gd`)**: item sprites exist at 12×12, 24×24 and 28×24 while the card's icon frame interior is 28×24 (frame highlight border: art x 4–33, y 6–31). All sprites are drawn at one shared **native** scale (`TextureFit.SCALE = 1`) and centered in the frame, so pixel proportions stay even and each sprite keeps its authored size — a 12×12 hat stays visibly smaller than a 24×24 revolver, a 28×24 rifle is a pixel narrower at each edge. Scaling each sprite up to fill the frame made 12px art as large as 24px art, and the earlier 28×29 box was 5px taller than the drawn frame, so sprites sat low and crossed the divider. The inventory/equipment cells use the same rule (`ItemSlotButton.ICON_BOX` 28×26); equipment cells are 30×28 so a 28×24 weapon still fits at native scale. Textures larger than a box fall back to an aspect-preserving fit; pixel art is never drawn at a fractional scale.
- **Detail line**: the label under the card carries the item category (plus quantity or equipped slot) only; the card already shows the full name.
- **Tooltip**: `UI/Tooltip/Tooltip.tscn` sits on canvas layer 6, above the Journal (layer 5) and below the scene transition layer (layer 10). At layer 2 the item card's name tooltip rendered behind the Journal.

Reuse `InventorySlotBackground.png`, `EquipmentSlotBackground.png`, `SelectedCharacterHighlight.png`, existing item sprites, and `Assets/UI/UI.tres`. `Nodes/Item Stats/ItemStats.tscn` can supply the gear detail presentation after it supports non-gear definitions and controller-readable full names. Missing sprites use a category fallback, never a fabricated item.

Stack counts, equipped/empty state, selection, focus, rarity, positive/negative deltas, and unavailable actions need text or shape in addition to color. Disabled actions have a visible reason. Tooltips supplement details but are not required for controller access.

### Selection and focus

- `getFocusTarget()` returns the selected member button, or the first inventory/equipment control if no member exists. Standard directional navigation connects members → equipment/inventory → details/actions.
- Selecting an inventory item updates details and, for gear, requests a side-effect-free preview. Selecting an equipment slot inspects that item but offers no direct unequip action.
- Preserve selected member key, item `instanceId`, equipment slot, scroll positions, and focus across live refreshes where those targets still exist. If an item disappears, choose a nearby valid cell without executing an action.
- `ui_accept` activates the focused button. **Equip** requires no confirmation because it is a reversible atomic swap; **Drop...** always opens confirmation.
- The drop panel traps focus and provides keyboard/controller quantity decrement/increment and direct whole-stack selection. `ui_cancel` cancels it first. Otherwise the existing shell returns focus from content to the tab bar before closing.
- `canCloseTab()` guards an open drop confirmation. No apply/revert model is needed: commands commit immediately and failed/cancelled commands leave state unchanged.

### Command feedback and refresh

On success, refresh from the provider's new snapshot, retain the relevant member/item where possible, and show a brief non-modal result such as **Equipped** or **Dropped 2 Paregoric**. On failure, preserve selection and show the command's readable reason. Never infer success from a pressed button or locally edit the displayed Dictionary.

`setTabActive(true)` connects provider signals once; `setTabActive(false)` and `_exit_tree()` disconnect them. Activation always re-reads state. A hidden cached tab needs no mutable domain copy or polling.

## Code-level architecture

### New and existing file responsibilities

**Create**

- `Data/Items/ItemCatalog.gd` — static stackable-item definitions and validation, following the existing data-script convention.
- `Globals/InventoryRules.gd` — `RefCounted`; normalization, add planning, stacking, slot lookup, and display projection. No autoload and no mutable global state.
- `Globals/CharacterStatCalculator.gd` — `RefCounted`; canonical equipment to fight-data projection and comparison deltas.
- `UI/Journal/ItemSlotButton.tscn`/`.gd` — focusable icon/name/quantity button used by inventory and equipment grids.
- `Tests/TestInventory.gd`, `Tests/TestEquipmentStats.gd`, `Tests/TestInventoryTab.gd`/`.tscn`, and `Tests/TestShootoutLoot.gd`/`.tscn`.

**Modify**

- `Globals/Party.gd` remains the sole mutable owner and exposes the provider/command API below.
- `Globals/ItemGeneration.gd`, `Data/Items/WeaponData.gd`, `EquipmentData.gd`, and loot tables add stable definition ids and quantities.
- `Actors/BaseActor.gd` and `Shootout/Shootout.gd` consume computed `beltSpace` and weapon/stats projections.
- `Nodes/Scene Manager/SceneManager.gd` publishes inventory-management availability.
- `UI/Journal/Tabs/InventoryTab.tscn`/`.gd` implements the provider-driven tab.
- `Shootout/Shootout.gd` and `Shootout/UI/ShootoutUI.*` defer the end signal until the result screen is acknowledged.
- `Nodes/Item Stats/ItemStats.*` supports every item category and non-hover full names.

No new autoload is required. `Party` instantiates one rules helper and one stat calculator; tests can instantiate the helpers directly.

### Item definitions and generated items

`ItemCatalog.gd` contains definitions keyed by `definitionId`. The first production definition is:

```gdscript
var definitions = {
	"paregoric": {
		"definitionId": "paregoric",
		"itemType": "consumable",
		"combatId": "Paregoric", # key in Shootout.itemsData
		"name": "Paregoric",
		"category": "supplies",
		"description": "Restores HP in a Shootout.",
		"stackLimit": 5,
		"droppable": true,
		"sprite": "res://Assets/Items/Paregoric.png",
	},
}
```

`validate() -> Array[String]` requires unique/non-empty ids, a supported `itemType`, positive integer `stackLimit`, Boolean `droppable`, and valid display/category fields. Consumables require a `combatId`; a production-data test checks it against `Shootout.itemsData`. Resources require their own stable definition before a loot table can drop them. Gear remains unstackable even if it has catalog metadata.

Add an `id` to every weapon base and generic/zone equipment base. `ItemGeneration` copies it to `definitionId` and adds `quantity: 1`; legendary keys become their `definitionId`. It also preserves an optional top-level `beltSpace` on generated belt items. Loot-table consumable/resource entries use `definitionId`, not display/combat names. Generated consumables/resources resolve their display fields through the catalog, while rolled weapons/equipment retain their complete generated Dictionary.

### Authoritative instance shapes

Inventory is a compact `Array[Dictionary]`; empty UI cells are projections only. Stackable entries contain no rolled per-instance fields:

```gdscript
{
	"instanceId": "item_17",
	"definitionId": "paregoric",
	"itemType": "consumable", # or "resources" / future stackable kind
	"quantity": 3,
}
```

Weapon/equipment entries preserve all generated fields and add identity/quantity:

```gdscript
{
	"instanceId": "item_18",
	"definitionId": "cattleman",
	"itemType": "weapon",      # or "equipment"
	"quantity": 1,
	"name": "Well-Kept Deadeye's Cattleman of the Quickdraw",
	"family": "revolver",      # weapon only
	"baseDamage": 7,            # weapon only
	"stats": { "cylinderIncrease": 2, "highTailin": 3 },
	# prefix, suffix, rarity, sprite, baseName, zone, lore as generated
}
```

Equipment entries use `"itemType": "equipment"` and `"slot": "headwear"` (or another canonical armor slot) instead of `family`/`baseDamage`. Both gear kinds always have `quantity: 1`.

`Party` assigns `item_<monotonic integer>` only when a new stack is accepted. Incoming `instanceId` values are discarded so external loot cannot duplicate identity. Merging into an existing stack retains that stack's id; overflow receives no newly allocated id. `instanceId` is the only UI command identity; array indexes are transient.

Each member has all seven keys, with full gear Dictionaries or `null`:

```gdscript
"equipment": {
	"weapon": { "instanceId": "starter_walker_rifle", "definitionId": "starter_rifle",
		"itemType": "weapon", "quantity": 1, "name": "Rifle", "baseName": "Rifle",
		"family": "rifle", "baseDamage": 4, "stats": {}, "sprite": "",
		"rarity": "common", "rarityName": "Trail-Worn", "prefix": {}, "suffix": {},
		"zone": "anywhere" },
	"headwear": null, "bandana": null, "duster": null,
	"belt": null, "trousers": null, "justins": null,
}
```

Migrate Walker's current belt `items` to `["Paregoric"]` and initialize shared inventory with one real `paregoric` stack. This preserves both existing items while satisfying Gunslinger's current `beltSpace = 1`. Remove the Party member's legacy `weapon` field after the canonical starter item exists; enemy actor Dictionaries are unchanged.

### `InventoryRules` add planning

Keep all validation and capacity work out of the UI. The main helper API is:

```gdscript
extends RefCounted
class_name InventoryRules

const GEAR_TYPES = ["weapon", "equipment"]
const EQUIPMENT_SLOTS = [
	"weapon", "headwear", "bandana", "duster", "belt", "trousers", "justins",
]

func planAdd(
	inventory: Array,
	items: Array,
	capacity: int,
	catalog,
	firstInstanceNumber: int
) -> Dictionary

func inventoryIndex(inventory: Array, instanceId: String) -> int
func equipmentSlot(item: Dictionary) -> String # "weapon" or item.slot; "" if invalid
func projectItem(item: Dictionary, catalog) -> Dictionary
```

`planAdd()` does not mutate any argument. It validates the complete input batch, duplicates the current inventory, and returns a proposed new Array. If any entry is malformed, has an unknown stackable definition, has non-positive/non-integer quantity, has inconsistent gear data, or exceeds capacity invariants, return `success = false` and no candidate inventory. Gear is validated as a complete self-contained rolled instance; it does not need a stackable catalog entry. `Party` only commits a successful plan.

For each valid input in array order:

1. Normalize stackables to `instanceId` (unassigned), `definitionId`, `itemType`, and `quantity`; preserve complete gear data with quantity one.
2. Add as much quantity as possible to existing compatible stacks in inventory order.
3. Create new stacks while `workingInventory.size() < capacity`, assigning ids only to newly accepted stacks.
4. Put any remaining quantity or unaccepted gear in `overflow`, preserving definition and rolled data.
5. If accepted quantity is positive, append one summary per input: `definitionId`, `name`, accepted `quantity`, and touched `instanceIds`. Zero-accepted inputs appear only in `overflow`.

Result contract:

```gdscript
{
	"success": true,             # false only for invalid input/catalog; full is valid
	"reason": "",              # stable snake_case reason on failure
	"inventory": [],             # proposed compact Array; not committed by helper
	"accepted": [],              # display-ready accepted summaries
	"acceptedInstanceIds": [],  # unique ids in deterministic order
	"overflow": [],              # normalized items with remaining quantity
	"nextInstanceNumber": 23,
}
```

`projectItem()` deep-copies the instance and merges catalog display metadata (`name`, `category`, `description`, `stackLimit`, `droppable`, `sprite`, `combatId`). Gear always receives `stackLimit = 1`; its rolled fields override base display metadata. It never returns an internal nested Dictionary by reference.

### `Party` provider and command API

```gdscript
signal inventoryChanged
signal equipmentChanged(memberKey: String)

const INVENTORY_CAPACITY = 24
var classesData = {}                    # read-only Shootout class definitions
var inventoryManagementAllowed = false # fail closed outside allowed scenes

func isInventoryDataAvailable() -> bool
func getInventorySnapshot() -> Dictionary
func getEquipmentPreview(memberKey: String, instanceId: String) -> Dictionary
func setInventoryManagementAllowed(allowed: bool) -> void
func addItems(items: Array) -> Dictionary
func addItem(item: Dictionary) -> Dictionary
func dropItem(instanceId: String, quantity: int) -> Dictionary
func equipItem(memberKey: String, instanceId: String) -> Dictionary
func applyLoot(loot: Dictionary) -> Dictionary
func applyFightResults(results: Dictionary) -> Dictionary
func getFightData(actorName: String) -> Dictionary
```

`Party._ready()` loads/validates `ItemCatalog`, obtains `Shootout.classesData` (the existing autoload order already initializes Shootout first), and constructs helpers. Tests that instantiate `Party.gd` without a tree inject a catalog/classesData through a small `configureInventory(catalog, classDefinitions)` initialization seam. Invalid catalog state makes `isInventoryDataAvailable()` false and disables add/drop/equip; it never produces partial live projections.

Snapshot contract:

```gdscript
{
	"capacity": 24,
	"used": inventory.size(),
	"managementAllowed": inventoryManagementAllowed,
	"items": [],   # projectItem() results in authoritative order
	"members": [{
		"key": "Walker Langley", # existing Party Dictionary key
		"actorName": "Walker Langley",
		"equipment": {},          # deep copy keyed by all seven slots
		"fightData": {},          # current CharacterStatCalculator projection
	}],
}
```

The UI treats snapshots as read-only even though Godot Dictionaries are reference types. Every provider read returns fresh deep copies. `getEquipmentPreview()` returns the same member/slot identity plus `current`, `projected`, and ordered `deltas`; invalid ids return `success = false` and a stable reason.

`addItem()` delegates to `addItems([item])`. `addItems()` calls `InventoryRules.planAdd()`, commits `inventory` and `_nextInstanceNumber` only on valid input, emits `inventoryChanged` once if anything was accepted, and returns the public result without the proposed internal inventory/counter fields. Capacity overflow is not a command error.

`applyLoot()` adds money independently, calls `addItems(loot.get("items", []))`, and returns that result plus `money` (the amount just added). Invalid item data does not roll back money. `applyFightResults()` preserves its HP/injury/knockout behavior, calls `applyLoot()` when loot exists, and returns `{ "loot": lootResult }` for the Shootout result payload.

### Drop and equip algorithms

All player-command failures return `{ "success": false, "reason": "..." }` and emit no signals. Use reason codes `data_unavailable`, `management_unavailable`, `unknown_member`, `unknown_item`, `not_equipment`, `invalid_slot`, `invalid_quantity`, `not_droppable`, and `belt_loadout_too_large`.

`dropItem(instanceId, quantity)`:

1. Require available data and `inventoryManagementAllowed`.
2. Resolve the entry by id and its projected `droppable` flag; equipped items are not in this collection and cannot be dropped by id.
3. Require `1 <= quantity <= entry.quantity` with an integer value.
4. Decrement the entry or remove it when the whole stack is dropped.
5. Emit `inventoryChanged` once and return `success`, `instanceId`, `definitionId`, and dropped `quantity`.

`equipItem(memberKey, instanceId)`:

1. Require available data, management availability, an existing member, and an inventory entry.
2. Require gear and resolve `weapon` or the item's authored `slot`; never accept a UI-supplied slot.
3. Build current and hypothetical fight data with `CharacterStatCalculator`.
4. Reject when computed `beltSpace >= 0` and `member.items.size() > beltSpace`.
5. Remember the candidate's inventory index and the old equipped item.
6. Remove the candidate, put the old item at that same index when non-null, and assign the candidate to the member's slot. An empty old slot simply frees the inventory cell.
7. Clamp persistent `member.hp` to projected `maxHp`; do not increase HP when max HP rises.
8. Emit `inventoryChanged` once and `equipmentChanged(memberKey)` once, then return `success`, `memberKey`, `slot`, `equippedInstanceId`, and `returnedInstanceId` (empty for an empty slot).

Validate all inputs before step 6. No UI callback writes either collection, and no extra capacity is needed for replacement. `getEquipmentPreview()` performs steps 1–4 without mutation and adds `current`, `projected`, and `deltas` to the result.

### Scene policy handoff

Add `SceneManager._syncInventoryPolicy()`:

```gdscript
func _syncInventoryPolicy() -> void:
	Party.setInventoryManagementAllowed(
		!transitioning and journalAllowedScenes.has(currentSceneKey)
	)
```

Call it with management disabled immediately after `transitioning = true`, then again after `transitioning = false` on successful loads and after `_abortTransition()` restores the prior scene. Also synchronize the initial main-menu state. `canOpenJournal()` remains the shell policy; this second check is the domain mutation policy. A future Town-only implementation changes `_syncInventoryPolicy()` (or a policy helper it calls), not `InventoryTab` or `Party.equipItem()` validation.

### `CharacterStatCalculator`

```gdscript
extends RefCounted
class_name CharacterStatCalculator

func calculate(
	member: Dictionary,
	classData: Dictionary,
	replacementSlot: String = "",
	replacementItem = null
) -> Dictionary

func compare(current: Dictionary, projected: Dictionary) -> Array
```

`calculate()` deep-copies the member, optionally replaces exactly one canonical equipment slot, and returns fight-ready data. It never reads autoloads or mutates equipment. `Party.getFightData()` calls it with `classesData.get(member.characterClass, {})`; preview calls it once unchanged and once with the candidate. Legacy test/member data without `equipment` retains its current weapon/no-equipment behavior.

Apply supported effects in this order:

1. Start with base member stats, filling the same missing defense/resistance/lasso defaults that `ActorBase` currently tolerates, and the selected equipment Dictionary.
2. Add equipment `stats.sixShootin`, `highTailin`, and `taffyin` to their top-level stat paths.
3. Add `stats.style` and `stats.sand` from every equipped item to `stats.defense`.
4. Add `stats.mxHp` to `baseMaxHp`, then apply the existing injury formula and floor at one.
5. Apply existing knockout debuffs to top-level stats after equipment additions.
6. For an equipped weapon, output `{ "type": "lead", "weapon": item.family, "baseDamage": item.baseDamage + int(item.stats.get(item.family + "Damage", 0)) }`; only the matching `revolverDamage`, `rifleDamage`, or `shotgunDamage` affix applies.
7. Set `beltSpace` to class `beltSpace` plus the equipped belt's optional top-level integer `beltSpace`; `-1` remains uncapped. Set `hp = min(member.hp, maxHp)`.

All other affixes remain visible on the item but do not produce a delta until their combat mechanics are implemented. Do not silently treat every entry in `item.stats` as a working combat modifier.

`compare()` returns an ordered Array, not Dictionary iteration order:

```gdscript
[
	{ "path": "maxHp", "label": "MxHP", "before": 12, "after": 15, "delta": 3 },
	{ "path": "stats.defense.style", "label": "Style", "before": 2, "after": 4, "delta": 2 },
	{ "path": "weapon.baseDamage", "label": "Damage", "before": 4, "after": 7, "delta": 3 },
	{ "path": "beltSpace", "label": "Belt space", "before": 1, "after": 2, "delta": 1 },
]
```

Include fixed rows for MxHP, Six Shootin', High Tailin', Taffyin', Style, Sand, weapon damage, and belt space; include zero deltas only for the compact current-stat summary, not the candidate's changed-stat list. Weapon family changes appear as a separate text row.

Add `ActorBase.beltSpace = -1` and read `actorData.get("beltSpace", -1)` in `init()`. In `Shootout.spawnActor()`, keep the existing class-data value for enemies; for `Party.party.has(actorName)`, pass `newShootoutActor.beltSpace` from the computed fight data to `applyLoadoutLimits()` instead. Call the limit function once. Valid Party loadouts therefore use the same belt value shown in preview; existing enemy behavior remains intact.

### Inventory tab scene and script contract

Build `InventoryTab.tscn` with stable node names:

```text
InventoryTab (Control)
├── ContentView (HBoxContainer)
│   ├── LeftPanel (PanelContainer)
│   │   └── LeftLayout (VBoxContainer)
│   │       ├── MemberScroll / MemberButtons (HBoxContainer)
│   │       ├── EquipmentGrid (GridContainer, 4 columns)
│   │       ├── MemberStats (RichTextLabelExtended8px)
│   │       ├── CapacityText (RichTextLabelExtended8px)
│   │       └── InventoryScroll / InventoryGrid (GridContainer, 6 columns)
│   └── DetailPanel (PanelContainer)
│       └── DetailLayout (VBoxContainer)
│           ├── DetailScroll / DetailContent (VBoxContainer)
│           │   ├── ItemStatsHost (Control)
│           │   ├── SelectionLabel (RichTextLabelExtended8px)
│           │   └── ComparisonRows (VBoxContainer)
│           ├── FeedbackLabel (RichTextLabelExtended8px)
│           └── Actions (HBoxContainer: EquipButton, DropButton)
├── DropOverlay (CenterContainer, hidden)
│   └── DropPanel (PanelContainer)
│       └── DropLayout (ItemName, QuantityLabel, DecrementButton,
│           IncrementButton, AllButton, ConfirmButton, CancelButton)
└── StateView (CenterContainer with StateTabSprite and StateMessageLabel)
```

Use a `ButtonGroup` for member selection and separate item/equipment selection state. `ItemSlotButton.gd` exposes `displayItem(item: Dictionary, emptyText: String = "")`, with `icon`, `itemName`, `quantity`, `emptyText`, and `tooltip_text` set from a projected item. Inventory buttons store `instanceId` in metadata; equipment buttons store `slot`. Empty cells are focusable only when they convey an empty equipment slot; unused inventory capacity cells are disabled.

**Text-node contract:** every text presentation in this feature uses the project's shared rich-text scenes, not native `Label` nodes or `Label.new()`. Use `UI/RichTextLabel Extended 8px/RichTextLabelExtended8px.tscn` for compact Journal cells, capacity/state/comparison/feedback/drop text, and `UI/RichTextLabel Extended/RichTextLabelExtended.tscn` for larger result text. This applies to `ItemSlotButton`'s `EmptyLabel`/`Quantity`, scene-authored labels, and dynamically created comparison rows. Buttons may remain `Button` controls because they provide actions, but their captions follow the same shared theme. Update text through the extended node's text/rich-text API rather than assuming a native `Label` API.

`InventoryTab.gd` state and entry points:

```gdscript
var inventoryProvider: Node = null # fake in tests; null resolves /root/Party
var _snapshot = {}
var _selectedMemberKey = ""
var _selectedInstanceId = ""
var _selectedEquipmentSlot = ""
var _selectionSource = "" # "inventory" or "equipment"
var _connectedProvider: Node = null
var _dropQuantity = 0

func refreshTab() -> void
func setTabActive(tabActive: bool) -> void
func getFocusTarget() -> Control
func canCloseTab() -> bool
func _onInventoryItemPressed(instanceId: String) -> void
func _onEquipmentSlotPressed(slot: String) -> void
func _onEquipPressed() -> void
func _onDropPressed() -> void
func _onDropConfirmed() -> void
func _onDropCancelled() -> void
```

`refreshTab()` resolves/connects the provider, handles unavailable data, reads one snapshot, rebuilds members/equipment/inventory, reconciles stable selections, then updates the detail pane. It does not call add/equip/drop. Member selection defaults to the first member; item selection falls back to the nearest remaining inventory index. Preserve scroll/focus only when the captured target still exists.

Inventory gear selection calls `getEquipmentPreview()` and renders item stats plus changed rows. Non-gear selection hides comparison and Equip. Equipment-slot selection shows that item and current member stats but no unequip action. Action enablement uses both the snapshot's `managementAllowed` and the preview/definition result. Failure text comes from a UI mapping of the stable reason codes.

`_onEquipPressed()` re-reads only the selected ids, calls `equipItem()` once, and handles the returned result; it does not optimistically swap displayed items. `_onDropPressed()` captures the id/max quantity and shows DropOverlay. Quantity starts at one, All sets the stack maximum, and Confirm calls `dropItem(_selectedInstanceId, _dropQuantity)` once. Cancel/close hides the overlay without a provider call. A successful provider signal performs the subsequent refresh.

`canCloseTab()` returns `!DropOverlay.visible`; `_onDropCancelled()` restores focus to the originating Drop button or item. `DropOverlay.mouse_filter = MOUSE_FILTER_STOP`, and `_unhandled_input()` consumes `ui_cancel` only while it is visible, calls `_onDropCancelled()`, and marks the viewport input handled. `setTabActive(false)` also cancels the pending drop before disconnecting. `getFocusTarget()` returns the selected member button, then the first enabled inventory button when no member exists. Connect provider signals using the same stored-connection lifecycle as `QuestsTab`; disconnect on deactivation and `_exit_tree()`.

Extend `ItemStats.displayItem()` with explicit branches for `weapon`, `equipment`, and catalog-backed stackables. Do not route consumables through its current generic `item.slot` access. Show quantity/stack limit outside the four modifier labels, wrap the full name in the Journal detail pane, and retain the existing two-line/tooltip behavior only in contexts that already rely on it.

### Shootout result and overflow flow

Change the result application in `Shootout._on_battle_ended()` to:

```gdscript
results["loot"] = generateLootForFight(results.rodeoLoot, winningSide)
var applicationResult = Party.applyFightResults(results)
results["lootResult"] = applicationResult.get("loot", {})
MusicPlayer.on_shootout_ended(results)
ui.showEndScreen(results)
# shootoutEnded is emitted by _onEndScreenContinuePressed(), not here.
```

Add `signal endScreenContinuePressed` to `ShootoutUI.gd` and connect it once in `Shootout._ready()`. Do not create the end-screen hierarchy in `showEndScreen()`. Move it to a dedicated `Shootout/UI/ShootoutEndScreen.tscn` + `ShootoutEndScreen.gd`, instanced (hidden by default) by `ShootoutUI.tscn` at scene load. The scene owns its outcome text, loot scroll/content, accepted/overflow text, and Continue button statically. `ShootoutUI.showEndScreen()` delegates to `endScreen.showResults(results)`, which updates text/button state, visibility, and focus only; it never instantiates/frees UI children. `hideEndScreen()` only hides that existing node.

The dedicated scene uses generic rich-text nodes for outcome/accepted/overflow text and owns acknowledgment state plus one-shot button behavior. `ShootoutUI` forwards its acknowledgment signal, preserving the existing deferred `shootoutEnded` contract. Tests must verify the `EndScreen` node exists before any results are shown, its child count remains unchanged across repeated shows/hides, and accepted/overflow rendering and one-shot acknowledgment still pass. `showEndScreen()` reads:

- `lootResult.money` for awarded cash (use `loot.money` only as a legacy-test fallback, never add both);
- `lootResult.accepted` for accepted item names/quantities;
- `lootResult.overflow` for a separate **Inventory full — left behind** list.

With no overflow, the button reads **Continue**. With overflow, it reads **Leave overflow & continue**, which is the explicit destructive confirmation. On press, hide/disable the result panel and emit `endScreenContinuePressed` once; `Shootout` then emits `shootoutEnded(winningSide, results)` with the complete accepted/overflow payload. No scene transition or external listener can discard overflow before this acknowledgment. A later player-selected loot screen replaces this panel's accept/leave interaction, not the inventory command API.

## Empty, unavailable, and failure states

- Missing/unreadable provider: replace the tab with **Inventory data unavailable** and the Inventory tab sprite. Do not show fixtures as production items.
- Valid empty inventory: show **No carried items**, `0 / capacity`, and empty cells; member equipment remains inspectable.
- No party members: keep inventory available and show **No party members** in the equipment/details region with Equip disabled.
- Management unavailable: inventory inspection remains available, but Equip explains why it is disabled. Dropping follows the same explicit scene policy if a future scene allows read-only Journal access.
- No selection: show **Select an item or equipment slot.** Empty slots show their slot name rather than fabricated stats.
- Malformed item/member data: log its stable id, withhold invalid details/actions, and preserve valid siblings. Never equip or drop by array index after a refresh.
- Missing item art: use the category fallback and retain the real item name/data. Missing definitions or invalid rolled stats are data errors, not empty inventory.

## Implementation plan

Implement as five reviewable patches in this order. Keep `InventoryTab` in its intentional unavailable state until patch 4; never seed fixture items during tab refresh. Run the listed gate before starting the next patch. Capacity enforcement and Shootout overflow acknowledgment land together in patch 2 so intermediate runtime behavior cannot silently discard loot.

### Patch 1 — Stable definitions and generation output

**Status: implemented.**

1. Create `Data/Items/ItemCatalog.gd` with the approved Paregoric definition and `validate()` errors for every malformed field.
2. Add stable `id` fields to all entries in `WeaponData.weaponFamilies`, `EquipmentData.genericBases`, and zone equipment. Use snake_case ids and test uniqueness within each generated base pool.
3. Update `ItemGeneration.generateWeapon()`, `generateEquipment()`, and `generateLegendary()` to emit `definitionId` and `quantity = 1` without changing rarity, affix, sprite, or RNG order.
4. Change loot-table consumable/resource entries to `definitionId`; normalize generated stackables with quantity and catalog display data. Update `Data/Shootout/LootTables/Rats.gd` to `definitionId: "paregoric"`.
5. Extend `Tests/TestItemGeneration.gd` and `Tests/TestLoot.gd` for stable ids, quantities, unchanged affix preservation, unknown resource rejection, and valid production combat ids.

**Gate:** run each suite separately: `RunAll.gd -- ItemGeneration`, then `RunAll.gd -- Loot`.

### Patch 2 — Inventory commands and end-to-end loot handling

**Status: implemented.**

1. Create `InventoryRules.gd`; implement `planAdd()`, id allocation, normalization, overflow, projection, and index/slot helpers exactly as specified. Unit-test the helper before wiring the autoload.
2. Add `Party`'s catalog/configuration seam, `_nextInstanceNumber`, `INVENTORY_CAPACITY`, signals, item snapshots, `addItem(s)`, and `dropItem()`. Route `applyLoot()` through `addItems()` and return accepted/overflow data.
3. Migrate Walker's belt to one Paregoric and add the other as one shared Paregoric. Keep the legacy starter weapon until patch 3.
4. Add `SceneManager._syncInventoryPolicy()` and disable management at transition start, restore it after completion/abort, and cover allowed/blocked scene keys.
5. Return the loot application result from `Party.applyFightResults()` and attach it as `results.lootResult` in `Shootout._on_battle_ended()`.
6. Add `ShootoutUI.endScreenContinuePressed`, the scrollable end-screen panel, accepted/overflow summaries, and Continue/Leave overflow button states. Move `shootoutEnded.emit()` into the one-shot continuation handler.
7. Create `Tests/TestInventory.gd` for exact-fit/partial/full additions, multi-stack merging, invalid batch atomicity, id uniqueness, drop validation, signal counts, snapshot isolation, money independence, and policy failures. Extend `Tests/TestJournal.gd` or its Scene Manager fixture for policy synchronization.
8. Extend `Tests/TestShootoutUI.gd` for accepted/overflow rendering and button labels. Create `Tests/TestShootoutLoot.gd`/`.tscn` proving no end signal occurs before acknowledgment, items/money apply once, overflow remains in the emitted result, and repeated clicks cannot emit twice.
9. Verify no-loot, quest-loot-disabled, defeat/flee, exact-fit, partial-fit, and full-overflow result paths before considering capacity enforcement complete.

**Gate:** run each suite separately: Inventory, Journal, Loot, ShootoutUI, ShootoutLoot, Injury.

### Patch 3 — Canonical equipment, shared stats, and equip command

**Status: implemented.**

1. Create `CharacterStatCalculator.gd` with the documented calculation order and fixed comparison paths. Preserve legacy member behavior when `equipment` is absent so existing injury tests remain meaningful.
2. Add canonical seven-slot equipment and the complete starter rifle instance, then remove Walker's legacy `weapon` field. Expand Party snapshots with member equipment/fight-data projections.
3. Route `Party.effectiveMaxHp()` and `getFightData()` through the calculator. Add current/projected preview and atomic `equipItem()` with HP clamp, belt validation, returned gear placement, and both signals.
4. Add `ActorBase.beltSpace`; update `Shootout.spawnActor()` so Party actors use the computed value and enemies retain class-data behavior. Remove the unused legacy `ActorBase.equipment` keys after checking references.
5. Create `Tests/TestEquipmentStats.gd` for every supported stat, family-specific weapon damage, unsupported-affix exclusion, injuries/knockouts, HP clamp/no-heal, empty/replaced slots, full-inventory replacement, belt rejection, preview/commit parity, and source-copy isolation.
6. Update `Tests/TestInjury.gd`, `TestActs.gd`, and `TestDamage.gd` for the computed fight-data shape and verify existing combat calculations remain unchanged without equipment.

**Gate:** run each suite separately: Inventory, EquipmentStats, Injury, Acts, Damage, ShootoutLoot.

### Patch 4 — Inventory & Equipment tab

**Status: implemented.**

1. Create `ItemSlotButton.tscn`/`.gd` and the `InventoryTab.tscn` node structure. Verify the 640×360 layout before connecting commands.
2. Implement provider resolution, snapshot refresh, member/equipment/inventory rebuilding, stable selection, current/projected details, empty/unavailable states, and signal connection lifecycle in `InventoryTab.gd`.
3. Extend `ItemStats.displayItem()` for stackables and full controller-readable names without regressing existing generated-item tests.
4. Wire Equip and Drop exactly once per press. Implement quantity decrement/increment/All, focus trapping/restoration, reason/result labels, and `canCloseTab()` guarding.
5. Create `Tests/TestInventoryTab.gd`/`.tscn` with fake-provider fixtures for every state and command result. Cover keyboard/controller traversal, long content, refresh focus/scroll, and actual panel sizing. Extend `Tests/TestJournal.gd` for lazy activation and cancel/close behavior.
6. Replace the intentional unavailable state only after the real Party snapshot and both commands pass their integration tests.

**Gate:** run each suite separately: Inventory, ItemGeneration, Journal.

## Implementation review — patch 4 findings

Review status: **resolved.** Three review findings were raised against the first patch-4 implementation; all are fixed and covered by tests.

1. **Resolved — shared text controls.** `InventoryTab.tscn`, `ItemSlotButton.tscn`, `InventoryTab._renderComparison()`, and the Shootout result/banner/effect text now use the shared `RichTextLabelExtended` scenes and `setRichTextLabel()`/`appendRichTextLabel()`. No native `Label` nodes or `Label.new()` remain in the feature's presentation code (`Countdown`-style buttons remain `Button` controls).
   - `UI/Journal/ItemSlotButton.tscn` uses `EmptyLabel` (`CenterContainer`) + `EmptyText` (`RichTextLabelExtended8px`) and a `Quantity` (`RichTextLabelExtended8px`); `ItemSlotButton.gd` updates both through the extended API.
   - `UI/Journal/Tabs/InventoryTab.tscn` renders Party/Equipment/Inventory headers, `CapacityText`, empty/state, member summary, selection/detail, comparison, feedback, and drop-confirmation text with `RichTextLabelExtended8px` instances.
   - `InventoryTab._renderComparison()` instantiates `RichTextLabelExtended8px.tscn` per row and formats with `setRichTextLabel()`.
   - Legacy `ShootoutUI.showEffects()`/`showBanner()` text was migrated too, so the Shootout UI no longer creates native labels at runtime.

2. **Resolved — scene-owned Shootout result screen.** `Shootout/UI/ShootoutEndScreen.tscn` + `.gd` own the outcome, loot scroll, accepted/overflow rows and Continue button, and are instanced hidden by `ShootoutUI.tscn` at load. `ShootoutUI.showEndScreen()`/`hideEndScreen()` delegate to `showResults()`/`hideResults()`, which only update text, visibility, focus and one-shot acknowledgment state; the hierarchy is never created or freed at runtime. A scene connection forwards `continuePressed` to `ShootoutUI._on_end_screen_continue_pressed()`, preserving the deferred `shootoutEnded` contract.

3. **Resolved — nearest-cell selection fallback.** `InventoryTab` keeps the previous inventory order, so when the selected item disappears it selects the next occupied cell at the same index, or the nearest preceding cell, and clears only when nothing remains. Reconciliation never invokes a command.

### Review remediation and tests

1. ✅ Shared rich-text controls across Inventory, the end screen, and Shootout effect/banner text; tests assert parsed text.
2. ✅ `ShootoutEndScreen` exists before results, and `Tests/TestShootoutUI.gd` asserts the hierarchy/child count is unchanged across repeated show/hide cycles while accepted/overflow rendering and one-shot acknowledgment still pass.
3. ✅ `Tests/TestInventoryTab.gd` covers removal from the middle, removal at the end, and removal of every item without any command being issued.
4. ✅ Gate passed: Inventory, EquipmentStats, ItemGeneration, ShootoutUI, ShootoutLoot, and Journal suites all pass.

### Patch 5 — Full verification and documentation

**Status: implemented.** Gate passed: the full suite is green and the visual review is recorded below.

1. Confirm the resolved [patch-4 findings](#implementation-review--patch-4-findings) stay green in the full suite.
2. Run `godot --headless --script res://Tests/RunAll.gd` and fix regressions in existing combat, Rodeo, reward, Journal, and scene-policy suites before sign-off.
3. Manually review real starter data, generated gear for every slot, full/empty inventory, stack overflow, drop quantities, HP changes, belt rejection, and Shootout overflow at 640×360 with mouse, keyboard, and controller.
4. Confirm opening/closing the Journal performs no RNG rolls, id allocation, item generation, or state writes; inspect repeated scene transitions and tab activations for duplicate signals.
5. Update this doc's status with implemented behavior. Update `Journal.md`, `Shootout/Rewards.md`, `Shootout/Moves Items and Ducks.md`, `Shootout/Damage and Stats.md`, and `System Design/Testing.md` with the actual inventory command, belt, stat, overflow, and test coverage.
6. Record any unsupported affix/ability behavior as a remaining combat gap; do not mark the whole affix system implemented merely because item details render.

**Gate:** full suite passes and manual visual/controller review is recorded in this doc.

#### Full-suite result

`godot --headless --script res://Tests/RunAll.gd` → **37/37 tests pass**. The one long-standing failure (`TestActorShadow`, the VERTICAL directional-coverage padding) was a stale expectation, not a product bug: `f775b0d` shipped the VERTICAL geometry as `+3` width padding and a `-3` bottom-line offset, while the test still asserted `+5`/`-2`. The test now asserts the shipped values, so the suite is a usable gate rather than a permanently red run.

#### Manual review at 640×360

Recorded with a real-`Party`/`ItemGeneration` harness (temporary, not committed) that drives the tab and the Shootout result panel and captures rendered frames:

| Case | Result |
| --- | --- |
| Starter data | One real Paregoric stack (`1 / 24`), starter rifle equipped, member summary `HP 12/12`, empty slots showing their greyed art. |
| Generated gear, every slot | 7/7 canonical slots filled in 35 generator rolls, each equipped through `Party.equipItem()` (all `success=true`); the summary reflected the accumulated Style/Sand/MxHP/belt-space bonuses. |
| Full inventory | `24 / 24`, all cells drawn, capacity text correct. |
| Stack overflow | With every stack at its limit, adding 3 accepted 0 and returned `overflow` with the full normalized entry; with a partial stack present the same add merged instead, which is the documented fill-partial-stacks-first behavior. |
| Empty inventory | `0 / 24`, empty cells, **No carried items**, equipment still inspectable. |
| Drop quantities | Overlay opened at quantity 1 of a 5-stack, `+` raised it to 2, Confirm left 3 — one command, correct remainder. |
| HP changes | Injured projection `5/5` from stored `12/12`; a successful equip wrote the clamped 5 back and never healed upward. |
| Belt rejection | With three belt items and `beltSpace` 1, the preview reported `belt_loadout_too_large`, the feedback label read "That belt cannot hold the current belt loadout.", and Equip was disabled. |
| Shootout overflow | Result panel showed "1 cash, 2 Paregoric" plus "Inventory full - left behind: 3 Paregoric" and the button read **Leave overflow & continue**. |

Controller/keyboard behavior was verified through the automated focus and input paths rather than a physical gamepad: `Tests/TestInventoryTab.gd` checks the tab focus target, focus surviving a refresh, `ui_cancel` closing the drop confirmation without issuing a second command, and focus returning to the selected item; `Tests/TestJournal.gd` drives the real shell's D-pad handoff (tab bar → member selector → back), and `Tests/TestActs.gd`/`TestShootoutUI.gd` cover the same focus patterns elsewhere. A hands-on gamepad pass remains a QA task before shipping, not an unimplemented feature.

Two presentation defects were found and fixed during the review:

- The shared label scenes carry the placeholder text `"ABOBA!"`. `InventoryTab._ready()` now clears every label that starts empty (capacity, empty-inventory, member summary, selection, feedback, drop item and quantity) and hides the item card until real details are shown, so the placeholder can no longer appear in the detail pane or the drop overlay.
- The item card had the same issue on its first build, because `displayItem()` returns early for an empty item and left the instanced label untouched.

#### Side-effect audit

Opening, closing and re-activating the Journal is read-only. `Tests/TestJournal.gd::testInventoryNoSideEffects` checks, across three open/close/activate cycles with member, equipment-slot and item selections in between: a seeded global RNG replays identically (no RNG consumption), `inventory`, `party`, `money` and the instance-id counter are unchanged, no items are generated, the active tab holds exactly one provider connection, and a deactivated tab holds none.

#### Remaining combat gaps (not UI gaps)

`CharacterStatCalculator` projects only `sixShootin`, `highTailin`, `taffyin`, `style`, `sand`, `mxHp`, the matching weapon-family damage affix and belt `beltSpace`. Every other affix in `Data/Items/AffixData.gd` — `bleedAffliction`, `poisonAffliction`, `damagePiercing`, `damageTakenReduction*`, `damageVsMarked`, `gunpowderDamage`, `initiative`, `lassoDamage`, `liquidSkull*`, `lootGems`/`lootGold`/`lootItems`, `mxEn`, `mxHpHealTauntingPerTurn`, `negativeEffect*`, `shrapnelDamage`, `silenceImmunity`, `turnOrder`, `cylinderIncrease` — renders on the item but produces no delta and no combat effect. The detail pane therefore describes what the item *has*, not a confirmed character change, and the comparison list omits those rows. Equipment-granted Move/Ability loadouts are likewise unimplemented. Do not read "affixes render" as "affixes work".

## Testing and acceptance

### Domain and combat

- Same-definition consumables/resources fill partial stacks before new slots; excess forms new stacks or reported overflow. Rolled gear never stacks.
- Capacity counts occupied stacks. Full, exact-fit, partial-fit, invalid-quantity, unknown-definition, and malformed-item cases have explicit results and no silent loss.
- Every inventory/equipment instance has a unique runtime id; snapshots cannot mutate internals; reads/previews emit no signals and have no gameplay side effects.
- Partial/full drops preserve the correct remainder and occupied count. Non-droppable, stale, and already-removed items fail without mutation.
- Every gear item reaches only its authored slot, regardless of class. Replacement preserves both item instances and used capacity, works with a full inventory, and emits only after atomic commit; equipping into an empty slot frees the candidate's inventory slot.
- Preview and `Party.getFightData()` agree for supported stats, weapon data, effective max HP, persistent injuries, knockout modifiers, and belt space. HP clamps down without healing upward.
- Belt reductions cannot silently truncate the persistent loadout. Legacy belt contents are neither duplicated into nor consumed from shared inventory by this iteration.
- Money and accepted/overflow item results remain correct when a full-inventory Shootout ends; overflow cannot disappear without explicit player confirmation.

### Tab and Journal

- Empty, unavailable, no-member, no-selection, missing-icon, malformed-entry, and management-unavailable states are distinct and contain no sample live data.
- Item/category/stack/slot details, current equipment, projected values, signed deltas, and disabled reasons match fake-provider fixtures.
- Equip and confirmed Drop call exactly one command with stable ids/quantity. Cancel, close, stale selection, and failed commands cause no mutation.
- Active updates refresh once without duplicate signal connections; hidden tabs do no periodic work. Member/item selection, focus, and scroll survive refreshes where valid. If an item disappears, the nearest remaining occupied cell is selected without invoking a command.
- All new UI text uses `UI/RichTextLabel Extended`/`RichTextLabel Extended 8px` nodes, including dynamically generated comparison rows and the Shootout result screen; new feature code does not use native `Label`/`Label.new()` for presentation.
- **Hover crash (fixed after the rich-text migration):** the Shootout stats panels must never be shorter than their content. The migration made the hovered panel's content 127px tall where the grid only gives it 125px (the shared 12px label reserves 22px and draws its text 5px down, and the Effects box added another 24px row). A panel that is even a pixel short makes the containers squeeze a row below its minimum and grow it back on the next layout pass, forever; that oscillation overflows the deferred-call queue and hard-crashes the engine ("Object was deleted while awaiting a callback" spam, then a segfault). Damage only mattered because it changes the HP text, which is what re-lays the panel out. Fix: the hovered panel's name/HP labels use a fixed single-line height with a 2px text offset and a string-measured width (`ShootoutUI._setPanelText`), the Effects boxes are horizontal rows of pinned `EFFECTS_BOX_MIN_SIZE` entries so extra effects widen the title row instead of raising it, and the stat/move icons use `EXPAND_IGNORE_SIZE` so their minimum size no longer depends on the rect the grid assigns (the same pattern as the Turn order strip's portraits). `Tests/TestShootoutUI.gd` asserts that the content fits its panel across HP digit-width changes, that the title row stays one line tall, that the HP value never overlaps the actor name, and that several effects do not grow the content.
- Long names, lore, affixes, many stacks, and quantity controls remain usable at 640×360 with visible focus and scrolling. All flows work without hover or drag-and-drop.
- TabBar-down enters the tab, `ui_cancel` exits drop confirmation before backing out to shell chrome, and Journal input never leaks into gameplay.

## Follow-ups after the first iteration

- **Player-selected loot:** replace deterministic take-what-fits with a result-screen choice of what to carry and what to leave. Retain the same capacity/overflow command results.
- **Unequip and drag-and-drop:** intentionally out of scope for now. Unequip requires a free inventory slot and an explicit no-weapon combat rule; drag-and-drop must not bypass command validation or controller parity.
- **Belt loadouts:** design shared-inventory ↔ belt assignment, combat consumption write-back, stack splitting/reservation, and belt-space changes together. The current arrays must not become an unexamined second item source.
- **Equipment abilities/affixes:** equipment-granted Move activation and unsupported affix mechanics need their combat designs before the UI can claim those effects are active.
- **Persistence:** instance-id allocation, inventory/equipment serialization, starter migration, and New Game reset belong to the save-service design.
- **Town-only switching:** remains a supported future policy change through `SceneManager._syncInventoryPolicy()`; it requires no Inventory tab or command-signature rewrite.

