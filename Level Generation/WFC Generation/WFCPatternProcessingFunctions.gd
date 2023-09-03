extends WFCBaseClass
class_name WFCPatternProcessing


##################################
### Pattern matching functions ###
##################################

func createNewPattern() -> PackedInt32Array:
	var _newInputPattern = PackedInt32Array()
	for i in range(9):
		_newInputPattern.append(-1)
	return _newInputPattern

func getPartialPatternForTile(_tile, _generatedTiles, _testTiles = null) -> PackedInt32Array:
	var _partialPattern = createNewPattern()
	var _i = 0
	for _x in range(-1, 2):
		for _y in range(-1, 2):
			var _checkedTile = Vector2(_tile.x + _x, _tile.y + _y).floor()
			if _testTiles != null and _testTiles.has(Vector2(_x, _y)):
				_partialPattern[_i] = _testTiles[Vector2(_x, _y)]
			elif _generatedTiles.has(_checkedTile):
				_partialPattern[_i] = _generatedTiles[_checkedTile]
			else:
				_partialPattern[_i] = -1
			_i += 1
	return _partialPattern

func findAllPartialPatternMatches(_partialPattern) -> Array:
	var _matches = []
	for _inputPattern in allInputs:
		var _match = isPartialPatternAMatch(_partialPattern, _inputPattern)
		if _match and !doesMatchesHavePattern(_partialPattern, _matches):
			_matches.append(_inputPattern)
	return _matches

func isPartialPatternAMatch(_partialPattern: PackedInt32Array, _inputPattern: PackedInt32Array) -> bool:
	for i in _partialPattern.size():
			if _partialPattern[i] != -1 and _partialPattern[i] != _inputPattern[i]:
				return false
	return true

func isPatternFull(_tile, _tilesToBeChanged) -> bool:
	var _partialPattern = getPartialPatternForTile(_tile, generatedTiles)
	var _tileCount = 0
	for _adjacentTileDirection in adjacentTileDirections:
		var _adjacentTile = Vector2(_tile.x + _adjacentTileDirection.x, _tile.y + _adjacentTileDirection.y)
		if (
			(
				_tilesToBeChanged.has(_adjacentTile)
			) or
			(
				!_tilesToBeChanged.has(_adjacentTile) and
				generatedTiles.has(_adjacentTile)
			)
		):
			_tileCount += 1
		else:
			return false
	return _tileCount == 9

func doesMatchesHavePattern(_newInputPattern, _patterns) -> bool:
	for _inputPattern in _patterns:
		if arePatternsEqual(_newInputPattern, _inputPattern):
			return true
	return false

func arePatternsEqual(_newInputPattern: PackedInt32Array, _inputPattern: PackedInt32Array) -> bool:
	for i in _newInputPattern.size():
			if _newInputPattern[i] != _inputPattern[i]:
				return false
	return true
