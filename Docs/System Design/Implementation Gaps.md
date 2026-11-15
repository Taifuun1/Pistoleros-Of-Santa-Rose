# Implementation gap register

This register compares the implemented design documents with the current code and authored content as of 2026-11-15. It deliberately verifies code rather than repeating older “current state” paragraphs that some design documents have not updated. It records missing implementation and content, not every optional polish idea.

Use [Content and balance catalog](Content%20and%20Balance%20Catalog.md) for authoring locations and [System coherence](System%20Coherence.md) for the integration plan.

## Priority meanings

- **P0 — playable-loop blocker:** a system cannot complete its intended real-game flow, or disconnected ownership can duplicate/lose progress.
- **P1 — required mechanic/coherence:** a documented first-iteration rule or shared contract is absent or contradictory.
- **P2 — content and coverage:** the machinery exists but production content, authored variety, validation, or acceptance is missing.
- **Deferred:** explicitly outside the current iteration; listed so it is not mistaken for a completed feature.

## 1. P0 playable-loop blockers

| Area | Implemented now | Missing or disconnected work |
|---|---|---|
| Encounter launch | `Shootout.pendingEncounter` is consumed by the Shootout scene; metadata, teams, win conditions and the debug fallback work. | There is no production caller that selects an encounter, sets `pendingEncounter`, launches `SceneManager` `"shootout"`, or supplies origin/quest context. Zone pools are read by newspapers, not gameplay. Directly entering a Shootout silently uses RatAmbush. |
| Encounter return | The result screen applies Party results once and emits `shootoutEnded(winningSide, results)` after acknowledgment. | No production listener receives that signal and returns to the Overworld, Location, or quest scene. A real fight therefore has no completed launch → fight → return loop. Return context must survive loading failure and be consumed once. |
| Event outcomes | Distance-based event selection, popup text/icons/choices and popup music exist. | `PlayerOverworldActor.process_event_result()` and `OverworldActor.process_event_result()` are `pass`. Every authored result string currently closes the popup without a gameplay effect. Outcome types, validation, encounter launch, rewards, injury and quest effects are unimplemented. |
| Vamoose and retreat routing | `Party.vamoose()` halves money, marks members downed, adds debuffs, and returns `"town"` or `"quest_checkpoint"`. Flee and non-wipe defeat outcomes are distinguished. | No caller invokes `vamoose()` or routes any outcome. Last-town and quest-checkpoint state does not exist. Flee/defeat also lack a return destination. |
| Town/camp recovery | `Party.resetInjury()` and `reduceInjury(amount)` exist. | Neither is called by production town entry, rest, or an item effect. Recovery cannot occur through gameplay. |
| Shared carried items → belts | Party owns bought/looted stackables and equipment; combat consumes names copied from each actor's `items` belt array. | There is no shared-inventory belt assignment/reservation or post-combat stack write-back. Bought Paregoric does not become a usable belt item through this system, while pre-authored belt items are effectively a second item source. This must be fixed before the consumable economy is meaningful. |
| Save and New Game | Vendors and Discovery expose validated versioned snapshots/reset methods; MainMenu has New Game and a disabled Continue. | There is no save service or disk persistence, Party/Quests/Locations/Overworld export-import, coordinated restore, or full New Game reset. Session state includes Party, quests, cutscene flags, map reveals, stock/Bank, player position, PokerMoney, and minigame points/materials. |
| Scene ownership under SceneManager | SceneManager stores the active scene under `CurrentScene` and exposes `get_current_scene()`. | Legacy event/spawn/Location/minigame code still calls `get_tree().current_scene`, which remains the SceneManager root in this architecture. Event player lookup and legacy spawn parenting are therefore not reliable production integration points; migrate to explicit scene references or `SceneManager.get_current_scene()`. |

## 2. P1 missing or contradictory mechanics

### Combat and loadouts

