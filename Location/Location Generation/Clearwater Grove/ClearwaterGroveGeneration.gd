extends AStar

#@export var waterNoise = FastNoiseLite.new()

signal generationCompleted(tile: int, toTile: int, areaSize: int)

var generatedChunkPosition
var generatedChunk = {}


func _ready():
	set_process_thread_group(PROCESS_THREAD_GROUP_SUB_THREAD)

func initGeneration(selectedChunk: Vector2i):
	generatedChunkPosition = selectedChunk
	generatedChunk = {}
	
	print("genning", generatedChunkPosition)
	
	$WFCChunkGenerator.generateChunk("Clearwater Grove", generatedChunkPosition)

func processTiles(tiles: Dictionary, tile: int, toTile: int, areaSize: int):
	generatedChunk.tiles = tiles
	$ChunkProcessor.generateWater()
	#setTiles(generatedChunk)
	#$ChunkProcessor.cleanUpTile(tile, toTile, areaSize)
	$ChunkProcessor.getOpenBorderTiles()
	$ChunkProcessor.connectBorderEntrances()
	#$ChunkProcessor.randomizeTrees(15)
	$ChunkProcessor.randomizeTileToTile(1, 2, 15)
	$ChunkProcessor.transformOpenBordersToTiles()
	$ChunkProcessor.fillVisibleEmptyTiles()
	#$ChunkProcessor.cleanUpBorders()
	$"../..".call_thread_safe("chunkFinished", generatedChunkPosition, generatedChunk.duplicate(true), name)
