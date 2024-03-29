extends TileMap
class_name BaseLevel

var levelId
var dungeonType
var dungeonSection
var dungeonLevelName
var visibility

var grid = []
var rooms = []
var areas = []
var openTiles = []
var spawnableItemTiles = []
var spawnableCritterTiles = []
var floorTiles = []
var stairs = { }
var additionalData = { }

var critters = []

func create(_dungeonType, _dungeonSection, _dungeonLevelName, _visibility):
#	levelId = Globals.levelId
#	name = str(Globals.levelId)
#	Globals.levelId += 1
	dungeonType = _dungeonType
	dungeonSection = _dungeonSection
	dungeonLevelName = _dungeonLevelName
	visibility = _visibility

#func createGrid(_tile = Globals.tiles.EMPTY, _generateNewLevel = true):
func createGrid(_tile = null, _generateNewLevel = true):
	if _generateNewLevel:
		pass
#		Globals.generatedLevels += 1
#		$"/root/World/UI/UITheme/Dancing Dragons".call_deferred("setLoadingText", "Generating level... (This will take a few minutes)\n{generatedLevels}".format({ "generatedLevels": Globals.generatedLevels }))
#	for x in range(Globals.gridSize.x):
#		grid.append([])
#		for _y in range(Globals.gridSize.y):
#			grid[x].append({
#				"tile": _tile,
#				"tileMetaData": {
#					"xFlip": false,
#					"yFlip": false
#				},
#				"critter": null,
#				"items": [],
#				"effects": [],
#				"interactable": null
#			})



####################################
### Dungeon generation functions ###
####################################

func placeStairs(_stairType = "DUNGEON", _stairData = []):
	if !spawnableItemTiles.empty() or !floorTiles.empty():
		if !_stairData.has("noDownStair"):
			stairs["downStair"] = placeStair("downStair", "DOWN_STAIR_", _stairType)
		if _stairData.has("makeSecondDownStair"):
			stairs["secondDownStair"] = placeStair("secondDownStair", "DOWN_STAIR_", _stairType)
		if !_stairData.has("noUpStair"):
			stairs["upStair"] = placeStair("upStair", "UP_STAIR_", _stairType)
		if _stairData.has("makeSecondUpStair"):
			stairs["secondUpStair"] = placeStair("secondUpStair", "UP_STAIR_", _stairType)
		for _stair in stairs.values():
			grid[_stair.x][_stair.y].interactable = null

func placeStair(_stairName, _stairTile, _stairType):
	for _i in range(10):
		var _stair = spawnableItemTiles[randi() % spawnableItemTiles.size()]
		if !floorTiles.empty():
			_stair = floorTiles[randi() % floorTiles.size()]
		if !isTileAStair(_stair):
#			grid[_stair.x][_stair.y].tile = Globals.tiles[_stairTile + "{type}".format({ "type": _stairType })]
			if floorTiles.has(_stair):
				floorTiles.erase(_stair)
			if spawnableItemTiles.has(_stair):
				spawnableItemTiles.erase(_stair)
			if spawnableCritterTiles.has(_stair):
				spawnableCritterTiles.erase(_stair)
			return _stair

func placeDoors(_doors, _checkIfNoDoorsInCorner = false):
	for _room in rooms:
		for _door in range(randi() % (_doors.max - _doors.min + 1) + _doors.min):
			placeDoor(_room, _checkIfNoDoorsInCorner)

func placeDoor(_room, _checkIfNoDoorsInCorner):
	for _i in range(20):
		var _tile
		if _checkIfNoDoorsInCorner:
			_tile = _room.walls[randi() % _room.walls.size()]
			var _up = _tile + Vector2i(0, -1)
			var _down = _tile + Vector2i(0, 1)
			var _left = _tile + Vector2i(-1, 0)
			var _right = _tile + Vector2i(1, 0)
