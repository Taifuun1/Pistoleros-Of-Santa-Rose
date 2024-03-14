extends AStar

@export var noiseTest = FastNoiseLite.new()

signal generationCompleted(tile: int, toTile: int, areaSize: int)

var generatedChunkPosition
var generatedChunkTiles = {}


func _ready():
	set_process_thread_group(PROCESS_THREAD_GROUP_SUB_THREAD)

func initGeneration(selectedChunk: Vector2i):
	generatedChunkPosition = selectedChunk
	generatedChunkTiles = {}
	
	print("genning", generatedChunkPosition)
	
	noiseTest.seed = randi()
	$WFCChunkGenerator.generateChunk("Clearwater Grove", generatedChunkPosition)

func processTiles(tiles: Dictionary, tile: int, toTile: int, areaSize: int):
	generatedChunkTiles = tiles
	generateWater()
	setTiles(generatedChunkTiles)
	#$ChunkProcessor.cleanUpTile(tile, toTile, areaSize)
	$ChunkProcessor.getChunkOpenBorderTiles()
	$ChunkProcessor.connectBorderEntrances()
	$ChunkProcessor.randomizeTrees(15)
	clear()
	$"../..".call_thread_safe("chunkFinished", generatedChunkPosition, generatedChunkTiles, name)

func generateWater():
	var tilePosition = local_to_map(Vector2(0, 0))
	for x in range(24):
		for y in range(48):
			var noise = noiseTest.get_noise_2d(tilePosition.x + x, tilePosition.y + y)
			
			var tile = 1
			if noise > 0.35:
				tile = 0
			
			if tile == 0:
				generatedChunkTiles[Vector2i(x, y)] = tile

func setTiles(tiles):
	for tile in tiles:
		set_cell(0, Vector2i(tile.x, tile.y), tiles[tile], Vector2(0, 0))
