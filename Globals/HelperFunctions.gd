extends Node


func isOutSideTileMap(point):
	return point.x < 0 or point.y < 0 or point.x >= WaveFunctionCollapse.gridSize.x or point.y >= WaveFunctionCollapse.gridSize.y
