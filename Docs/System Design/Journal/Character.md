# Character tab

The Journal's Character tab is a read-only character sheet for the current party. It presents the full persistent combat stat catalog, current HP and journey condition, class and Rodeo information, and the persistent modifiers that explain the displayed values.

**Status: patch 3 automated verification complete — the read-only character sheet, real Party integration, focus/no-side-effect coverage and the full 39-test suite pass. Only the manual 640×360 visual/controller review remains.** `Globals/Party.gd` already owns the required member state and `Globals/CharacterStatCalculator.gd` supplies both Shootout fight-start projections and the character-sheet read projection. This design avoids creating another mutable character model or changing combat calculations.

Related designs: [Journal overview](Journal.md), [Inventory & Equipment](Inventory%20and%20Equipment.md), [Damage and Stats](../Shootout/Damage%20and%20Stats.md), [Death, Injury and Retreat](../Shootout/Death%20Injury%20and%20Retreat.md), and [Rodeos](../Rodeos.md).

## Approved first-iteration decisions

- Show the **full combat stat catalog**, not only the compact Inventory summary.
- Show **Base** and **Effective** columns for every applicable stat row. Current HP is a separate header value.
- Use a static character icon, name, class, and shared party level. A rendered model is not part of this iteration.
- Show the Rodeo's authored name and full description, plus party level in the identity header. Do not calculate or interpolate exact level-scaled Rodeo numbers in the Journal.
- Keep Character and Inventory member selections independent. Add no cross-tab selection state or **Manage equipment** shortcut yet.
- Keep active Moves and belt contents out of this iteration. Move activation and belt-loadout management require a separate design.
- Keep the entire tab read-only. No equipment, healing, injury, Rodeo, class, level, or loadout commands are exposed.
- Show persistent modifier provenance: journey injuries, knockout debuffs, relevant class contributions, and supported equipped-item effects. Do not claim unsupported affixes are active.

## Information architecture

### Member selection and identity

Use one horizontal icon-button selector in authoritative party order. Each button has a stable `memberKey`, actor-name tooltip, toggle behavior through one `ButtonGroup`, and the same 28×28 portrait treatment as Inventory. Reuse the `Assets/Icons/{ActorName}Icon.png` naming convention and placeholder fallback; extract the existing pure portrait-path/loading logic into a small shared Journal helper rather than giving the two tabs different art rules.

The identity header contains the selected member's static icon, full `actorName`, `characterClass`, party `level`, `hp / maxHp`, and a visible **Downed** condition when applicable. `hp` and `maxHp` come from the effective fight-start projection; HP is clamped by the existing calculator, not by UI code. Missing class data must not be displayed as a real class or as unlimited belt space.

On first valid load select the first member. Preserve `_selectedMemberKey` across refreshes while it remains valid. If it disappears or becomes malformed, select the first remaining valid member. Selecting a member only rerenders the cached read snapshot; it does not notify Inventory, call a domain command, or mark anything as seen. Selection is session/UI state, not save data.

### Full stat catalog

`CharacterStatCalculator` emits ordered rows; the scene renders them in this exact group/order rather than iterating Dictionary keys. Every numeric row has `base` and `effective`; text rows use display strings. A missing/invalid value is `null` and renders as an em dash with a data warning, never as a fabricated zero.

