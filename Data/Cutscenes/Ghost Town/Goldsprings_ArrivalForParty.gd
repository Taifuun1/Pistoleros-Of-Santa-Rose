# GDScript cutscene data for 'Ghost town - Arrival at Goldsprings'
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Goldsprings - Arrival for Party"
	},
	"nextLocation": {
		"location": "Goldsprings - Arrival for Party",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "TF1", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "A", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(40, 0)},
		{"name": "Townsfolk", "type": "Unknown", "position": Vector2i(60, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "TF1", "text": "Hey there, fellers. How you doin' on this fine night?"}},
		{"object": "dialog", "data": {"actor": "A", "text": "We're not getting lynched, so better than usual..."}},
		{"object": "dialog", "data": {"actor": "TF1", "text": "What's that?"}},
		{"object": "dialog", "data": {"actor": "G", "text": "We're doing fantastic! Everythings ready for the festivities. Let's get into the saloon and begin!"}},
		{"object": "dialog", "data": {"actor": "Townsfolk", "text": "move into the saloon"}}
	]
}
