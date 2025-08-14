
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "After escaping Texas Freedoms ranch"
	},
	"nextLocation": {
		"location": "After escaping Texas Freedoms ranch",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"},
		{"name": "Gwyneth", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker", "text": "God damn, the citizens here can be fiercer than the desert wind."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "That <i>pistolero</i> was like some of the <i>señoritas</i> back home!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "What a mess. Let's try our luck at another ranch. Perhaps others here won't be as territorial as that land owner."}}
	]
}
