extends Node


var generationVariables = {
	"tileset": 1,
	"trees": "Mushroom"
}

var chunkGenerationTypes = {
	"chance": {
		"open shaft": 40,
		"ore vein": 35,
		"stream": 15,
		"bandit camp": 10
	},
	"types": {
		"open shaft": {
			"getOpenBorderTiles": null,
			"connectBorderEntrances": null,
			"randomizeTileToTile": {
				"fromTileType": 2,
				"toTileType": 1,
				"tileChance": 20
			},
			"transformOpenBordersToTiles": null,
			"fillVisibleEmptyTiles": null,
			"addInteractables": [
				{
					"name": "Mining",
					"type": "Gold Rush",
					"count": [2, 5],
					"tileType": "ground"
				}
			]
		},
		"ore vein": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/WestFieldMinesRocks.tres"),
				"noiseCutoff": 0.3
			},
			"cleanUpTile": {
				"fromTile": 2,
				"toTile": 1,
				"areaSize": 3
			},
			"getOpenBorderTiles": null,
			"connectBorderEntrances": null,
			"randomizeTileToTile": {
				"fromTileType": 2,
				"toTileType": 1,
				"tileChance": 10
			},
			"transformOpenBordersToTiles": null,
			"fillVisibleEmptyTiles": null,
			"addInteractables": [
				{
					"name": "Mining",
					"type": "Gold Rush",
					"count": [3, 7],
					"tileType": "ground"
				}
			]
		},
		"stream": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/WestFieldMinesRocks.tres"),
				"noiseCutoff": 0.15
			},
			"cleanUpTile": {
				"fromTile": 2,
				"toTile": 1,
				"areaSize": 2
			},
			"getOpenBorderTiles": null,
			"connectBorderEntrances": null,
			"randomizeTileToTile": {
				"fromTileType": 2,
				"toTileType": 1,
				"tileChance": 15
			},
			"transformOpenBordersToTiles": null,
			"fillVisibleEmptyTiles": null,
			"addInteractables": [
				{
					"name": "Panning",
					"type": "Gold Rush",
					"count": [1, 3],
					"tileType": "ground"
				}
			]
		},
		"bandit camp": {
			"getOpenBorderTiles": null,
			"connectBorderEntrances": null,
			"randomizeTileToTile": {
				"fromTileType": 2,
				"toTileType": 1,
				"tileChance": 25
			},
			"transformOpenBordersToTiles": null,
			"fillVisibleEmptyTiles": null,
			"addInteractables": [
				{
					"name": "Robbing",
					"type": "Gold Rush",
					"count": [1, 2],
					"tileType": "ground"
				}
			]
		}
	}
}
