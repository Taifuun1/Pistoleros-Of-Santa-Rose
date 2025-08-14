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
		{"name": "Morrison", "type": "Named People"},
		{"name": "Walker", "type": "Named People"}
	],
	"shots": [
		{"object": "action", "data": {"description": "Morrison counts the money"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "...That's enough."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Not a moment too soon. These damn prospectors are a stubborn bunch."}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "We can buy the explosives at the mine warehouse."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Move it."}}
	]
}