| Gap | Current evidence and required completion |
|---|---|
| Multi-target acts resolve one actor | `positions.type: "multi"` exists and Doctor's Kit says it heals every living member, but `Shootout.selectActor()` stores one target and `resolveWithFocus()` calls the resolver once. Implement target-set expansion, per-position taunt redirection, UI confirmation/animation/focus, death handling, and AI scoring. |
| Effect-driven stat modifiers are reserved | `ShootoutEffectManager.getStatModifier()` currently returns the base value and no effect type modifies stats. Taunt redirects but does not grant its designed defensive buffs. Implement data-driven stat effects and route initiative, damage, UI and other reads through the shared `Shootout.getModifiedStat()` seam instead of direct Rodeo-only reads. |
| Jammed has no authored effect payload | `resolveSpecialChamber()` displays “Jammed!” and advances; it does not apply the buff/debuff described by the Cylinder requirements. Define whether weapon, class, or global data owns that effect and implement validation/resolution. Reload currently only spends the action, as designed. |
| Miss/on-hit semantics need enforcement | `resolveMove()` applies an attack ability's effect list after quality calculation even when Miss multiplies damage to zero. The latest Damage/Stats answer says a Miss applies nothing. Gate on-hit effects by the chosen rule and test attack abilities before authoring bleed/poison Moves. |
| Class abilities are not executable class grants | Class files contain descriptive strings such as “Attack and bleed affliction”; Party/actor `moves` contains only directly authored names. Replace descriptions with canonical Move ids or a validated grant projection, then implement out-of-combat activation within the four-move cap. |
| Equipment abilities are absent | Equipment has stats/affixes but no data contract or fight-loadout path for granted Moves. Define item-granted Move ids, activation/preview, replacement behavior, and combat validation together. |
| Unsupported affixes roll and sell without mechanics | `CharacterStatCalculator` applies only Six Shootin', High Tailin', Taffyin', Style, Sand, MxHP, the equipped weapon family's damage, and top-level belt space. Other generated stats—including explosive/lasso lines, marked/cylinder bonuses, MxEN, initiative/turn-order aliases, effect resistance/duration, piercing/reduction/taunt recovery, silence immunity, loot bonuses, and bleed/poison affliction—remain display text. Either implement each mechanic and preview or exclude it from generation/pricing until supported. |
| Zone loot does not receive encounter Zone | Vendor stock passes `zoneId` into generation; Shootout loot entries create only `{itemType, rarity}`. Since Zone equipment has `dropsAnywhere: false`, regular Shootout loot cannot roll the current Zone's equipment. Propagate encounter/pool Zone and add tests. |
| Weapon identity has little combat differentiation | `WeaponData` bases provide id/name/sprites/value, but base damage rolls from family affix ranges; Magazines/ranges are family-wide. If individual weapons are meant to differ mechanically, author per-base combat stats rather than only economic values. |
| Dust-up/Showdown AI difficulty is undifferentiated | Both use `PICK_FROM_TOP = 2` and shared scoring. The design calls for easier/dumber Dust-ups and lower stats; implement encounter-level AI selection/weights and tune compositions. |
| Boss support has no boss content | AI script loading and non-rout win conditions exist, but `Data/Shootout/AI` and unique boss actors/Rodeos/encounters/loot are absent. The `hp_below` open design note also requests per-boss thresholds while the implementation supports side totals only. |
| Walker/story Rodeo changes are unwired | Natural Gunslinger and other Rodeo files exist, but quest completion never swaps `Party.party["Walker Langley"].rodeo` or any other story Rodeo. |
| Player basic-attack rule needs resolution | Enemy AI gathers a basic Attack, while the player Acts row exposes Moves/items/reposition/Flee and the UI doc says “no basic attacks.” Confirm whether every player attack must be a Move; align Combat, UI, AI, and class content before balancing. |

### Progression, economy, and persistence

