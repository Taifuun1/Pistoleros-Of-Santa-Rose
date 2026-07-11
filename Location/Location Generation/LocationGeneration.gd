extends AStar

#@export var noise = FastNoiseLite.new()

## A pure-data WFC solve submitted to WorkerThreadPool. Process thread groups
## are synchronized with the frame and therefore still stall rendering when a
## group spends hundreds of milliseconds inside WFCSolver.run(). A worker-pool
## task is not part of that frame barrier.
class ChunkSolveTask:
	extends RefCounted

	var _mutex := Mutex.new()
	var _solver: WFCSolver
	var _result: Dictionary
	var _completed := false

	func _init(solver: WFCSolver) -> void:
		_solver = solver

	func run() -> void:
		var solvedTiles := _solver.run()
		_mutex.lock()
		_result = solvedTiles
		_completed = true
		_mutex.unlock()

	func isCompleted() -> bool:
		_mutex.lock()
		var completed := _completed
		_mutex.unlock()
		return completed

	func takeResult() -> Dictionary:
		_mutex.lock()
		var solvedTiles := _result
		_mutex.unlock()
		return solvedTiles

var chunkGenerationTypes

var generatedChunkPosition
var generatedChunk = {}
var tileTypes = {
	"water": [],
	"grass": [],
	"forest": []
}
var interactables = []
var solveTask: ChunkSolveTask
var solveTaskId := -1


func _ready():
	set_process(false)

func initGeneration(selectedChunk: Vector2i, generatedLocation: String):
	generatedChunkPosition = selectedChunk
	generatedChunk = {}
	
	chunkGenerationTypes = load("res://Data/Location Generation/{generatedLocation}.gd".format({ "generatedLocation": generatedLocation.replace(" ", "") })).new().chunkGenerationTypes
	
	var model: WFCModel = WaveFunctionCollapse.models[generatedLocation]
	var chunkSeed := WFCSolver.makeSeed(generatedLocation, generatedChunkPosition, WaveFunctionCollapse.baseSeed)
	var solver := WFCSolver.new(model, WaveFunctionCollapse.gridSize, chunkSeed)
	solveTask = ChunkSolveTask.new(solver)
	solveTaskId = WorkerThreadPool.add_task(solveTask.run, false, "WFC chunk %s" % str(generatedChunkPosition))
	set_process(true)


func _process(_delta: float) -> void:
	if solveTask == null or not solveTask.isCompleted():
		return
	# Release WorkerThreadPool's task bookkeeping. The task has already published
	# completion, so this only waits for its run() call to return and cannot turn
	# the expensive solve back into a main-thread wait.
	WorkerThreadPool.wait_for_task_completion(solveTaskId)
	var tiles := solveTask.takeResult()
	solveTask = null
	solveTaskId = -1
	set_process(false)
	processTiles(tiles)


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
