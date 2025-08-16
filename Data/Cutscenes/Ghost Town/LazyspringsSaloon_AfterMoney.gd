var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Lazysprings Saloon - After Money Gathered"
	},
	"nextLocation": {
		"location": "Lazysprings Saloon - After Money Gathered",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "G", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "W", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "A", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "G", "text": "...We have enough money."}},
		{"object": "dialog", "data": {"actor": "W", "text": "This dampness will follow me to my grave. What a miserable swamp."}},
		{"object": "dialog", "data": {"actor": "A", "text": "It's was spring home for our tribe! You shut your mouth!"}},
		{"object": "dialog", "data": {"actor": "G", "text": "Alright, enough. Let's go to Goldsprings, and get this party started."}}
	]
}
