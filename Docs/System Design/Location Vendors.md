# Location vendors

Location vendors are enterable rooms in resupply Locations where the party prepares for its next trail journey: buy supplies and rolled gear, sell trail gear, store equipment, and read local enemy intelligence.

This is the high-level feature design for “Location vendors” in `Docs/Features.md`. **Status: patch-1 data foundations, patch-2 runtime domain, patch-3 rooms/navigation/modal shell, patch-4 shop/Bank views, patch-5 map discovery and patch-6 newspaper reports are implemented, and patch-7's persistence audit, content gate and documentation pass are implemented (shared Zone catalog, deterministic item generation, pricing/data schemas, explicit trail departure, deterministic vendor stock, atomic purchases/sales, shared Bank and save snapshots, proximity interaction, vendor rooms with safe return navigation, the persistent vendor menu modal with Buy/Sell/Bank/newspaper views, the Lazysprings interiors with the explicit trail-departure interaction, map discovery: buying and using a map reveals hidden Overworld Locations atomically, and Zone newspapers projected from the shared encounter pools). What remains open is content blocked on art/world data (vendor NPC art, further Zone encounters, reachable secret caches) and the manual 640×360 acceptance pass.** The companion [code-level design and implementation plan](Location%20Vendors%20Implementation.md) defines the technical contracts.

## Goals

- Make towns and other resupply Locations useful destinations between trail journeys.
- Turn money earned on the trail into meaningful preparation choices without bypassing the shared inventory’s capacity pressure.
- Give randomly rolled weapons and equipment a reliable acquisition and selling outlet.
- Make enterable buildings and interactive vendor characters easy to identify in the world.
- Provide free, practical information that helps the player prepare for the current Zone’s Shootouts.
- Preserve rolled item identity, stats, and ownership through every purchase, sale, deposit, and withdrawal.

## First-iteration decisions

The feature list leaves several rules open. These are the proposed first-iteration rules, not claims about existing behavior:

- Vendor services are housed in separate rooms entered from their parent Location. A vendor menu opens only by interacting with the character inside, not automatically when entering the room.
- General-store supplies have a fixed catalog and remain available in unlimited quantities, subject to money and inventory space. Authored map offers are one per reveal and disappear once their contents are known.
- Gun and equipment stores each offer a finite selection of unique, randomly rolled items. A purchased offer leaves the selection.
- Random stock belongs to a specific vendor and persists across menu closure, room exit, and Location re-entry. **All** gun and equipment vendors roll new stock only when the party explicitly departs for the trail. Walking into the Overworld for a quest transition, retreat, or other non-departure reason does not reroll it.
- Selling is limited to unequipped weapons at gun stores and unequipped equipment at equipment stores. Sales require confirmation, are final, and have no buyback in this iteration. Sold items do not enter the random shop stock.
- The Bank is one shared stash available at every Bank. It stores weapons and equipment from the shared inventory, including their rolled data. It does not store money, supplies, maps, resources, or equipped items.
- Bank transfers and newspaper reports have no resource cost. Withdrawing still requires enough carried-inventory space.
- Maps are carried items used from the Journal outside Shootouts. Using one permanently reveals its authored secret Locations and secret-item markers; it does not teleport the player or directly grant loot.
- “Current Zone” at a newspaper office means the Zone containing that office’s parent Location, not a potentially stale last-known Overworld chunk.

Stock counts, prices, sell-value ratios, map contents, vendor placement, and report text are content/balance work. The architecture must not hardcode them in UI scenes.

## Player loop

1. Return from the trail with money, rolled gear, and a constrained shared inventory.
2. Explore a resupply Location and identify enterable buildings by their floating icons.
3. Enter a vendor building, approach its character, and interact to open the appropriate menu.
4. Prepare for the next journey:
   - buy consumables, one-time boosts, and maps at the general store;
   - buy or sell weapons at the gun store;
   - buy or sell other equipment at the equipment store;
   - move gear between carried inventory and the shared Bank stash;
   - read the local newspaper’s enemy-party and Shootout guidance.
