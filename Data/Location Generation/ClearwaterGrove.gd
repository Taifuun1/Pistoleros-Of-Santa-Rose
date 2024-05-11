extends Node


var chunkGenerationTypes = {
	"chance": {
		"forest": 50,
		"sparse forest": 40,
		"lakes": 10
	},
	"types": {
		"forest": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/ClearwaterGroveLakes.tres"),
				"noiseCutoff": 0.35
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
			"countTileTypes": null,
			"addInteractables": [
				{
					"name": "Golden Alexander",
					"type": "Flowers",
					"count": [3, 13],
					"tileType": "grass"
				}
			]
		},
		"sparse forest": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/ClearwaterGroveLakes.tres"),
				"noiseCutoff": 0.35
			},
			"cleanUpTile": {
				"fromTile": 2,
				"toTile": 1,
				"areaSize": 4
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
			"countTileTypes": null,
			"addInteractables": [
				{
					"name": "Golden Alexander",
					"type": "Flowers",
					"count": [3, 13],
					"tileType": "grass"
				}
			]
		},
		"lakes": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/ClearwaterGroveLakes.tres"),
				"noiseCutoff": 0.1
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
			"countTileTypes": null,
			"addInteractables": [
				{
					"name": "Golden Alexander",
					"type": "Flowers",
					"count": [3, 13],
					"tileType": "grass"
				}
			]
		}
	}
}
