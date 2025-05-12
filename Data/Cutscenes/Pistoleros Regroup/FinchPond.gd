var data = {
	"type": "cutscene",
	"setting": load("res://Location/Locations/Pistoleros Regroup/Finch Pond/FinchPond.tscn"),
	"shots": [
		{
			"object": "wait",
			"data": {
				"time": 1
			}
		},
		{
			"object": "camera",
			"data": {
				"position": Vector2i(50, 0)
			}
		},
		{
			"object": "wait",
			"data": {
				"time": 1.5
			}
		},
		{
			"object": "camera",
			"data": {
				"position": Vector2i(100, 0)
			}
		},
		{
			"object": "wait",
			"data": {
				"time": 2
			}
		},
		{
			"object": "dialog",
			"data": {
				"text": "Test dialog"
			}
		}
	]
}