| Group | Row and path | Base source | Effective source | Format |
| --- | --- | --- | --- | --- |
| Vitality | MxHP — `maxHp` | Stored `baseMaxHp` (legacy fallback `maxHp`, then `hp`), without gear/injury | `calculate().maxHp`, including gear MxHP and injury | Integer |
| Core | Six Shootin' — `stats.sixShootin` | `member.stats` | `calculate().stats` | Integer |
| Core | High Tailin' — `stats.highTailin` | `member.stats` | `calculate().stats` | Integer |
| Core | Taffyin' — `stats.taffyin` | `member.stats` | `calculate().stats` | Integer |
| Lead | Revolver — `stats.damage.lead.revolver` | `member.stats` | `calculate().stats` | Integer |
| Lead | Rifle — `stats.damage.lead.rifle` | `member.stats` | `calculate().stats` | Integer |
| Lead | Shotgun — `stats.damage.lead.shotgun` | `member.stats` | `calculate().stats` | Integer |
| Explosive | Gunpowder — `stats.damage.explosive.gunpowder` | `member.stats` | `calculate().stats` | Integer |
| Explosive | Liquid — `stats.damage.explosive.liquid` | `member.stats` | `calculate().stats` | Integer |
| Explosive | Shrapnel — `stats.damage.explosive.shrapnel` | `member.stats` | `calculate().stats` | Integer |
| Offense | Lasso — `stats.damage.lasso` | `member.stats` | `calculate().stats` | Integer |
| Defense | Style — `stats.defense.style` | `member.stats` | `calculate().stats` | Integer |
| Defense | Sand — `stats.defense.sand` | `member.stats` | `calculate().stats` | Integer |
| Resistances | Bleed — `stats.resistances.bleed` | `member.stats` | `calculate().stats` | Whole percentage |
| Resistances | Poison — `stats.resistances.poison` | `member.stats` | `calculate().stats` | Whole percentage |
| Weapon | Family — `weapon.weapon` | Legacy unequipped weapon only when no canonical equipment exists; otherwise none | `calculate().weapon.weapon` | Text, **None** when legitimately empty |
| Weapon | Damage — `weapon.baseDamage` | Same legacy base weapon rule; otherwise zero | `calculate().weapon.baseDamage`, including matching family affix | Integer |
| Loadout | Belt space — `beltSpace` | Class `beltSpace` | `calculate().beltSpace`, including equipped belt bonus | Integer; unknown is unavailable, not “uncapped” |

The calculator's returned `baseMaxHp` already includes equipment MxHP. It is therefore **not** the raw Base cell: Base MxHP comes from the stored member value, while Effective MxHP is the calculated `maxHp`. The gear-adjusted pre-injury value is used only to explain the injury modifier.

Explosive rows show the member/fight-projection stats at the listed paths. Shootout's additional class `explosiveBase` appears as a separate class modifier; it is not silently added to either member stat cell. Rodeo and transient Effect modifications are also excluded from Base/Effective cells because they depend on combat context. This keeps the sheet's **Effective** label equivalent to the persistent `Party.getFightData()` projection, not a promise of every possible in-fight value.

Percentage formatting multiplies the stored fraction by 100 and rounds once for display; it does not alter the source or projection. Existing `-1` unknown-stat sentinels are unavailable values, not player-facing numbers. Weapon family and damage are separate rows; do not present their sum with an offensive stat as final attack damage because hit quality, defense, Rodeos, and Effects are applied later.

### Rodeo, conditions, and modifiers

Resolve a non-empty member `rodeo` key case-insensitively against the same `Shootout.rodeosData` definitions used by combat. A known Rodeo contributes only its stable key, authored `name`, and full `description` to the character projection. Do not instantiate `ShootoutRodeoManager`, register an actor, apply level scaling, fire triggers, or evaluate conditions while building the sheet. A null/empty key displays **No Rodeo**; an unknown key displays the raw key with **Rodeo data unavailable**, without hiding valid stats.

Render persistent modifiers below the Rodeo in deterministic order: journey injury, knockout debuffs in stored order, class contributions, then equipment in canonical slot order. Each modifier contains a kind, stable source id where one exists, display name, ordered effect rows, and optional duration/detail data. The domain projection supplies these rows; the UI does not inspect item Dictionaries or reimplement stat formulas.

- **Journey injury:** present whenever `injuryDamage > 0`, even before it crosses the MxHP-loss threshold. Its effect is `maxHp = calculate().maxHp - calculate().baseMaxHp` (zero or negative). Show **No MxHP lost yet** for zero; otherwise show the signed MxHP penalty. Explain that Town entry resets injuries and camp items reduce them. Keep raw `injuryDamage` and `injuryRate` as internal balance data.
- **Knockout:** show each supported stat penalty and its `shootoutsLeft`. Group rows only when their complete effects and remaining duration match. `downed` remains visible independently in the identity header.
- **Class:** include nonzero `explosiveBase` as a class contribution. Base belt space already has its own stat row; do not duplicate it as a modifier.
- **Equipment:** list only supported, nonzero effects from actual equipped items: core stats, Style/Sand, MxHP, the equipped weapon's matching family damage affix, and belt space. Use `instanceId` as source id and the item's display name/slot as its label. Unsupported affixes remain inspectable in Inventory but never appear here as working modifiers.

