# Combat

Notes for combat.

## Overview

	*Combat encounters are called Shootouts
    *Turn-based combat
		*Each turn, every character gets to take an action
		*Turn order is based on High Tailin' stat and other modifiers
			*On even stat, turn order is random
	*Character actions
		*Attack
			*Attack target(s) with held weapon
		*Ability
			*Use one of characters abilities
		*Item
			*Use item on belt
		*Duck
			*Changes characters cylinders to be one lower for the turn
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
			*Each cylinder pattern Chamber index can have a value between -3-3
			*All of the cylinder pattern Magazines get added up to form the final cylinder pattern
				*Each index for all Magazines is added for the final cylinder pattern index
		*Cylinder patterns are always divisible by 4
			*If a cylinder pattern of a Chamber is shorter than another Magazines, it gets repeated till it matches the longest cylinder pattern
		*At the start of combat, characters get placed at the beginning of their cylinder pattern
			*For each turn, they advance one in their cylinder pattern
			*When the Cylinder ends, it jumps back to the beginning of the cylinder pattern
		*Cylinders can have special cylinder indexes, eg. Reload
	*Positions
		*Characters have a position in fights
		*DD style positioning, with a 3x3 grid (3 height, 3 width)
		*Characters can use a turn to move between adjacent positions in a fight
		*Specific weapons can fire only from specific friendly columns, and target only specific enemy columns

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
				*Melee
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
			*Damage every character turn start
			*Won't stop until healed with items or abilities
			*Doesn't stack
		*Poison
			*Damage every turn start
			*Slowly wears off
			*Can stack
		*Cylinder
			*Cylinders for character increase or decrease
			*Can target specific cylinder index or all cylinders
			*Won't change until modified with another cylinder modifier
		*Mark
			*Mark a character
			*After one turn, dealing damage to the character deals extra damage
			*Can be cleansed with items or abilities
			*Doesn't stack
		*Damage type mark
			*Mark a character
			*Dealing damage to the character with a specific damage type deals extra damage
			*Can be cleansed with items or abilities
			*Doesn't stack
		*Damage piercing
			*Increases characters damage piercing against a defensive damage types
			*Lasts for an amount of turns
		*Damage decrease
			*Decreases characters damage against a defensive damage type
			*Lasts for an amount of turns
		*Taunt
			*Taunt friendly row or column character is standing on
			*All targeted characters on taunted tiles get directed to the taunt caster
			*Defensive buffs to the caster on taunted attacks
			*Lasts for an amount of turns
		*Silence
			*Disable abilities
			*Lasts for an amount of turns

## Classes
	*Class decides characters base stats, stat increases, Rodeo, class abilities and weapons and equipment that they can hold
	*Gunslinger/Gunslinget
		*Damage class
		*Can hold all weapons
		*Can wear most equipment
		*Abilities work in first and second column
		*Abilities
			*Attack and self-increase hit rate
			*Attack and bleed affliction
			*Self-increase damage type
			*Self-cleanse bleed
	*Bobtail Guard
		*Anti-style class
		*Can hold rifles
		*Can wear most equipment
		*Abilities work in second and third column
		*Targets backrows
		*Abilities
			*Attack and poison affliction
			*Cylinder drop affliction
			*Mark affliction
	*Line Rider
		*Anti-sand class
		*Can hold shotguns
		*Can wear most equipment
		*Abilities work in second column
		*Targets frontrows
		*Abilities
			*Poison cleanse
			*Self-increase damage piercing
			*Disrupt first and second column positioning
	*Bottle Courage Bulldozer
		*Tank class
		*Can't hold rifles or shotguns
		*Can wear any equipment
		*Abilities work in first column
		*Abilities
			*Self-increase damage type defense
			*Self-taunt current row or column
			*Cylinder increase application
			*Disrupt second and third column positioning
	*Dust Whisperer
		*Can't hold lead weapons
		*Can wear less equipment than other classes
		*High item modifiers
		*Abilities work in third column
		*Abilities
			*Bleed cleanse and affliction
			*Poison cleanse and affliction
			*Damage type mark applications
			*Damage decrease applications
			*Damage piercing application

## Rodeo
	*Characters passive ability
	*Rodeo is active during combat
		*Always active
		*Activated at the beginning or at the end of the fight
		*Activated at the beginning or end of every turn
		*Activated at the beginning or end of every character turn
	*Decided by character class
		*Unique named characters can have unique Rodeos
		*Higher level characters have higher values for the Rodeo (if applicable)

## Abilities
	*Characters can have abilities based on their class and worn equipment
	*Class abilities
		*Usually focused on utility
	*Equipment abilities
		*Usually focused on damage

## Weapons
	*Lead weapons
		*Usually main weapons for human characters
		*Can sometimes apply effects
		*Generally single-target
		*Revolvers
			*High damage against characters with no resistances
			*Both Style and Sand affect damage
				*Higher value is used
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

## Equipment
	*Equipment has types that decide which classes can wear them and what stats they generally give
	*Equipment types
		*Generic
			*All classes can wear
			*General-use equipment
			*Generic equipment should always have value, even if more niche equipment is better for a given situation
		*Damage
			*Gunslingers and Bobtail guards can wear
			*Direct damage buffs and afflictions
			*Style resistances
		*Dot
			*Gunslingers and Line Riders can wear
			*Buffs to DOTs
			*Sand resistances
		*Tank
			*Gunslingers and Bottle Courage Bulldozers can wear
			*Stats focused on defense
			*Only equipment type that can give defense to both damage types(with exceptions)
		*Utility
			*Bottle Courage Bulldozers and Dust Whisperers can wear
			*Applications and unique effects
	*Equipment pieces
		*John B.
			*Headwear
			*Low resistances
			*Most impactfull skills
		*Bandana
			*Mostly cosmetic
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

## Balance
    *Defensive damage types
		*Style
	*Weapons
		*Revolvers are general use weapons that can be used by non-Dust Whisperer classes
		*Rifles are anti-style weapons that can be used by Gunslingers and Bobtail Guards
		*Shotguns are anti-sand weapons that can be used by Gunslingers and Line Riders
