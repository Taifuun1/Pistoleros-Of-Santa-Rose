var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Arrival at the Bandidos hideout"
	},
	"nextLocation": {
		"location": "Arrival at the Bandidos hideout",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker", "text": "Here we are... Let's take stock of the situation before we start blastin'."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "YEEEHAAWWW!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "<i>Oh dios</i>, Aiyana has lost it! She's going in!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "God damnit! Pull out your guns, were doing it her way, double barrels shining! Make 'em feel it!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "<i>Coraje para Gwyneth!</i>"}}
	]
}
