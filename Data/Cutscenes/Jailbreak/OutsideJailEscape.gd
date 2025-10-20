var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Outside the jail"
	},
	"nextLocation": {
		"location": "Outside the jail",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth Remington", "type": "Named People"},
		{"name": "Walker Langley", "type": "Named People"},
		{"name": "Morrison Branson", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We're out. Where to now?"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Anywhere is better than here."}},
		{"object": "dialog", "data": {"actor": "Morrison Branson", "text": "Head north, to Fairpeaks."}}
	]
}
