var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Train Robbery",
		"location": "Continental Train - Aftermath"
	},
	"nextLocation": {
		"location": "Continental Train - Aftermath",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(0, 0)},
		{"name": "Wyatt Garrett", "type": "Named People", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(0, 0)}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "I... I got you! There's nowhere to run, Wyatt!"}},
		{"object": "dialog", "data": {"actor": "Wyatt Garrett", "text": "Hmph. You criminals are all simple minded folk. All you think about is killing and looting."}},
		{"object": "dialog", "data": {"actor": "Wyatt Garrett", "text": "Do you really think I didn't have a plan B?"}},
		{"object": "action", "data": {"description": "Wyatt jumps off the train onto a Fed-driven wagon"}},
		{"object": "dialog", "data": {"actor": "Wyatt Garrett", "text": "Your days are numbered, Walker."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Damn... He jumped off."}},
		{"object": "dialog", "data": {"actor": "Wyatt Garrett", "text": "I'll see you in hell, when my time comes."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Huh?"}},
		{"object": "action", "data": {"description": "Walker turns around to see explosives on the train tracks"}}
	]
}