5. Close the menu and leave the room, returning just outside the same building.
6. Depart for the trail through the Location’s explicit departure interaction. At that point the next journey begins and random vendor selections reset.

## Shared experience

### Buildings and vendor characters

- Enterable buildings have a floating door icon. The vendor character has a distinct floating interaction icon. Icons remain legible against the room art and do not obscure the player or interaction prompt.
- Doors and characters use the existing interaction action. Entering requires deliberate interaction near a door; merely brushing past a building does not change scenes.
- The interaction prompt names the available action, such as **Enter General Store** or **Talk to Gunsmith**.
- If interaction areas overlap, only the closest eligible target activates. One press causes at most one transition or menu opening.
- Vendor rooms contain a visible exit. Returning places the player at a safe position outside the original door and must not immediately retrigger entry.
- Vendor menus pause gameplay and block movement, world interactions, and Journal opening. Closing one restores gameplay, focus, and the previous pause state. Scene transitions close the menu safely.

### Menu presentation

- Use the existing pixel-art UI language at the 640×360 reference viewport, with mouse and keyboard/controller operation.
- Always show the vendor name, party money, and carried inventory usage (`used / capacity`). Buy, sell, and Bank views show enough item detail to make a decision without memorizing stats.
- Lists retain a stable order after refresh. Selection returns to a sensible neighboring entry when the selected offer or item leaves the list.
- Every disabled action explains why: insufficient money, insufficient space, wrong item category, already revealed map, unavailable data, or no selection.
- Stackable purchases support an explicit quantity and show the total before confirmation. Rolled gear is bought one at a time.
- Opening, browsing, selecting, and cancelling do not mutate items, money, stock, discovery, or RNG state. The sole exception is lazy creation of a vendor’s not-yet-created stock for the current journey; repeated views never reroll it.
- Empty catalogs, sold-out selections, empty inventories, an empty Bank, and unavailable reports are intentional readable states rather than blank panels.

### Economy and inventory

- All purchases use the party’s shared money pouch. Money cannot become negative.
- Purchased items enter the same capacity-limited inventory as loot and supplies. A purchase is all-or-nothing: if the full quantity does not fit, no item, money, or stock changes. There is no silent overflow, automatic dropping, or direct placement into equipment or the Bank.
- Equipped items do not appear for sale or Bank deposit because they are not in the shared carried inventory.
- Selling removes only the confirmed carried quantity and credits the quoted amount once. An item’s rolled affixes and stats determine one consistent valuation; the UI does not invent prices.
- Ordinary gear is sellable by default. Content may mark quest-bound or otherwise protected gear as unsellable; such items remain inspectable and display the reason.
- Bank deposits free carried space immediately. Withdrawals are all-or-nothing and preserve the item’s stable instance identity and complete rolled data.
- There is no separate Bank capacity limit in this iteration. The Bank is accessible only at Bank characters, so it does not remove trail-time carrying decisions.

## Vendor types

### General store

The general store is the reliable resupply point for the next trip.

- Sell authored consumables such as explosives and potions, one-time boosts such as magazines and cigar packs, and authored maps.
- Use each item’s real gameplay definition and description. A boost or consumable that has no implemented effect cannot be presented as functional shop stock.
- Keep ordinary supplies available rather than randomly rotating them; random gear stores provide the vendor selection variability.
- Sell maps only while at least one of their targets remains unrevealed and the party is not already carrying that map. A map’s offer states whether it reveals Locations, secret items, or both.
- Do not add a general-store selling tab in this iteration. Weapon and equipment sales belong to their specialist stores.

### Gun store

- Present a finite selection of randomly rolled weapons using the same generator, party-progression rarity, Zone rules, names, sprites, and affixes as trail loot.
- Show weapon family, base damage, rarity, affixes, and purchase price.
- Allow the player to sell unequipped weapons found or acquired on the trail. Show the quoted sale price before the final confirmation.
- Remove purchased stock immediately. Do not replenish it when the menu or room closes.
- Roll a fresh finite selection for the next trail cycle on explicit trail departure.