#			if (
#				!isOutSideTileMap(_up) and
#				!isOutSideTileMap(_down) and
#				!isOutSideTileMap(_left) and
#				!isOutSideTileMap(_right) and
#				(
#					(
#						grid[_up.x][_up.y].tile == Globals.tiles.WALL_STONE_BRICK and
#						grid[_down.x][_down.y].tile == Globals.tiles.WALL_STONE_BRICK
#					) or
#					(
#						grid[_left.x][_left.y].tile == Globals.tiles.WALL_STONE_BRICK and
#						grid[_right.x][_right.y].tile == Globals.tiles.WALL_STONE_BRICK
#					) or
#					(
#						grid[_up.x][_up.y].tile == Globals.tiles.WALL_WOOD_PLANK and
#						grid[_down.x][_down.y].tile == Globals.tiles.WALL_WOOD_PLANK
#					) or
#					(
#						grid[_left.x][_left.y].tile == Globals.tiles.WALL_WOOD_PLANK and
#						grid[_right.x][_right.y].tile == Globals.tiles.WALL_WOOD_PLANK
#					)
#				)
#			):
#				pass
#			else:
#				continue
		else:
			_tile = _room.walls[randi() % _room.walls.size()]
		if isTileADoor(_tile):
			continue
		else:
#			grid[_tile.x][_tile.y].tile = Globals.tiles.DOOR_CLOSED
			_room.walls.erase(_tile)
			return
	push_error("Can't place doors")

#func areAllStairsConnected():
#	astarNode.clear()
#	pathFind(Globals.blockedTiles)
	
	if stairs.values().size() == 0 or (stairs.has("downStair") and stairs["downStair"] == null) or (stairs.has("upStair") and stairs["upStair"] == null):
		return false
	for startStair in stairs.values():
		for endStair in stairs.values():
			if startStair == endStair:
				continue
			if calculatePath(startStair, endStair).size() == 0:
				return false
	return true

#func fillEmptyTiles(_tile, _fillEdges = null):
#	for x in range(grid.size()):
#		for y in range(grid[x].size()):
#			if grid[x][y].tile == -1:
#				grid[x][y].tile = Globals.tiles[_tile]
#	if _fillEdges != null:
#		for x in range(grid.size()):
#			if grid[x][0].tile == Globals.tiles.DOOR_CLOSED:
#				grid[x][0].tile = Globals.tiles[_fillEdges]
#		for x in range(grid.size()):
#			if grid[x][grid[x].size() - 1].tile == Globals.tiles.DOOR_CLOSED:
#				grid[x][grid[x].size() - 1].tile = Globals.tiles[_fillEdges]
#		for y in range(1, grid[0].size() - 1):
#			if grid[0][y].tile == Globals.tiles.DOOR_CLOSED:
#				grid[0][y].tile = Globals.tiles[_fillEdges]
#		for y in range(1, grid[0].size() - 1):
#			if grid[grid.size() - 1][y].tile == Globals.tiles.DOOR_CLOSED:
#				grid[grid.size() - 1][y].tile = Globals.tiles[_fillEdges]

func placeRandomInteractables(_interactables):
	for _interactable in _interactables:
		match _interactable:
			"altar":
				if randi() % 13 == 0:
					for _i in range(randi() % 2 + 1):
						var _randomSpawnableTile = spawnableItemTiles[randi() % spawnableItemTiles.size()]
#						if grid[_randomSpawnableTile.x][_randomSpawnableTile.y].interactable == null:
#							grid[_randomSpawnableTile.x][_randomSpawnableTile.y].interactable = Globals.interactables.ALTAR
			"fountain":
				if randi() % 7 == 0:
					for _i in range(randi() % 3 + 1):
						var _randomSpawnableTile = spawnableItemTiles[randi() % spawnableItemTiles.size()]
#						if grid[_randomSpawnableTile.x][_randomSpawnableTile.y].interactable == null:
#							grid[_randomSpawnableTile.x][_randomSpawnableTile.y].interactable = Globals.interactables.FOUNTAIN
#			"gems":
#				for _i in range(randi() % 81 + 20):
#					var _randomSpawnableTile = Vector2i(randi() % int(Globals.gridSize.x), randi() % int(Globals.gridSize.y))
#					if (
#						grid[_randomSpawnableTile.x][_randomSpawnableTile.y].interactable == null and
#						(
#							grid[_randomSpawnableTile.x][_randomSpawnableTile.y].tile == Globals.tiles.WALL_CAVE or
#							grid[_randomSpawnableTile.x][_randomSpawnableTile.y].tile == Globals.tiles.WALL_CAVE_DEEP
#						)
#					):
#						grid[_randomSpawnableTile.x][_randomSpawnableTile.y].interactable = Globals.interactables.GEMS

