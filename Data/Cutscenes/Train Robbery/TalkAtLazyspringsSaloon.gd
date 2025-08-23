var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Train Robbery",
		"location": "Lazysprings Saloon"
	},
	"nextLocation": {
		"location": "Lazysprings Saloon",
		"playerPosition": Vector2i(0, 0)
	},
	"initialCameraPosition": Vector2i(0, 0),
	"actors": [
		{"name": "Gwyneth Remington", "type": "Named People", "position": Vector2i(0, 0)},
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(20, 0)},
		{"name": "Aiyana", "type": "Named People", "position": Vector2i(40, 0)},
		{"name": "Manuel Cárdenas", "type": "Named People", "position": Vector2i(60, 0)},
		{"name": "Wells", "type": "Named People", "position": Vector2i(80, 0)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(0, 0)}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "OK, gang. Here's the plan."}},
		{"object": "action", "data": {"description": "Gwyneth puts down a map on the table"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We're going to go right here, near Berry Ridge Farms. From there, we'll see the train coming."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "We have to stop the train. So, we're going to jump on the train from our horses."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "What about the Feds?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "I'm going with the assumption that there are only Feds in the train itself."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "If there's Feds on horses following the train, we'll have to ride ahead of the train and blow up the tracks to stop it."}},
		{"object": "dialog", "data": {"actor": "Manuel Cárdenas", "text": "Our <i>explosivos</i> expert is not so young. He can't ride as fast as the train!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "I know. Let's ask Wells if he can keep up once he arrives here."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Would be real fucking nice if our <i>actual</i> explosives expert was here. Plan B would be no problem for Morrison!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Even if he can't hit a barn wall from a spitting distance, we could always count on him!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Walker, your fucking loud mouth always puts us into the ditch. That was no way to treat a Pistolero back at Twin Creeks!"}},
		{"object": "dialog", "data": {"actor": "Walker Langley", "text": "What? I just put down the plan. We ride for the Pistoleros, no-one else."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Morrison is <i>gone!</i> Doesn't sound like riding with the Pistoleros!"}},
		{"object": "action", "data": {"description": "Wells enters the saloon"}},
		{"object": "dialog", "data": {"actor": "Wells", "text": "Hey there, partners. I'm here, and ready for action."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "Hey there, Wells. I think we got our plans figured out."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "There's just one thing. How good is your horse riding?"}},
		{"object": "dialog", "data": {"actor": "Wells", "text": "I haven't rode a horse too much in my later years. And it always wakes up my back pains."}},
		{"object": "dialog", "data": {"actor": "Wells", "text": "Just riding here was trek. Can't ride too hard, like in my youthful years."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "OK, that's fine. Just so we know what to expect. We don't expect you to do any heavy lifting in the robbery."}},
		{"object": "dialog", "data": {"actor": "Gwyneth Remington", "text": "It's time, gang. Let's move out, and make the greatest robbery in the West happen!"}}
	]
}
