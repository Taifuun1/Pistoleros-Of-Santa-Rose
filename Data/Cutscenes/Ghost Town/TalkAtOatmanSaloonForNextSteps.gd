# GDScript cutscene data for 'Talk at Oatman saloon for next steps'
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Oatman Saloon"
	},
	"nextLocation": {
		"location": "Oatman Saloon",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "W", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "A", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "W", "text": "Now what?"}},
		{"object": "dialog", "data": {"actor": "G", "text": "Let's go through all the village saloons and ask around."}},
		{"object": "dialog", "data": {"actor": "A", "text": "I could play a hand..."}},
		{"object": "dialog", "data": {"actor": "G", "text": "Might as well relax a little bit now that we're out of harms way."}}
	]
}
