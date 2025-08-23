var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Goldsprings - Outside Saloon"
	},
	"nextLocation": {
		"location": "Goldsprings - Outside Saloon",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Tennessee Diamonds", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "Dallas Spades", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Tennessee Diamonds", "text": "The plan is, you go in at midnight, and spook the townsfolk. They'll run into the night with their tail between their legs."}},
		{"object": "dialog", "data": {"actor": "Tennessee Diamonds", "text": "The townsfolk will blame Wells, and well be able to get back at him!"}},
		{"object": "dialog", "data": {"actor": "Dallas Spades", "text": "Right. But wouldn't you be a scarier ghost since you're taller?"}},
		{"object": "dialog", "data": {"actor": "Tennessee Diamonds", "text": "Nonsense, Dallas! With your naturally weasely movements, the townsfolk will wet their pants before you can say 'Phantom Pull'!"}},
		{"object": "dialog", "data": {"actor": "Dallas Spades", "text": "We could have just went back to swindling people at the poker table..."}}
	]
}
