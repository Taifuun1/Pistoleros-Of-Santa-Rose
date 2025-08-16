var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Stagecoach",
		"location": "Arrival in Silverton"
	},
	"nextLocation": {
		"location": "Arrival in Silverton",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "MA", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "W", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "MA", "text": "Silverton!"}},
		{"object": "dialog", "data": {"actor": "W", "text": "Shit... Heaven..."}},
		{"object": "dialog", "data": {"actor": "G", "text": "Let's wind down in the saloon."}}
	]
}
