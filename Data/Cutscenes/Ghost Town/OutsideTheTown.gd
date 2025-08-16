var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Outside the Town"
	},
	"nextLocation": {
		"location": "Outside the Town",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "A", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "A", "text": "Where is Wyatt Garrett? I thought he'd be right on our trail."}},
		{"object": "dialog", "data": {"actor": "G", "text": "Wyatt is no yesterdays finch. He must be preparing to defend the Continental Train."}},
		{"object": "dialog", "data": {"actor": "G", "text": "The train will be swarming with Feds, I'm sure."}}
	]
}
