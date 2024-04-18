extends Node


func isOutSideTileMap(point):
	return point.x < 0 or point.y < 0 or point.x >= HelperVariables.locationChunkSize.x or point.y >= HelperVariables.locationChunkSize.y

func sortToTurnOrder(a, b) -> bool:
	if a.highTailin == b.highTailin:
		if randi() % 2 == 0:
			return true
		else:
			return false
	return a.highTailin < b.highTailin
