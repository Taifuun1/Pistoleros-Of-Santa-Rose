extends LocationMapBase

## Keep background generation deliberately conservative. WFC is CPU-heavy and
## there is no benefit in saturating several cores to generate distant chunks
## while the player is using the already-ready current chunk.
const CONCURRENT_CHUNK_GENERATORS := 1


func _ready():
	randomize()
	setChunkPriority(Vector2i(0, 0))
	$Entities/Actors/PlayerActor.position = $Map.map_to_local(Vector2i(11, 1))
	$ChunkGenerators/WFCInputCreation.initWFCGeneration([Locations.currentLocation])
	
	# Initialize the player reveal controller
	var reveal_controller = $Entities/PlayerRevealController
	if reveal_controller != null:
		reveal_controller.init($Entities/Actors/PlayerActor)

func initWFCGenerationFinished():
	emptyChunks.append_array($ChunkGenerators/LocationMapLayoutGeneration.generateMapLayout())
	emptyChunks.erase(Vector2i(0, 0))
	for _generator in CONCURRENT_CHUNK_GENERATORS:
		generateNewChunk()

func chunkFinished(generatedChunk: Vector2i, data: Dictionary, idleGenerator: String):
	idleGenerators.append(idleGenerator)
	generatedChunks[generatedChunk] = data
	generateNewChunk()

func generateNewChunk():
	if emptyChunks.is_empty():
		return
	var generatorName = idleGenerators.pop_front()
	var generator = get_node("ChunkGenerators/{generatorName}".format({ "generatorName": generatorName }))
	if chunkPriority != null and !generatedChunks.has(chunkPriority):
		var prioritizedChunk: Vector2i = chunkPriority
		chunkPriority = null
		emptyChunks.erase(prioritizedChunk)
		generator.call_deferred("initGeneration", prioritizedChunk, Locations.currentLocation)
		return
	generator.call_deferred("initGeneration", emptyChunks.pop_front(), Locations.currentLocation)
