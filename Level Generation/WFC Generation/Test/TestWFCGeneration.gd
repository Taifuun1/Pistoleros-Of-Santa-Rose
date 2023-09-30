extends TileMap

@onready var waveFunctionCollapse = preload("res://Level Generation/WFC Generation/WaveFunctionCollapse.tscn")

var generatedChunks = [
	Vector2i(0,0)
]
var edgeChunks = [
	Vector2i(-1,0),
	Vector2i(0,-1),
	Vector2i(0,1),
	Vector2i(1,0)
]
var currentlyLoadedChunks = [
	Vector2i(0,0)
]

func _ready():
	$"../WFCInputCreation".addInputs("Test", "res://Level Generation/WFC Generation/Test/Inputs")
	WaveFunctionCollapse.inputs.grass = $"../WFCInputCreation".assignInputsForInputSet()
	$"../WFCInputCreation".removeInputs()
	generateStartingChunks()

func _checkChunks():
	var _playerLocationVector2 = Vector2(local_to_map($"../Player".position))
	var _edgeChunksToBeChecked = []
	for _edgeChunk in edgeChunks:
		if _playerLocationVector2.distance_to(_edgeChunk) <= 2 and !(_edgeChunk in currentlyLoadedChunks):
			var waveFunctionCollapseInstance = waveFunctionCollapse.instantiate()
			waveFunctionCollapseInstance.selectInputSet("grass")
			add_child(waveFunctionCollapseInstance)
			waveFunctionCollapseInstance.generateChunk(_edgeChunk)
			if !generatedChunks.has(_edgeChunk):
				generatedChunks.append(_edgeChunk)
			currentlyLoadedChunks.append(_edgeChunk)
			_edgeChunksToBeChecked.append(_edgeChunk)
	
	var _newEdgeChunks = edgeChunks.duplicate(true)
	for _edgeChunk in _edgeChunksToBeChecked:
		_newEdgeChunks.append_array(checkForEdgeChunks(_edgeChunk, _newEdgeChunks))
		_newEdgeChunks.erase(_edgeChunk)
	var _removedChunksToBeChecked = []
	var _newCurrentlyLoadedChunks = currentlyLoadedChunks.duplicate(true)
	for _currentlyLoadedChunk in currentlyLoadedChunks:
		if _playerLocationVector2.distance_to(_currentlyLoadedChunk) > 2:
			var _generatedChunkToLocal = Vector2i(0, 0)
			if _currentlyLoadedChunk.x > 0 or _currentlyLoadedChunk.x < 0:
				_generatedChunkToLocal.x = _currentlyLoadedChunk.x * 50
			if _currentlyLoadedChunk.y > 0 or _currentlyLoadedChunk.y < 0:
				_generatedChunkToLocal.y = _currentlyLoadedChunk.y * 50
			$"../Tiles".resetChunkTiles(_generatedChunkToLocal)
			_newCurrentlyLoadedChunks.erase(_currentlyLoadedChunk)
			_removedChunksToBeChecked.append(_currentlyLoadedChunk)
	for _removedChunk in _removedChunksToBeChecked:
		_newEdgeChunks.append(_removedChunk)
		_newEdgeChunks = checkForLegibleEdgeChunks(_removedChunk, _newCurrentlyLoadedChunks, _newEdgeChunks)
	edgeChunks = _newEdgeChunks
	currentlyLoadedChunks = _newCurrentlyLoadedChunks
	
	for _chunk in edgeChunks:
		var _generatedChunkToLocal = Vector2i(0, 0)
		if _chunk.x > 0 or _chunk.x < 0:
			_generatedChunkToLocal.x = _chunk.x * 50 + WaveFunctionCollapse.gridSize.x / 2
		if _chunk.y > 0 or _chunk.y < 0:
			_generatedChunkToLocal.y = _chunk.y * 50 + WaveFunctionCollapse.gridSize.y / 2
		$"../Tiles".set_cell(0, _generatedChunkToLocal, 2, Vector2(0, 0))
	
	$"../ChunkCheckTimer".start()

func generateStartingChunks() -> void:
	var waveFunctionCollapseInstance = waveFunctionCollapse.instantiate()
	waveFunctionCollapseInstance.name = "startingWFC"
	waveFunctionCollapseInstance.selectInputSet("grass")
	add_child(waveFunctionCollapseInstance)
	$startingWFC.generateChunk(Vector2i(0,0))
	$"../ChunkCheckTimer".start()

func checkForEdgeChunks(_edgeChunk, _currentEdgeChunks):
	var _newEdgeChunks = []
	var _directionalDirections = [
		Vector2i(-1,0),
		Vector2i(0,-1),
		Vector2i(0,1),
		Vector2i(1,0)
	]
	for _direction in _directionalDirections:
		var _checkedChunk = _edgeChunk + _direction
		if (
			!currentlyLoadedChunks.has(_checkedChunk) and
			!_currentEdgeChunks.has(_checkedChunk) and
			!_newEdgeChunks.has(_checkedChunk)
		):
			_newEdgeChunks.append(_checkedChunk)
	return _newEdgeChunks

func checkForLegibleEdgeChunks(_removedChunk, _currentlyLoadedChunks, _newEdgeChunks):
	var _newCurrentEdgeChunks = _newEdgeChunks.duplicate(true)
	var _directionalDirections = [
		Vector2i(-1,0),
		Vector2i(0,-1),
		Vector2i(0,1),
		Vector2i(1,0)
	]
	for _chunkCheckDirection in _directionalDirections:
		var _checkedChunk = _removedChunk + _chunkCheckDirection
		if !_newCurrentEdgeChunks.has(_checkedChunk) and checkIfCurrentlyLoadedChunksDirectionalToChunk(_checkedChunk, _currentlyLoadedChunks):
			_newCurrentEdgeChunks.append(_checkedChunk)
		else:
			_newCurrentEdgeChunks.erase(_checkedChunk)
	return _newCurrentEdgeChunks

func checkIfCurrentlyLoadedChunksDirectionalToChunk(_chunk, _currentlyLoadedChunks):
	var _directionalDirections = [
		Vector2i(-1,0),
		Vector2i(0,-1),
		Vector2i(0,1),
		Vector2i(1,0)
	]
	for _directionalChunkCheckDirection in _directionalDirections:
		var _checkedDirectionalChunk = _chunk + _directionalChunkCheckDirection
		if _currentlyLoadedChunks.has(_checkedDirectionalChunk):
			return true
	return false
