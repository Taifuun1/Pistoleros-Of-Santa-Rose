var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Train Robbery",
		"location": "Continental Train - Inside"
	},
	"nextLocation": {
		"location": "Continental Train - Inside",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Aiyana", "type": "Named People", "position": Vector2i(0, 0)},
		{"name": "Gwyneth Remington", "type": "Named People", "position": Vector2i(20, 0)},
		{"name": "Manuel Cárdenas", "type": "Named People", "position": Vector2i(40, 0)},
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(60, 0)},
		{"name": "Fed", "type": "Other", "position": Vector2i(80, 0)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(0, 0)}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "What's going on?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Looks like the train is moving. The Feds must have been able to push back the bandit groups."}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "The train moving is good! But we are not in control! We need to get to <i>la locomotora!</i>"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Ehh, there ain't no hurry to stop this tankhorse. It's all just fine and dandy."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Pardon me, Walker, but it certainly isn't. We're on a clock here. The more we dawdle, the worse it's going to get for us."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "This has been a pattern for a while now. You misassess the situation, give out the wrong opinion, and we get into trouble."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We have to rethink how we approach dangerous situations."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "It's them Feds who make it all so difficult. My straight-shot plans keep us on the trail."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "..."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "I've been keeping this gang focused ever since we got separated in Redbadger Forest. There's always a fight brewing with you and the rest of the gang."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "I'm not happy with the state of affairs as they currently stand."}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "Nah, it's fine. We're doing alright."}},
		{"object": "action", "data": {"description": "Feds emerge from front-portions of the train"}},
		{"object": "dialog", "data": {"actor": "Fed", "text": "There they are! The Pistoleros of Santa Rose! Get 'em!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Fuck! That's too many of them!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Shoot and retreat to the back of the train!"}},
		{"object": "action", "data": {"description": "A firefight with Feds starts"}}
	]
}
