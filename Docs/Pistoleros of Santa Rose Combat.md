
# Overview

    *Turn-based combat
		*Each turn, every character gets a move
			*Turn order is base on High Tailin' stat and other modifiers
				*On even stat, turn order is random
	*Character actions
		*Attack
			*Attack target(s) with held weapon
		*Ability
			*Use one of characters abilities
		*Item
			*Use held item
		*Duck
			*Changes characters hits to be one lower
	*Hit-rates
		*Hit-rate or a hit-rate pattern is a sequence of numbers
		*Hit-rate decides the quality of an attack
			*Hit-rate quality is between 0-3
				*0 is Miss
				*1 is Graze
				*2 is Hit
				*3 is Critical Hit
		*Each character, class and weapon has a hit-rate pattern
			*These individual hit-rate patterns are called Prototypes
			*All of the hit-rate pattern prototypes get added up to form the final hit-rate pattern
				*Each index for all prototypes is added for the final hit-rate pattern
			*
		*Hit-rate patterns are always divisible by 4
			*If a hit-rate pattern of something is shorter than another one, it gets repeated till it
			 matches the longest hit-rate pattern
		*At the start of combat, characters get placed randomly on their hit-rate pattern
			*For each turn, they advance one in their hit-rate pattern
			*When the hit-rate pattern ends, it jumps back to the beginning of the hit-rate pattern
		*Hit-rates can have special hit-rate indexes, eg. Reload
	*Positions
		*Characters have a position in fights
		*DD style positioning, with a 3x4 grid (3 height, 4 width)
		*Characters can move between positions in a fight
		*Specific weapons can fire only from specific friendly columns, and target only specific enemy columns

### Stats

	*Stats are based on character base stats, held weapon and worn equipment and item modifiers
	*Stats have some random variance
	*Types
		*Initiative
			*Initiative decides turn order on each turn
			*Calculations
				*Base level is decided by High Tailin'
				*Influenced by Rodeo and item modifiers
		*Damage types
			*Damage types decide the damage that character deals and takes

			*Offensive
				*Lead
					*Base level is decided by Six Shootin'
					*Influenced by Rodeo and item modifiers
				*Explosive
					*Base level is decided by class
					*Influenced by Rodeo and item modifiers
				*Melee
					*Base level is decided by weapon damage
			*Defensive
				*Style
					*Base level is decided by equipment and Taffyin'
				*Sand
					*Base level is decided by equipment and 

### Effects
	*Characters can be applied or afflicted effects
	*Types
		*Bleed
			*Damage every character turn start
			*Won't stop until healed with items or abilities
			*Doesn't stack
		*Poison
			*Damage every turn start
			*Slowly wears off
			*Can stack
		*Hit-rate
			*Hit-rates for character increase or drop
			*Can target specific hit-rate index or all hit-rates
			*Won't change until modified with another hit-rate modifier
		*

### Classes
	*Class decides characters stat increases, Rodeo, class abilities and weapons and equipment that they can hold
	*Damage class
		*Can hold most weapons
		*Can wear most equipment

### Rodeo
	*Characters passive ability
	*Rodeo is active during combat
		*Can be always active or activated at the beginning or the end of the fight or
		 beginning or end of every turn or character turn
	*Decided by character class
		*Unique named characters can have unique Rodeos
		*Higher level characters have higher values for the Rodeo (if applicable)

### Abilities
	*Characters can have abilities based on their class and worn equipment
	*Class abilities
		*
	*Equipment abilities
		*


			*Characters have different stats and abilities based on class, equipment and something else too?
	*Major encounter combat
		*Every character takes a turn
			*Characters initiative decides who goes first
			*Even initiative makes it random which character goes first
		*Actions
			*Attacks
				*Weapons have different attacks
				*Some unique weapons have unique attacks
			*Abilities
				*Character specific
				*Usable items
			*Take cover
				*Taking cover changes first or more hits on character to hit, graze or miss
			*Run
				*Attempt escape from fight
				*Result
					*Fail, lose turn for whole team
					*Barely escape, escape, take damage and enemies are immobilized at location for a very short time
					*Comfortably escape, escape and enemies are dazed at location for a short time
					*Easily escape, escape and enemies disappear from location

### Weapons
	*Lead weapons
		*Usually main weapons for human characters
		*Revolvers
			*High damage against characters with no resistances
			*Both Style and Sand affect damage
			*Can usually hit most rows
		*Rifles
			*High damage against characters with high Style
			*Style resistance increases damage, Sand resistance lowers damage
			*Can usually only hit the back rows
		*Shotguns
			*High damage against characters with high Sand
			*Sand resistance increases damage, Style resistance lowers damage
			*Can usually only hit the front rows
	*Explosive weapons
		*Gunpowder
			*
		*Liquid
			*
		*
			*
	*Melee weapons
		*Damage not affected by stats, only weapon base damage is counted
		*Mostly used by animals

### Balance
    *