| Gap | Current evidence and required completion |
|---|---|
| Quest progression does not drive progression | `Quests.currentMainQuestLevel` remains level 1/common and `Party.level` remains 1; completion only updates objective state. Implement one authoritative mapping from main-quest completion to Party level, item rarity, Rodeo scaling, Stagecoach speed, and any story unlocks. |
| Loot bands are unused | Rats declares `band: "early"`, but encounter selection does not filter tables/pools by quest progression and generation is band-agnostic. Define band selection and authored early/mid/late content. |
| Quest rewards are not executable | Encounter `loot: false` suppresses combat drops, but QuestDefinition has no rewards and quest completion pays nothing. Add validated reward data/commands or an explicit cutscene reward path, including legendary awards and capacity overflow handling. |
| Legendaries have no acquisition path | Thirteen definitions and `generateLegendary()` exist, but only the interactive item-generation test calls it. Add quest/authored awards; do not add them randomly to ordinary Shootout loot contrary to the design. |
| Vamoose does not match the latest loss rule | Code halves only money. The latest answer in Death/Injury/Retreat says money and equipment; define exactly which carried/equipped/Bank items are eligible and implement atomic loss without duplicating instance ids. |
| Minigame rewards use parallel state | Poker writes `PokerMoney.money` (starting at 100), not `Party.money`; Bear Hunt/Gold Rush write `Locations.minigamePoints` and panning materials, not Party inventory/resources. Define conversion/ownership and transaction boundaries so vendors and loot cannot disagree with minigame wealth. |
| Party content is incomplete | Only Walker is present in `Party.party`; Gwyneth, Manuel, Aiyana and Morrison are not playable Party fighters. Generic enemy actor content is only Squeky rat. Add the full Party and enemy data/animations before balancing four-person encounters. |
| Resources have no production definitions | `ItemCatalog` supports `resources`, but no resource definition or resource loot entry exists. Connect gathering/minigame materials to the shared model before authoring resource rewards or sales. |

## 3. Overworld, Journal, vendors, and narrative gaps

| Area | Missing work beyond what is implemented |
|---|---|
| Dynamic visual parties | Only shared ZoneData/OverworldZoneCatalog landed. `SpawnData`, seeded spawn director, weighted multi-actor parties, off-screen placement, lifetimes, population caps, atomic cleanup, and `VisualSpawns` nodes are absent. Legacy `#8#16.gd` still defines one fixed three-rabbit spawn point. |
| Event/Zone coherence | OverworldEvents has independent grassland/desert/forest/swamp rectangles that overlap differently from the eight canonical Zones. Replace private geometry with canonical Zone lookup plus an explicit Zone → event-pool mapping; inject RNG for deterministic tests. |
| Encounter Zone coverage | Canyon has two real encounters and one pool. Ghost Town, Grassy Plains, Pine Forest, Hilly Mining, Snowy Mountain, Desert Prairie, and Swamp have no pools/actors/copy and correctly report newspaper data unavailable. |
| Loot coverage | Only the early Rats table exists. Other enemy parties, progression bands, resource drops, boss tables, and Zone-specific rewards need authoring after selection/Zone propagation works. |
| General-store content | Fixed production offers are Paregoric and Canyon Cache Map. Explosives, magazines, cigar packs, one-time boosts and camp recovery items are deliberately not sold because their mechanics do not exist. Doctor's Kit has a combat definition but no production vendor offer. |
| Secret destinations | Canyon Cache Map reveals Gold Run on the Journal map. `Gold Run.tscn` has terrain, a player and one building and reuses `Lazysprings.gd`, but no secret cache/reward interaction is implemented. No `secret_item` target is authored. Build distinctive reachable destinations and rewards rather than treating a marker or enterable shell as completed secret content. |
| Vendor art/content breadth | Five Lazysprings interiors and interactions exist, but they reuse existing art; bespoke vendor NPC/interior art and other towns' vendors are not authored. Exact stock counts/prices/sale ratio/affix valuation are first-pass balance values. |
| Quest map markers | All five Pistoleros Regroup objectives have empty `map_target_id`, so production quest markers never appear. Author valid manifest targets or deliberately document targetless objectives. |
| Prologue continuation | The five-Location chain ends at Littlehill Grove with no onward exit. Decide and implement the Lazysprings/next-arc transition, final quest completion behavior, Party recruitment, and progression rewards. `Locations.currentQuest` remains a separate setting selector from authoritative Quests state. |
| Settings and audio controls | SettingsTab is an intentional unavailable message and MainMenu Settings is `pass`; no audio/video/game settings, volume control, Apply/Revert policy, or save-management UI exists. |
| PlayerReveal coverage | The controller is implemented and documented for Clearwater Grove, but other Locations and dynamically spawned occluders need explicit controller/group/material setup. This is scene authoring and manual visual QA, not a global automatic effect. |
| Music/content validation | Playback and decision hooks exist, but there is no broad lint proving every MusicData/cutscene track, animation path, or hit frame exists. Add data validation rather than relying on runtime fallback/warnings. |
| Flairs | The pre-transition Flair scene/layer, shared pools from Names.md, resolver, timing and tests are unimplemented. Current Shootout flavor is printed and shown as an in-combat banner using different pools. |

