# GDScript cutscene data for 'After the party'
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Goldsprings - After Party"
	},
	"nextLocation": {
		"location": "Goldsprings - After Party",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Aiyana", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "Manuel Cárdenas", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "Gwyneth Remington", "type": "Unknown", "position": Vector2i(40, 0)},
		{"name": "Walker Langley", "type": "Unknown", "position": Vector2i(60, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "That went exceptionally well. The village folk had a great impression."}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "<i>¡Grandes festividades!</i>"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "And there were no complications after."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "I didn't drink tonight, pardner."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Can't piss on the totem pole here..."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Let's get sleeping, and talk out the rest on the morrow."}}
	]
}
