extends Node


func isOutSideTileMap(point):
	return point.x < 0 or point.y < 0 or point.x >= HelperVariables.locationChunkSize.x or point.y >= HelperVariables.locationChunkSize.y