func placeContainers(_containers):
	for _container in _containers:
		for _index in _containers[_container].amount:
			var _tile
			if _containers[_container].has("tile"):
				_tile = _containers[_container].tile
			else:
				_tile = spawnableItemTiles[randi() % spawnableItemTiles.size()]
			if _containers[_container].has("types"):
				$"/root/World/Items/Items".createItem(_container, _tile, 1, false, { "specificSpawn": _containers[_container].types }, self)
			else:
				$"/root/World/Items/Items".createItem(_container, _tile, 1, false, { "randomSpawn": true }, self)

func resetLevel():
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y].critter != null:
				get_node("/root/World/Critters/{critterId}".format({ "critterId": grid[x][y].critter })).addCritterBackToPopulation(Vector2i(x, y), self)
			grid[x][y].tile = -1
			grid[x][y].tileMetaData = {
				"xFlip": false,
				"yFlip": false
			}
			grid[x][y].critter = null
			grid[x][y].items = []
			grid[x][y].effects = []
			grid[x][y].interactable = -1
	rooms.clear()
	areas.clear()
	openTiles.clear()
	spawnableItemTiles.clear()
	spawnableCritterTiles.clear()
	floorTiles.clear()
	stairs.clear()
	critters.clear()
	
#	pathFindingAstarNode.clear()
#	astarNode.clear()
#	weightedAstarNode.clear()



######################
### Area functions ###
######################

func getRoom(_tile, _tileType):
	var _roomTiles = [_tile]
	var _adjacentTiles = checkAdjacentTilesForTile(_tile, [_tileType.floor])
	_roomTiles.append_array(_adjacentTiles)
	while !_adjacentTiles.empty():
		for _adjacentTile in checkAdjacentTilesForTile(_adjacentTiles.pop_back(), [_tileType.floor]):
			if !_roomTiles.has(_adjacentTile):
				_adjacentTiles.append(_adjacentTile)
				_roomTiles.append(_adjacentTile)
	return _roomTiles

func getArea(_tile, _tileType):
	var _areaTiles = [_tile]
	var _adjacentTiles = checkAdjacentTilesForTile(_tile, [_tileType])
	_areaTiles.append_array(_adjacentTiles)
	while !_adjacentTiles.empty():
		for _adjacentTile in checkAdjacentTilesForTile(_adjacentTiles.pop_back(), [_tileType]):
			if !_areaTiles.has(_adjacentTile):
				_adjacentTiles.append(_adjacentTile)
				_areaTiles.append(_adjacentTile)
	return _areaTiles

func getAndCleanUpRooms(_tileTypes):
	# Get floors
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			for _tileType in _tileTypes:
				pass
#				if grid[x][y].tile == Globals.tiles[_tileType.floor] and !isTileAlreadyInARoom(Vector2i(x,y)):
#					rooms.append({
#						"floors": getRoom(Vector2i(x, y), _tileType),
#						"walls": []
#					})
#					break
	
	# Clean up missing walls
#	for _room in rooms:
#		for _floorTile in _room.floors:
#			for _tileType in _tileTypes:
#				if grid[_floorTile.x][_floorTile.y].tile == Globals.tiles[_tileType.floor]:
#					for _adjacentTile in checkAdjacentTilesForTile(_floorTile, [_tileType.floor, _tileType.wall], false):
#						grid[_adjacentTile.x][_adjacentTile.y].tile = Globals.tiles[_tileType.wall]
	
	# Get walls
	for _room in rooms:
		var _walls = []
		for _floorTile in _room.floors:
			for _tileType in _tileTypes:
				for _adjacentTile in checkAdjacentTilesForTile(_floorTile, [_tileType.wall]):
					_walls.append(_adjacentTile)
		_room.walls = _walls

