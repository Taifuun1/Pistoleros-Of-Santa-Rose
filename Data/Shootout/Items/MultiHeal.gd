extends Node


var data = {
	"name": "multiHeal",
	"baseAmount": 1,
	"side": "player",
	"positions": {
		"type": "multi",
		"shape": "column",
		"targets": {
			"columns": [1, 2, 3, 4]
		}
	}
}
