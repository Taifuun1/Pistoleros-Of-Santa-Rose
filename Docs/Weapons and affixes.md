
# Weapons, equipment and affixes

Names for weapons, equipment and affixes. Rollable affix stats. Rarity tiers for weapons and equipment.

Affixes are rolled with item type, rarity, and zone as parameters. Type will set wich type of item the rolled item will be(Revolver, Johnny B. etc.). Rarity is decided by the level of the party, which is tied to main quest progression — rolled items always use the party's current main quest rarity; a specific rarity can also be passed as a parameter when generating an item directly. Rarity is the item's power tier — items have no separate tier stat. The current zone for the party sets the zone. Each type of equipment has restrictions on which affixes it can roll(defined loosely in [Combat doc](Combat.md)). Affixes are tied to specific stats. Every rolled item always gets two affixes regardless of rarity; each affix is chosen based on a random stat line. Unique modifiers and flavour texts are reserved for unique items. The UI node for an item is in [Item Stat node](../Nodes/Item%20Stats/ItemStats.tscn).

## Rarity (Common → Unique)

- **Trail-Worn** (common)
- **Serviceable** (uncommon)
- **Well-Kept** (rare)
- **Storied** (epic)
- **Legendary of the West** (unique tier — one-of-a-kind named items, no random affixes, they have their own lore, unique modifiers and fixed stats)

## Affix stats

Affix stat values are rolled per rarity. Flag stats (Silence immunity) grant their effect instead of rolling a numeric value.

Revolver damage
Rifle damage
Shotgun damage
Gunpowder stick damage
Liquid skull damage
Liquid skull duration
Shrapnel boom damage
Lasso damage increase
Damage against marked
Cylinder increase
High Tailin'
Six Shootin'
Taffyin'
MxHp
MxEn
Style increase
Sand increase
Initiative increase
Turn order increase
Reduce negative effect potency
Reduce negative effect duration
Damage piercing
Damage taken reduction
Damage taken reduction when taunting
Mxhp healed when taunting per turn
Silence immunity
Increased loot (gold)
Increased loot (items)
Increased loot (gems)
Poison affliction
Bleed affliction

## Prefixes

### Offense

Deadeye's — Cylinder increase
Gunslinger's — Revolver damage
Smokewagon — Shotgun damage
Bloodied — Damage versus marked
Sharpshot — Rifle damage
Widowmaker's — Damage piercing

### Defense

Ironclad — Sand
Ace-high - Style
Stonewall — Mxhp healed when taunting per turn
Rawhide-Tough — MxHP
Undertaker's — Damage taken reduction
Grizzled — MxEN
Bronco - Reduce negative effect potency

### Utility/Speed

Cowboys - Six Shootin'
Fleet-Footed — High Tailin'
Coyote's — Initiative
Sundance — Turn order
Prospector's — Increased loot (gems)
Silver-Tongued — Taffyin'
Stagecoach's - Increased loot (items)

### Status

Rattlesnake's — Poison affliction
Firebrand — Bleed affliction
Thunderhead's — Gunpowder stick damage
Saloon-Forged - Liquid skull damage
Whiskey-Soaked - Liquid skull duration
Dusty - Silence immunity

## Suffixes
...of the Long Rider - Initiative increase
...of the Tinkerers - Damage piercing
...of the Quickdraw — High tailin'
...of the Hangman - Bonus vs. marked
...of the Prairie Wolf - Damage versus marked
...of the Iron Horse - Damage reduction
...of the Lonesome Trail - Rifle damage
...of the High Roller - Cylinder increase
...of the Snake Charmer - Poison potency reduction
...of the Last Stand - Damage taken reduction when taunting
...of the Six Feet Under - Shrapnel boom damage
...of the Gold Rush - Increased loot (gold)
...of the Dead Reckoning - Cylinder increase
...of the Cattleherder - Lasso damage increase
...of the Poker Face - Reduce negative effect duration
...of the Mother Lode - Increased loot (gems)
...of the Lucky Horseshoe - Increased loot (items)

Example rolled item: "Well-kept Deadeye's Six-Shooter of the Quickdraw"

## Weapons

### Revolvers

44\. Magnum
500\. Bushwhacker
Cattleman
Colt 1851 Navy
Colt Paterson
Colt Python
Colt Walker
LeMat
Pepper-box
Remington 1875
Remington Army
Bisley
Colt Single Action Army
Smith & Wesson
Taurus

### Rifles

Hawken
Remington Rolling Block
Repeating Carbine
Sharps 1853
Sharps 1874
Winchester 37
Winchester 69
Winchester Henry
Winchester Hotchkiss
Winchester Wild West
Winchester Under Barrel
Winchester Trapper

### Shotguns

A.H. Fox Double Barrel
Colt 1839
Colt 1855 Revolving
Ithaca 12 Gauge
Ithaca Double Barrel
L.C. Smith Hammerless
Winchester 1887
Winchester 1893
Winchester 1897
W.W. Greener

## Zone-Tied Items

Zone-tiered item names are purely flavour, they have no impact on the equipments stats or look. They are either tied to only dropping in their respective zones or anywhere.

### Grassy Plains / Forest

Prairie Rider's Duster
Green Hollow Bandana
Meadowlark Boots

### Hilly Mining Area

Prospector's Britches
Silver Vein Belt
Coal-Dusted Stetson

### Snowy Mountain

Angora Winter Chaps
Frostbit Duster
Snowshoe Trail Boots
Ice-Crusted Bandolier

### Desert Prairie

Sandstorm Veil
Sun-Bleached Stetson
Dust Devil's Duster
Cracked-Leather Boots

### Pine Forest

Woodsman's Flannel Coat
Needle-Stitched Boots

### Swamp

Mudder's Work Boots
Gator-Hide Belt
Swamp Rat's Poncho
Mossy Bandolier

### Canyon

Echo Walker's Boots
Red Rock Duster
Canyon Wind Bandana

### Ghost Town

Undertaker's Black Coat
Hangman's Neckerchief
Phantom Rider's Spurs
Six Feet Under Belt

### Town

Gambler's Waistcoat
Saloon-Keeper's Vest
Preacher's Frock Coat
Marshal's Badge Belt

## Unique/Legendary Items
"Widowmaker" — six-shooter
"Big Iron" — six-shooter
"High Noon" - six-shooter
"Lawgivers Justice" - rifle
"Winchester Rotating Rifle" - rifle
"Buckshot" - shotgun
"Buffalo Tamer" - shotgun
"Coyote's Last Howl" — bandana
"The Gambler's Deck" — belt
"Miner's Toolrack" - belt
"The Undertaker's Coat" — duster
"Pine Hill Spurs" — boots
"Stylish Spurs" - boots
