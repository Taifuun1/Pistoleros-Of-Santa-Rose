extends AStar

#@export var noise = FastNoiseLite.new()

var chunkGenerationTypes

signal generationCompleted(tile: int, toTile: int, areaSize: int)

var generatedChunkPosition
var generatedChunk = {}


func _ready():
	set_process_thread_group(PROCESS_THREAD_GROUP_SUB_THREAD)

func initGeneration(selectedChunk: Vector2i, generatedLocation: String):
	generatedChunkPosition = selectedChunk
	generatedChunk = {}
	
	chunkGenerationTypes = load("res://Data/Location Generation/{generatedLocation}.gd".format({ "generatedLocation": generatedLocation.replace(" ", "") })).new().chunkGenerationTypes
	
	print("genning", generatedChunkPosition)
	
	$WFCChunkGenerator.generateChunk("Clearwater Grove", generatedChunkPosition)

func processTiles(tiles: Dictionary):
	generatedChunk.tiles = tiles
	
	var chanceTable = []
	for type in chunkGenerationTypes.chance:
		for tableItem in chunkGenerationTypes.chance[type]:
			chanceTable.append(type)
	
	var generationType = chanceTable[randi() % chanceTable.size()]
	print("generationType ", generationType)
	var generationCommands = chunkGenerationTypes.types[generationType]
	
	for generationCommand in generationCommands:
		if generationCommands[generationCommand] == null:
			Callable($ChunkProcessor, generationCommand).call()
			continue
		Callable($ChunkProcessor, generationCommand).call(generationCommands[generationCommand])

	$"../..".call_thread_safe("chunkFinished", generatedChunkPosition, generatedChunk.duplicate(true), name)
