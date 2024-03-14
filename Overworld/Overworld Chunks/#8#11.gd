extends Node2D

var locations = {
	"Lazysprings": {
		"position": Vector2i(20, 36),
		"shape": PackedVector2Array([
			Vector2i(0, -2),
			Vector2i(1, 0),
			Vector2i(0, 2),
			Vector2i(-1, 0)
		]),
		"pregenerated": true
	},
	"Clearwater Grove": {
		"position": Vector2i(28, 36),
		"shape": PackedVector2Array([
			Vector2i(0, -2),
			Vector2i(1, 0),
			Vector2i(0, 2),
			Vector2i(-1, 0)
		]),
		"pregenerated": false
	}
}
