var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Train Robbery",
		"location": "Continental Train - Inside"
	},
	"nextLocation": {
		"location": "Continental Train - Inside",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth", "type": "Named People", "position": Vector2i(0, 0)},
		{"name": "Aiyana", "type": "Named People", "position": Vector2i(20, 0)},
		{"name": "Manuel", "type": "Named People", "position": Vector2i(40, 0)},
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(60, 0)},
		{"name": "Fed", "type": "Other", "position": Vector2i(80, 0)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(0, 0)}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "They're of our backs, for now."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "We still gotta stop the train!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Our <i>cálido amigo</i>, Morrison, could have blown up <i>las ruedas del tren</i> easy!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "But no <i>amigos</i>, no <i>grandes explosivos!</i>"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "We make only enemies, no friends!"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "We ain't made any friends after the fuckup with the Feds. People ain't too friendly round these parts."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Big lies! As usual!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "My <i>amigo</i>, <i>Compañero alegre</i>, sweet frowny-face! Lost to Pistoleros, for all time!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "<i>Mi villano</i>, Walker, you treat Morrison worse than dirt!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "I see you have no respect for any Pistolero. Not good for morale!"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Morrisons got his own problems to figure out. We ought to look out for ourselves."}},
		{"object": "action", "data": {"description": "More Feds emerge on to the train coach"}},
		{"object": "dialog", "data": {"actor": "Fed", "text": "There's nowhere to run, Pistoleros! Give up!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Get on the roof!"}},
		{"object": "action", "data": {"description": "The gang is overwhelmed and has to escape to the train roof"}}
	]
}
