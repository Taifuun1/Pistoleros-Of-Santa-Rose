var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Stagecoach",
		"location": "Messenger Post - Before Leaving"
	},
	"nextLocation": {
		"location": "Messenger Post - Before Leaving",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "G", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "EG", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "G", "text": "Hey! Everything ready for the trail?"}},
		{"object": "dialog", "data": {"actor": "EG", "text": "Sure is. It's going to be a grueling trip."}},
		{"object": "dialog", "data": {"actor": "G", "text": "No doubt. We're all stocked up, and ready to go. Let's get going."}},
		{"object": "dialog", "data": {"actor": "EG", "text": "Yup. Since you're our escort, we'll be following your lead."}}
	]
}
