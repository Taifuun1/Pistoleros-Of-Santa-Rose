
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "Talk at Texas Freedoms ranch"
	},
	"nextLocation": {
		"location": "Talk at Texas Freedoms ranch",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Morrison", "type": "Named People"},
		{"name": "Walker", "type": "Named People"},
		{"name": "Texas Freedom", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Now, where might the owner of this fine establishment be?"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Let's just wait for the land owner."}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "...I don't really like this."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Hmh?"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "The sovereign citizens in the West don't like when uninvited people wander onto their lands."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Pffft. We'll just talk it out with him, get our horses, and be on our way."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "There's nothing to worry about."}},
		{"object": "wait", "data": {"time": 1}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "Who the hell are you people?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Allow us to introduce ourselves. We are unemployed cowboys, looking to purchase a few horses for our convenience. Are you the owner of this fine ranch?"}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "Mah name's Texas Freedom."}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "This right here is private property. Mine, in fact."}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "I'm gon' have to ask you to leave mah property - and I do mean right the hell now."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Sir, we are simply looking to purchase a few steed. Perhaps we could..."}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "Get the hell off my land! Before I start blastin' my six-shooter!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "But sir..."}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "You asked for it, pardner!"}}
	]
}
