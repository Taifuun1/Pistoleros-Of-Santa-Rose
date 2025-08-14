
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "Outside the bank"
	},
	"nextLocation": {
		"location": "Outside the bank",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"},
		{"name": "Snakeflats Sheriff", "type": "Other"},
		{"name": "Law Keeper", "type": "Other"},
		{"name": "Walker", "type": "Named People"}
	],
	"shots": [
		{"object": "action", "data": {"description": "Everyone except Walker is outside"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Where's Walker?"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "We were in such a hurry, but he decides to drag his boots..."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Ey, we've got to go, <i>Amigo!</i> Hurry!"}},
		{"object": "action", "data": {"description": "The Law Keeper and the local Sheriff walks onto the scene"}},
		{"object": "dialog", "data": {"actor": "Snakeflats Sheriff", "text": "Well, well, what do we have here? I thought the commotion was just another saloon brawl, but looks like we've got some real bank robbers on our hands."}},
		{"object": "dialog", "data": {"actor": "Snakeflats Sheriff", "text": "You know, we don't appreciate any brigands 'round deeese parts, pardner."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "We ain't no brigands! We're the big <i>Amigos</i>, friend!"}},
		{"object": "dialog", "data": {"actor": "Law Keeper", "text": "...Hmmm..."}},
		{"object": "action", "data": {"description": "Gwyneth draws her gun"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "You better stay back, lawgiver. We got a fist full of lead, and you're outgunned!"}},
		{"object": "dialog", "data": {"actor": "Snakeflats Sheriff", "text": "Outgunned? Hah! Come in, boys!"}},
		{"object": "action", "data": {"description": "Multiple of the sheriffs goons come to aid"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Ahh... Shouldn't have said anything."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Too late for regrets! Start blasting!"}},
		{"object": "action", "data": {"description": "A fight ensues"}}
	]
}
