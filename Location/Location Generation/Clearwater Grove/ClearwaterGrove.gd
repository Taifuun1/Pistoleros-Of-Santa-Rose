extends TileMap

@export var noiseTest = FastNoiseLite.new()

func _ready():
	init()

func init():
	noiseTest.seed = randi()
	generateWater()
	$WFCChunkGenerator.generateChunk("Clearwater Grove")

func generateWater():
	var tilePosition = local_to_map(Vector2(0, 0))
	for x in range(240):
		for y in range(240):
			var noise = noiseTest.get_noise_2d(tilePosition.x - 120 + x, tilePosition.y - 120 + y)
			
			var tile = 0
			if noise > 0.35:
				tile = 1
			set_cell(0, Vector2i(tilePosition.x - 120 + x, tilePosition.y - 120 + y), 0, Vector2(tile, 0))

func setTiles(_tiles):
	for _tile in _tiles:
		set_cell(0, Vector2i(_tile.x, _tile.y), _tiles[_tile], Vector2(0, 0))
