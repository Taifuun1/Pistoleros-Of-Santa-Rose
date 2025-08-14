
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "Arrival at Snakeflats"
	},
	"nextLocation": {
		"location": "Arrival at Snakeflats",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker", "text": "Put your masks on! Guns out! Get to the bank!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "YEEEHAAWWW!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "<i>Adelante!</i>"}}
	]
}
