var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Pistoleros Regroup",
		"location": "Littlehill Grove"
	},
	"nextLocation": {
		"location": "Littlehill Grove",
		"playerPosition": Vector2i(450, 560)
	},
	"initialCameraPosition": Vector2i(450, 560),
	"actors": [
		{"name": "Walker Langley", "type": "Named People", "position": Vector2i(450, 560)},
		{"name": "Gwyneth", "type": "Named People", "position": Vector2i(470, 560)},
		{"name": "Aiyana", "type": "Named People", "position": Vector2i(490, 560)},
		{"name": "Manuel", "type": "Named People", "position": Vector2i(510, 560)},
		{"name": "Morrison", "type": "Named People", "position": Vector2i(530, 560)}
	],
	"shots": [
		{"object": "camera", "data": {"position": Vector2i(450, 560)}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "Who's there?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "It's just us, Morrison."}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "...Oh, heavens. I thought the Feds finally caught up."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Do you have your horse?"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "She's here..."}},
		{"object": "action", "data": {"description": "Morrison walks the horse out of the brush"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Finally, some good news. How many bags are there?"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "..."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Where's the bags, Morrison?"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "Here..."}},
		{"object": "action", "data": {"description": "Morrison pulls out one bag of cash"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "ONE bag? Damnit! Damnit all to hell!"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "You couldn't grab more than one single bag!"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "I..."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Walker, that's enough. We've had enough troubles for a whole year."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "Eyyyy, <i>amigos.</i> Let's have a bit more <i>camaradería</i>, eh?"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "It's alright. Now we've something to work with. We have supplies, and some money."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "Lets take stock of what we have."}},
		{"object": "action", "data": {"description": "After counting the supplies and the money"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "...And that's it."}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "We don't got enough for anything, really. Enough for a trip to the nearest Fed prison, and that's it."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "There's enough here to get to Lazysprings. We can think of what we do after we get there."}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "...I'm sorry. I couldn't grab more. The Feds were already blasting when I got to the safe."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "It's okay. All that matters it that were all safe."}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "We got a little <i>compañerismo</i>, eh? We'll do it together!"}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "We'll be fine. As long as we can figure out what to do next."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "We've always pulled through. Because we are..."}},
		{"object": "dialog", "data": {"actor": "Gwyneth", "text": "...The Pistoleros of Santa Rose!"}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "Yeah!"}},
		{"object": "dialog", "data": {"actor": "Manuel", "text": "<i>Salud!</i>"}},
		{"object": "dialog", "data": {"actor": "Morrison", "text": "<i>sob</i>"}},
		{"object": "dialog", "data": {"actor": "Walker", "text": "Alright, let's move it. We're going to Lazysprings."}},
		{"object": "dialog", "data": {"actor": "Aiyana", "text": "I can't wait to get to the saloon! Nothing beats a bottle of whiskey after a bad day!"}}
	]
}
