# Combat

Notes for combat.

## Overview

	*Combat encounters are called Shootouts
    *Turn-based combat
		*Each turn, every character gets to take an action
		*Turn order is based on High Tailin' stat and other modifiers
			*On even stat, turn order is random
	*Character actions
		*Four actions max in fights for any given character
		*Actions can be activated and deactivated outside of fights
		*Action types depend on what class and name the character has
			*Attacks
				*Attack target(s) with held weapon, with any modifiers applied from the attacks
			*Abilities
				*Characters can have abilities based on their class and worn equipment
				*Class abilities
					*Usually focused on utility
				*Equipment abilities
					*Usually focused on damage
			*Items
				*Consumables that can have varying effects
				*Amount that can be brought to a Shootout is decided by belt space
				*Limited amounts, must be bought at town areas
			*Ducks
				*Defensive moves that apply buffs to allied characters
	*Cylinders
		*Cylinder or a cylinder pattern is a sequence of numbers
		*Each number in a Cylinder is called a Chamber
			*Chamber decides the quality of an attack
				*Chamber quality is between 0-3
					*0 is Miss
					*1 is Graze
					*2 is Hit
					*3 is Critical Hit
		*Each character, class and weapon has a cylinder pattern
			*These individual cylinder patterns are called Magazines
			*Each cylinder pattern Chamber index can have a value between -3 to 3
			*All of the cylinder pattern Magazines get added up to form the final cylinder pattern
				*Each index for all Magazines is added for the final cylinder pattern index
		*Cylinder patterns are always a length of 6
		*At the start of combat, characters get placed at the beginning of their cylinder pattern
			*For each turn they take, they advance one in their cylinder pattern
			*When the Cylinder ends, it jumps back to the beginning of the cylinder pattern
		*Cylinders can have special cylinder indexes, eg. Reload, Jammed, that are additional Chambers on top of the usual 6
			*The special indexes cannot be modified
	*Positions
		*Characters have a position in fights
		*Darkest Dungeon style positioning, with 4 positions
		*Characters can use a turn to move between adjacent positions in a fight
		*Specific weapons and attacks can fire only from specific friendly columns, and target only specific enemy columns

## Stats
	*Stats are based on characters base stats, held weapon, worn equipment and item modifiers
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
				*Lasso
					*Base level is decided by weapon damage
			*Defensive
				*Style
					*Base level is decided by equipment and Taffyin'
				*Sand
					*Base level is decided by equipment and class
		*Resistances
			*Damage reduction to negative effects

## Effects
	*Characters can be applied or afflicted effects
	*Types
		*Bleed
			*Damage every afflicted character turn start
			*Won't stop until healed with items or abilities
			*Doesn't stack, only highest affliction applies
		*Poison
			*Damage every whole turn start
			*Slowly wears off, some percentage like 35%
			*Can stack
		*Cylinder
			*Character increase or decrease for cylinders
			*Can target specific cylinder index or all cylinders
			*Won't change until modified with another cylinder modifier, or after fight ends
		*Mark
			*Mark a character
			*After one whole turn, dealing damage to the character deals extra damage, consuming the mark
			*Can be cleansed with items or abilities
			*Doesn't stack
		*Damage type mark
			*Mark a character
			*Dealing damage to the character with a specific damage type deals extra damage, keeping the mark for the turn
			*Can be cleansed with items or abilities
			*Doesn't stack
		*Damage piercing
			*Increases characters damage piercing against a defensive damage type
			*Lasts for an amount of turns
		*Damage decrease
			*Decreases characters damage against a defensive damage type
			*Lasts for an amount of turns
		*Taunt
			*Taunt friendly positions characters are standing on
			*All targeted characters on taunted tiles get directed to the taunt caster
			*Defensive buffs to the caster on taunted attacks
			*Lasts for an amount of turns

