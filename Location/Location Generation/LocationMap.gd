extends LocationMapHelpers

var emptyChunks = []
var currentlyGeneratingChunks = []
var idleGenerators = ["Gen1", "Gen2", "Gen3"]
var chunkPriority = null

var generatedChunks = {}

var currentChunk = null


func _ready():
	randomize()
	setChunkPriority(Vector2i(0, 0))
	$ChunkGenerators/WFCInputCreation.initWFCGeneration(["Clearwater Grove"])

func initWFCGenerationFinished():
	emptyChunks.append_array($ChunkGenerators/LocationMapLayoutGeneration.generateMapLayout())
	for idleGenerator in 3:
		generateNewChunk()

func chunkFinished(generatedChunk: Vector2i, tiles: Dictionary, idleGenerator: String):
	idleGenerators.append(idleGenerator)
	generatedChunks[generatedChunk] = tiles
	if currentChunk == null and generatedChunk == Vector2i(0, 0):
		currentChunk = Vector2i(0, 0)
		$Map.setTiles(generatedChunks[currentChunk])
		addTrees("Birch", 4)
		$UI/Loading.hide()
	print()
	print("finished")
	print("chunk count:", generatedChunks.size())
	print("empty chunk count:", emptyChunks.size())
	generateNewChunk()

func generateNewChunk():
	if emptyChunks.is_empty():
		return
	var generatorName = idleGenerators.pop_front()
	if chunkPriority != null:
		get_node("ChunkGenerators/{generatorName}".format({ "generatorName": generatorName })).call_thread_safe("initGeneration", chunkPriority)
		chunkPriority = null
		return
	get_node("ChunkGenerators/{generatorName}".format({ "generatorName": generatorName })).call_thread_safe("initGeneration", emptyChunks.pop_front())

func setChunkPriority(chunk: Vector2i):
	chunkPriority = chunk

func generateChunks(thread):
	while(!emptyChunks.is_empty()):
		var chunkGenerationDone = false
		var generatorName = generateNewChunk()
		while !chunkGenerationDone:
			MultiThreading.semaphore.wait()
			get_node("ChunkGenerators/{generatorName}".format({ "generatorName": generatorName })).doWFCGenerationCycle()
			
	call_deferred("checkIfThreadsAreDone")
	thread.call_deferred("wait_to_finish")

func checkIfAGeneratorIsIdle():
	if idleGenerators.is_empty():
		return null
	return 
