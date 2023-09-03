extends TileMap
class_name WFCBaseClass

@onready var constants = preload("res://Objects/WFCConstants.gd").new()
@onready var edgeTile = preload("res://Objects/EdgeTile.gd")
@onready var helperFunctions = preload("res://Objects/WFCHelperFunctions.gd").new()

@onready var tiles = constants.tiles
@onready var adjacentTileDirections = constants.adjacentTileDirections

#var gridSize = Vector2(60,28)
var gridSize = Vector2(24,24)
var entropyVariation = 0

var allInputs
var generatedTiles = {}
var edgeTiles = []
var nonLegibleTiles = []


func resetGeneration() -> void:
	allInputs.clear()
	generatedTiles.clear()
	edgeTiles.clear()
	nonLegibleTiles.clear()
