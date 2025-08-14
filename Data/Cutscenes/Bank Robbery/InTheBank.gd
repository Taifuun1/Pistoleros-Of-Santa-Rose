
var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Bank Robbery",
		"location": "In the bank"
	},
	"nextLocation": {
		"location": "In the bank",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Walker", "type": "Named People"},
		{"name": "Aiyana", "type": "Named People"},
		{"name": "Morrison", "type": "Named People"},
		{"name": "Bank Assistant", "type": "Other"},
		{"name": "Gwyneth", "type": "Named People"},
		{"name": "Manuel", "type": "Named People"}
	],
	"shots": [
		{"object": "dialog", "data": {"actor": "Walker", "text": "This is a robbery! Put your hands up!"}},
		{"object": "dialog", "data": {"actor": "Bank Assistant", "text": "Don't shoot!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Keep your hands where I can see them!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Let's get cracking! Morrison! Bring the dynamite!"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "...I'm coming..."}},
		{"object": "dialog", "data": {"actor": "Bank Assistant", "text": "Please don't hurt us!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Quiet! We don't want no ruckus!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "The dynamite is in place. Let's blast 'em."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Get to cover! I'm gonna blow it up!"}},
		{"object": "action", "data": {"description": "Everyone takes cover and the safe explodes"}},
		{"object": "action", "data": {"description": "The gang coalesces around the safe"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Look at that..."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "<i>Riqueza</i> like sand in the desert!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Yes! There's money here for days!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Get it all on the horses. Step on it! And tie it on properly this time!"}}
	]
}
