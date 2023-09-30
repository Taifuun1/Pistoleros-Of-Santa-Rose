
########################
### Helper functions ###
########################

func sortToLowestEntropy(a, b) -> bool:
	return a.matches.size() < b.matches.size()

func checkIfArrayOfClassesHasValue(_array, _property, _value) -> int:
	for _index in _array.size():
		if _array[_index][_property] == _value:
			return _index
	return -1

func isTileOutsideGrid(_tile) -> bool:
	return (
		_tile.x < 1 or
		_tile.y < 1 or
		_tile.x > WaveFunctionCollapse.gridSize.x - 2 or
		_tile.y > WaveFunctionCollapse.gridSize.y - 2
	)

func isTileInsideGrid(_tile) -> bool:
	return (
		_tile.x >= 0 and
		_tile.y >= 0 and
		_tile.x < WaveFunctionCollapse.gridSize.x and
		_tile.y < WaveFunctionCollapse.gridSize.y
	)
