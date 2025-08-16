var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Stagecoach",
		"location": "Silverton Hunting Office"
	},
	"nextLocation": {
		"location": "Silverton Hunting Office",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "G", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "W", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "G", "text": "Hmmm... Looks like we have enough."}},
		{"object": "dialog", "data": {"actor": "G", "text": "This should be enough to get us winter clothing, fire making equipment, and the maps we need."}},
		{"object": "dialog", "data": {"actor": "G", "text": "We can try to get through the hills west of here."}},
		{"object": "dialog", "data": {"actor": "W", "text": "I'm not really looking to get eaten by a bear. Way too many close calls already. Let's move out."}}
	]
}
