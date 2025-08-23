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
		{"name": "Manuel Cárdenas", "type": "Unknown", "position": Vector2i(20, 0)},
		{"name": "Gwyneth Remington", "type": "Unknown", "position": Vector2i(40, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Dusty Trail Saloon Keeper", "text": "Want a drink?"}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "My <i>amigo!</i> A big glass for me!"}},
		{"object": "dialog", "data": {"actor": "Dusty Trail Saloon Keeper", "text": "One whiskey coming right up."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Do you know of any explosives experts around these parts?"}},
		{"object": "dialog", "data": {"actor": "Dusty Trail Saloon Keeper", "text": "Might be there's still some left from the goldrush back in the day. I'd try Twin Creek, since it's near Gold Springs."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We'll go there. Thanks, partner."}}
	]
}
