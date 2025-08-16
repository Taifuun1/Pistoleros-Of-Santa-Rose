# GDScript cutscene data for 'Talk with Dusty Trail saloon keeper'
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Dusty Trail Saloon - Keeper"
	},
	"nextLocation": {
		"location": "Dusty Trail Saloon - Keeper",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Dusty Trail Saloon Keeper", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "MA", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "G", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Dusty Trail Saloon Keeper", "text": "Want a drink?"}},
		{"object": "dialog", "data": {"actor": "MA", "text": "My <i>amigo!</i> A big glass for me!"}},
		{"object": "dialog", "data": {"actor": "DTSK", "text": "One whiskey coming right up."}},
		{"object": "dialog", "data": {"actor": "G", "text": "Do you know of any explosives experts around these parts?"}},
		{"object": "dialog", "data": {"actor": "DTSK", "text": "Might be there's still some left from the goldrush back in the day. I'd try Twin Creek, since it's near Gold Springs."}},
		{"object": "dialog", "data": {"actor": "G", "text": "We'll go there. Thanks, partner."}}
	]
}