When there are no injuries, knockouts, class contributions, or supported gear effects, show **No persistent modifiers**. This is distinct from unavailable/malformed modifier data.

## User experience and scene layout

Use the existing 560×280 Journal panel and `Assets/UI/UI.tres`. Keep the member selector and identity header fixed; only the stat and detail bodies scroll. The HP and Downed fields use fixed minimum widths and never wrap, so the two-line identity block cannot squeeze HP to one pixel or starve the stat/detail scrollers of height. Do not add tabs within Character, collapsible required information, horizontal stat scrolling, or a model viewport.

```text
[Walker] [Other member...]                              Party level 1
[Icon] Walker Langley — Gunslinger                      HP 12 / 12  Downed
┌ Stats ────────────────┬────────┬──────────┐ ┌ Rodeo ────────────────────┐
│ Group / stat          | Base   | Effective│ │ Leaders Duck              │
│ Core / Lead / ...     |  ...   | ...      │ │ Full authored description │
│ (vertical scroll)     |        |          │ ├ Conditions and modifiers ─┤
└───────────────────────┴────────┴──────────┘ │ Injury / knockout / gear  │
                                               │ (vertical scroll)         │
                                               └───────────────────────────┘
```

Create stable scene structure along these lines; exact container margins are implementation details validated at 640×360:

```text
CharacterTab (Control)
├── ContentView (VBoxContainer)
│   ├── MemberScroll / MemberButtons (HBoxContainer)
│   ├── IdentityPanel (PanelContainer)
│   │   └── IdentityLayout (icon, NameText, ClassLevelText, HpText, DownedText)
│   └── BodyColumns (HBoxContainer)
│       ├── StatsPanel / StatsScroll / StatRows (VBoxContainer)
│       └── DetailPanel / DetailScroll / DetailContent (VBoxContainer)
│           ├── RodeoNameText
│           ├── RodeoDescriptionText
│           ├── ConditionRows (VBoxContainer)
│           └── ModifierRows (VBoxContainer)
└── StateView (CenterContainer with StateTabSprite and StateMessageText)
```

Use `UI/RichTextLabel Extended 8px/RichTextLabelExtended8px.tscn` for compact headers, table cells, conditions, modifiers, and state text, including dynamically created rows. Use the larger shared rich-text scene only if the identity/Rodeo name needs it. Do not introduce native `Label`/`Label.new()` presentation. Set `autowrap_mode` on long text and pin numeric column minimum widths so long names wrap in their own cells without displacing Base/Effective values. Group headers repeat inside `StatRows` in provider order; no Dictionary iteration determines presentation.

`getFocusTarget()` returns the selected member button, or the first valid button if no selection exists, and `null` for empty/unavailable states. `MemberScroll`, `StatsScroll`, and `DetailScroll` use keyboard/controller focus and standard Godot scrolling. Wire selected-member right/down focus to `StatsScroll`; `StatsScroll` left returns to the selected member and right reaches `DetailScroll`; `DetailScroll` left returns to `StatsScroll`. Keep normal member-to-member navigation. The shell wires the selected member's up neighbor to the tab bar, and existing `ui_cancel` behavior returns content focus to shell chrome before closing. Add no input actions and no hover-only required content.

`canCloseTab()` remains inherited and `true`; there are no modal subflows. Refresh captures selected member, stat/detail scroll positions, and focused region, rebuilds only valid dynamic rows, then restores those values when their targets still exist. If the focused member disappears, move focus to its replacement only when focus was already inside this tab.

### Empty, unavailable, and malformed states

