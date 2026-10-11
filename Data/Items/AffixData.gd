## Affix stat definitions and prefix/suffix pools for item generation.
## Design source: Docs/Weapons and affixes.md
##
## NOTE: All numeric ranges are PLACEHOLDERS chosen for initial balancing.
## Bounds are per-rarity ({ "common"/"uncommon"/"rare"/"epic": { "min",
## "max" } }) and are rolled with the item's rarity (see
## Globals/ItemGeneration.gd _rollAffixValue()). Flag stats (silenceImmunity)
## are never rolled, so they use a single placeholder bound.


var statValues = {
	"revolverDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"rifleDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"shotgunDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"gunpowderDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"liquidSkullDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"liquidSkullDuration": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"shrapnelDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"lassoDamage": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"damageVsMarked": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"cylinderIncrease": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"highTailin": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"sixShootin": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"taffyin": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"mxHp": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"mxEn": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"style": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"sand": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"initiative": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"turnOrder": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"negativeEffectPotencyReduction": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"negativeEffectDurationReduction": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"damagePiercing": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"damageTakenReduction": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"damageTakenReductionTaunting": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"mxHpHealTauntingPerTurn": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	# Flag stat: the value is never rolled (flags always grant 1), so a single
	# placeholder bound is enough.
	"silenceImmunity": { "min": 1, "max": 1 },
	"lootGold": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"lootItems": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"lootGems": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"poisonAffliction": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
	"bleedAffliction": {
		"common": { "min": 5, "max": 15 },
		"uncommon": { "min": 10, "max": 20 },
		"rare": { "min": 20, "max": 25 },
		"epic": { "min": 25, "max": 30 },
	},
}

## Rollable affix stats.
## kind: "percent" (percentage modifier), "flat" (flat points), "flag" (boolean on/off)
## category: "offense"/"defense"/"utility"/"status", following the design
## doc's prefix groupings (explosive damage affixes sit under Status). Used to
## color affixes and keywords in the item display.
var stats = {
	"revolverDamage": { "displayName": "Revolver damage", "kind": "flat", "value": statValues.revolverDamage, "category": "offense" },
	"rifleDamage": { "displayName": "Rifle damage", "kind": "flat", "value": statValues.rifleDamage, "category": "offense" },
	"shotgunDamage": { "displayName": "Shotgun damage", "kind": "flat", "value": statValues.shotgunDamage, "category": "offense" },
	"gunpowderDamage": { "displayName": "Gunpowder stick damage", "kind": "flat", "value": statValues.gunpowderDamage, "category": "status" },
	"liquidSkullDamage": { "displayName": "Liquid skull damage", "kind": "flat", "value": statValues.liquidSkullDamage, "category": "status" },
	"liquidSkullDuration": { "displayName": "Liquid skull duration", "kind": "flat", "value": statValues.liquidSkullDuration, "category": "status" },
	"shrapnelDamage": { "displayName": "Shrapnel boom damage", "kind": "flat", "value": statValues.shrapnelDamage, "category": "status" },
	"lassoDamage": { "displayName": "Lasso damage increase", "kind": "flat", "value": statValues.lassoDamage, "category": "offense" },
	"damageVsMarked": { "displayName": "Damage against marked", "kind": "percent", "value": statValues.damageVsMarked, "category": "offense" },
	"damagePiercing": { "displayName": "Damage piercing", "kind": "flat", "value": statValues.damagePiercing, "category": "offense" },
	"cylinderIncrease": { "displayName": "Cylinder increase", "kind": "flat", "value": statValues.cylinderIncrease, "category": "offense" },
	"highTailin": { "displayName": "High Tailin'", "kind": "flat", "value": statValues.highTailin, "category": "utility" },
	"sixShootin": { "displayName": "Six Shootin'", "kind": "flat", "value": statValues.sixShootin, "category": "utility" },
	"taffyin": { "displayName": "Taffyin'", "kind": "flat", "value": statValues.taffyin, "category": "utility" },
	"mxHp": { "displayName": "MxHp", "kind": "flat", "value": statValues.mxHp, "category": "defense" },
	"mxEn": { "displayName": "MxEn", "kind": "flat", "value": statValues.mxEn, "category": "defense" },
	"style": { "displayName": "Style", "kind": "flat", "value": statValues.style, "category": "defense" },
	"sand": { "displayName": "Sand", "kind": "flat", "value": statValues.sand, "category": "defense" },
	"initiative": { "displayName": "Initiative", "kind": "flat", "value": statValues.initiative, "category": "utility" },
	"turnOrder": { "displayName": "Turn order", "kind": "flat", "value": statValues.turnOrder, "category": "utility" },
	"negativeEffectPotencyReduction": { "displayName": "Negative effect potency reduction", "kind": "percent", "value": statValues.negativeEffectPotencyReduction, "category": "defense" },
	"negativeEffectDurationReduction": { "displayName": "Negative effect duration reduction", "kind": "percent", "value": statValues.negativeEffectDurationReduction, "category": "defense" },
	"damageTakenReduction": { "displayName": "Damage taken reduction", "kind": "percent", "value": statValues.damageTakenReduction, "category": "defense" },
	"damageTakenReductionTaunting": { "displayName": "Damage taken reduction when taunting", "kind": "percent", "value": statValues.damageTakenReductionTaunting, "category": "defense" },
	"mxHpHealTauntingPerTurn": { "displayName": "MxHp healed when taunting per turn", "kind": "flat", "value": statValues.mxHpHealTauntingPerTurn, "category": "defense" },
	"silenceImmunity": { "displayName": "Silence immunity", "kind": "flag", "value": statValues.silenceImmunity, "category": "status" },
	"lootGold": { "displayName": "Increased loot (gold)", "kind": "percent", "value": statValues.lootGold, "category": "utility" },
	"lootItems": { "displayName": "Increased loot (items)", "kind": "percent", "value": statValues.lootItems, "category": "utility" },
	"lootGems": { "displayName": "Increased loot (gems)", "kind": "percent", "value": statValues.lootGems, "category": "utility" },
	"poisonAffliction": { "displayName": "Poison affliction", "kind": "flat", "value": statValues.poisonAffliction, "category": "status" },
	"bleedAffliction": { "displayName": "Bleed affliction", "kind": "flat", "value": statValues.bleedAffliction, "category": "status" },
}

