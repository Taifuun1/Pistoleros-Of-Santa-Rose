extends TileMap
class_name WFCBaseClass

@onready var constants = preload("res://Location/Location Generation/Wave Function Collapse/WFCConstants.gd").new()
@onready var edgeTile = preload("res://Location/Location Generation/Wave Function Collapse/EdgeTile.gd")
@onready var helperFunctions = preload("res://Location/Location Generation/Wave Function Collapse/WFCHelperFunctions.gd").new()

@onready var tiles
@onready var adjacentTileDirections = constants.adjacentTileDirections

var entropyVariation = 0

var inputs
var generatedTiles = {}
var edgeTiles = []
var nonLegibleTiles = []


func selectInputSet(inputSet) -> void:
	inputs = WaveFunctionCollapse.inputs[inputSet]

func resetGeneration() -> void:
	generatedTiles.clear()
	edgeTiles.clear()
	nonLegibleTiles.clear()
