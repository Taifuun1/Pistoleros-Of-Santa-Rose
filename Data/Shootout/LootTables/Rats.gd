extends Node


# Loot table (Docs/System Design/Shootout/Rewards.md), keyed by enemy party.
# "band" is the quest-progression band: later bands get picked as main quests
# are completed. Values are balance placeholders.
var data = {
	"name": "Rats",
	"band": "early",
	"money": { "min": 2, "max": 6, "chance": 0.8 },
	"rolls": 1,
	"entries": [
		{ "kind": "consumable", "id": "Paregoric", "weight": 3 },
		{ "kind": "weapon", "rarity": ["common"], "weight": 1 },
		{ "kind": "equipment", "rarity": ["common"], "weight": 1 }
	]
}