## Classes
	*Class decides characters base stats, stat increases, Rodeo, class abilities and weapons and equipment that they can hold
	*Gunslinger/Gunslinget
		*Damage class
		*Can hold all weapons
		*Can wear Style equipment
		*Abilities work in first, second and third rows
		*Targets all rows
		*Abilities
			*Attack and self-increase hit rate
			*Attack and bleed affliction
			*Self-increase damage type
			*Self-cleanse bleed
	*Bobtail Guard
		*Anti-style class
		*Can hold rifles
		*Can wear Sand equipment
		*Abilities work in third and fourth rows
		*Can't target the first row
		*Abilities
			*Attack and poison affliction
			*Cylinder drop affliction
			*Mark affliction
	*Line Rider
		*Anti-sand class
		*Can hold shotguns
		*Can wear Style equipment
		*Abilities work in second and third columns
		*Targets all rows
		*Abilities
			*Poison cleanse
			*Self-increase damage piercing
			*Disrupt first and second column positioning
	*Bottle Courage Bulldozer
		*Tank class
		*Can't hold rifles or shotguns
		*Can wear Sand equipment
		*Abilities work in first column
		*Abilities
			*Self-increase damage type defense
			*Self-taunt column
			*Cylinder increase application
			*Disrupt second and third column positioning
	*Dust Whisperer
		*Can't hold lead weapons
		*Can wear less equipment than other classes, maybe no equipment classes at all? Only non-style and non-sand equipment?
		*High item modifiers
		*Abilities work in third and fourth row
		*Abilities
			*Bleed cleanse and affliction
			*Poison cleanse and affliction
			*Damage type mark applications
			*Damage decrease applications
			*Damage piercing application

## Rodeo
	*Characters passive ability
	*Lots of game-warping Rodeos
	*Rodeo is active during combat
		*Always active
		*Activated at the beginning or at the end of the fight
		*Activated at the beginning or end of every whole turn
		*Activated at the beginning or end of every character turn
	*Decided by character class
		*Unique named characters can have unique Rodeos
		*Higher level characters have higher values for the Rodeo (if applicable)

## Weapons
	*Lead weapons
		*Usually main weapons for human characters
		*Can sometimes apply effects
		*Generally single-target
		*Revolvers
			*High damage against characters with no resistances
			*Both Style and Sand affect damage
				*Higher value is used
		*Rifles
			*High damage against characters with high Style
			*Style resistance increases damage, Sand resistance lowers damage
		*Shotguns
			*High damage against characters with high Sand
			*Sand resistance increases damage, Style resistance lowers damage
	*Explosive weapons
		*Main weapons for certain classes, like the Dust Whisperer
		*Applies and afflicts effects
		*Main purpose is to apply large amounts of effects to multiple enemies
		*Gunpowder Stick
			*Silence
		*Liquid Skull Bottle
			*Poison
		*Shrapnel Kaboom
			*Bleed
	*Lasso weapons
		*Damage not affected by stats, only weapon base damage is counted?
			*Good for low damage scaling classes like the Dust Whisperer who benefit from high flat damage

## Equipment
	*Equipment has types that decide which classes can wear them and what stats they generally give
	*Equipment types
		*Generic
			*All classes can wear
			*General-use equipment
			*Lower values or missing abilities compared to class specific equipment
			*Generic equipment should always have value in certain cases, even if more niche equipment is often better
		*Damage class equipment
			*Gunslingers and Lineriders can wear
			*Direct damage buffs and afflictions
			*Style resistances
		*Tank class equipment
			*Bobtail Guards and Line Riders can wear
			*Buffs to DOTs
			*Sand resistances
		*Tank
			*Gunslingers and Bottle Courage Bulldozers can wear
			*Stats focused on defense
			*Only equipment type that can give defense to both damage types(with exceptions)
		*Utility
			*Dust Whisperers can wear
			*Applications and unique effects
	*Equipment pieces
		*John B.
			*Headwear
			*Low resistances
			*Most impactfull skills
		*Bandana
			*Mostly cosmetic, low stats
			*No skills
			*Needed for some quests
		*Jacket
			*Highest resistances
			*No skills
		*Belt
			*Low resistances
			*Some impactfull skills
			*Affects belt space in Shootouts
		*Pants
			*Medium resistances
			*Can have skills
		*Justins
			*Low-to-medium resistances
			*Skills are common


## Items
	*Characters have a limited fight inventory, based on slots on belt
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

## Balance
	*Weapons
		*TBD
    *Defensive damage types
		*Style and Sand
		*With two types, hopefully balancing is easier and makes gameplay more varied
		*Hopefully creates sort of rock-paper-scissor-dynamic
