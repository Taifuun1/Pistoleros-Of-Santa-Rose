var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Train Robbery",
		"location": "Continental Train - Outside"
	},
	"nextLocation": {
		"location": "Continental Train - Outside",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(0, 0)},
		{"name": "Manuel Cárdenas", "type": "Named People", "position": Vector2i(20, 0)},
		{"name": "Aiyana", "type": "Named People", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(0, 0)}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "OK, boys and girls! Get into the train!"}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "<i>¡Ponte tus bufandas de vaquero!</i>"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "YEEEHAAWWW!"}}
	]
}
