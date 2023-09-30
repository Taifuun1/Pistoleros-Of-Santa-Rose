extends TileMap
class_name WFCBaseClass

@onready var constants = preload("res://Level Generation/WFC Generation/WFCConstants.gd").new()
@onready var edgeTile = preload("res://Level Generation/WFC Generation/EdgeTile.gd")
@onready var helperFunctions = preload("res://Level Generation/WFC Generation/WFCHelperFunctions.gd").new()

@onready var tiles = constants.tiles
@onready var adjacentTileDirections = constants.adjacentTileDirections

var entropyVariation = 0

var inputs
var generatedTiles = {}
var edgeTiles = []
var nonLegibleTiles = []


func selectInputSet(_set):
	inputs = WaveFunctionCollapse.inputs[_set]

func resetGeneration() -> void:
	inputs.clear()
	generatedTiles.clear()
	edgeTiles.clear()
	nonLegibleTiles.clear()
