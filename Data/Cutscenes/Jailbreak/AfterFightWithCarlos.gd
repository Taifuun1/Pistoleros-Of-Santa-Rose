var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Jailbreak",
		"location": "After the fight with Carlos"
	},
	"nextLocation": {
		"location": "After the fight with Carlos",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Carlos", "type": "Named People"},
		{"name": "Walker", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"}
	],
	"shots": [
		{"object": "action", "data": {"description": "Carlos is on the ground, bleeding to death"}},
		{"object": "dialog", "data": {"actor": "Carlos", "text": "Ooooh... <i>Del diablos</i> got me..."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "That's what you get for messing with the Pistoleros of Santa Rose."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "I got the money. It's all right here."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Thank fuck something's going our way. We don't got too much time now."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "We got to get the explosives, and then run straight to Sandy Cross. There we'll find Gwyneth, in jail."}}
	]
}
