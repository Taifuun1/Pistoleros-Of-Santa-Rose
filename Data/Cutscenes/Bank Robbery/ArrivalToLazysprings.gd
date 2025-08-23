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
		{"name": "Gwyneth Remington", "type": "Named People"},
		{"name": "Walker Langley", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Manuel Cárdenas", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "There! That's Lazysprings!"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Finally."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Let's go the saloon first thing we get there. My mouth is thirsty."}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "Ayyy, I could use some good <i>compañía</i>, with drinks to quench my thirst."}}
	]
}
