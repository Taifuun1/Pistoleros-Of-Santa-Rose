var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Stagecoach",
		"location": "Arrival at Fairpeaks"
	},
	"nextLocation": {
		"location": "Arrival at Fairpeaks",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "MO", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "A", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "MO", "text": "I see Fairpeaks!"}},
		{"object": "dialog", "data": {"actor": "A", "text": "Ahhh... Finally."}},
		{"object": "dialog", "data": {"actor": "G", "text": "We got to get Aiyana to the infirmary stat."}}
	]
}