func getSpawnableTiles(_openTiles, _spawnableItemTiles, _spawnableCritterTiles, useAreas = false, _floorTiles = null):
	pass
#	for x in Globals.gridSize.x:
#		for y in Globals.gridSize.y:
#			for _tile in _openTiles:
#				if useAreas:
#					for _area in areas:
#						if _area.has(Vector2i(x, y)) and _area.size() > 75:
#							openTiles.append(Vector2i(x, y))
#							break
#				elif grid[x][y].tile == Globals.tiles[_tile]:
#					openTiles.append(Vector2i(x, y))
#					break
#	for x in Globals.gridSize.x:
#		for y in Globals.gridSize.y:
#			for _tile in _spawnableItemTiles:
#				if useAreas:
#					for _area in areas:
#						if _area.has(Vector2i(x, y)) and _area.size() > 75:
#							spawnableItemTiles.append(Vector2i(x, y))
#							break
#				elif grid[x][y].tile == Globals.tiles[_tile]:
#					spawnableItemTiles.append(Vector2i(x, y))
#					break
#	for x in Globals.gridSize.x:
#		for y in Globals.gridSize.y:
#			for _tile in _spawnableCritterTiles:
#				if useAreas:
#					for _area in areas:
#						if _area.has(Vector2i(x, y)) and _area.size() > 75:
#							spawnableCritterTiles.append(Vector2i(x, y))
#							break
#				elif grid[x][y].tile == Globals.tiles[_tile]:
#					spawnableCritterTiles.append(Vector2i(x, y))
#					break
#	if _floorTiles != null:
#		for x in Globals.gridSize.x:
#			for y in Globals.gridSize.y:
#				for _tile in _floorTiles:
#					if useAreas:
#						for _area in areas:
#							if _area.has(Vector2i(x, y)) and _area.size() > 75:
#								floorTiles.append(Vector2i(x, y))
#								break
#					elif grid[x][y].tile == Globals.tiles[_tile]:
#						floorTiles.append(Vector2i(x, y))
#						break

func isTileAlreadyInARoom(_tile):
	for _room in rooms:
		for _floor in _room.floors:
			if _floor == _tile:
				return true
		for _wall in _room.walls:
			if _wall == _tile:
				return true
	return false

func isTileAlreadyInAnArea(_tile):
	for _area in areas:
		for _floor in _area:
			if _floor == _tile:
				return true
	return false



###############################
### Tile checking functions ###
###############################

func checkAdjacentTilesForOpenSpace(_position, _checkForSingleOpenSpace = false, checkForCritters = false, _shuffleDirections = true):
	var _openTiles = []
	var _directions = [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0)
	]
	if _shuffleDirections:
		_directions.shuffle()
	for _direction in _directions:
		var _checkedTilePosition = Vector2i(_position.x + _direction.x, _position.y + _direction.y)
#		if !isOutSideTileMap(_checkedTilePosition):
#			var _checkedTileInGrid = grid[_checkedTilePosition.x][_checkedTilePosition.y]
#			if Globals.isTileFree(_checkedTilePosition, grid):
#				if checkForCritters:
#					if _checkedTileInGrid.critter == null:
#						_openTiles.append(_checkedTilePosition)
#						if _checkForSingleOpenSpace:
#							return _openTiles
#				else:
#					_openTiles.append(_checkedTilePosition)
#					if _checkForSingleOpenSpace:
#						return _openTiles
	return _openTiles

func checkAdjacentTilesForTile(_tile, _tileTypes, _checkForTile = true):
	var _tiles = []
	var _directions = [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0)
	]
	for _direction in _directions:
		var _checkedTilePosition = Vector2i(_tile.x + _direction.x, _tile.y + _direction.y)
#		if !isOutSideTileMap(_checkedTilePosition):
#			if isTileOneOfTypes(_checkedTilePosition, _tileTypes) and _checkForTile:
#				_tiles.append(_checkedTilePosition)
#			elif !isTileOneOfTypes(_checkedTilePosition, _tileTypes) and !_checkForTile:
#				_tiles.append(_checkedTilePosition)
	return _tiles

