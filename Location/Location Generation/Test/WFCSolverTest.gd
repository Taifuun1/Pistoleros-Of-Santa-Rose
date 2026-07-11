extends Node

## Headless self-test for the WFC model builder + solver.
## Run this scene to verify the algorithm produces full, constraint-satisfying
## grids. Prints PASS/FAIL lines and quits.


func _ready() -> void:
	var allPassed := true
	allPassed = _testUniform() and allPassed
	allPassed = _testCheckerboard() and allPassed
	allPassed = _testDeterminism() and allPassed
	allPassed = _testConcurrentSolvers() and allPassed
	print("WFC SELF-TEST: ", "ALL PASSED" if allPassed else "FAILURES PRESENT")
	get_tree().quit(0 if allPassed else 1)


func _makePattern(fn: Callable) -> PackedInt32Array:
	var p := PackedInt32Array()
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			p.append(fn.call(ox, oy))
	return p


func _testUniform() -> bool:
	var p0 := _makePattern(func(_ox, _oy): return 0)
	var p1 := _makePattern(func(_ox, _oy): return 1)
	var model := WFCModelBuilder.build([p0, p1])

	var size := Vector2i(8, 8)
	var solver := WFCSolver.new(model, size, 4242)
	var start := Time.get_ticks_usec()
	var tiles := solver.run()
	var elapsed := Time.get_ticks_usec() - start

	if tiles.size() != size.x * size.y:
		print("uniform: FAIL wrong size ", tiles.size())
		return false
	var first: int = tiles[Vector2i(0, 0)]
	for key in tiles:
		if tiles[key] != first:
			print("uniform: FAIL non-uniform output")
			return false
	print("uniform: PASS (value=%d, %d cells, %.2f ms)" % [first, tiles.size(), elapsed / 1000.0])
	return true


func _testCheckerboard() -> bool:
	var c0 := _makePattern(func(ox, oy): return posmod(ox + oy, 2))
	var c1 := _makePattern(func(ox, oy): return posmod(ox + oy + 1, 2))
	var model := WFCModelBuilder.build([c0, c1])

	var size := Vector2i(10, 10)
	var solver := WFCSolver.new(model, size, 77)
	var tiles := solver.run()

	if tiles.size() != size.x * size.y:
		print("checkerboard: FAIL wrong size ", tiles.size())
		return false
	# Every 4-neighbour pair must differ.
	for x in size.x:
		for y in size.y:
			var v: int = tiles[Vector2i(x, y)]
			if x + 1 < size.x and tiles[Vector2i(x + 1, y)] == v:
				print("checkerboard: FAIL horizontal match at ", Vector2i(x, y))
				return false
			if y + 1 < size.y and tiles[Vector2i(x, y + 1)] == v:
				print("checkerboard: FAIL vertical match at ", Vector2i(x, y))
				return false
	print("checkerboard: PASS (valid alternating grid)")
	return true


func _testDeterminism() -> bool:
	var p0 := _makePattern(func(ox, _oy): return posmod(ox, 2))
	var p1 := _makePattern(func(ox, _oy): return posmod(ox + 1, 2))
	var model := WFCModelBuilder.build([p0, p1])
	var size := Vector2i(12, 12)

	var a := WFCSolver.new(model, size, 999).run()
	var b := WFCSolver.new(model, size, 999).run()
	for key in a:
		if a[key] != b[key]:
			print("determinism: FAIL diverging output at ", key)
			return false
	print("determinism: PASS (identical output for identical seed)")
	return true


func _testConcurrentSolvers() -> bool:
	# Same read-only model shared by several threads solving different seeds.
	var p0 := _makePattern(func(_ox, _oy): return 0)
	var p1 := _makePattern(func(_ox, _oy): return 1)
	var model := WFCModelBuilder.build([p0, p1])
	var size := Vector2i(16, 16)

	var threads: Array[Thread] = []
	for i in 4:
		var t := Thread.new()
		t.start(_solveOnThread.bind(model, size, 1000 + i))
		threads.append(t)
	var ok := true
	for t in threads:
		var result: Dictionary = t.wait_to_finish()
		if result.size() != size.x * size.y:
			ok = false
	if ok:
		print("concurrent: PASS (4 threads shared one read-only model)")
	else:
		print("concurrent: FAIL")
	return ok


func _solveOnThread(model: WFCModel, size: Vector2i, seed: int) -> Dictionary:
	return WFCSolver.new(model, size, seed).run()
