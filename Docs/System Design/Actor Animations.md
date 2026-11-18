# Actor Animations

Design for one generic way to build and drive actor animations. **Status: design (not yet implemented); scheduled as commit 17a in [Next Steps Implementation Plan](Next%20Steps%20Implementation%20Plan.md).** Requirements came from reviewing the hand-authored Walker Langley scenes and the built-in Location/Overworld actor animations before the commit-17 content push.

## Problem

- Every combat actor needs a hand-authored `*Animations.tscn` (hundreds of `AtlasTexture` sub-resources plus `SpriteFrames`) at `res://Animations/{type}/{ActorNameWithoutSpaces}Animations.tscn` (Overworld actors: `res://Animations/Overworld/{type}/{ActorNameWithoutSpaces}Animations.tscn`). Adding an actor today means duplicating that editing work, and commit 17 adds several actors.
- Idle selection is hardcoded at call sites (`"Idle Revolver"` / `"Idle Rifle"` / `"Idle"`), so weapon-specific behavior is in code, not data.
- Overworld/Location actors use built-in scenes for Idle/Run; those scenes duplicate the same structure per actor.
- Hit frames already have a separate combat source (`FrameData`), so animation data must not fork a second hit-frame contract.

## Current state inventory

- `Animations/BaseAnimation.gd` + `.tscn`: the shared runtime — `initAnimations(idleAnimation, frameHit)`, `playAnimation(name, isOneshot, lookForFrameHit, next)`, `flipAnimation`, `onAnimationFrameHit`. All three consumers instantiate this shape and drive it with names.
- `Actors/Shootout/ShootoutActor.gd`: loads `res://Animations/{type}/{actorName}Animations.tscn` and picks the idle by weapon in code.
- `Actors/Overworld/OverworldActor.gd`: loads `res://Animations/Overworld/{type}/{actorName}Animations.tscn`; a missing scene aborts the spawn with a warning.
- `Actors/Location/PlayerLocationActor.gd`: built-in Idle/Run playback on an `AnimatedSprite2D`.
- `Globals/FrameData.gd`: per-weapon combat hit frames (unchanged combat read).

## Decisions

1. **One data registry, not per-actor scenes.** New `Data/Actors/ActorAnimationRegistry.gd` maps each actor id to its states. An entry per state is data-only: sprite-sheet path, frame size (default 40 px), frame count or explicit frame indices, playback speed, loop, optional hit frame, optional next state. Sheets and fps/loop semantics match the existing `SpriteFrames` resource exactly, so visuals are unchanged.
2. **One builder/service.** New `Globals/ActorAnimationService.gd` exposes `forActor(actorType, actorName) -> BaseAnimation`: it instantiates `res://Animations/BaseAnimation.tscn`, injects generated `SpriteFrames` and calls `initAnimations(defaultIdle, hitFrame)` — the same object the old scenes produced. `idleForWeapon(actorId, weaponId)` returns the weapon's idle when `idleByWeapon` is authored, else the default Idle. No new autoload is needed: the service is a `RefCounted` builder created where it is used (or an autoload if cross-scene caching proves necessary).
3. **Shared cached resources.** The builder constructs one `SpriteFrames` per actor id and reuses it across instances, so 100 rats share one resource instead of 100 scene parses. Sprite-sheet textures load through Godot's shared texture cache.
4. **Legacy fallback during migration.** A call site that finds no registry entry falls back to the legacy `.tscn` path (if present) and logs the fallback once. New content is registry-first; legacy scenes are deleted only after every consumer is migrated (cleanup commit after commit 17).
5. **Canonical state names.** `Idle`, `IdleRevolver`, `IdleRifle`, `Run`, `Walk`, `Attack`, `Shoot`, `Duck` (plus the existing Overworld direction names). Unknown states fall back to `Idle` with a warning instead of breaking a spawn. `idleByWeapon` covers revolver/rifle/shotgun-specific idles without code branches.
6. **Hit frames stay out of the registry for now.** `FrameData` remains the combat read; the registry only carries per-state hit frames when a later commit unifies the two reads deliberately (no duplicate contract).

## Efficiency answers to the open questions

- *More efficient than separate animation files?* Yes: the registry is one data file; adding an actor is a small dictionary entry per state instead of a hand-edited scene. Building `SpriteFrames` once per actor id and caching them removes the per-instance scene parse cost and keeps one texture per sheet in memory.
- *Generic way to set animations for every actor?* The three call sites (Shootout spawn, OverworldActor, Location/PlayerLocationActor) all ask the service for a `BaseAnimation` by actor id; weapon idles come from data (`idleByWeapon`), and unknown actors/states degrade to Idle with a warning rather than aborting the spawn.

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

