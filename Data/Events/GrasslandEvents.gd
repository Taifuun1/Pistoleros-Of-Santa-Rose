extends Node


var events = {
	"Cattle Stampede": {
		"text": "The ground trembles beneath your feet. A herd of longhorns comes thundering over the ridge, heading straight for your group. There's no time to think!",
		"image_type": "animal",
		"choices": [
			{ "label": "Scatter and regroup", "result": "scatter_stampede" },
			{ "label": "Fire shots to redirect the herd", "result": "redirect_stampede" },
			{ "label": "Ride hard and outrun them", "result": "outrun_stampede" }
		]
	},
	"Prairie Dog Town": {
		"text": "Your horse stumbles as the ground gives way slightly — you've ridden into a prairie dog town. The little critters pop up all around, watching you with beady eyes.",
		"image_type": "animal",
		"choices": [
			{ "label": "Navigate carefully through", "result": "navigate_prairie_dogs" },
			{ "label": "Chase them off with noise", "result": "scare_prairie_dogs" },
			{ "label": "Take a detour around", "result": "detour_prairie_dogs" }
		]
	},
	"Broken Fence": {
		"text": "A long stretch of fence has been knocked down, and a dozen cattle have wandered out onto the open range. A farmstead is visible in the distance.",
		"image_type": "item",
		"choices": [
			{ "label": "Herd the cattle back", "result": "herd_cattle" },
			{ "label": "Ride to the farmstead to inform them", "result": "inform_farmer" },
			{ "label": "Leave it — not your problem", "result": "ignore_fence" }
		]
	},
	"Wildflower Meadow": {
		"text": "You ride through a stunning meadow bursting with wildflowers. The air smells sweet and your horses seem to perk up. A good place to rest a spell.",
		"image_type": "nature",
		"choices": [
			{ "label": "Rest here a while", "result": "rest_meadow" },
			{ "label": "Gather some flowers", "result": "gather_flowers" },
			{ "label": "Press on — no time to dawdle", "result": "ignore_meadow" }
		]
	},
	"Coyote Pack": {
		"text": "A pack of coyotes circles at the edge of your camp, drawn by the smell of food. They're bold — one has already crept close enough to snatch something.",
		"image_type": "animal",
		"choices": [
			{ "label": "Fire a warning shot", "result": "warn_coyotes" },
			{ "label": "Throw them some scraps to drive them off", "result": "feed_coyotes" },
			{ "label": "Chase them off on horseback", "result": "chase_coyotes" }
		]
	}
}
