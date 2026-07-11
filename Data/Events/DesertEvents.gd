extends Node


var events = {
	"Mirage": {
		"text": "Water. A shimmering lake just ahead, with trees and shade. Your horses pull toward it eagerly. But something feels off — the heat out here plays tricks on the mind.",
		"image_type": "weather",
		"choices": [
			{ "label": "Ride toward it", "result": "chase_mirage" },
			{ "label": "Trust your gut and stay the course", "result": "ignore_mirage" },
			{ "label": "Check the map for water sources", "result": "check_map_mirage" }
		]
	},
	"Scorpion Nest": {
		"text": "You nearly step on a cluster of scorpions sheltering under a flat rock. The ground around it is riddled with them. One of your party yelps — a close call.",
		"image_type": "animal",
		"choices": [
			{ "label": "Check everyone for stings", "result": "check_stings" },
			{ "label": "Clear the path carefully", "result": "clear_scorpions" },
			{ "label": "Give the area a wide berth", "result": "avoid_scorpions" }
		]
	},
	"Bleached Bones": {
		"text": "The skeleton of a horse lies half-buried in the sand, saddle still attached. The saddlebags are intact. Whatever happened here, it wasn't pretty.",
		"image_type": "item",
		"choices": [
			{ "label": "Search the saddlebags", "result": "search_bones" },
			{ "label": "Look for signs of what happened", "result": "investigate_bones" },
			{ "label": "Ride on — bad omen", "result": "ignore_bones" }
		]
	},
	"Dust Devil": {
		"text": "A spinning column of dust and debris dances across the flats toward you. It's not dangerous on its own, but it's disorienting and your horses are skittish.",
		"image_type": "weather",
		"choices": [
			{ "label": "Hold steady and let it pass", "result": "wait_dust_devil" },
			{ "label": "Ride around it", "result": "avoid_dust_devil" },
			{ "label": "Charge straight through", "result": "charge_dust_devil" }
		]
	},
	"Dry Watering Hole": {
		"text": "The watering hole marked on your map is bone dry. Cracked mud and animal tracks are all that remain. The horses are thirsty and so are you.",
		"image_type": "nature",
		"choices": [
			{ "label": "Ration what water you have", "result": "ration_water" },
			{ "label": "Search for another source nearby", "result": "search_water" },
			{ "label": "Push hard to the next town", "result": "push_to_town" }
		]
	},
	"Vultures Circling": {
		"text": "A dozen vultures wheel lazily overhead, descending toward something just over the next dune. Could be an animal. Could be something else.",
		"image_type": "animal",
		"choices": [
			{ "label": "Investigate what they've found", "result": "investigate_vultures" },
			{ "label": "Scare them off and check", "result": "scare_vultures" },
			{ "label": "Steer well clear", "result": "avoid_vultures" }
		]
	}
}
