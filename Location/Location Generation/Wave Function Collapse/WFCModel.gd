extends RefCounted
class_name WFCModel

## Immutable description of a single WFC input set.
##
## Built once per location on the main thread (see WFCModelBuilder) and then
## treated as strictly read-only, so it can be shared by many WFCSolver
## instances running concurrently on worker threads without any locking.

# Cardinal neighbour directions and their opposites (index-aligned).
const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPPOSITE := [1, 0, 3, 2]

# 3x3 patterns. Each is a length-9 PackedInt32Array indexed as
# (colOffset + 1) * 3 + (rowOffset + 1), where offsets are in {-1, 0, 1}.
# Index 4 is therefore the centre tile.
var patterns: Array = []
var patternCount: int = 0

# Per-pattern data.
var weights: PackedFloat32Array = PackedFloat32Array()   # relative frequency
var centerTile: PackedInt32Array = PackedInt32Array()     # patterns[p][4]

# propagator[dir][pattern] -> PackedInt32Array of pattern indices that may
# occupy the neighbouring cell in that direction. Precomputed once.
var propagator: Array = []
