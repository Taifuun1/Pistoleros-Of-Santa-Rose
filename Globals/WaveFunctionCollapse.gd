extends Node

var gridSize = Vector2i(24, 48)

# Raw 3x3 input patterns per input set (built by WFCInputCreation).
var inputs = {}
# Immutable WFCModel per input set (built once, shared read-only across threads).
var models = {}
# Global base seed; combined with the chunk position for deterministic output.
var baseSeed = 0

