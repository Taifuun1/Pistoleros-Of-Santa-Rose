var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "Start of the prison break"
	},
	"nextLocation": {
		"location": "Start of the prison break",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth Remington", "type": "Named People"},
		{"name": "Morrison Branson", "type": "Named People"},
		{"name": "Walker Langley", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "OK, here we are. Morrison, set it up."}},
		{"object": "dialog", "data": {"actor": "Morrison Branson", "text": "On it..."}},
		{"object": "action", "data": {"description": "Morrison sets up the explosives and takes cover"}},
		{"object": "dialog", "data": {"actor": "Morrison Branson", "text": "It's gonna blow!"}},
		{"object": "action", "data": {"description": "Jail wall exlodes"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Alright, boys and girls! Let's get to it! Find Gwyneth!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "YEEEHAAWWW!"}}
	]
}
