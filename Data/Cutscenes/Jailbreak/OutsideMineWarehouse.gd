var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Outside the mine warehouse"
	},
	"nextLocation": {
		"location": "Outside the mine warehouse",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker", "type": "Named People"},
		{"name": "Carlos", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker", "text": "The fuck is that noise?"}},
		{"object": "action", "data": {"description": "The Bandidos of El Sacramento pull up, with their leader, Carlos"}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "Eyyyy, <i>Pistoleros del Diablo</I>! High time for <i>venganza!</i>"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "The Bandidos of El Sacramento! <i>¡Feo!</i>"}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "Uuuuh, Manuel, <i>malo amigo</i>! We here to give our regards, for last time! Big money, gone with Pistoleros, not good for us."}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "We take back what ours."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "The hell you will! I ain't some yesterdays finch! We worked hard for this money!"}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "Ooooh, I'm sure you did, <i>amigo</i>. Like in El Tecoo <i>plantación</i>, eh? Big guns, and big words. I give you what for."}},
		{"object": "action", "data": {"description": "A fight ensues"}}
	]
}
