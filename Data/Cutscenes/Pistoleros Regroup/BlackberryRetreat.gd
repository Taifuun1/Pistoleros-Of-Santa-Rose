var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Pistoleros Regroup",
		"location": "Blackberry Retreat"
	},
	"nextLocation": {
		"location": "Blackberry Retreat",
		"playerPosition": Vector2i(400, 540)
	},
	"initialCameraPosition": Vector2i(400, 540),
	"actors": [
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(400, 540)},
		{"name": "Gwyneth", "type": "Named People", "position": Vector2i(420, 540)},
		{"name": "Aiyana", "type": "Named People", "position": Vector2i(440, 540)},
		{"name": "Manuel", "type": "Named People", "position": Vector2i(460, 540)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(400, 540)}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "There you are, Manuel. Looking worse for wear."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Ooooh, I've been worse, Gwyneth. The sight of friendly faces washes the bad feelings away."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "What happened, Manuel?"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "I rode with Morrison for a long while. The Feds didn't give up <i>la caza</i> easily."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "The gunshots scared my <i>caballo</i>, and it reared. I fell on my side!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Luckily, the Feds didn't see me. They went after Morrison."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Which direction did he ride to?"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "We we're headed for Littlehill Grove."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Can you stand, Manuel?"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "My <i>amigo</i>, my leg is good as new!"}},
		{"object": "action", "data": {"description": "Gwyneth helps Manuel get up"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "There, you'll be riding again in no time."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Good. Let's get moving. We have to find Morrison."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Oh, I hope he's okay. He's not the bravest <i>alma</i>."}}
	]
}
