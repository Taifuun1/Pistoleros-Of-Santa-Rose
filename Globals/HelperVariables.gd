extends Node


var overworldChunkSize = Vector2i(64, 64)
var locationChunkSize = Vector2i(24, 48)
var tileSize = Vector2i(24, 12)

var cardinalDirections = {
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
	"top": Vector2i(0, -1),
	"bottom": Vector2i(0, 1)
}