- Missing provider/methods, unavailable provider, malformed top-level snapshot, or a nonempty member list with no valid entries: hide content and show **Character data unavailable** with the Character tab sprite.
- Valid empty `members`: show **No party members**, not unavailable data and not Walker fixture data.
- Some malformed members: warn with their key/index, skip them, and preserve valid siblings. Never retain stale details for a selected member that failed validation.
- Missing portrait: use the shared placeholder while retaining real identity/stats.
- No Rodeo, unknown Rodeo definition, no injuries, and no persistent modifiers use their distinct inline states; they do not replace the whole sheet.
- Missing class or invalid individual stats: render only affected fields as unavailable and warn. Do not convert missing class belt space `-1` to **Unlimited**, display unknown stat sentinels, or turn invalid numbers into zero.
- A valid member with no equipment shows legitimate empty weapon values and identical unmodified Base/Effective rows, not an error.

## Authoritative read model

### `CharacterStatCalculator.projectCharacter()`

Add a pure read projection beside the existing `calculate()`/`compare()` APIs:

```gdscript
func projectCharacter(member: Dictionary, classData: Dictionary) -> Dictionary
```

It calls `calculate(member, classData)` exactly once and never reads autoloads, mutates the source, generates ids, rolls RNG, or changes combat state. `calculate()` and `getFightData()` retain their current signatures and behavior. The projection returns:

```gdscript
{
    "hp": int,                    # effective.hp
    "maxHp": int,                 # effective.maxHp
    "statRows": [{
        "group": String,
        "path": String,
        "label": String,
        "base": Variant,          # number/String/null
        "effective": Variant,     # number/String/null
        "format": "integer" | "percent" | "text",
    }],
    "modifiers": [{
        "kind": "injury" | "knockout" | "class" | "equipment",
        "sourceId": String,       # instanceId/class/stable condition id; empty if none
        "name": String,
        "slot": String,           # equipment only; otherwise empty
        "effects": [{
            "path": String,
            "label": String,
            "amount": float,
            "format": "integer" | "percent",
        }],
        "shootoutsLeft": int,     # knockout only; otherwise 0
        "detail": String,         # e.g. no MxHP lost yet/recovery hint
    }],
}
```

Use one fixed private stat-row specification for paths, groups, labels, formats, and base/effective lookup. Add a path reader that supports every documented nested path; do not duplicate a long UI-specific chain of Dictionary reads. Modifier descriptions may share supported-effect extraction with `calculate()` if that can be done without changing its calculation order. Otherwise keep extraction in this calculator and cover parity exhaustively; never move modifier interpretation into `CharacterTab.gd`.

For canonical equipment members, Base weapon is empty/zero even if stale legacy weapon data remains. For legacy members without an `equipment` Dictionary, preserve their existing weapon as Base so older test/data shapes do not regress. Base belt space is `classData.beltSpace` when present and valid, otherwise `null`; Effective belt space retains the calculator's `-1` internal unknown value but projects it as `null` for this UI.

### `Party` character provider

Add a provider surface independent of `isInventoryDataAvailable()`:

```gdscript
signal partyChanged(memberKey: String) # Empty key means the whole party changed.

var rodeosData = {}

func configureCharacterData(
    classDefinitions: Dictionary,
    rodeoDefinitions: Dictionary
) -> void
func isCharacterDataAvailable() -> bool
func getCharacterJournalSnapshot() -> Dictionary
```

`Party._ready()` continues to initialize inventory exactly as before, then supplies the already loaded `Shootout.classesData` and `Shootout.rodeosData` to `configureCharacterData()`. The configuration seam also supports headless tests without autoloads. `configureCharacterData()` stores deep copies of both registries and treats them as immutable read data. An empty valid registry makes only dependent class/Rodeo fields unavailable; it does not fabricate data or make an otherwise valid party disappear.

Character availability requires completed character configuration and a usable stat calculator. It does **not** require an item catalog, valid inventory, inventory-management permission, or a Shootout scene. `_ensureStatCalculator()` may initialize the same pure helper used by fight data. Keep `configureInventory()` compatibility for existing tests and callers; the two availability flags must not be coupled.

`getCharacterJournalSnapshot()` returns fresh deep copies in authoritative party order:

```gdscript
{
    "level": int,
    "members": [{
        "key": String,             # existing Party Dictionary key
        "actorName": String,
        "characterClass": String,
        "downed": bool,
        "hp": int,
        "maxHp": int,
        "statRows": Array,          # projectCharacter() rows
        "modifiers": Array,         # projectCharacter() modifiers
        "rodeo": null | {
            "key": String,          # stored member key, including unknown keys
            "available": bool,      # definition lookup succeeded
            "name": String,         # authored name when available
            "description": String,  # authored text when available
        },
    }],
}
```

For each valid member Dictionary, call `_statCalculator.projectCharacter(member, _classDataFor(member))`, merge identity/condition fields, and append the Rodeo projection. `hp`, `maxHp`, rows, and modifiers come only from that projection. Rodeo lookup uses the same case-insensitive key normalization as combat but copies only display metadata. Unknown member keys, missing member Dictionaries, and invalid projections warn and skip; a valid empty party returns an empty `members` Array. Callers cannot mutate `Party`, class data, Rodeo definitions, equipment, or nested stats through the returned snapshot.

No inventory command or Shootout manager is invoked by a snapshot read. The tab must remain useful when inventory data is unavailable and must not become a second consumer of `getInventorySnapshot()` merely to obtain `fightData`.

### Change notifications

`partyChanged` is the Character tab's only live-update subscription. Emit it after a complete committed mutation, never before validation and never during snapshot reads:

- `equipItem()` emits `partyChanged(memberKey)` after the successful atomic swap, alongside the existing inventory/equipment signals. Rejected swaps emit nothing.
- `applyFightResults()` emits `partyChanged("")` once after all HP, injury, downed, and knockout updates finish. Suppress per-member flee notifications inside that batch so one fight result causes one Character refresh.
- `applyFleeCost(actorName)` emits for that member when called as a standalone committed change; use a private/batch path or optional notification flag from `applyFightResults()`.
- `resetInjury()`, `reduceInjury()`, and `vamoose()` emit `partyChanged("")` once when they actually change character state. No-op camp/town calls need not refresh.
- Future level, membership, class, and Rodeo mutations must use Party commands that emit the appropriate member key or empty whole-party key. In particular, the planned quest-driven Walker Rodeo swap must not directly edit `Party.party` if the open Character tab is expected to update immediately.

Existing `inventoryChanged` and `equipmentChanged` behavior remains for Inventory. Money-only or unequipped-inventory changes do not emit `partyChanged` because they cannot change this sheet. Do not add polling to compensate for uninstrumented direct Dictionary writes; route those writes through domain commands instead.

## `CharacterTab.gd` provider and rendering contract

Add the same injection/lifecycle pattern used by Inventory and Quests:

```gdscript
## Provider Node contract: isCharacterDataAvailable(),
## getCharacterJournalSnapshot(), and partyChanged(memberKey: String).
## Null resolves /root/Party.
var characterProvider: Node = null

func refreshTab() -> void
func setTabActive(tabActive: bool) -> void
func getFocusTarget() -> Control
```

Maintain only `_snapshot`, `_membersByKey`, `_selectedMemberKey`, `_memberButtons`, `_connectedProvider`, and pending focus/scroll restoration state. `_snapshot` is an immutable UI read result, not authoritative character state or save data. `_resolveCharacterProvider()` returns the injection or `/root/Party` only while inside the tree. `_providerCanRead()` checks both methods. Connect `partyChanged` once while active, disconnect on deactivation and `_exit_tree()`, and refresh on its callback only while active.

`refreshTab()` performs this sequence:

1. Capture selection, scroll, and focused-region state; clear stale normalized indexes without emitting domain signals.
2. Resolve/connect the provider according to active state. Show unavailable and return for missing providers, unavailable data, or invalid top-level snapshots.
3. Deep-copy and defensively normalize `level` and `members`. Require nonempty stable keys, valid identity/projection fields, ordered stat-row arrays, modifier arrays, and valid Rodeo shape. Skip only invalid members; distinguish valid empty input from wholly invalid input.
4. Reconcile `_selectedMemberKey`, rebuild member buttons once per refresh, and render identity, fixed-order stats, Rodeo, and modifiers for that member.
5. Show content or the valid empty state, then restore scroll/focus. Do not call `getFightData()`, `calculate()`, equipment commands, or another tab from the scene.