func isTileOneOfTypes(_checkedTilePosition, _tileTypes):
#	for _tileType in _tileTypes:
#		if grid[_checkedTilePosition.x][_checkedTilePosition.y].tile == Globals.tiles[_tileType]:
#			return true
	return false

func whichTilesAreOpenAndFreeOfCritters(_tile, _distance):
	var _legibleTiles = []
	for x in range(_tile.x - _distance, _tile.x + _distance + 1):
		for y in range(_tile.y - _distance, _tile.y + _distance + 1):
			if isTileOpenAndFreeOfCritters(Vector2i(x,y)):
				_legibleTiles.append(Vector2i(x,y))
	return _legibleTiles

func isTileOpenAndFreeOfCritters(_tile):
#	if (
#		_tile.y >= 0 and
#		_tile.y < grid[0].size() and
#		_tile.x >= 0 and
#		_tile.x < grid.size() and
#		Globals.isTileFree(_tile, grid) and
#		isTileFreeOfCritters(_tile) and
#		grid[_tile.x][_tile.y].tile != Globals.tiles.DOOR_CLOSED
#	):
#		return true
	return false

func isTileFreeOfCritters(_tile):
	if grid[_tile.x][_tile.y].critter == null:
		return true
	return false

func isTileAStair(_newStair):
	for _stair in stairs.values():
		if _newStair == _stair:
			return true
	return false

func isTileADoor(_tile):
#	if grid[_tile.x][_tile.y].tile == Globals.tiles.DOOR_CLOSED:
#		return true
	return false



#######################
### Astar functions ###
#######################


### General pathfinding ###

func calculatePath(pathStartPosition, pathEndPosition):
	pass
#	return astarNode.get_point_path(id(pathStartPosition), id(pathEndPosition))
#
#func pathFind(_illegibleTiles = []):
#	astarNode.clear()
#	connectAllCells(addLegibleTiles(_illegibleTiles))
#
#func addLegibleTiles(_illegibleTiles):
#	var points = []
#	for x in (grid.size()):
#		for y in (grid[x].size()):
#			var point = Vector2i(x, y)
#			if isTileIllegibleInPathfind(point, _illegibleTiles):
#				continue
#			points.append(point)
#			astarNode.add_point(id(point), point, 1.0)
#	return points

#func connectAllCells(points):
#	for point in points:
#		var pointIndex = id(point)
#		var pointsRelative = PoolVector2Array([
#			Vector2i(point.x, point.y - 1),
#			Vector2i(point.x + 1, point.y - 1),
#			Vector2i(point.x + 1, point.y),
#			Vector2i(point.x + 1, point.y + 1),
#			Vector2i(point.x, point.y + 1),
#			Vector2i(point.x - 1, point.y + 1),
#			Vector2i(point.x - 1, point.y),
#			Vector2i(point.x - 1, point.y - 1)
#		])
#		for pointRelative in pointsRelative:
#			var pointRelativeIndex = id(pointRelative)
#			if isOutSideTileMap(pointRelative):
#				continue
#			if not astarNode.has_point(pointRelativeIndex):
#				continue
#			astarNode.connect_points(pointIndex, pointRelativeIndex, false)

func isTileIllegibleInPathfind(_point, _illegibleTiles):
	for _illegibleTile in _illegibleTiles:
		if grid[_point.x][_point.y].tile == _illegibleTile:
			return true
	return false

#func addPointToPathPathding(point):
#	var _pointId = id(point)
#	if astarNode.has_point(_pointId):
#		astarNode.set_point_disabled(_pointId, false)
#	else:
#		astarNode.add_point(_pointId, point, 1.0)
#		var pointsRelative = PoolVector2Array([
#			Vector2i(point.x, point.y - 1),
#			Vector2i(point.x + 1, point.y - 1),
#			Vector2i(point.x + 1, point.y),
#			Vector2i(point.x + 1, point.y + 1),
#			Vector2i(point.x, point.y + 1),
#			Vector2i(point.x - 1, point.y + 1),
#			Vector2i(point.x - 1, point.y),
#			Vector2i(point.x - 1, point.y - 1)
#		])
#		for pointRelative in pointsRelative:
#			var pointRelativeIndex = id(pointRelative)
#			if isOutSideTileMap(pointRelative):
#				continue
#			if not astarNode.has_point(pointRelativeIndex):
#				continue
#			astarNode.connect_points(_pointId, pointRelativeIndex, false)


