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
		{"name": "Aiyana", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "Walker Langley", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "Gwyneth Remington", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "...This place is chilly."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Where we gon' find the pickaxe-user?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We could go looking for his mine. But maybe that would make him even more angry. Let's just go to the saloon."}}
	]
}