## Prefixes, grouped by category (design doc grouping kept for reference/future weighting).
var prefixes = {
	"offense": {
		"Deadeye's": "cylinderIncrease",
		"Gunslinger's": "revolverDamage",
		"Smokewagon": "shotgunDamage",
		"Bloodied": "damageVsMarked",
		"Sharpshot": "rifleDamage",
		"Widowmaker's": "damagePiercing",
	},
	"defense": {
		"Ironclad": "sand",
		"Ace-high": "style",
		"Stonewall": "mxHpHealTauntingPerTurn",
		"Rawhide-Tough": "mxHp",
		"Undertaker's": "damageTakenReduction",
		"Grizzled": "mxEn",
		"Bronco": "negativeEffectPotencyReduction",
	},
	"utility": {
		"Cowboys": "sixShootin",
		"Fleet-Footed": "highTailin",
		"Coyote's": "initiative",
		"Sundance": "turnOrder",
		"Prospector's": "lootGems",
		"Silver-Tongued": "taffyin",
		"Stagecoach's": "lootItems",
	},
	"status": {
		"Rattlesnake's": "poisonAffliction",
		"Firebrand": "bleedAffliction",
		"Thunderhead's": "gunpowderDamage",
		"Saloon-Forged": "liquidSkullDamage",
		"Whiskey-Soaked": "liquidSkullDuration",
		"Dusty": "silenceImmunity",
	},
}

## Suffixes. Names include the "of the ..." part so they can be appended to the
## item name directly.
## NOTE: "of the Hangman" and "of the Prairie Wolf" both roll damageVsMarked,
## and "of the High Roller" / "of the Dead Reckoning" both roll cylinderIncrease
## (duplicates as written in the design doc).
## NOTE: "of the Snake Charmer" is "Poison potency reduction" in the doc; it is
## mapped to the generic negativeEffectPotencyReduction stat (assumption).
var suffixes = {
	"of the Long Rider": "initiative",
	"of the Tinkerers": "damagePiercing",
	"of the Quickdraw": "highTailin",
	"of the Hangman": "damageVsMarked",
	"of the Prairie Wolf": "damageVsMarked",
	"of the Iron Horse": "damageTakenReduction",
	"of the Lonesome Trail": "rifleDamage",
	"of the High Roller": "cylinderIncrease",
	"of the Snake Charmer": "negativeEffectPotencyReduction",
	"of the Last Stand": "damageTakenReductionTaunting",
	"of the Six Feet Under": "shrapnelDamage",
	"of the Gold Rush": "lootGold",
	"of the Dead Reckoning": "cylinderIncrease",
	"of the Cattleherder": "lassoDamage",
	"of the Poker Face": "negativeEffectDurationReduction",
	"of the Mother Lode": "lootGems",
	"of the Lucky Horseshoe": "lootItems",
}
