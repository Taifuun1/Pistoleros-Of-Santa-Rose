
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "End of fight with Texas Freedom"
	},
	"nextLocation": {
		"location": "End of fight with Texas Freedom",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Texas Freedom", "type": "Named People"},
		{"name": "Walker", "type": "Named People"},
		{"name": "Gwyneth", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "You ain't gon' drive me off my own land! I got my rights!"}},
		{"object": "dialog", "data": {"actor": "Texas Freedom", "text": "Either you get off my property, or you'll face judgement from God! Castle doctrine!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Dang, this Whiskey Bulldozers got gutts, and the gunslingin' to back it up."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Walker, there's no reason to risk our lives here! We're just here to get some horses!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Time to high tail it. Let's disappear like coyotes into the night!"}}
	]
}
