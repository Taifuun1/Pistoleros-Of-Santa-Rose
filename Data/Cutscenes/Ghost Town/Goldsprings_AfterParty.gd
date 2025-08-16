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
		{"name": "A", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "MA", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(40, 0)},
		{"name": "W", "type": "Unknown", "position": Vector2i(60, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "A", "text": "That went exceptionally well. The village folk had a great impression."}},
		{"object": "dialog", "data": {"actor": "MA", "text": "<i>¡Grandes festividades!</i>"}},
		{"object": "dialog", "data": {"actor": "G", "text": "And there were no complications after."}},
		{"object": "dialog", "data": {"actor": "W", "text": "I didn't drink tonight, pardner."}},
		{"object": "dialog", "data": {"actor": "A", "text": "Can't piss on the totem pole here..."}},
		{"object": "dialog", "data": {"actor": "G", "text": "Let's get sleeping, and talk out the rest on the morrow."}}
	]
}
