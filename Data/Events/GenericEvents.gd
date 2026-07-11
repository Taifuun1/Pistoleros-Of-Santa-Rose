extends Node


var events = {
	"Wandering Stranger": {
		"text": "A lone rider appears on the horizon, slowly making their way toward you. They tip their hat as they approach, eyes scanning your group carefully.",
		"image_type": "encounter",
		"choices": [
			{ "label": "Greet them warmly", "result": "greet_stranger" },
			{ "label": "Keep your hand near your iron", "result": "cautious_stranger" },
			{ "label": "Ride past without a word", "result": "ignore_stranger" }
		]
	},
	"Rattlesnake": {
		"text": "Your horse rears up suddenly! A rattlesnake coils in the middle of the trail, shaking its tail in warning. The horses are spooked.",
		"image_type": "animal",
		"choices": [
			{ "label": "Shoot the snake", "result": "shoot_snake" },
			{ "label": "Carefully steer around it", "result": "avoid_snake" },
			{ "label": "Try to scare it off", "result": "scare_snake" }
		]
	},
	"Abandoned Wagon": {
		"text": "An overturned wagon sits at the side of the trail. The horses are gone and the cargo is scattered. No sign of the owners anywhere.",
		"image_type": "item",
		"choices": [
			{ "label": "Search the wreckage", "result": "search_wagon" },
			{ "label": "Look for tracks", "result": "track_wagon" },
			{ "label": "Leave it be", "result": "ignore_wagon" }
		]
	},
	"Dust Storm": {
		"text": "A wall of red dust rolls across the plains toward you. The wind picks up and visibility drops fast. You need to make a decision quickly.",
		"image_type": "weather",
		"choices": [
			{ "label": "Push through it", "result": "push_dust_storm" },
			{ "label": "Find shelter and wait it out", "result": "shelter_dust_storm" },
			{ "label": "Turn back and go around", "result": "avoid_dust_storm" }
		]
	},
	"Wanted Poster": {
		"text": "Nailed to a fence post is a fresh wanted poster. The face on it looks vaguely familiar. The reward is substantial — dead or alive.",
		"image_type": "document",
		"choices": [
			{ "label": "Take note of the bounty", "result": "note_bounty" },
			{ "label": "Tear it down", "result": "tear_poster" },
			{ "label": "Ride on", "result": "ignore_poster" }
		]
	},
	"Injured Traveler": {
		"text": "A man is slumped against a boulder by the roadside, clutching his side. He looks up at you with desperate eyes. 'Please... bandits got me good.'",
		"image_type": "encounter",
		"choices": [
			{ "label": "Help patch him up", "result": "help_traveler" },
			{ "label": "Ask what happened first", "result": "question_traveler" },
			{ "label": "Ride on — could be a trap", "result": "ignore_traveler" }
		]
	},
	"Campfire Remains": {
		"text": "The ashes of a recent campfire still smolder at the side of the trail. Whoever was here left in a hurry — there's food still on the pan.",
		"image_type": "item",
		"choices": [
			{ "label": "Help yourself to the food", "result": "take_campfire_food" },
			{ "label": "Search the camp", "result": "search_campfire" },
			{ "label": "Move on quickly", "result": "ignore_campfire" }
		]
	}
}
