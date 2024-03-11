extends AStar

@export var noiseTest = FastNoiseLite.new()


func _ready():
	init()

func init():
	noiseTest.seed = randi()
	generateWater()
	$WFCChunkGenerator.generateChunk("Clearwater Grove")

func processTiles(tile: int, toTile: int, areaSize: int):
	#$ChunkProcessor.cleanUpTile(tile, toTile, areaSize)
	$ChunkProcessor.getChunkOpenBorderTiles()
	$ChunkProcessor.connectBorderEntrances()
	$ChunkProcessor.addTrees("Birch", 4)

func generateWater():
	var tilePosition = local_to_map(Vector2(0, 0))
	for x in range(240):
		for y in range(240):
			var noise = noiseTest.get_noise_2d(tilePosition.x - 120 + x, tilePosition.y - 120 + y)
			
			var tile = 0
			if noise > 0.35:
				tile = 1
			set_cell(0, Vector2i(tilePosition.x - 120 + x, tilePosition.y - 120 + y), 0, Vector2(tile, 0))

func setTiles(tiles):
	for tile in tiles:
		if get_cell_source_id(0, tile) == 0 and get_cell_atlas_coords(0, tile) == Vector2i(0, 0):
			set_cell(0, Vector2i(tile.x, tile.y), tiles[tile], Vector2(0, 0))
