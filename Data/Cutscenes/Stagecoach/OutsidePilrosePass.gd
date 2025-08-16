var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Stagecoach",
		"location": "Outside Pilrose Pass"
	},
	"nextLocation": {
		"location": "Outside Pilrose Pass",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "G", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "EG", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "G", "text": "...I think we've made it."}},
		{"object": "dialog", "data": {"actor": "EG", "text": "We're out! We're saved!"}},
		{"object": "dialog", "data": {"actor": "G", "text": "That couldn't have been much closer."}},
		{"object": "dialog", "data": {"actor": "G", "text": "We still have to make it to Silverton. It should be somewhere up ahead. Follow any road north we find, and we should get there eventually."}}
	]
}
