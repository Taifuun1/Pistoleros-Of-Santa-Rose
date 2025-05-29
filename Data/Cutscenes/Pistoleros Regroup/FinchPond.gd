var data = {
	"type": "cutscene",
	"setting": {
		"quest": "Pistoleros Regroup",
		"location": "Finch Pond"
	},
	"nextLocation": {
		"location": "Finch Pond",
		"playerPosition": Vector2i(275, 475)
	},
	"initialCameraPosition": Vector2i(275, 475),
	"actors": [
		{
			"name": "Walker Langley",
			"type": "Named People",
			"position": Vector2i(275, 475)
		}
	],
	"shots": [
		{
			"object": "camera",
			"data": {
				"position": Vector2i(275, 475)
			}
		},
		{
			"object": "wait",
			"data": {
				"time": 3
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "Ugghhhh..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "What happened... I can't remember..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "There was piles of cash... and a chase..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "I remember... flashes of light. Gunfire."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "What happened to the bags of cash? Ahhh..."
			}
		},
		{
			"object": "dialog",
			"data": {
				"actor": "Walker",
				"text": "I got to find Gwyneth. Where is she?"
			}
		}
	]
}
