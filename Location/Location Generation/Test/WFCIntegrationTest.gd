extends Node

## Headless integration test for the real WFC pipeline (Phase 0 / Phase 2 safety net).
##
## Reads a real location's TileMap inputs through WFCInputCreation (main thread),
## builds a WFCModel via WFCModelBuilder, then runs WFCSolver on many chunks and
## asserts:
##   - every cell in the 24x48 grid has a value,
##   - values are within a sane tileset id range,
##   - the precomputed propagator is symmetric across opposite directions,
##   - deterministic output for a fixed seed,
##   - no exceptions.
## Prints PASS/FAIL lines plus a per-chunk timing baseline and quits.

const LOCATION := "Clearwater Grove"
const CHUNK_COUNT := 30


func _ready() -> void:
	var allPassed := true
	allPassed = await _testRealLocation() and allPassed
	print("WFC INTEGRATION TEST: ", "ALL PASSED" if allPassed else "FAILURES PRESENT")
	get_tree().quit(0 if allPassed else 1)


func _testRealLocation() -> bool:
	var inputCreation = load("res://Location/Location Generation/Wave Function Collapse/WFCInputCreation.tscn").instantiate()
	add_child(inputCreation)
	await inputCreation.addInputs(LOCATION)
	var patterns: Array = inputCreation.assignInputsForInputSet()
	inputCreation.removeInputs()
	inputCreation.queue_free()

	if patterns.is_empty():
		print("real: FAIL no patterns extracted for %s" % LOCATION)
		return false

	var model := WFCModelBuilder.build(patterns)
	print("real: %d unique patterns for %s, gridSize %s" % [model.patternCount, LOCATION, str(WaveFunctionCollapse.gridSize)])

	var ok := true
	ok = _checkPropagatorSymmetry(model) and ok

	var gridSize: Vector2i = WaveFunctionCollapse.gridSize
	var expectedCells := gridSize.x * gridSize.y
	var minTile := 1 << 30
	var maxTile := -(1 << 30)
	var totalUs := 0

	for i in CHUNK_COUNT:
		var chunkPos := Vector2i(i % 6, i / 6)
		var chunkSeed := WFCSolver.makeSeed(LOCATION, chunkPos, WaveFunctionCollapse.baseSeed)
		var solver := WFCSolver.new(model, gridSize, chunkSeed)
		var start := Time.get_ticks_usec()
		var tiles := solver.run()
		totalUs += Time.get_ticks_usec() - start

		if tiles.size() != expectedCells:
			print("real: FAIL chunk %s produced %d cells (expected %d)" % [str(chunkPos), tiles.size(), expectedCells])
			return false
		for x in gridSize.x:
			for y in gridSize.y:
				var key := Vector2i(x, y)
				if not tiles.has(key):
					print("real: FAIL missing cell %s in chunk %s" % [str(key), str(chunkPos)])
					return false
				var v: int = tiles[key]
				if v < 0:
					print("real: FAIL out-of-range tile %d at %s in chunk %s" % [v, str(key), str(chunkPos)])
					return false
				minTile = mini(minTile, v)
				maxTile = maxi(maxTile, v)

	print("real: PASS (%d chunks, tile ids %d..%d, avg %.3f ms/chunk)" % [
		CHUNK_COUNT, minTile, maxTile, (totalUs / float(CHUNK_COUNT)) / 1000.0
	])

	# Determinism: same seed -> identical grid.
	var seedA := WFCSolver.makeSeed(LOCATION, Vector2i(3, 3), WaveFunctionCollapse.baseSeed)
	var runA := WFCSolver.new(model, gridSize, seedA).run()
	var runB := WFCSolver.new(model, gridSize, seedA).run()
	for key in runA:
		if runA[key] != runB[key]:
			print("real: FAIL non-deterministic output at %s" % str(key))
			return false
	print("determinism (real model): PASS")

	return ok


func _checkPropagatorSymmetry(model: WFCModel) -> bool:
	for d in WFCModel.DIRECTIONS.size():
		var opposite: int = WFCModel.OPPOSITE[d]
		for a in model.patternCount:
			for b in model.propagator[d][a]:
				# b is compatible after a in direction d, so a must be
				# compatible after b in the opposite direction.
				if not (a in model.propagator[opposite][b]):
					print("symmetry: FAIL b=%d in prop[%d][%d] but a=%d missing from prop[%d][%d]" % [b, d, a, a, opposite, b])
					return false
	print("symmetry: PASS (propagator symmetric across opposite directions)")
	return true


