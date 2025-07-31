var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Pistoleros Regroup",
		"location": "Pine Meadows"
	},
	"nextLocation": {
		"location": "Pine Meadows",
		"playerPosition": Vector2i(600, 125)
	},
	"initialCameraPosition": Vector2i(650, 125),
	"actors": [
		{
			"name": "Walker Langley",
			"type": "Named People",
			"position": Vector2i(600, 125)
		},
		{
			#"name": "Gwyneth Remington",
			"name": "Walker Langley",
			"type": "Named People",
			"position": Vector2i(700, 125)
		}
	],
	"shots": [
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "Who's that?"
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Gwyneth",
				"text": "Walker, you're alive. Thank god."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Gwyneth",
				"text": "I wasn't sure if you would make it."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "Nevermind that, where's the cash?"
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Gwyneth",
				"text": "The Feds chased us up the mountain creek. I don't know where we got separated. The entire thing was a blur."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Gwyneth",
				"text": "I rode through the woods as fast as I could. At some point, the branches from the trees must have tangled on me."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Gwyneth",
				"text": "I don't know where the money is. It's gone."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "Darn it to hell! Where's the rest of the gang? They had the rest of it!"
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Gwyneth",
				"text": "Calm down, Walker. That's not important. We have to find the others, before we worry about anything else."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "Hells, we didn't do all this for nothing, did we, Gwyneth? Let's search, the rest of them must be around here somewhere."
			}
		}
	]
}
