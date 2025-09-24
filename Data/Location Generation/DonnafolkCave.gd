extends Node


var generationVariables = {
	"tileset": 1,
	"trees": "Mushroom"
}

var chunkGenerationTypes = {
	"chance": {
		"dry stalagmites": 30,
		"stalagmites": 20,
		"mushrooms": 40,
		"lakes": 10
	},
	"types": {
		"stalagmites": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/DonnafolkCaveLakes.tres"),
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
			"addInteractables": [
				#{
					#"name": "Golden Alexander",
					#"type": "Flowers",
					#"count": [3, 13],
					#"tileType": "ground"
				#}
			]
		},
		"dry stalagmites": {
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
				#{
					#"name": "Golden Alexander",
					#"type": "Flowers",
					#"count": [3, 13],
					#"tileType": "ground"
				#}
			]
		},
		"mushrooms": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/DonnafolkCaveLakes.tres"),
				"noiseCutoff": 0.25
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
			"addInteractables": [
				#{
					#"name": "Golden Alexander",
					#"type": "Flowers",
					#"count": [3, 13],
					#"tileType": "ground"
				#}
			]
		},
		"lakes": {
			"generateFromNoiseMap": {
				"noiseMap": load("res://Location/Location Generation/Noise Maps/DonnafolkCaveLakes.tres"),
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
			"addInteractables": [
				#{
					#"name": "Golden Alexander",
					#"type": "Flowers",
					#"count": [3, 13],
					#"tileType": "ground"
				#}
			]
		}
	}
}
