# Combat

Notes for combat.

This is a design doc: it describes the intended design, and the implementation may lag behind it. Undecided design points are collected in [Open Questions](#open-questions).

## Glossary

- **Shootout** - a combat encounter
- **Move** - a single action a character takes on their Turn (attack, ability, item, duck or reposition)
- **Turn** - one character taking their Move
- **Round** - one full pass in which every living character has taken a Turn
- **Cylinder** - a character's final sequence of Chambers, which decides attack quality
- **Chamber** - a single value in a Cylinder (0-3: Miss, Graze, Hit, Critical Hit)
- **Magazine** - one of the partial cylinder patterns (character, class and weapon) that are summed into the final Cylinder
- **Style / Sand** - the two defensive damage types
- **Duck** - a defensive Move that applies buffs to allied characters
- **Rodeo** - a character's passive ability, active during combat
- **Belt space** - how many items a character can bring into a Shootout

Base stats referenced in this doc (full definitions live in the stats doc, TBD):

- **High Tailin'** - initiative
- **Six Shootin'** - Lead damage
- **Taffyin'** - Style defense
- **MxHp** - max health

## Overview

- Combat encounters are called Shootouts
- Turn-based combat
	- Each Turn, every character gets to take an action, called a Move
	- Turn order is based on High Tailin', a random roll and other modifiers
		- On even stats, turn order is random
- Character moves
	- Four moves to choose from max in Shootouts for any given character
	- If a character has more than 4 total moves, they can be activated and deactivated outside of fights
	- Move types depend on the character's class; unique named characters can have unique moves
	- Move types
		- Attacks
			- Attack target(s) with held weapon, with any modifiers applied from the attacks
		- Abilities
			- Characters can have abilities based on their class and worn equipment
			- Class abilities
				- Usually focused on utility
			- Equipment abilities
				- Usually focused on damage
		- Items
			- Consumables that can have varying effects
			- Amount that can be brought to a Shootout is decided by belt space
			- Limited amounts, must be bought at town areas
		- Ducks
			- Defensive moves that apply buffs to allied characters
- Cylinders
	- A Cylinder (or cylinder pattern) is a sequence of numbers
	- Each number in a Cylinder is called a Chamber
		- The Chamber decides the quality of an attack
			- Chamber quality is between 0-3
				- 0 is Miss
				- 1 is Graze
				- 2 is Hit
				- 3 is Critical Hit
	- Each character, class and weapon has a cylinder pattern
		- These individual cylinder patterns are called Magazines
		- Each Magazine Chamber can have a value between -3 to 3
		- All of the Magazines get added up to form the final Cylinder
			- Each Chamber for all Magazines is added for the final Cylinder Chamber
			- Final Chamber values are clamped between 0 and 3
		- Example: character Magazine [1, 0, 2] + class Magazine [0, 1, -1] + weapon Magazine [2, -1, 0] = Cylinder [3, 0, 1]
	- Cylinders are always a length of 2-6
	- At the start of combat, characters get placed at the beginning of their Cylinder
		- Only attacking with a weapon advances the Cylinder; Abilities, Items, Ducks and repositioning do not
		- For each weapon attack, the character advances one Chamber in their Cylinder
		- When the Cylinder ends, it jumps back to the beginning
	- Cylinders can have special Chambers, eg. Reload and Jammed
		- Reload: the character spends their Move reloading and cannot attack
		- Jammed: the attack instead gives a buff or a debuff
		- Special Chambers cannot usually be modified, except with special items, modifiers or Rodeos
- Positions
	- Characters have a position in fights
	- Darkest Dungeon style positioning, with 4 positions per side (max 4 characters per side)
	- Positions are numbered 1-4 from the front (position 1 is closest to the enemy)
	- Moving between adjacent positions costs a Move
	- Specific weapons and attacks can fire only from specific friendly positions, and target only specific enemy positions
	- Effects can disrupt positioning; a character stuck in a position where none of their moves work must spend Moves repositioning

## Stats

- Stats are based on character's base stats, held weapon, worn equipment and other modifiers
- There is no hit-rate stat: accuracy is entirely decided by Cylinders and cylinder modifiers
- Types
	- Health
		- MxHp decides how much damage a character can take
	- Initiative
		- Initiative decides turn order
		- Calculations
			- Base level is decided by High Tailin'
			- Modified by a random roll
			- Influenced by Rodeo and item modifiers
	- Damage types
		- Damage types decide the damage that a character deals and takes
		- Offensive
			- Lead
				- Base level is decided by Six Shootin'
				- Influenced by Rodeo and item modifiers
			- Explosive
				- Base level is decided by class
				- Influenced by Rodeo and item modifiers
			- Lasso
				- Decided by weapon base damage only; not modified by stats
		- Defensive
			- Style
				- Base level is decided by equipment and Taffyin'
			- Sand
				- Base level is decided by equipment and class
	- Resistances
		- Reduction to negative effects (exact model TBD, see Open Questions)

## Damage and hit calculation

Proposed pipeline for a weapon attack (numbers are placeholders for balancing):

1. The attacker's current Chamber decides hit quality
2. Hit quality multiplies damage: Miss 0%, Graze 50%, Hit 100%, Critical Hit 150%
3. Base damage comes from the weapon plus the relevant offensive stat (Lead, Explosive or Lasso)
4. The target's defensive damage types (Style and Sand) modify the damage, per the weapon family rules (see Weapons)
5. Resistances, damage piercing, damage decrease and flat modifiers are applied last

Example: a Gunslinger with Cylinder [2, 3, 1, 0] makes their second weapon attack, landing on Chamber 3 (Critical Hit). Base damage 10 x 150% = 15. The target has Style 4 and Sand 1; revolvers use the higher value, so 15 - 4 = 11 damage.

## Effects

- Characters can be applied or afflicted effects
- Types
	- Bleed
		- Damage at the start of each of the afflicted character's Turns
		- Won't stop until healed with items or abilities
		- Doesn't stack, only the highest affliction applies
			- All bleeds are stored, so when the highest affliction ends the next one takes its place
	- Poison
		- Damage at the start of each Round
		- Slowly wears off, some percentage like 35%
		- Can stack both duration and damage
	- Cylinder
		- Increases or decreases a character's Chambers
		- Can target specific Chambers or the whole Cylinder
		- Won't change until modified with another cylinder modifier, or after the fight ends
	- Mark
		- Marks a character
		- After one full Round, the mark becomes active: dealing damage to the character deals extra damage and effects, consuming the mark
		- The mark stays until consumed or cleansed
		- Can be cleansed with items or abilities
		- Doesn't stack
	- Damage type mark
		- Marks a character
		- Dealing damage to the character with a specific damage type deals extra damage, keeping the mark for the Round
		- Can be cleansed with items or abilities
		- Doesn't stack
	- Damage piercing
		- Increases a character's damage piercing against a defensive damage type
		- Lasts for an amount of turns
	- Damage decrease
		- Decreases a character's damage against a defensive damage type
		- Lasts for an amount of turns
	- Taunt
		- The caster taunts the friendly positions their allies are standing on
		- Enemies that target a taunted position have their attack redirected to the caster
		- The caster gains defensive buffs on taunt cast and/or when hit by taunted attacks
		- Lasts for an amount of turns
	- Silence
		- The silenced character cannot use Abilities (proposed, see Open Questions)
		- Lasts for an amount of turns

### Stacking summary

| Effect | Stacks? | Duration model | Removed by |
| --- | --- | --- | --- |
| Bleed | No; highest applies, rest are stored | Until healed | Healing items/abilities |
| Poison | Yes, duration and damage | Wears off ~35% per Round | Cleanse items/abilities, wearing off |
| Cylinder | Replaces previous modifier | Until modified or fight ends | Another cylinder modifier, fight end |
| Mark | No | Until consumed or cleansed | Triggering, cleanse |
| Damage type mark | No | One Round | Cleanse, round end |
| Damage piercing | TBD | Amount of turns | Expiry |
| Damage decrease | TBD | Amount of turns | Expiry |
| Taunt | TBD | Amount of turns | Expiry |
| Silence | TBD | Amount of turns | Expiry |

## Classes

- Class decides character's base stats, stat increases, Rodeo, class abilities and the weapons they can hold
- Equipment affinities below are synergies, not restrictions: any class can wear any equipment (see Equipment)

| Class | Role | Weapons | Equipment affinity | Abilities work from | Targets |
| --- | --- | --- | --- | --- | --- |
| Gunslinger/Gunslinget | Damage | All lead weapons | Style | Positions 1-3 | All positions |
| Bobtail Guard | Anti-Style | Rifles | Sand | Positions 3-4 | All except enemy position 1 |
| Line Rider | Anti-Sand | Shotguns, lassos | Style | Positions 2-3 | All positions |
| Bottle Courage Bulldozer | Tank | Revolvers only | Sand | Position 1 | TBD |
| Dust Whisperer | Support/affliction | Explosives, lassos | Undecided (see Open Questions) | Positions 3-4 | TBD |

### Gunslinger/Gunslinget

- Damage class
- Abilities
	- Attack and self cylinder increase
	- Attack and bleed affliction
	- Self-increase damage type
	- Self-cleanse bleed

### Bobtail Guard

- Anti-style class
- Abilities
	- Attack and poison affliction
	- Cylinder drop affliction
	- Mark affliction

### Line Rider

- Anti-sand class
- Abilities
	- Poison cleanse
	- Self-increase damage piercing
	- Disrupt first and second position positioning

### Bottle Courage Bulldozer

- Tank class
- Abilities
	- Self-increase damage type defense
	- Self-taunt position
	- Cylinder increase application
	- Disrupt second and third position positioning

### Dust Whisperer

- High item modifiers
- Abilities
	- Bleed cleanse and affliction
	- Poison cleanse and affliction
	- Damage type mark applications
	- Damage decrease applications
	- Damage piercing application

## Rodeo

- A character's passive ability
- Lots of game-warping Rodeos
- Rodeo is active during combat
	- Always active
	- Activated at the beginning or at the end of the fight
	- Activated at the beginning or end of every Round
	- Activated at the beginning or end of every character Turn
- Decided by character class (how a Rodeo is chosen from the class list is TBD, see Open Questions)
	- Unique named characters can have unique Rodeos
	- Higher level characters have higher values for the Rodeo (if applicable)

## Weapons

- Lead weapons
	- Usually main weapons for characters
	- Can sometimes apply effects
	- Generally single-target
	- Revolvers
		- High damage against characters with no resistances
		- Both of the target's Style and Sand reduce damage; the higher value is used
	- Rifles
		- High damage against characters with high Style
		- The target's Style resistance increases damage, their Sand resistance lowers damage
	- Shotguns
		- High damage against characters with high Sand
		- The target's Sand resistance increases damage, their Style resistance lowers damage
- Explosive weapons
	- Main weapons for certain classes, like the Dust Whisperer
	- Applies and afflicts effects
	- Main purpose is to apply large amounts of effects to multiple enemies
	- Gunpowder Stick
		- Silence
	- Liquid Skull Bottle
		- Poison
	- Shrapnel Kaboom
		- Bleed
- Lasso weapons
	- Can be held by Line Riders and Dust Whisperers
	- Damage is not affected by stats; only weapon base damage is counted
		- Good for low damage scaling classes like the Dust Whisperer who benefit from high flat damage

Weapon family summary:

| Family | Strong against | Defensive type interaction |
| --- | --- | --- |
| Revolvers | Targets with no resistances | Higher of target's Style/Sand reduces damage |
| Rifles | High Style targets | Target's Style increases damage, Sand lowers it |
| Shotguns | High Sand targets | Target's Sand increases damage, Style lowers it |
| Explosives | Groups | Effect application over raw damage |
| Lassos | Anyone | Flat damage, ignores stats |

## Equipment

- Any class can wear any equipment; equipment types describe what a piece focuses on, and wearing off-affinity equipment involves tradeoffs
- Equipment types
	- General rules for equipment types, doesn't apply for all items
	- Generic
		- General-use equipment
		- Lower values or missing abilities compared to focused equipment
		- Generally, generic equipment should always have value in certain cases, even if more niche equipment is often better
	- Damage
		- Direct damage buffs and afflictions
		- Style resistances
		- Synergizes with Gunslingers and Line Riders
	- Affliction
		- Buffs to DOTs
		- Sand resistances
		- Synergizes with Bobtail Guards
	- Defense
		- Stats focused on defense
		- Only equipment type that can give defense to both damage types (with exceptions)
		- Synergizes with Bottle Courage Bulldozers
	- Utility
		- Applications and unique effects
		- Synergizes with Dust Whisperers
- Equipment pieces
	- John B.
		- Headwear
		- Low resistances
		- Most impactful moves
	- Bandana
		- Mostly cosmetic, low stats
		- No moves
		- Needed for some quests
	- Jacket
		- Highest resistances
		- No moves
	- Belt
		- Low resistances
		- Some impactful moves
		- Affects belt space in Shootouts
	- Pants
		- Medium resistances
		- Can have moves
	- Justins
		- Low-to-medium resistances
		- Moves are common

## Items

- Each character has a limited fight inventory, based on slots on their worn belt
- Using an item takes a Move
- Item types
	- Healing
		- Healing instantly or over time
		- Single- or multi-target
		- Can be used on other friendly characters
	- Affliction
		- Apply afflictions to enemies
		- Single- or multi-target
	- Cleanse
		- Cleanse afflictions
		- Single- or multi-target
		- Can be used on other friendly characters

## Death, injury and retreat

- Injury
	- Characters MxHP is modified by how much damage they have taken on any given journey
	- The more damage a character takes, the less MxHP they have in future fights
	- MxHP can be restored with bought camp items
	- MxHP resets when entering a town
- Knockout
	- Being knocked out gives additional debuffs for the next few Shootouts
- Retreat
	- Called Vamoose
	- Happens when all 4 gang members are downed
	- The party is thrown into the last visited town
	- Half of all loot is lost
	- If any quest is in progress, the party is thrown to the last checkpoint
- Fleeing
	- Possible after 15 turns
	- Lose a portion of money when fleeing

## Rewards

TBD. Winning a Shootout should grant cash and resources (several Rodeos already reference post-fight gains). Define XP/leveling and loot.

- Levels
	- Levels are gained on quest completion
	- So level progression follows quest progression
- Loot
	-

## Encounters

TBD. Define:

- How Shootouts start (overworld contact, ambushes, story)
- Typical party sizes and compositions (see Actors.md for NPC parties)
- Boss encounters and difficulty scaling
- How animals fight: do they have Cylinders, positions and classes?

Shootouts happen in three ways: in Overworld events, in Locations as ambushes, and during story quests

- Overworld events can have multiple results based on chosen options
- Ambushes are randomly spawned in Locations 

## Balance

- Weapons
	- TBD
- Defensive damage types
	- Style and Sand
	- With two types, hopefully balancing is easier and makes gameplay more varied
	- Hopefully creates a sort of rock-paper-scissors dynamic
- Target metrics (TBD)
	- Average Shootout length in Rounds
		- 5-10 rounds
		- Shootouts should be more about attrition, expect in quests where the difficulty is higher
	- Expected hits-to-kill per class archetype
	- Healing economy per fight
		- Healing is generally reserved for rare difficult fights and quest Shootouts
		-
	- Item scarcity goals for belt space
		- Low item classes like Pistolero should only have 0-1 slots
		- Dust Whisperers can have up to 5 slots
		- Other classes are in between 1-4

## Open Questions

1. Dust Whisperer equipment: a dedicated Utility type, Generic only, or no equipment at all (compensated by high item modifiers)?
	- Dust Whisperers have a dedicated Utility equipment type(need a more western name)
2. Do lassos count towards the Gunslinger's weapon pool (currently lassos are Line Rider + Dust Whisperer only)?
	- No
3. Is lasso damage truly flat, or do some modifiers (damage piercing, marks) still apply?
	- Lasso damage can be modified, just not by character stats
4. Is turn order re-rolled every Round, or set once at the start of a Shootout? (Current implementation sorts once by High Tailin'.)
	- Re-rolled every round
5. Cylinder visibility: can the player see their own full Cylinder? Enemies' Cylinders?
	- Player can see both their and the enemys Cylinders
6. Chamber clamping: final Chamber values are clamped to 0-3; consider wrapping instead?
	- Use clamping
7. Resistance model: chance to resist application vs. percentage reduction of effect potency? Which effects do resistances apply to?
	- Percentage reduction to effect potency
	- Applied to bleed and poison
8. Do Marks expire if never triggered?
	- Expires after a turn or two
9. Special Chambers: exact behavior of Reload and Jammed (proposed: Reload = Move spent reloading, no attack; Jammed = attack fails)
	- Defined earlier in the doc
10. How is a character's Rodeo chosen from the class list (random at recruitment, player choice, unlocked by level)?
	- The gang members have predefined Rodeos
	- Exception is Walker, who'se Rodeo changes every quest completion
	- Other characters with unique names their own unique Rodeos
	- Generic enemies can also have Rodeos, but not all of them
11. Taunt details: does it redirect multi-target attacks? What breaks it (caster death, displacement, cleanse)?
	- Taunt redirects multi-target attacks for each protected position
	- Taunt isn't broken by anything, it runs out of Rounds, after which it needs to be re-applied
12. Do damage piercing and damage decrease effects stack with themselves?
	- This has to be decided after armor calculations are built
13. Can items target allies in any position?
	- Yes
14. Silence: exact scope (Abilities only, or also Ducks and items?)
	- Abilities only
