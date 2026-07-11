extends Node


var events = {
	"Bear Encounter": {
		"text": "A large black bear blocks the trail ahead, standing on its hind legs and sniffing the air. It hasn't charged yet, but it's watching you intently.",
		"image_type": "animal",
		"choices": [
			{ "label": "Back away slowly", "result": "retreat_bear" },
			{ "label": "Make noise to scare it off", "result": "scare_bear" },
			{ "label": "Draw your weapon", "result": "draw_on_bear" }
		]
	},
	"Hidden Trapper": {
		"text": "A grizzled old trapper steps out from behind a tree, rifle in hand but pointed at the ground. 'Easy now. Just checking who's passing through my territory.'",
		"image_type": "encounter",
		"choices": [
			{ "label": "Introduce yourself peacefully", "result": "greet_trapper" },
			{ "label": "Ask if he knows the area well", "result": "question_trapper" },
			{ "label": "Keep moving and say nothing", "result": "ignore_trapper" }
		]
	},
	"Fallen Tree": {
		"text": "A massive old pine has fallen across the trail, completely blocking the path. It's too big to jump and too long to easily go around in the dense undergrowth.",
		"image_type": "nature",
		"choices": [
			{ "label": "Chop through it", "result": "chop_tree" },
			{ "label": "Find a way around through the brush", "result": "detour_tree" },
			{ "label": "Backtrack to another route", "result": "backtrack_tree" }
		]
	},
	"Strange Sounds": {
		"text": "The forest goes quiet. Then — a low, rhythmic knocking sound echoes through the trees. Your horses' ears flatten. Something is out there, watching.",
		"image_type": "encounter",
		"choices": [
			{ "label": "Investigate the source", "result": "investigate_sounds" },
			{ "label": "Move quickly and quietly", "result": "sneak_past_sounds" },
			{ "label": "Make camp and wait for daylight", "result": "camp_sounds" }
		]
	},
	"Wild Berries": {
		"text": "A thicket of wild berry bushes lines the trail, heavy with ripe fruit. They look good, but you're not entirely sure what kind they are.",
		"image_type": "nature",
		"choices": [
			{ "label": "Pick and eat them — they look fine", "result": "eat_berries" },
			{ "label": "Identify them carefully first", "result": "identify_berries" },
			{ "label": "Leave them alone", "result": "ignore_berries" }
		]
	},
	"Abandoned Cabin": {
		"text": "A small log cabin sits in a clearing, door hanging open. Moss covers the roof and the windows are dark. It looks like no one has been here in years.",
		"image_type": "item",
		"choices": [
			{ "label": "Search inside", "result": "search_cabin" },
			{ "label": "Make camp here for the night", "result": "camp_cabin" },
			{ "label": "Keep moving", "result": "ignore_cabin" }
		]
	}
}
