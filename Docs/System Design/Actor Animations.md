# Actor Animations

Design for one generic way to build and drive actor animations. **Status: fully implemented.** The Shootout spawn has routed through the service since commit 17a; commit 17 authored every new combat actor as registry data only (the four main-party members and the five Kipley Wilds bandits needed no per-actor `.tscn`); commit 19 completed the migration — the Overworld wanderers (CanvasTexture normal maps via a per-state `normalMap` and the `"runtime": "overworld"` schema), the two player actors (directional Move/Idle-Run sets) and the cutscene performers all resolve through the registry, and the migrated legacy scenes (`WalkerLangleyAnimations.tscn`, `SquekyRatAnimations.tscn`, `FluffyRabbitAnimations.tscn`) are deleted. Requirements came from reviewing the hand-authored Walker Langley scenes and the built-in Location/Overworld actor animations before the commit-17 content push.

## Problem

- Every combat actor needs a hand-authored `*Animations.tscn` (hundreds of `AtlasTexture` sub-resources plus `SpriteFrames`) at `res://Animations/{type}/{ActorNameWithoutSpaces}Animations.tscn` (Overworld actors: `res://Animations/Overworld/{type}/{ActorNameWithoutSpaces}Animations.tscn`). Adding an actor today means duplicating that editing work, and commit 17 adds several actors.
- Idle selection is hardcoded at call sites (`"Idle Revolver"` / `"Idle Rifle"` / `"Idle"`), so weapon-specific behavior is in code, not data.
- Overworld/Location actors use built-in scenes for Idle/Run; those scenes duplicate the same structure per actor.
- Hit frames already have a separate combat source (`FrameData`), so animation data must not fork a second hit-frame contract.

## Current state inventory

- `Animations/BaseAnimation.gd` + `.tscn`: the shared runtime — `initAnimations(idleAnimation, frameHit)`, `playAnimation(name, isOneshot, lookForFrameHit, next)`, `flipAnimation`, `onAnimationFrameHit`. All consumers instantiate this shape and drive it with names. `Animations/Overworld/OverworldAnimations.gd` is the lighter overworld runtime: `playAnimation(animation)` with replay-on-finish.
- `Actors/Shootout/ShootoutActor.gd`, `Actors/Cutscene/CutsceneActor.gd`, `Actors/Overworld/OverworldActor.gd` and both player actors resolve their animation node through `Globals/ActorAnimationService.gd` (commit 19); no call site loads a per-actor scene anymore.
- `Globals/FrameData.gd`: per-weapon combat hit frames (unchanged combat read).

## Decisions

1. **One data registry, not per-actor scenes.** New `Data/Actors/ActorAnimationRegistry.gd` maps each actor id to its states. An entry per state is data-only: sprite-sheet path, frame size (default 40 px), frame count or explicit frame indices, playback speed, loop, optional hit frame, optional next state. Sheets and fps/loop semantics match the existing `SpriteFrames` resource exactly, so visuals are unchanged.
2. **One builder/service.** New `Globals/ActorAnimationService.gd` exposes `forActor(actorType, actorName) -> BaseAnimation`: it builds the `Node2D` + `Animations.gd` runtime in code (root, `AnimationSprite` with generated `SpriteFrames`, `AnimationPlayer` with generated per-state frame tracks — the same shape the authored scenes produce) and returns it ready for `initAnimations`/`playAnimation`. `idleForWeapon(actorId, weaponId)` returns the weapon's idle when `idleByWeapon` is authored, else the default Idle. No new autoload is needed: the service is a `RefCounted` builder created where it is used (or an autoload if cross-scene caching proves necessary).
3. **Shared cached resources.** The builder constructs one `SpriteFrames` per actor id and reuses it across instances, so 100 rats share one resource instead of 100 scene parses. Sprite-sheet textures load through Godot's shared texture cache.
4. **Legacy fallback during migration.** A call site that finds no registry entry falls back to the legacy `.tscn` path (if present) and logs the fallback once. New content is registry-first; legacy scenes are deleted only after every consumer is migrated (cleanup commit after commit 17).
5. **Canonical state names.** `Idle`, `IdleRevolver`, `IdleRifle`, `Run`, `Walk`, `Attack`, `Shoot`, `Duck` (plus the existing Overworld direction names). Unknown states fall back to `Idle` with a warning instead of breaking a spawn. `idleByWeapon` covers revolver/rifle/shotgun-specific idles without code branches.
6. **Hit frames stay out of the registry for now.** `FrameData` remains the combat read; the registry only carries per-state hit frames when a later commit unifies the two reads deliberately (no duplicate contract).
7. **Timings are per-frame data.** A state plays at a uniform `step` (default 0.15s) or, when hand-held frames matter, at authored `frameTimes` — one duration per played frame, from which the service spaces the track keys and derives the animation length. An optional `sequence` lists the frame indices to play in order (indices may repeat), letting a state replay an earlier frame: Shoot Rifle's legacy tenth SpriteFrames entry was a repeat of frame 0 held 0.25s as return-to-ready, authored as `sequence: [0..8, 0]` over the shrunken nine-frame sheet. The original scene timings were recovered from the deleted legacy scenes' git history: the legacy `AnimationPlayer` libraries keyed non-uniform holds (Walker Langley's Shoot Revolver 0.5s draw anticipation + 0.45s recoil, Shoot Rifle's 0.35s fired-frame hold, Snap's reaction holds), while SpriteFrames-only states played at the resource's 5fps (0.2s). The recovered draw timings (`Shoot Revolver` 1.65s, `Shoot Rifle` 1.0s) are shared by every actor whose draw sheets slice the same frame counts — the main party and the Kipley Wilds bandits author the identical `frameTimes`/`sequence` data. Two legacy details could not map 1:1 onto the current sheets and are folded into the adjacent frame (documented in the registry comments): Shoot Revolver's 0.05s end flash of frame 0. (Shoot Rifle's repeat entry is played exactly via `sequence`.)