Member presses bind the stable key, update only selection/rendered detail, and preserve the current provider snapshot. Formatting helpers handle integer, signed integer, percentage, text/None, and null/em dash values. Dynamic rows use shared rich-text scenes and fixed provider labels; user/authored strings are inserted as text, not BBCode. No row press triggers an action because the sheet is read-only.

## Files and responsibilities

**Create**

- `UI/Journal/PartyMemberArt.gd` — pure portrait path/fallback loading shared by Character and Inventory; no autoload or mutable state.
- `Tests/TestCharacterSheet.gd` — headless calculator projection, Party provider, snapshot-isolation, and notification tests.
- `Tests/TestCharacterTab.gd` and `.tscn` — scene-run fake-provider rendering, selection, state, focus, and lifecycle tests. `Tests/RunAll.gd` discovers them automatically.

**Modify**

- `Globals/CharacterStatCalculator.gd` — add the fixed full-catalog `projectCharacter()` read model; preserve existing combat calculation behavior.
- `Globals/Party.gd` — configure class/Rodeo read data, expose character snapshots, and emit `partyChanged` after committed character mutations.
- `UI/Journal/Tabs/CharacterTab.tscn` and `.gd` — replace the placeholder with the provider-driven read-only scene.
- `UI/Journal/Tabs/InventoryTab.gd` — delegate portrait lookup to `PartyMemberArt.gd` without changing selection, dimensions, or fallback behavior.
- `Tests/TestJournal.gd` — cover real Character shell focus handoff, activation refresh, and read-only/no-side-effect integration.
- `Docs/System Design/Journal/Journal.md` and this document — mark implementation status only after the final gate.

Do not add an autoload, input action, SceneManager policy, save format, or Journal cross-tab navigation API. Existing Journal lazy instantiation, pause/modal behavior, and availability policy remain unchanged.

## Testing and acceptance

### Calculator projection and Party provider

`Tests/TestCharacterSheet.gd` covers:

- Exactly 18 rows in the documented group/order, with stable paths, labels, formats, and Base/Effective values.
- Raw Base MxHP versus gear-adjusted pre-injury MxHP versus Effective MxHP; current HP clamping; injuries below, at, and above the MxHP-loss threshold.
- Core, Lead, Explosive, Lasso, Style/Sand, resistance, weapon, and belt values against the same member/class fixtures passed to `calculate()`/`getFightData()`.
- Equipment and knockout deltas, matching-only weapon-family affixes, class `explosiveBase`, belt bonuses, unsupported-affix exclusion, deterministic modifier order, source ids, and knockout durations.
- Canonical equipment ignoring stale legacy Base weapon data, legacy no-equipment Base weapon preservation, valid empty equipment, unknown class belt space, and unknown `-1` stats projecting as `null`.
- Percentage formatting inputs and null/text/empty weapon values; no final attack-damage fabrication.
- Source member, stats, equipment, class data, and Rodeo data remain deeply unchanged after projection and snapshot reads. Two snapshots have no shared mutable nested Dictionaries/Arrays.
- Character availability and snapshots work without inventory configuration; valid empty parties differ from unavailable data; members retain authoritative order.
- Known mixed-case Rodeo lookup, no Rodeo, and unknown Rodeo states copy the correct metadata without running scaling or triggers.
- Successful equip, fight results, standalone flee, injury reset/reduction, and Vamoose emit exactly the documented notifications. Rejected equip and no-op mutations emit none; batched fight/flee changes emit once.

Run existing EquipmentStats, Inventory, and Injury suites to prove the refactor did not alter combat stats, equipment commands, or persistent fight rules.

### Character tab

`Tests/TestCharacterTab.gd` uses a fake provider with call counters and no mutation methods:

