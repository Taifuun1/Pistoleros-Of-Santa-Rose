var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Talk at West Field Mines once the money is gathered"
	},
	"nextLocation": {
		"location": "Talk at West Field Mines once the money is gathered",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Morrison Branson", "type": "Named People"},
		{"name": "Walker Langley", "type": "Named People"}
	],
	"shots": [
		{"object": "action", "data": {"description": "Morrison Branson counts the money"}},
		{"object": "dialog", "data": {"actor": "Morrison Branson", "text": "...That's enough."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Not a moment too soon. These damn prospectors are a stubborn bunch."}},
		{"object": "dialog", "data": {"actor": "Morrison Branson", "text": "We can buy the explosives at the mine warehouse."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Move it."}}
	]
}