### Equipment store

- Follow the gun-store rules for finite rolled stock, purchases, sales, and departure resets, but restrict both stock and sales to non-weapon equipment.
- Show equipment slot, rarity, affixes, and other gameplay stats. Use the shared item-stat presentation so shop and Journal values agree.
- Zone-themed equipment uses the store’s authored Zone context; it does not depend on where the player happened to enter the Overworld most recently.

### Bank

- Present carried gear and stored gear as two clearly labelled collections.
- Support one-action deposit and withdrawal for individual unstackable gear items. Selection and inspection never move anything.
- Share the same stash across all Banks and preserve acquisition order within each collection for predictable presentation.
- Allow free deposits at any time the Bank menu is available. Reject a withdrawal that does not fit without changing either collection.
- Keep money and equipped gear outside the stash. Do not add interest, fees, investment, loans, or item durability in this iteration.

### Newspaper office

- Provide a free, read-only report for the office’s parent Location Zone.
- List the regular enemy parties that can appear in that Zone’s encounter pool: party/encounter name, expected composition, enemy classes or families, relevant weapon or damage types, and notable mechanics where authored.
- Provide useful Shootout tips connected to those parties, plus general advice where appropriate. Tips describe real mechanics; they must not promise unsupported immunities, drops, or behaviors.
- Do not report visual-only Overworld parties as Shootout encounters, reveal exact future random rolls, add quest markers, or expose quest-only bosses unless their content explicitly includes a newspaper report.
- If a Zone has no authored report or encounter pool, say that no local intelligence is available. Never substitute another Zone’s report.

## Maps and secret reveals

Maps are a bridge between shopping and the Journal Overworld map, not a second map screen.

- Each map definition has a stable identity and an authored list of secret target ids. Targets may be hidden Locations or hidden secret-item points.
- The player buys the map into carried inventory, selects it in the Journal Inventory tab, and chooses **Use**. The Journal must be in a context where item use is allowed; Shootouts and transitions are not valid contexts.
- A successful use consumes one map and permanently reveals every target in its definition. Reveal state survives room and scene changes and belongs in future save data.
- Revealed Locations and secret-item points appear as distinct selectable markers on the existing Journal Overworld map. They use the same projection and keyboard/controller POI navigation as other markers.
- Secret markers provide location information only. Reaching and obtaining a secret item remains world/gameplay content; buying or using a map never grants the item.
- If every target is already revealed, using or buying another copy is blocked without consuming it. Invalid or missing target data fails closed without consuming the map.
- Ordinary Locations that are currently always visible remain visible. Only targets explicitly authored as hidden participate in map reveals; this feature does not add general fog of war.

## State and persistence boundaries

Runtime state has the following ownership at the design level:

- **Party:** money, carried inventory, equipped items, and inventory capacity.
- **Vendor state:** each random vendor’s current-trail-cycle offers and its departure-cycle identity.
- **Bank state:** the single shared gear stash.
- **Discovery state:** revealed secret Location and secret-item ids.
- **Location/navigation state:** the current vendor room and enough return information to restore its parent Location and door spawn.
- **Encounter and Zone data:** the authoritative party compositions and Zone identity used by newspaper reports.

All runtime collections survive ordinary scene changes. The future save service must serialize random stock with its seed/cycle and complete rolled items, the Bank stash, discovery ids, and the trail-departure counter. Loading a save must not reroll stock or duplicate purchased items. New Game must clear all of them. Save serialization itself remains part of the unimplemented save system, but these features must expose snapshots suitable for it rather than hide state in UI nodes.

## Content and assets

The first playable content pass needs:

- At least one resupply Location with all five vendor types, or a documented smaller rollout in which absent vendor buildings are simply not placed.
- Authored interiors, exterior door placements, safe entry/return points, vendor actors, and collision/navigation.
- Floating door and vendor-interaction icons, vendor/menu icons, secret-Location and secret-item map icons, and normal focus/disabled/confirmation states.
- Functional general-store definitions for explosives, potions, magazines/cigar packs, and maps. Placeholder purchases with no effect are not acceptable as completed content.
- Stock counts and price/value data for ordinary supplies and every rollable weapon/equipment base.
- Hidden Location/secret-item target data and the corresponding reachable world content.
- Zone encounter pools and accurate newspaper editorial/tip text.
- Music and sound hooks consistent with the existing shop music support.

## Non-goals

- Vendor schedules, walking shopkeepers, branching vendor dialogue, reputation, haggling, dynamic supply/demand, or per-town Bank stashes.
- Buying directly into an equipment slot, direct equipped-item sales/deposits, buyback, auctions, crafting, repairs, or item durability.
- Selling consumables/resources, banking money, Bank interest, or Bank capacity pressure.
- General Overworld fog of war, fast travel, map teleportation, or automatic secret-loot grants.
- Exact tracking of live enemy parties or visual-only Overworld spawns through newspapers.
- A full quest/journey-system rewrite. Only an authoritative explicit trail-departure signal is required by this feature.
- Save-management UI implementation, though runtime state must be save-ready.

## Acceptance criteria

1. Every placed vendor building has a floating icon, deliberate entry interaction, separate room, interactive vendor character, and safe return to the same exterior door.
2. The general store sells working supplies, boosts, and maps for party money; insufficient funds or space never causes a partial purchase.
3. Gun and equipment stores show deterministic rolled selections appropriate to vendor type and Zone. Purchases remove only the bought offer.
4. Random selections are identical after closing/reopening, leaving/re-entering, and ordinary scene transitions, and change only after explicit trail departure.
5. Weapon/equipment sales accept only the correct unequipped category, preserve all other items, require confirmation, and credit exactly one quoted price.
6. Every Bank shares one gear stash. Deposit/withdrawal preserves complete rolled data and instance ids; a full inventory blocks withdrawal atomically.
7. Using a valid map consumes exactly one copy, reveals its authored markers permanently, and leaves already visible ordinary Locations unchanged. Duplicate/invalid reveals do not consume it.
8. The newspaper shows accurate enemy-party information and tips for its parent Location Zone, never a fallback Zone, at no cost.
9. All menus have usable empty/error states, stable focus, mouse and keyboard/controller navigation, readable 640×360 layouts, and no gameplay input leakage.
10. Repeated commands, double-clicks, held interaction input, and scene transitions cannot duplicate items/money, reroll stock, or leave pause/music locked.

## Dependencies and open content work

- The shared Zone catalog proposed in [Dynamic Overworld spawns](Overworld%20Spawns.md) is now the sole source of Zone identity (`Data/Overworld/ZoneData.gd` + `OverworldZoneCatalog`); vendor code consumes canonical ids rather than copying music bands.
- Region encounter pools are partially authored: the shared pool loader and the real `canyon` pool (`CanyonRats`, `CanyonRatNest`) exist, so the newspaper reports the canyon from production data. Every other Zone still has no pool/copy and the newspaper shows its intentional unavailable state rather than another Zone's news.
- Map reveals extend [Overworld Map](Journal/Overworld%20Map.md); item use extends [Inventory & Equipment](Journal/Inventory%20and%20Equipment.md). Neither creates a vendor-specific duplicate inventory or map state.
- Prices, sale ratio, stock counts, initial town/vendor names, room art, secret content and report wording are authored for Lazysprings/canyon as a first pass. Exact economy numbers stay content decisions; the *mechanics* are no longer placeholders — every shipped offer resolves a working effect, and the remaining content blockers (vendor art, other-Zone encounters, reachable secret caches) are recorded in [Location vendors — implementation](Location%20Vendors%20Implementation.md) rather than papered over.
