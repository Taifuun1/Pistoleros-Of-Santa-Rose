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
			"Idle Revolver": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyIdleRevolver.png", "frames": 8 },
			"Idle Rifle": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyIdleRifle.png", "frames": 8 },
			"Run": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyRun.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyDrawRevolver.png", "frames": 11 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleyDrawRifle.png", "frames": 10 },
			"Snap": { "sheet": "res://Assets/Characters/Named People/Walker Langley/WalkerLangleySnap.png", "frames": 13 },
		},
	},
	"SquekyRat": {
		"defaultIdle": "Idle",
		"states": {
			"Idle": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdle.png", "wholeSheet": true },
			"Idle Look": { "sheet": "res://Assets/Characters/Animals/Squeky Rat/SquekyRatIdleLook.png", "frameSize": Vector2i(24, 24), "frames": 2 },
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
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationDrawRevolver.png", "frames": 11 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Aiyana/AiyanaAnimationDrawRifle.png", "frames": 9 },
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
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationDrawRevolver.png", "frames": 11 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Gwyneth Remington/GwynethRemingtonAnimationDrawRifle.png", "frames": 9 },
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
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationDrawRevolver.png", "frames": 11 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Manuel Cárdenas/ManuelCárdenasAnimationDrawRifle.png", "frames": 9 },
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
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationDrawRevolver.png", "frames": 11 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Named People/Morrison Branson/MorrisonBransonAnimationDrawRifle.png", "frames": 9 },
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
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/BobtailGuardAnimationWhisperingPinesReachDrawRifle.png", "frames": 9 },
		},
	},
	"DustWhisperer": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/DustWhispererAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/DustWhispererAnimationWhisperingPinesReachDrawRifle.png", "frames": 9 },
		},
	},
	"LineRider": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/LineRiderAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/LineRiderAnimationWhisperingPinesReachDrawRifle.png", "frames": 9 },
		},
	},
	"WhiskeyBulldozer": {
		"defaultIdle": "Idle Rifle",
		"idleByWeapon": { "rifle": "Idle Rifle" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/WhiskeyBulldozerAnimationWhisperingPinesReachIdleRifle.png", "frames": 8 },
			"Shoot Rifle": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/WhiskeyBulldozerAnimationWhisperingPinesReachDrawRifle.png", "frames": 9 },
		},
	},
	"Pistolero": {
		"defaultIdle": "Idle Revolver",
		"idleByWeapon": { "revolver": "Idle Revolver" },
		"spriteOffset": Vector2(0, -15),
		"states": {
			"Idle Revolver": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/PistoleroAnimationWhisperingPinesReachIdleRevolver.png", "frames": 8 },
			"Shoot Revolver": { "sheet": "res://Assets/Characters/Bandits/Whispering Pines Reach/PistoleroAnimationWhisperingPinesReachDrawRevolver.png", "frames": 11 },
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
