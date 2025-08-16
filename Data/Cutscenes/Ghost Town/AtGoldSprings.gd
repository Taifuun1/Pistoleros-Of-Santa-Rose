# GDScript cutscene data for 'At Gold Springs'
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Gold Springs Arrival"
	},
	"nextLocation": {
		"location": "Gold Springs Arrival",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "A", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "W", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "A", "text": "...This place is chilly."}},
		{"object": "dialog", "data": {"actor": "W", "text": "Where we gon' find the pickaxe-user?"}},
		{"object": "dialog", "data": {"actor": "G", "text": "We could go looking for his mine. But maybe that would make him even more angry. Let's just go to the saloon."}}
	]
}
