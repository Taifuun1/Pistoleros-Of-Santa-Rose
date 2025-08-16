var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Stagecoach",
		"location": "Pilrose Pass"
	},
	"nextLocation": {
		"location": "Pilrose Pass",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "G", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "EG", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "G", "text": "This is Pilrose Pass."}},
		{"object": "dialog", "data": {"actor": "EG", "text": "Look up ahead! The Charokee patrols are everywhere!"}},
		{"object": "dialog", "data": {"actor": "G", "text": "They are truly on a warpath now. We have to fight our way through."}},
		{"object": "dialog", "data": {"actor": "EG", "text": "Oh no..."}},
		{"object": "dialog", "data": {"actor": "G", "text": "Time to grit your teeth. Push forward, as fast as you can. The more time we waste, the more patrols we have to defeat. Move it!"}}
	]
}
