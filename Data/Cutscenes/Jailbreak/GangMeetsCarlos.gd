var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "The gang meets Carlos"
	},
	"nextLocation": {
		"location": "The gang meets Carlos",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker Langley", "type": "Named People"},
		{"name": "Carlos", "type": "Named People"},
		{"name": "Manuel Cárdenas", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Come out, sombrero dent! You got our money, and we got your lead!"}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "Ooooh, it's the <i>Pistoleros del Diablo</i>! We meet again!"}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "If you don't give our money back, we'll show you we're worse than <i>el diablo</i> himself!"}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "Big words, big-big <i>tontos</i>! Time to find <i>dios</i>, Pistoleros!"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "We'll settle this right here."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "We'll be there, Gwyneth! Just hold on!"}},
		{"object": "action", "data": {"description": "A fight ensues"}}
	]
}
