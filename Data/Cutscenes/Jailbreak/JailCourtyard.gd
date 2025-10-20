var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Jail courtyard"
	},
	"nextLocation": {
		"location": "Jail courtyard",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Wyatt Garrett", "type": "Named People"},
		{"name": "Walker Langley", "type": "Named People"},
		{"name": "Gwyneth Remington", "type": "Named People"},
		{"name": "Texas Freedom", "type": "Named People"},
		{"name": "Manuel Cárdenas", "type": "Named People"}
	],
	"shots": [
	    {"object": "dialog", "data": {"actor": "Wyatt Garrett", "text": "Hmmh, what do we have here? Have the coyotes crawled out of the den?"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Who the fuck is that? Is that the hippopotamus Fed?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "It sure is! And he doesn't look too happy!"}},
		{"object": "dialog", "data": {"actor": "Wyatt Garrett", "text": "Oh, I'm quite happy, actually. This could not be a better opportunity. I won't be needing to run after you all in some devilish goose chase."}},
		{"object": "action", "data": {"description": "Multiple Feds pull up on the scene."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "...Fuck."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Okay, buddy! If it's a gunfight you want, it's a gunfight you'll get!"}},
	    {"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "We will dance <i>la danza de la muerte</i> under the moon and the stars, <i>alguacil!</i>"}},
		{"object": "action", "data": {"description": "The crew is pinned down; the fight continues into the 'During the fight' scene."}}
	]
}