## 4. Poker, minigames, WFC, and optional first-iteration work

| Area | Current gap |
|---|---|
| Poker reachability and economy | Poker rules/AI and session bankroll exist, but SceneManager has no poker scene key/production entrance. Story-scaled maximum bets are not implemented; wallet size is the effective cap. Connect entry/return and Party money before treating it as a town feature. |
| Poker/table rules review | The implementation uses four-card flushes and a single blind charged to every player, which are unusual Texas hold'em variants. Confirm these are intended house rules and document them; the high-level Poker doc does not specify them. |
| Bear Hunt/Gold Rush integration | Minigames award points/materials but have no shared inventory/resource conversion or coherent save lifecycle. Bear Hunt has no automated scoring suite; the Features list's herb-picking minigame is not added. |
| Generated-map content iteration | The WFC model/builder/solver, deterministic seeded generation, entropy, contradiction restart/fallback and worker integration exist. Remaining Features work is content/behavior: larger/varied chunk areas, vegetation memory, dynamic animals, more varied decoration, path readability/passability, and any stale placement/pathfinding bugs. Optional reflections, backtracking, border seeding and debug visualisation remain optional, not missing core solver work. |
| SceneManager polish | Core registry/fades/threaded loading and modal layers exist. Loading progress, configurable transition presentation, and comprehensive gated scene-flow tests remain polish/QA; they do not replace the missing encounter router. |
| Journal deferred interactions | Direct unequip, drag-and-drop, player-selected loot, cross-tab member shortcuts, exact level-scaled Rodeo display, and read-only Move/belt inspection are explicitly deferred. They are not required to claim the current Inventory/Character first iterations complete. |
| Loot selection | Current loot deterministically accepts what fits and requires overflow acknowledgment. Player-selected loot is deferred; the missing launcher/return path is not deferred and remains P0. |

## 5. Design decisions that must be reconciled before balancing

These are specification conflicts, not safe implementation assumptions:

1. **Persistent HP/knockouts versus always-full HP:** Party implements persistent HP, injury, downed state and three-fight knockout debuffs. The latest answer in `Death Injury and Retreat.md` instead says no knockouts/debuffs and always start fights at max HP, with MxHP attrition handled separately. Choose one canonical rule and update Party, Character, recovery, tests and docs together.
2. **Bleed stacking:** `ShootoutEffectManager` stores bleed instances but only the highest ticks, with stored instances taking over. The later note in `Effects.md` says multiple stacks combine (for example, two stacks equal one damage) and healing removes stacks. Define stack amount/damage/healing semantics before authoring bleed items or affixes.
3. **Vamoose loss scope:** requirements say half of all loot, implementation halves money, and the latest answer says money and equipment. Specify carried versus equipped/Bank scope and rounding.
4. **Player attacks:** the UI removes basic attacks while enemy AI uses them. Decide whether basic weapon attacks are implicit Moves, explicit data Moves, or enemy-only.
5. **Boss HP conditions:** implemented `hp_below` targets a whole side, while the encounter design's latest note asks for a specific boss/actor. Add per-actor targeting if required rather than balancing around side totals accidentally.
6. **Poker rules:** “Texas hold'em” does not by itself communicate four-card flushes or every-player blinds. Record exact house rules before economy balancing.
7. **Zone item acquisition:** Zone-tied equipment currently has a vendor path but not a Shootout-loot path. Confirm whether this is intentional; if not, use the encounter-Zone propagation requirement above.

