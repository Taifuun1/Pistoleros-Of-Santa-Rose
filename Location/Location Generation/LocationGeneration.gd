extends AStar

#@export var noise = FastNoiseLite.new()

var chunkGenerationTypes

var generatedChunkPosition
var generatedChunk = {}
var tileTypes = {
	"water": [],
	"grass": [],
	"forest": []
}
var interactables = []


func _ready():
	set_process_thread_group(PROCESS_THREAD_GROUP_SUB_THREAD)

func initGeneration(selectedChunk: Vector2i, generatedLocation: String):
	generatedChunkPosition = selectedChunk
	generatedChunk = {}
	
	chunkGenerationTypes = load("res://Data/Location Generation/{generatedLocation}.gd".format({ "generatedLocation": generatedLocation.replace(" ", "") })).new().chunkGenerationTypes
	
	$WFCChunkGenerator.generateChunk(generatedLocation, generatedChunkPosition)

func processTiles(tiles: Dictionary):
	generatedChunk.tiles = tiles
	generatedChunk.interactables = interactables
	
	var chanceTable = []
	for type in chunkGenerationTypes.chance:
		for tableItem in chunkGenerationTypes.chance[type]:
			chanceTable.append(type)
	
	var generationType = chanceTable[randi() % chanceTable.size()]
	#print("generationType ", generationType)
	var generationCommands = chunkGenerationTypes.types[generationType]
	
	for generationCommand in generationCommands:
		if generationCommands[generationCommand] == null:
			Callable($ChunkProcessor, generationCommand).call()
			continue
		Callable($ChunkProcessor, generationCommand).call(generationCommands[generationCommand])

	$"../..".call_thread_safe("chunkFinished", generatedChunkPosition, generatedChunk.duplicate(true), name)