## Efficiency answers to the open questions

- *More efficient than separate animation files?* Yes: the registry is one data file; adding an actor is a small dictionary entry per state instead of a hand-edited scene. Building `SpriteFrames` once per actor id and caching them removes the per-instance scene parse cost and keeps one texture per sheet in memory.
- *Generic way to set animations for every actor?* Call sites ask the service for a `BaseAnimation` runtime by actor id; weapon idles come from data (`idleByWeapon`), and unknown actors/states degrade to Idle with a warning rather than aborting the spawn.

## Scope of commit 17a (decided; completed by commit 19)

- **Routed:** the Shootout actor spawn (`Actors/Shootout/ShootoutActor.gd`) — Walker Langley and Squeky rat resolve through the registry, with the legacy scene merged in for any state the registry does not cover.
- **Deferred with reasons (commit 17a), completed in commit 19:** `Animations/Overworld/*` animal scenes carried `CanvasTexture` normal maps and their own `OverworldAnimations.gd` runtime — the registry gained a per-state `normalMap` and a `"runtime": "overworld"` entry kind whose service build produces the same Sprite2D + looping-track structure. The player actors (`PlayerOverworldActor`/`PlayerLocationActor`) embedded directional Move/Idle-Run states plus the shadow contract — both sets moved into the registry (`PlayerOverworld`, `PlayerLocation`) with the scenes rebuilt without their embedded sprite/animation nodes; the shadow contract is unchanged (`ShadowScript.attachTo` still finds the sprite, and the wagon's per-view coverage logic stays in the actor script). The legacy actor scenes (`WalkerLangleyAnimations.tscn`, `SquekyRatAnimations.tscn`, `FluffyRabbitAnimations.tscn`) are deleted; the service's legacy-scene merge remains as a fallback for future unregistered actors.

## Tests

- New `Tests/TestActorAnimations.gd`: the registry builds a real `SpriteFrames` with the expected frame counts/loop/speed; `idleForWeapon` returns the authored weapon idle and the default fallback; a missing actor or state falls back to Idle with a warning instead of failing; legacy-scene fallback still resolves for unregistered actors.
- `Tests/TestContentLint` gains registry checks: every sheet path exists, playback speed is positive, hit frames are inside the frame count, and state names come from the canonical set.

## Implementation order (commit 17a)

1. `Data/Actors/ActorAnimationRegistry.gd` with the Walker Langley and Squeky rat states converted from their current scenes (data identical to today's visuals).
2. `Globals/ActorAnimationService.gd` builder + cache + `idleForWeapon`.
3. Route the three call sites through the service with the legacy fallback; convert Location/PlayerLocationActor's built-in Idle/Run to the same runtime.
4. Tests + content-lint entries; delete legacy scenes only in a later cleanup commit once nothing references them.

## Open (intentionally deferred)

- A `.ase`-to-registry authoring tool (export frames from the Aseprite files the artist edits) — worth building when the sheet count grows; not required for commit 17a.
- Unifying the registry's hit frames with `FrameData` (one combat read) after the service is proven.

