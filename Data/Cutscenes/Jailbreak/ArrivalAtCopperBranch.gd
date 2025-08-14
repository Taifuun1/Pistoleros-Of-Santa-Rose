var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Arrival at Copper Branch"
	},
	"nextLocation": {
		"location": "Arrival at Copper Branch",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Manuel", "type": "Named People"},
		{"name": "Walker", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Manuel", "text": "I see Copper Branch! We're here!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Hmph. What a trip. My ass is sore from ridin'."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Let's get to the saloon and regroup."}}
	]
}
