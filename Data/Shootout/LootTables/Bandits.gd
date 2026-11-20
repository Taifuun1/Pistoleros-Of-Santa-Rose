extends Node


# Loot table (Docs/System Design/Shootout/Rewards.md), keyed by enemy party:
# the Whispering Pines Reach bandit parties (commit 17). Values are balance
# placeholders like the Rats table.
var data = {
	"name": "Bandits",
	"band": "early",
	"money": { "min": 4, "max": 10, "chance": 0.8 },
	"rolls": 1,
	"entries": [
		{ "kind": "consumable", "definitionId": "paregoric", "weight": 3 },
		{ "kind": "weapon", "rarity": ["common"], "weight": 1 },
		{ "kind": "equipment", "rarity": ["common"], "weight": 1 }
	]
}
