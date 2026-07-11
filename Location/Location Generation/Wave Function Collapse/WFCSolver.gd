extends RefCounted
class_name WFCSolver

## Conventional overlapping-model Wave Function Collapse solver.
##
## Pure data: it never touches the scene tree, so it can run entirely on a
## worker thread. It reads a shared, read-only WFCModel and keeps all mutable
## state local, meaning many solvers can run concurrently without locking.
##
## Algorithm (Gumin-style):
##   observe  -> pick the lowest-entropy cell and collapse it to one pattern
##   propagate-> arc-consistency using per-(cell, pattern, direction) support
##               counts, so work is proportional to the eliminations, not to
##               the number of input patterns
## On a contradiction the attempt restarts with a new seed; after MAX_ATTEMPTS
## it returns a best-effort grid so a chunk always loads.

const MAX_ATTEMPTS := 10
const DEFAULT_TILE := 0

var model: WFCModel
var width: int
var height: int
var cellCount: int
var patternCount: int
var numDirections: int
var solverSeed: int

# Per (cell, pattern) possibility flag (1 = still possible). Flat, row per cell.
var possible: PackedByteArray
# Number of still-possible patterns per cell.
var possibleCount: PackedInt32Array
# Support counts, indexed (cell * patternCount + pattern) * numDirections + dir.
# support[c][p][d] = how many still-possible patterns in the neighbour in
# direction d are compatible with p occupying cell c.
var support: PackedInt32Array

# Weighted-entropy bookkeeping (per cell).
var sumsOfWeights: PackedFloat32Array
var sumsOfWeightLogWeights: PackedFloat32Array
var entropies: PackedFloat32Array

# Precomputed constants derived from the model weights.
var weightLogWeights: PackedFloat32Array
var totalWeight: float
var totalWeightLogWeight: float

# Propagation stack of encoded (cell * patternCount + pattern) values.
var stack: PackedInt32Array
var stackSize: int

var contradiction: bool
var rng: RandomNumberGenerator


func _init(_model: WFCModel, _gridSize: Vector2i, _seed: int) -> void:
	model = _model
	width = _gridSize.x
	height = _gridSize.y
	cellCount = width * height
	patternCount = model.patternCount
	numDirections = WFCModel.DIRECTIONS.size()
	solverSeed = _seed
	rng = RandomNumberGenerator.new()

	weightLogWeights = PackedFloat32Array()
	weightLogWeights.resize(patternCount)
	totalWeight = 0.0
	totalWeightLogWeight = 0.0
	for p in patternCount:
		var w := model.weights[p]
		var wLog := w * log(w)
		weightLogWeights[p] = wLog
		totalWeight += w
		totalWeightLogWeight += wLog


## Deterministic seed from the location + chunk position + a global base seed.
static func makeSeed(location: String, chunkPosition: Vector2i, baseSeed: int) -> int:
	return hash([location, chunkPosition, baseSeed])


## Runs the solve and returns Dictionary[Vector2i, int] of tile ids for the grid.
func run() -> Dictionary:
	if patternCount == 0:
		return _filledOutput(DEFAULT_TILE)
	for attempt in MAX_ATTEMPTS:
		rng.seed = solverSeed + attempt
		if _solveAttempt():
			return _output()
	# Could not fully solve within the attempt budget; return best-effort so the
	# chunk still loads (mirrors the old fillEmptyGenerationTiles fallback).
	return _output()


func _solveAttempt() -> bool:
	_initState()
	var cell := _selectCell()
	while cell != -1:
		_collapseCell(cell)
		if not _propagate():
			return false
		cell = _selectCell()
	return true



func _initState() -> void:
	possible = PackedByteArray()
	possible.resize(cellCount * patternCount)
	possible.fill(1)

	possibleCount = PackedInt32Array()
	possibleCount.resize(cellCount)
	possibleCount.fill(patternCount)

	sumsOfWeights = PackedFloat32Array()
	sumsOfWeights.resize(cellCount)
	sumsOfWeights.fill(totalWeight)

	sumsOfWeightLogWeights = PackedFloat32Array()
	sumsOfWeightLogWeights.resize(cellCount)
	sumsOfWeightLogWeights.fill(totalWeightLogWeight)

	entropies = PackedFloat32Array()
	entropies.resize(cellCount)
	entropies.fill(_entropyFromSums(totalWeight, totalWeightLogWeight))

	support = PackedInt32Array()
	support.resize(cellCount * patternCount * numDirections)
	for cell in cellCount:
		for p in patternCount:
			var base := (cell * patternCount + p) * numDirections
			for d in numDirections:
				support[base + d] = model.propagator[d][p].size()

	stack = PackedInt32Array()
	stack.resize(cellCount * patternCount)
	stackSize = 0
	contradiction = false