- Missing/unavailable/malformed providers and snapshots, valid empty party, partially invalid members, and wholly invalid nonempty input produce the specified states without fixtures leaking into production.
- Identity, HP/downed state, all row groups, Base/Effective numbers, percentages, null em dashes, text/None values, Rodeo variants, every modifier kind, and empty-modifier text match fake data.
- First-member default, stable-key preservation, removal fallback, and member switching do not request another snapshot or call any command. Character has no Inventory selection dependency.
- Refresh restores valid selection, stat/detail scroll, and focused region; stale selected details are cleared. Missing art uses the placeholder.
- Active `partyChanged` refreshes once; repeated activation does not duplicate connections; hidden tabs do not refresh or poll; `_exit_tree()` disconnects cleanly.
- TabBar-down enters the selected member, navigation reaches both ScrollContainers, and `ui_cancel` backs out through the existing shell contract. There is no close guard or secondary panel.
- Long names, Rodeo text, modifier lists, and all 18 rows remain readable at the real Journal content size with no horizontal stat scroll, clipped required values, native `Label` presentation, or layout oscillation.

### Journal integration and manual review

Extend `Tests/TestJournal.gd` so real Character activation uses the production Party provider, shell focus handoff targets its selected member, reactivation refreshes once, and repeated open/close plus selection/scrolling leaves authoritative Party state unchanged. Prove an equipment/fight/injury mutation followed by activation renders the new projection rather than stale cached state.

After automated gates, perform a real 640×360 mouse/keyboard/controller pass with multiple members, long text, injuries, knockouts, equipment modifiers, missing art, empty party/unavailable fixtures, repeated Journal opens, tab switching, and scene changes. Verify readable integer scaling, visible focus, independent scrolling, no input leakage, and no live Shootout values being misrepresented as persistent state.

## Implementation plan

Implement in three reviewable patches. Keep `CharacterTab` unavailable until its scene can render only real provider data; test fixtures belong in `Tests`, never in production refresh/default paths.

### Patch 1 — Pure character projection and notifications

**Status: implemented.** `CharacterStatCalculator.projectCharacter()` projects the fixed 18-row Base/Effective catalog and persistent modifiers; `Party.configureCharacterData()`, `isCharacterDataAvailable()`, `getCharacterJournalSnapshot()` and `partyChanged` are live. `Tests/TestCharacterSheet.gd` passes along with EquipmentStats, Inventory/InventoryTab, Injury and Journal; `CharacterTab` intentionally remains in its unavailable state.

1. Add `CharacterStatCalculator.projectCharacter()` with the fixed 18-row specification, Base/Effective path lookup, legacy weapon handling, null projection for unavailable values, and deterministic persistent-modifier extraction.
2. Reuse supported-equipment-effect extraction inside the calculator where practical, while proving `calculate()` output and ordering remain unchanged. Do not add Rodeo scaling or final damage calculations.
3. Add Party's character configuration/availability fields, class/Rodeo initialization, case-insensitive display lookup, deep-copied `getCharacterJournalSnapshot()`, and valid-empty behavior. Keep inventory availability independent.
4. Add `partyChanged` and instrument successful equip, fight result, flee, injury, and Vamoose paths with batch/no-op semantics. Do not emit from reads or rejected commands.
5. Create `Tests/TestCharacterSheet.gd` for every projection/provider/notification case above. Keep `CharacterTab` in its intentional unavailable state in this patch.

**Gate:** run the new CharacterSheet suite, then EquipmentStats, Inventory, and Injury separately. All must pass before UI work; no existing fight-data expectation may change.

### Patch 2 — Character scene and fake-provider interaction tests

**Status: implemented.** `UI/Journal/PartyMemberArt.gd` centralizes portrait lookup, Inventory delegates to it, and `UI/Journal/Tabs/CharacterTab.tscn`/`.gd` render the full read-only sheet with ordered Base/Effective rows, Rodeo, conditions/modifiers, inline empty states, stable selection and focus/scroll restoration. `Tests/TestCharacterTab.gd`/`.tscn` passes, as do the InventoryTab and real-shell Journal gates; `CharacterTab` already resolves `/root/Party` by default, so patch 3 is verification/status work rather than activation.