### Weighted pathfinding ###

#func calculateWeightedPath(pathStartPosition, pathEndPosition):
#	return weightedAstarNode.get_point_path(id(pathStartPosition), id(pathEndPosition))

#func pathFindWeightedPath(_illegibleTiles, _pointWeighting):
#	weightedAstarNode.clear()
#	connectAllWeightedCells(addLegibleWeighedTiles(_illegibleTiles, _pointWeighting))

func addLegibleWeighedTiles(_illegibleTiles, _pointWeighting):
	var points = []
	for x in (grid.size()):
		for y in (grid[x].size()):
			var point = Vector2i(x, y)
			if isTileIllegibleInPathfind(point, _illegibleTiles):
				continue
			else:
				var _weight = 1.0
#				for _weighting in _pointWeighting:
#					if grid[x][y].tile == Globals.tiles[_weighting.tile]:
#						_weight = _weighting.weighting
				points.append(point)
#				weightedAstarNode.add_point(id(point), point, _weight)
	return points

#func connectAllWeightedCells(points):
#	for point in points:
#		var pointIndex = id(point)
#		var pointsRelative = PoolVector2Array([
#			Vector2i(point.x, point.y - 1),
#			Vector2i(point.x + 1, point.y - 1),
#			Vector2i(point.x + 1, point.y),
#			Vector2i(point.x + 1, point.y + 1),
#			Vector2i(point.x, point.y + 1),
#			Vector2i(point.x - 1, point.y + 1),
#			Vector2i(point.x - 1, point.y),
#			Vector2i(point.x - 1, point.y - 1)
#		])
#		for pointRelative in pointsRelative:
#			var pointRelativeIndex = id(pointRelative)
#			if isOutSideTileMap(pointRelative):
#				continue
#			if not weightedAstarNode.has_point(pointRelativeIndex):
#				continue
#			weightedAstarNode.connect_points(pointIndex, pointRelativeIndex, true)



###############################
### Miscellaneous functions ###
###############################

#func getGenerationGrid():
#	for x in range(grid.size()):
#		for y in range(grid[x].size()):
#			grid[x][y].tile = get_cellv(Vector2i(x,y))
#			grid[x][y].tileMetaData = {
#				"xFlip": is_cell_x_flipped(x, y),
#				"yFlip": is_cell_y_flipped(x, y)
#			}

func getCritterTile(_critter):
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y].critter == _critter:
				return Vector2i(x, y)
	return false

func getTilePosition(_tile):
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if _tile == grid[x][y].tile:
				return Vector2i(x, y)
	return false

func placeCritterOnTypeOfTile(_tile, _critter):
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if _tile == grid[x][y].tile:
				grid[x][y].critter = _critter
				return

#func doFinalPathfinding(_blockedTiles = Globals.blockedTiles):
#	astarNode.clear()
#	pathFindingAstarNode.clear()
#	pathFind(_blockedTiles)
#	enemyPathfinding(grid)