func _entropyFromSums(sumWeights: float, sumWeightLogWeights: float) -> float:
	if sumWeights <= 0.0:
		return 0.0
	return log(sumWeights) - sumWeightLogWeights / sumWeights


# Lowest positive-entropy cell, with a tiny random tie-breaker. Returns -1 when
# every cell is collapsed (entropy 0 / a single remaining pattern).
func _selectCell() -> int:
	var minEntropy := INF
	var selected := -1
	for cell in cellCount:
		if possibleCount[cell] <= 1:
			continue
		var e := entropies[cell] + 1e-6 * rng.randf()
		if e < minEntropy:
			minEntropy = e
			selected = cell
	return selected


func _collapseCell(cell: int) -> void:
	var chosen := _chooseWeightedPattern(cell)
	var baseCell := cell * patternCount
	for p in patternCount:
		if p != chosen and possible[baseCell + p] == 1:
			_ban(cell, p)


func _chooseWeightedPattern(cell: int) -> int:
	var baseCell := cell * patternCount
	var remaining := rng.randf() * sumsOfWeights[cell]
	for p in patternCount:
		if possible[baseCell + p] == 1:
			remaining -= model.weights[p]
			if remaining <= 0.0:
				return p
	# Numerical safety net: return the first still-possible pattern.
	for p in patternCount:
		if possible[baseCell + p] == 1:
			return p
	return 0


func _ban(cell: int, pattern: int) -> void:
	var flagIndex := cell * patternCount + pattern
	if possible[flagIndex] == 0:
		return
	possible[flagIndex] = 0

	var base := flagIndex * numDirections
	for d in numDirections:
		support[base + d] = 0

	possibleCount[cell] -= 1
	sumsOfWeights[cell] -= model.weights[pattern]
	sumsOfWeightLogWeights[cell] -= weightLogWeights[pattern]

	if possibleCount[cell] <= 0:
		contradiction = true
		return
	entropies[cell] = _entropyFromSums(sumsOfWeights[cell], sumsOfWeightLogWeights[cell])

	stack[stackSize] = flagIndex
	stackSize += 1


func _propagate() -> bool:
	# Hoist read-only members/constants into locals; the hot loop below runs
	# millions of times per solve. NB: the mutable Packed arrays (possible,
	# support, stack) are written through their members on purpose — caching
	# them in locals would desync on GDScript's copy-on-write.
	var pc := patternCount
	var nd := numDirections
	var w := width
	var h := height
	var propagator := model.propagator
	var directions := WFCModel.DIRECTIONS
	var opposites := WFCModel.OPPOSITE

	while stackSize > 0:
		stackSize -= 1
		var encoded := stack[stackSize]
		var cell := encoded / pc
		var pattern := encoded % pc
		var x := cell / h
		var y := cell % h

		for d in nd:
			var dir: Vector2i = directions[d]
			var nx := x + dir.x
			var ny := y + dir.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var neighbourBase := (nx * h + ny) * pc
			var opposite: int = opposites[d]
			var compatiblePatterns: PackedInt32Array = propagator[d][pattern]
			for s in compatiblePatterns:
				var sFlag := neighbourBase + s
				if possible[sFlag] == 0:
					continue
				var supportIndex := sFlag * nd + opposite
				support[supportIndex] -= 1
				if support[supportIndex] == 0:
					_ban(nx * h + ny, s)
					if contradiction:
						return false
	return true



func _output() -> Dictionary:
	var tiles := {}
	for x in width:
		for y in height:
			var baseCell := (x * height + y) * patternCount
			var value := DEFAULT_TILE
			for p in patternCount:
				if possible[baseCell + p] == 1:
					value = model.centerTile[p]
					break
			tiles[Vector2i(x, y)] = value
	return tiles


func _filledOutput(tile: int) -> Dictionary:
	var tiles := {}
	for x in width:
		for y in height:
			tiles[Vector2i(x, y)] = tile
	return tiles
