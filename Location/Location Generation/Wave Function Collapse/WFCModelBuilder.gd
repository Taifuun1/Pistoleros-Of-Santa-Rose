extends RefCounted
class_name WFCModelBuilder

## Builds an immutable WFCModel from a set of 3x3 input patterns.
##
## The patterns are the (already deduplicated + rotated) length-9
## PackedInt32Array patterns produced by WFCInputCreation and cached in
## WaveFunctionCollapse.inputs[<location>]. This runs once per location on the
## main thread; the expensive part is precomputing the adjacency propagator so
## that the solver never has to rescan inputs at runtime.


static func build(inputPatterns: Array) -> WFCModel:
	var model := WFCModel.new()
	model.patterns = inputPatterns
	model.patternCount = inputPatterns.size()

	for pattern in inputPatterns:
		# Uniform weights for now; WFCInputCreation deduplicates patterns so the
		# original frequencies are not available. Kept as a hook for weighting.
		model.weights.append(1.0)
		model.centerTile.append(pattern[4])

	# propagator[dir][t1] = every pattern t2 that may occupy the neighbouring
	# cell in direction DIRECTIONS[dir] given t1 in the current cell.
	model.propagator = []
	for d in WFCModel.DIRECTIONS.size():
		var perDirection := []
		perDirection.resize(model.patternCount)
		for t1 in model.patternCount:
			var compatible := PackedInt32Array()
			for t2 in model.patternCount:
				if _agrees(inputPatterns[t1], inputPatterns[t2], WFCModel.DIRECTIONS[d]):
					compatible.append(t2)
			perDirection[t1] = compatible
		model.propagator.append(perDirection)

	return model


# True if pattern b may sit in direction d relative to pattern a, i.e. their
# overlapping cells hold identical tile values.
static func _agrees(a: PackedInt32Array, b: PackedInt32Array, d: Vector2i) -> bool:
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var bx := ox - d.x
			var by := oy - d.y
			if bx >= -1 and bx <= 1 and by >= -1 and by <= 1:
				if a[(ox + 1) * 3 + (oy + 1)] != b[(bx + 1) * 3 + (by + 1)]:
					return false
	return true