## 6. Validation, QA, and documentation debt

| Gap | Needed closure |
|---|---|
| Real scene-flow coverage | Add automated tests for event choice → encounter → result → origin/town/checkpoint return, failed scene load, double launch/continue, and Party mutation exactly once. Current manager tests do not prove this production flow. |
| OverworldEvents | Add injected-RNG cadence/pool/Zone tests, active-event lifecycle tests, and tests proving each result id resolves exactly one valid outcome. |
| Combat scene coverage | Add real multi-target and full encounter scene tests; verify animations, effect death, flee/Vamoose routing, result overflow, and return cleanup rather than only isolated managers. |
| Data lint | Centralize checks for duplicate `data.name`, unknown actors/classes/Moves/Rodeos/items/effects, invalid positions/win conditions, missing animations/backgrounds/music/hit frames, loot references/bands, encounter pools, quest map targets, and cutscene shot references. Folder loading currently overwrites duplicate names. |
| Persistence tests | Add Party and Quests export/import validation, coordinated all-or-nothing restore, New Game reset, migration, and actual Save/Continue application-restart tests. Existing Vendors/Discovery snapshot tests cover only part of the state. |
| Non-gating tests | Poker and SceneManager's in-tree tests call `quit()` unconditionally and cannot report failure through the automated suite. Give them real exit codes and discovery, or replace them with gated `Tests/Test*.gd`/`.tscn` suites. |
| Shutdown/resource cleanup | The 2026-11-15 headless validation emits ObjectDB/RID/resource-leak warnings in otherwise passing tests, including ClearwaterGroveSceneTest and several combat scripts. Track ownership and release scene/script resources so the documented clean-exit acceptance is met; a zero test exit code alone does not close this. |
| Bear Hunt and cutscenes | Add Bear Hunt scoring simulations and broad cutscene data/reference lint; current quest-trigger tests cover only the new quest shot path, not all 93 scripts. |
| Manual acceptance | Character, Quests, vendor views/navigation, map/marker readability, Shootout presentation and PlayerReveal still require their documented real 640×360 mouse/keyboard/controller/art checks. Headless tests cannot close these. |
| Balance measurement | Combat target metrics are 5–10 Rounds, regular enemies at 3–5 hits, powerful enemies at 10+, and scarce impactful healing. Add reproducible encounter simulations/telemetry before treating placeholder damage, AI, prices, affix ranges and stock counts as balanced. |
| Open visual issues | `Docs/Issues.md` still lists Journal music starting after a long open period, Move/Flee right alignment, click-to-reposition, and Inventory party-icon height. Verify/reproduce and close them during UI acceptance. |
| Stale design status | Several docs retain old “pending/current state” notes after later patches (for example Cylinder/effect UI, canyon pools, Rodeos, and Region-pool summaries). Historical test counts are snapshots, not current proof. Update each source doc when its implementation lands and keep this register dated. |

## 7. Explicitly deferred, not blockers

The following should not be used to inflate the required first-iteration worklist: vendor schedules/haggling/buyback/per-town Banks, general fog of war/fast travel, moving visual parties, mid-fight reinforcements, direct unequip/drag-and-drop, player-selected loot, exact level-scaled Rodeo text in Character, cross-tab shortcuts, WFC reflection/backtracking/debug visualisation, and loading-screen progress art. They require new design only after the coherent core loop works.