1. Extract `PartyMemberArt.gd`, delegate Inventory's existing portrait lookup to it, and run InventoryTab tests before building on it.
2. Build the stable `CharacterTab.tscn` hierarchy with fixed selector/identity regions, independent stat/detail scrolling, shared rich-text controls, and the standard Character empty/unavailable view.
3. Implement provider resolution/injection, active-only `partyChanged` connections, defensive snapshot normalization, stable member selection, ordered stat/modifier rendering, formatting, and all inline/whole-tab states.
4. Implement `getFocusTarget()`, member/stat/detail focus neighbors, scroll/focus capture and restoration, deactivation cleanup, and inherited close behavior. Add no commands, cross-tab calls, input actions, timers, or polling.
5. Create `Tests/TestCharacterTab.gd`/`.tscn` with long and malformed fake snapshots. Verify the complete rendering/state/focus/lifecycle contract at the real content size.

**Gate:** run CharacterTab, InventoryTab, and Journal separately, then inspect the fake-provider scene at 640×360. Fix clipping, unreadable numeric columns, focus traps, and container oscillation before production integration.

### Patch 3 — Production integration and full verification

**Status: automated gates complete; manual visual/controller review pending.** `Tests/TestJournal.gd` now covers real Character provider resolution, shell focus handoff, live and activation-time refresh after a Party command, Character/Inventory selection independence, provider connection counting, and inspection/no-side-effect cycles. The focused Character/Inventory/Journal gates and the complete `RunAll.gd` suite pass (**39/39**). The real 640×360 mouse/keyboard/controller review with long text, injuries/knockouts and equipment modifiers remains the only unfinished acceptance step.

1. Confirm the already-active real Party provider through the default `/root/Party` resolution; no Journal registry or SceneManager changes should be necessary.
2. Extend `Tests/TestJournal.gd` for real Character focus handoff, lazy refresh, no-side-effect reads, and fresh data after domain mutations. Confirm Character and Inventory selections remain independent.
3. Run focused CharacterSheet/CharacterTab/Journal checks, then the complete `Tests/RunAll.gd` suite. Do not treat a passing fake-provider test as proof of production class/Rodeo initialization.
4. Complete the manual multi-member visual/controller review, including equipment/injury/knockout changes across tab activation and scene changes.
5. Update this document and the Journal overview with implemented status, actual test results, and any deliberately deferred visual issues. Do not mark manual review complete from headless tests alone.

**Gate commands:**

```sh
godot --headless --script res://Tests/RunAll.gd -- Character
godot --headless --script res://Tests/RunAll.gd -- EquipmentStats
godot --headless --script res://Tests/RunAll.gd -- Inventory
godot --headless --script res://Tests/RunAll.gd -- Injury
godot --headless --script res://Tests/RunAll.gd -- Journal
godot --headless --script res://Tests/RunAll.gd
```

The Character filter runs both new suites; the other focused filters guard shared stat, equipment, persistent-condition, portrait, and shell behavior. The final unfiltered run is required because Party and calculator changes affect Shootout setup beyond the Journal.

## Follow-ups after the first iteration

- **Rendered presentation:** consider a model only after the full text/stat layout has spare space at integer scale; the static icon remains the fallback.
- **Exact Rodeo values:** add a shared pure level-scaling/display projection used by both combat and Journal. Do not duplicate `ShootoutRodeoManager.applyLevelScaling()` in UI.
- **Moves and belt loadouts:** design read-only inspection, activation limits, shared-inventory assignment, consumption write-back, and controller flows together.
- **Cross-tab shortcuts:** if desired, add Journal-level selected-member navigation or **Manage equipment** requests without letting tabs find each other through node paths.
- **Live Shootout access:** if Journal availability expands into Shootouts, decide explicitly whether Character remains the persistent journey sheet or receives a separate live-combat provider. Never accidentally mix persistent Party HP with live actor HP/effects.
- **Persistence:** save/load character state belongs to Party and the future save service. The tab stores no authoritative member data or persistent per-member UI selection.

There are no blocking open design decisions for the first iteration. The approved scope above distinguishes implementation follow-ups from unresolved behavior.
