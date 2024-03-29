extends LocationMapBase


func _ready():
	randomize()
	setChunkPriority(Vector2i(0, 0))
	$Entities/Actors/PlayerActor.position = $Map.map_to_local(Vector2i(11, 1))
	$ChunkGenerators/WFCInputCreation.initWFCGeneration(["Clearwater Grove"])

func initWFCGenerationFinished():
	emptyChunks.append_array($ChunkGenerators/LocationMapLayoutGeneration.generateMapLayout())
	emptyChunks.erase(Vector2i(0, 0))
	for idleGenerator in 3:
		generateNewChunk()

func chunkFinished(generatedChunk: Vector2i, data: Dictionary, idleGenerator: String):
	idleGenerators.append(idleGenerator)
	generatedChunks[generatedChunk] = data
	#print("finished generating", generatedChunk)
	generateNewChunk()

func generateNewChunk():
	if emptyChunks.is_empty():
		return
	var generatorName = idleGenerators.pop_front()
	if chunkPriority != null and !generatedChunks.has(chunkPriority):
		get_node("ChunkGenerators/{generatorName}".format({ "generatorName": generatorName })).call_thread_safe("initGeneration", chunkPriority, currentGeneration)
		chunkPriority = null
		return
	get_node("ChunkGenerators/{generatorName}".format({ "generatorName": generatorName })).call_thread_safe("initGeneration", emptyChunks.pop_front(), currentGeneration)
