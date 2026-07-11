extends Node


var events = {
	"Quicksand": {
		"text": "One of your horses lurches sideways, leg sinking into the ground. What looked like solid earth is a patch of quicksand. The animal is panicking.",
		"image_type": "nature",
		"choices": [
			{ "label": "Work carefully to pull the horse free", "result": "free_horse_quicksand" },
			{ "label": "Cut the horse loose and move on", "result": "abandon_horse_quicksand" },
			{ "label": "Throw a rope and haul it out", "result": "rope_horse_quicksand" }
		]
	},
	"Alligator": {
		"text": "A pair of yellow eyes breaks the surface of the murky water ahead. Then another pair. The crossing you planned suddenly looks a lot more dangerous.",
		"image_type": "animal",
		"choices": [
			{ "label": "Find another crossing", "result": "find_crossing_gator" },
			{ "label": "Make noise to drive them off", "result": "scare_gators" },
			{ "label": "Cross fast and hope for the best", "result": "rush_crossing_gator" }
		]
	},
	"Fog Bank": {
		"text": "A thick wall of fog rolls in off the water, swallowing the trail ahead. Within minutes you can barely see your hand in front of your face.",
		"image_type": "weather",
		"choices": [
			{ "label": "Press on slowly and carefully", "result": "push_fog" },
			{ "label": "Make camp and wait for it to lift", "result": "wait_fog" },
			{ "label": "Try to navigate by sound", "result": "navigate_fog" }
		]
	},
	"Sunken Chest": {
		"text": "Something glints in the shallow water beside the trail — the corner of a wooden chest, half-submerged in the mud. It's padlocked.",
		"image_type": "item",
		"choices": [
			{ "label": "Haul it out and break the lock", "result": "open_chest" },
			{ "label": "Look for a key nearby", "result": "search_key_chest" },
			{ "label": "Leave it — could be cursed", "result": "ignore_chest" }
		]
	},
	"Swamp Witch": {
		"text": "An old woman in ragged clothes stands knee-deep in the water, stirring something in a pot. She looks up at you with sharp, knowing eyes. 'I been expecting you.'",
		"image_type": "encounter",
		"choices": [
			{ "label": "Hear what she has to say", "result": "listen_witch" },
			{ "label": "Ask her about the area", "result": "question_witch" },
			{ "label": "Ride on — she gives you the creeps", "result": "ignore_witch" }
		]
	},
	"Mosquito Swarm": {
		"text": "A massive cloud of mosquitoes descends on your group. The horses are going wild and everyone is swatting frantically. You need to get out of here.",
		"image_type": "animal",
		"choices": [
			{ "label": "Ride hard to get clear", "result": "flee_mosquitoes" },
			{ "label": "Light a smoky fire to drive them off", "result": "smoke_mosquitoes" },
			{ "label": "Cover up and push through slowly", "result": "endure_mosquitoes" }
		]
	}
}
