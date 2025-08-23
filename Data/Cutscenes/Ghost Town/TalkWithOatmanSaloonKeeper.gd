# GDScript cutscene data for 'Talk with Oatman saloon keeper'
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Ghost Town",
		"location": "Oatman Saloon - Keeper"
	},
	"nextLocation": {
		"location": "Oatman Saloon - Keeper",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Oatman Saloon Keeper", "type": "Unknown", "position": Vector2i(0, 0)},
		{"name": "Gwyneth Remington", "type": "Unknown", "position": Vector2i(20, 0)}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Oatman Saloon Keeper", "text": "Hey there, partner. What can I get you?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Hello. We're here to inquire of any mining expectice in the area. We're looking for someone who has a lot of experience with explosives."}},
		{"object": "dialog", "data": {"actor": "Oatman Saloon Keeper", "text": "Mmmh, I don't think there's anyone like that in Oatman. Not much mining going 'round these parts."}},
		{"object": "dialog", "data": {"actor": "Oatman Saloon Keeper", "text": "If I were you, I might try further up northeast. There used to be some mining activity up there."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Will do. Thanks for the help, partner."}}
	]
}
