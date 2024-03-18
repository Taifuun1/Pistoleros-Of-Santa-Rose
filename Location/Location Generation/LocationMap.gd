extends LocationMapHelpers


func _ready():
	randomize()
	setChunkPriority(Vector2i(0, 0))
	$ChunkGenerators/WFCInputCreation.initWFCGeneration(["Clearwater Grove"])

func initWFCGenerationFinished():
	emptyChunks.append_array($ChunkGenerators/LocationMapLayoutGeneration.generateMapLayout())
	emptyChunks.erase(Vector2i(0, 0))
	for idleGenerator in 3:
		generateNewChunk()

func chunkFinished(generatedChunk: Vector2i, data: Dictionary, idleGenerator: String):
	idleGenerators.append(idleGenerator)
	generatedChunks[generatedChunk] = data
	if currentChunk == Vector2i(0, 0) and generatedChunk == Vector2i(0, 0):
		currentChunk = Vector2i(0, 0)
		generatedChunks[generatedChunk].openBorders.top = {
			"firstOpenTile": Vector2i(11, 0),
			"lastOpenTile": Vector2i(12, 1),
			"tiles": [
				Vector2i(11, 0),
				Vector2i(11, 1),
				Vector2i(12, 0),
				Vector2i(12, 1)
			],
			"halfwayTile": Vector2i(11, 1)
		}
		changeChunk("bottom")
		#currentChunk = Vector2i(0, 0)
		#$Map.setTiles(generatedChunks[currentChunk])
		#var tileTypes = transformWFCTilesToMapTiles(generatedChunks[currentChunk])
		#for tileType in tileTypes:
			#match tileType:
				#"water":
					#$Map.setTerrainTiles(tileTypes[tileType], 0, 1)
				#"ground":
					#$Map.setTerrainTiles(tileTypes[tileType], 0, 0)
				#"trees":
					#$Map.setTerrainTiles(tileTypes[tileType], 0, 2)
		#addTrees(tileTypes.trees, "Birch", 4)
		#addExits(openBorderTiles)
		#$UI/Loading.hide()
	print()
	print("finished generating", generatedChunk)
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
