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
		{"name": "Morrison Branson", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "Aiyana", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "Gwyneth Remington", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Morrison Branson", "text": "I see Fairpeaks!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Ahhh... Finally."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We got to get Aiyana to the infirmary stat."}}
	]
}
