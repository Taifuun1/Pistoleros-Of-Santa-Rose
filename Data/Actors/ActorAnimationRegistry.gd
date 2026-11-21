extends RefCounted
class_name ActorAnimationRegistry

## Data-driven animation states per actor id (Docs/System Design/Actor
## Animations.md, commit 17a). One registry entry replaces a hand-authored
## `*Animations.tscn`: every state slices consecutive frames from a sprite
## sheet (`wholeSheet` states use the sheet as a single full-size frame) and
## plays at `step` seconds per frame through the shared `Animations.gd`
## runtime. `defaultIdle`/`idleByWeapon` replace the hardcoded idle selection.
## States missing from the registry fall back to the actor's legacy scene
## through the service's merge, so conversion can happen incrementally.

const DEFAULT_FRAME_SIZE := Vector2i(40, 40)
const DEFAULT_STEP := 0.15

var actors = {
	"WalkerLangley": {
		"defaultIdle": "Idle",
		"idleByWeapon": { "revolver": "Idle Revolver", "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyIdle.png", "frames": 8, "loop": false },
			# Timings recovered from the deleted legacy scene's git history
			# (commit 19^): the AnimationPlayer library keyed Idle/Idle
			# Revolver/Idle Rifle at uniform 0.15s steps; the SpriteFrames-only
			# states played at 5fps (0.2s per frame).
			"Idle Look": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyIdle.png", "frames": 8, "step": 0.2 },
			"Idle Revolver": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyIdleRevolver.png", "frames": 8 },
			"Idle Rifle": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyIdleRifle.png", "frames": 8 },
			"Run": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyRun.png", "frames": 8, "step": 0.2 },
			"Walk": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyWalk.png", "frames": 8, "step": 0.2 },
			"Ponder": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyPonder.png", "frames": 18, "step": 0.2 },
			"Push Hat": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyPushHat.png", "frames": 16, "step": 0.2 },
			"Tip": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyTip.png", "frames": 14, "step": 0.2 },
			"Throw": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyThrow.png", "frames": 7, "step": 0.2 },
			# Non-uniform legacy AnimationPlayer keys, authored as per-frame
			# durations (recovered from the deleted scene's git history and
			# shared by every actor whose draw sheets slice the same frame
			# counts). Shoot Revolver: 0.5s draw anticipation on frame 0,
			# 0.45s recoil hold on frame 7; the legacy 0.05s tail flash of
			# frame 0 folds into the final frame (total 1.65s). Shoot Rifle:
			# six quick 0.05s windup keys, the 0.35s hold on frame 6, then
			# the legacy tenth SpriteFrames entry — a repeat of frame 0 held
			# 0.25s as return-to-ready — plays explicitly via `sequence`
			# (total 1.0s). Snap: holds after the snap (0.2s) and the
			# reaction (0.3s).
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyDrawRevolver.png", "frames": 11, "frameTimes": [0.5, 0.05, 0.15, 0.05, 0.05, 0.05, 0.05, 0.45, 0.05, 0.15, 0.1] },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
			"Snap": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleySnap.png", "frames": 13, "frameTimes": [0.1, 0.1, 0.1, 0.1, 0.2, 0.1, 0.1, 0.1, 0.3, 0.1, 0.1, 0.1, 0.1] },
			"Draw Revolver Cool": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyDrawRevolverCool.png", "frames": 19, "step": 0.2 },
			"Draw Revolver Super Cool": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyDrawRevolverSuperCool.png", "frames": 30, "step": 0.2 },
		},
	},
	"SquekyRat": {
		"defaultIdle": "Idle",
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdle.png", "wholeSheet": true },
			# Legacy SpriteFrames speed 5fps (commit 19^ history).
			"Idle Look": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdleLook.png", "frameSize": Vector2i(24, 24), "frames": 2, "step": 0.2 },
			"Melee": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdleAttack.png", "frameSize": Vector2i(24, 24), "frames": 5, "step": 0.2 },
			"Run": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdleSkidadle.png", "frameSize": Vector2i(24, 24), "frames": 2, "step": 0.2 },
			"Walk": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdleSkamper.png", "frameSize": Vector2i(24, 24), "frames": 2, "step": 0.2 },
		},
	},
	# Main party (commit 17): the full authored template sets. "Shoot Revolver"/
	# "Shoot Rifle" feed the sequencer's weapon-to-state mapping; "Throw" and
	# "Walk" stay available for later consumers.
	"Aiyana": {
		"defaultIdle": "Idle",
		"idleByWeapon": { "revolver": "Idle Revolver", "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationIdle.png", "frames": 8 },
			"Idle Revolver": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationIdleRevolver.png", "frames": 8 },
			"Idle Rifle": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationIdleRifle.png", "frames": 8 },
			"Run": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationRun.png", "frames": 8 },
			"Walk": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationWalk.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationDrawRevolver.png", "frames": 11, "frameTimes": [0.5, 0.05, 0.15, 0.05, 0.05, 0.05, 0.05, 0.45, 0.05, 0.15, 0.1] },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
			"Throw": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationThrow.png", "frames": 7 },
		},
	},
	"GwynethRemington": {
		"defaultIdle": "Idle",
		"idleByWeapon": { "revolver": "Idle Revolver", "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationIdle.png", "frames": 8 },
			"Idle Revolver": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationIdleRevolver.png", "frames": 8 },
			"Idle Rifle": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationIdleRifle.png", "frames": 8 },
			"Run": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationRun.png", "frames": 8 },
			"Walk": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationWalk.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationDrawRevolver.png", "frames": 11, "frameTimes": [0.5, 0.05, 0.15, 0.05, 0.05, 0.05, 0.05, 0.45, 0.05, 0.15, 0.1] },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
			"Throw": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationThrow.png", "frames": 7 },
		},
	},
	"ManuelCárdenas": {
		"defaultIdle": "Idle",
		"idleByWeapon": { "revolver": "Idle Revolver", "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationIdle.png", "frames": 8 },
			"Idle Revolver": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationIdleRevolver.png", "frames": 8 },
			"Idle Rifle": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationIdleRifle.png", "frames": 8 },
			"Run": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationRun.png", "frames": 8 },
			"Walk": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationWalk.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationDrawRevolver.png", "frames": 11, "frameTimes": [0.5, 0.05, 0.15, 0.05, 0.05, 0.05, 0.05, 0.45, 0.05, 0.15, 0.1] },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
			"Throw": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationThrow.png", "frames": 7 },
		},
	},
	"MorrisonBranson": {
		"defaultIdle": "Idle",
		"idleByWeapon": { "revolver": "Idle Revolver", "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationIdle.png", "frames": 8 },
			"Idle Revolver": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationIdleRevolver.png", "frames": 8 },
			"Idle Rifle": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationIdleRifle.png", "frames": 8 },
			"Run": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationRun.png", "frames": 8 },
			"Walk": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationWalk.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationDrawRevolver.png", "frames": 11, "frameTimes": [0.5, 0.05, 0.15, 0.05, 0.05, 0.05, 0.05, 0.45, 0.05, 0.15, 0.1] },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
			"Throw": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationThrow.png", "frames": 7 },
		},
	},
	# Whispering Pines Reach bandits (commit 17): rifle fighters carry the two
	# authored rifle states; the revolver-carrying Pistolero carries the revolver
	# pair. defaultIdle matches the carried weapon.
	"BobtailGuard": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/BobtailGuardAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/BobtailGuardAnimationWhisperingPinesReachDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
		},
	},
	"DustWhisperer": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/DustWhispererAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/DustWhispererAnimationWhisperingPinesReachDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
		},
	},
	"LineRider": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/LineRiderAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/LineRiderAnimationWhisperingPinesReachDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
		},
	},
	"WhiskeyBulldozer": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/WhiskeyBulldozerAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/WhiskeyBulldozerAnimationWhisperingPinesReachDrawRifle.png", "frames": 9, "sequence": [0, 1, 2, 3, 4, 5, 6, 7, 8, 0], "frameTimes": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.35, 0.05, 0.05, 0.25] },
		},
	},
	"Pistolero": {
		"defaultIdle": "Idle Revolver",
		"idleByWeapon": { "revolver": "Idle Revolver" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Revolver": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/PistoleroAnimationWhisperingPinesReachIdleRevolver.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/PistoleroAnimationWhisperingPinesReachDrawRevolver.png", "frames": 11, "frameTimes": [0.5, 0.05, 0.15, 0.05, 0.05, 0.05, 0.05, 0.45, 0.05, 0.15, 0.1] },
		},
	},
	# Location player (commit 19): the embedded Idle/Idle2/Run/Run2 set of
	# PlayerLocationActor.tscn converted to data. Only Idle/Run are played
	# today; Idle2/Run2 stay available for the art swap.
	"PlayerLocation": {
		"defaultIdle": "Idle",
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Templates/Legacy/Test2Animation_40x40.png", "frames": 8, "step": 0.1, "loop": true },
			"Idle2": { "sheet": "res://Assets/Characters/Templates/Legacy/Test2Animation_40x40_run_smears_4_outline.png", "frames": 8, "step": 0.1, "loop": true },
			"Run": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyRun.png", "frames": 8, "step": 0.15, "loop": true },
			"Run2": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangeyRun2.png", "frames": 8, "step": 0.15, "loop": true },
		},
	},
	# Overworld wagon player (commit 19): the directional Move set of
	# PlayerOverworldActor.tscn. The wagon's slow steps (0.5s/1.0s per frame)
	# are authored data; the per-view shadow coverage stays in the actor
	# script (shadow geometry itself unchanged).
	"PlayerOverworld": {
		"defaultIdle": "Move Down Side",
		"spriteOffset": Vector2(0, -24),
		"states": {
			"Move Down": { "sheet": "res://Assets/Map Entities/Wagon/WagonDown.png", "frameSize": Vector2i(24, 24), "frames": 2, "step": 1.0, "loop": true },
			"Move Down Side": { "sheet": "res://Assets/Map Entities/Wagon/WagonDownSide.png", "frameSize": Vector2i(24, 24), "frames": 4, "step": 0.5, "loop": true },
			"Move Side": { "sheet": "res://Assets/Map Entities/Wagon/WagonSide.png", "frameSize": Vector2i(24, 24), "frames": 4, "step": 0.5, "loop": true },
			"Move Up": { "sheet": "res://Assets/Map Entities/Wagon/WagonUp.png", "frameSize": Vector2i(24, 24), "frames": 2, "step": 1.0, "loop": true },
			"Move Up Side": { "sheet": "res://Assets/Map Entities/Wagon/WagonUpSide.png", "frameSize": Vector2i(24, 24), "frames": 4, "step": 0.5, "loop": true },
		},
	},
	# Overworld wanderer (commit 19): the first "runtime": "overworld" entry.
	# The service builds the OverworldAnimations runtime with per-state
	# Sprite2D nodes, so CanvasTexture normal maps survive the migration.
	"FluffyRabbit": {
		"runtime": "overworld",
		"defaultIdle": "Idle",
		"states": {
			"Idle": {
				"sheet": "res://Assets/Map Entities/Fluffy Rabbit/FluffyRabbit.png",
				"normalMap": "res://Assets/Map Entities/Fluffy Rabbit/FluffyRabbit_n.png",
				"frames": 4,
				"step": 0.2,
				"loop": true,
			},
		},
	},
}


func hasActor(actorId: String) -> bool:
	return actors.has(actorId)


func getActor(actorId: String) -> Dictionary:
	var entry = actors.get(actorId, null)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}


func getStates(actorId: String) -> Dictionary:
	return getActor(actorId).get("states", {})


func defaultIdleFor(actorId: String, fallback := "Idle") -> String:
	return str(getActor(actorId).get("defaultIdle", fallback))


## Weapon-specific idle from `idleByWeapon`, or the actor's default idle.
func idleForWeapon(actorId: String, weaponId: String, fallback := "Idle") -> String:
	var entry := getActor(actorId)
	var idleByWeapon = entry.get("idleByWeapon", null)
	if idleByWeapon is Dictionary and (idleByWeapon as Dictionary).has(weaponId):
		return str((idleByWeapon as Dictionary).get(weaponId))
	return defaultIdleFor(actorId, fallback)