#func placePresetItems(_items, _level):
#	for _item in _items:
#		if _item.has("items"):
#			if _item.items.types != null:
#				if typeof(_item.tiles) == TYPE_VECTOR2_ARRAY:
#					for x in range(_item.tiles[0].x, _item.tiles[1].x + 1):
#						for y in range(_item.tiles[0].y, _item.tiles[1].y + 1):
#							if randi() % 101 <= _item.chance and Globals.isTileFree(Vector2i(x, y), grid) and grid[x][y].tile != Globals.tiles.DOOR_CLOSED:
#								$"/root/World/Items/Items".createItem(
#									$"/root/World/Items/Items".getRandomItemByItemTypes(_item.items.types, _item.items.randomByRarity),
#									Vector2i(x, y),
#									1,
#									false,
#									{},
#									_level
#								)
#				else:
#					if randi() % 101 <= _item.chance and Globals.isTileFree(_item.tiles, grid) and grid[_item.tiles.x][_item.tiles.y].tile != Globals.tiles.DOOR_CLOSED:
#						$"/root/World/Items/Items".createItem(
#							$"/root/World/Items/Items".getRandomItemByItemTypes(_item.items.types, _item.items.randomByRarity),
#							_item.tiles,
#							1,
#							false,
#							{},
#							_level
#						)
#			elif _item.items.names != null:
#				if typeof(_item.tiles) == TYPE_VECTOR2_ARRAY:
#					for x in range(_item.tiles[0].x, _item.tiles[1].x + 1):
#						for y in range(_item.tiles[0].y, _item.tiles[1].y + 1):
#							if randi() % 101 <= _item.chance and Globals.isTileFree(Vector2i(x, y), grid) and grid[x][y].tile != Globals.tiles.DOOR_CLOSED:
#								$"/root/World/Items/Items".createItem(
#									_item.items.names[randi() % _item.items.names.size()],
#									Vector2i(x, y),
#									1,
#									false,
#									{},
#									_level
#								)
#				else:
#					if randi() % 101 <= _item.chance and Globals.isTileFree(_item.tiles, grid) and grid[_item.tiles.x][_item.tiles.y].tile != Globals.tiles.DOOR_CLOSED:
#						var _itemName = _item.items.names
#						if typeof(_item.items.names) == TYPE_ARRAY:
#							_itemName = _item.items.names[randi() % _item.items.names.size()]
#						$"/root/World/Items/Items".createItem(
#							_itemName,
#							_item.tiles,
#							1,
#							false,
#							{},
#							_level
#						)

func placePresetCritters(_critters, _level):
	for _critter in _critters:
		if _critter.has("critters"):
			pass
#			if _critter.critters.races != null:
#				if typeof(_critter.tiles) == TYPE_VECTOR2_ARRAY:
#					for x in range(_critter.tiles[0].x, _critter.tiles[1].x + 1):
#						for y in range(_critter.tiles[0].y, _critter.tiles[1].y + 1):
#							if randi() % 101 <= _critter.chance and Globals.isTileFree(Vector2i(x, y), grid) and grid[x][y].tile != Globals.tiles.DOOR_CLOSED:
#								$"/root/World/Items/Items".createItem(
#									$"/root/World/Items/Items".getRandomItemByItemTypes(_critter.critters.races, _critter.critters.randomByRarity),
#									Vector2i(x, y),
#									false,
#									{},
#									_level,
#									grid
#								)
#				else:
#					if randi() % 101 <= _critter.chance and Globals.isTileFree(_critter.tiles, grid) and grid[_critter.tiles.x][_critter.tiles.y].tile != Globals.tiles.DOOR_CLOSED:
#						$"/root/World/Items/Items".createItem(
#							$"/root/World/Items/Items".getRandomItemByItemTypes(_critter.critters.races, _critter.items.randomByRarity),
#							_critter.tiles,
#							false,
#							{},
#							_level,
#							grid
#						)
#			if _critter.critters.names != null:
#				if typeof(_critter.tiles) == TYPE_ARRAY:
#					for x in range(_critter.tiles[0].x, _critter.tiles[1].x + 1):
#						for y in range(_critter.tiles[0].y, _critter.tiles[1].y + 1):
#							if randi() % 101 <= _critter.chance and Globals.isTileFree(Vector2i(x, y), grid) and grid[x][y].tile != Globals.tiles.DOOR_CLOSED:
#								var _isDeactivated = null
#								if _critter.has("isDeactivated"): _isDeactivated = _critter.isDeactivated
#								$"/root/World/Critters/Critters".spawnCritter(
#									_critter.critters.names[randi() % _critter.critters.names.size()],
#									Vector2i(x, y),
#									_isDeactivated,
#									true,
#									_level
#								)
#				else:
#					if randi() % 101 <= _critter.chance and Globals.isTileFree(_critter.tiles, grid) and grid[_critter.tiles.x][_critter.tiles.y].tile != Globals.tiles.DOOR_CLOSED:
#						var _isDeactivated = null
#						if _critter.has("isDeactivated"): _isDeactivated = _critter.isDeactivated
#						var _critterName = _critter.critters.names
#						if typeof(_critter.critters.names) == TYPE_ARRAY:
#							_critterName = _critter.critters.names[randi() % _critter.critters.names.size()]
#						$"/root/World/Critters/Critters".spawnCritter(
#							_critterName,
#							_critter.tiles,
#							_isDeactivated,
#							true,
#							_level
#						)

