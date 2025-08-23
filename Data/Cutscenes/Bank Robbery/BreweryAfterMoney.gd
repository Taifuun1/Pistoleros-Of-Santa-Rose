
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "Talk at the brewery once the money is gathered"
	},
	"nextLocation": {
		"location": "Talk at the brewery once the money is gathered",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth Remington", "type": "Named People"},
		{"name": "Walker Langley", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "20... 30... 40... That's it. This should be enough."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Finally. I'm tired of wandering the forests. Let's get to some good ol' fashioned robbin'."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "YEEEHAAWWW! Time for a shootout!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Alright. We're going to Snakeflats. It's a smaller village to the east, with a bank."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Get your provisions together. We'll meet back here after the robbery."}}
	]
}
