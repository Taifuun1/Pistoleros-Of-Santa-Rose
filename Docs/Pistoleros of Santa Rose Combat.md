
# Overview

    *Turn-based combat
		*Each turn, every character gets to take an action
		*Turn order is base on High Tailin' stat and other modifiers
			*On even stat, turn order is random
	*Character actions
		*Attack
			*Attack target(s) with held weapon
		*Ability
			*Use one of characters abilities
		*Item
			*Use item on belt
		*Duck
			*Changes characters hit-rates to be one lower
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
			*Each hit-rate pattern Prototype index can have a value between -3-3
			*All of the hit-rate pattern Prototypes get added up to form the final hit-rate pattern
				*Each index for all Prototypes is added for the final hit-rate pattern
		*Hit-rate patterns are always divisible by 4
			*If a hit-rate pattern of a Prototype is shorter than another Prototypes, it gets repeated till it
			 matches the longest hit-rate pattern
		*At the start of combat, characters get placed randomly on their hit-rate pattern
			*For each turn, they advance one in their hit-rate pattern
			*When the hit-rate pattern ends, it jumps back to the beginning of the hit-rate pattern
		*Hit-rates can have special hit-rate indexes, eg. Reload
	*Positions
		*Characters have a position in fights
		*DD style positioning, with a 3x4 grid (3 height, 4 width)
		*Characters can use  a turn to move between adjacent positions in a fight
		*Specific weapons can fire only from specific friendly columns, and target only specific enemy columns

### Stats

	*Stats are based on characters base stats, held weapon, worn equipment and item modifiers
	*Stats have some random variance in fights
	*Types
		*Initiative
			*Initiative decides turn order on each turn
			*Calculations
				*Base level is decided by High Tailin'
				*Influenced by Rodeo and item modifiers
		*Damage types
			*Damage types decide the damage that a character deals and takes
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
					*Base level is decided by equipment and class
		*Resistances
			*Damage reduction to negative effects

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
		*Mark
			*Mark a character
			*After one turn, dealing damage to the character deals extra damage
			*Can be cleansed with items or abilities
			*Doesn't stack
		*Damage piercing
			*Increases characters damage piercing against a defensive damage types
			*Lasts for an amount of turns
		*Taunt
			*Taunt friendly row or column character is standing on
			*All targeted characters on taunted tiles get directed to the taunt caster
			*Lasts for an amount of turns
		*Silence
			*Disable abilities
			*Lasts for an amount of turns

### Classes
	*Class decides characters stat increases, Rodeo, class abilities and weapons and equipment that they can hold
	*Damage class
		*Can hold most weapons
		*Can wear most equipment
		*Abilities
			*Self-increase damage type
			*Self-cleanse bleed
	*Anti-style class
		*Can hold rifles
		*Can wear most equipment
		*Targets backrows
		*Abilities
			*Hit-rate drop affliction
			*Mark affliction
	*Anti-sand class
		*Can hold shotguns
		*Can wear most equipment
		*Targets frontrows
		*Abilities
			*Poison cleanse
			*Self-increase damage piercing
	*Tank class
		*Can't hold rifles or shotguns
		*Can wear any equipment
		*Abilities
			*Self-increase damage type defense
			*Self-taunt current row or column
			*Hit-rate increase application
	*Support class
		*Can't hold lead weapons
		*Can wear less equipment than other classes
		*Abilities
			*Bleed cleanse and affliction
			*Poison cleanse and affliction
			*Damage piercing application

### Rodeo
	*Characters passive ability
	*Rodeo is active during combat
		*Always active
		*Activated at the beginning or the end of the fight
		*Activated at the beginning or end of every turn
		*Activated at the beginning or end of every turn character turn
	*Decided by character class
		*Unique named characters can have unique Rodeos
		*Higher level characters have higher values for the Rodeo (if applicable)

### Abilities
	*Characters can have abilities based on their class and worn equipment
	*Class abilities
		*Usually focused on utility
	*Equipment abilities
		*Usually focused on damage

### Weapons
	*Lead weapons
		*Usually main weapons for human characters
		*Can sometimes apply effects
		*Generally single-target
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
		*Main weapons for certain classes
		*Applies and afflicts effects
		*Main purpose is to apply large amounts of effects to multiple enemies
		*Gunpowder
			*Silence
		*Liquid
			*Poison
		*Shrapnel
			*Bleed
	*Melee weapons
		*Damage not affected by stats, only weapon base damage is counted
		*Mostly used by animals

### Items
	*Characters have a limited fight inventory
	*Using an item takes a turn
	*Item types
		*Healing
			*Healing instantly or over time
			*Single- or multi-target
			*Can be used on other friendly characters
		*Affliction
			*Apply afflictions to enemies
			*Single- or multi-target
		*Cleanse
			*Cleanse afflictions
			*Single- or multi-target
			*Can be used on other friendly characters

### Balance
    *Defensive damage types
		*
	*Weapons
		*Revolvers are general use weapons that can be used by non-support classes
		*