func clearOutInputs():
	if has_node("Inputs"):
		for _inputNode in $Inputs.get_children():
			_inputNode.clear()
			_inputNode.queue_free()
	clear()

func getLevelSaveData():
	var _grid = {  }
	var _openTiles = {  }
	var _spawnableItemTiles = {  }
	var _spawnableCritterTiles = {  }
	var _floorTiles = {  }
	var _stairs = {  }
	
	for x in grid.size():
		_grid[x] = {  }
		for y in grid[x].size():
			_grid[x][y] = grid[x][y]
	for index in openTiles.size():
		_openTiles[str(index)] = {
			"x": openTiles[index].x,
			"y": openTiles[index].y
		}
	for index in spawnableItemTiles.size():
		_spawnableItemTiles[str(index)] = {
			"x": spawnableItemTiles[index].x,
			"y": spawnableItemTiles[index].y
		}
	for index in spawnableCritterTiles.size():
		_spawnableCritterTiles[str(index)] = {
			"x": spawnableCritterTiles[index].x,
			"y": spawnableCritterTiles[index].y
		}
	for index in floorTiles.size():
		_floorTiles[str(index)] = {
			"x": floorTiles[index].x,
			"y": floorTiles[index].y
		}
	for key in stairs.keys():
		_stairs[key] = {
			"x": stairs[key].x,
			"y": stairs[key].y
		}
	
	return {
		levelId = levelId,
		dungeonType = dungeonType,
		dungeonSection = dungeonSection,
		dungeonLevelName = dungeonLevelName,
		visibility = visibility,
		critters = critters,

		grid = _grid,
		openTiles = _openTiles,
		spawnableItemTiles = _spawnableItemTiles,
		spawnableCritterTiles = _spawnableCritterTiles,
		floorTiles = _floorTiles,
		stairs = _stairs
	}

func loadLevel(_levelData):
#	createGrid(Globals.tiles.EMPTY, false)
	
	levelId = _levelData.levelId
	name = str(levelId)
	dungeonType = _levelData.dungeonType
	dungeonSection = _levelData.dungeonSection
	dungeonLevelName = _levelData.dungeonLevelName
	visibility = _levelData.visibility
	critters = _levelData.critters
	
	for x in _levelData.grid.size():
		for y in _levelData.grid[str(x)].size():
			grid[x][y] = _levelData.grid[str(x)][str(y)]
	for index in _levelData.openTiles.size():
		openTiles.append(Vector2i(_levelData.openTiles[str(index)].x, _levelData.openTiles[str(index)].y))
	for index in _levelData.spawnableItemTiles.size():
		spawnableItemTiles.append(Vector2i(_levelData.spawnableItemTiles[str(index)].x, _levelData.spawnableItemTiles[str(index)].y))
	for index in _levelData.spawnableCritterTiles.size():
		spawnableCritterTiles.append(Vector2i(_levelData.spawnableCritterTiles[str(index)].x, _levelData.spawnableCritterTiles[str(index)].y))
	for index in _levelData.floorTiles.size():
		floorTiles.append(Vector2i(_levelData.floorTiles[str(index)].x, _levelData.floorTiles[str(index)].y))
	for key in _levelData.stairs.keys():
		stairs[key] = Vector2i(_levelData.stairs[key].x, _levelData.stairs[key].y)
	
#	doFinalPathfinding()
