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
		{"name": "Walker Langley", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "Gwyneth Remington", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "Aiyana", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Now what?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Let's go through all the village saloons and ask around."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "I could play a hand..."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Might as well relax a little bit now that we're out of harms way."}}
	]
}
