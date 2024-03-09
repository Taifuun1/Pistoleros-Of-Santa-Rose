extends TileMap
class_name WFCBaseClass

@onready var constants = preload("res://Location/Location Generation/WFCConstants.gd").new()
@onready var edgeTile = preload("res://Location/Location Generation/EdgeTile.gd")
@onready var helperFunctions = preload("res://Location/Location Generation/WFCHelperFunctions.gd").new()

@onready var tiles
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
