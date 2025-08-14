var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "Arrival to Lazysprings"
	},
	"nextLocation": {
		"location": "Arrival to Lazysprings",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth", "type": "Named People"},
		{"name": "Walker", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "There! That's Lazysprings!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Finally."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Let's go the saloon first thing we get there. My mouth is thirsty."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Ayyy, I could use some good <i>compañía</i>, with drinks to quench my thirst."}}
	]
}
