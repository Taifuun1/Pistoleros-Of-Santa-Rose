extends Node


const SceneManagerScript = preload("res://Nodes/Scene Manager/SceneManager.gd")


## Switches scenes through the scene manager when it is in the tree (normal
## game runs). Falls back to a direct scene change when a scene is run
## directly (F6) without the scene manager.
func changeScene(sceneKey: String, context := {}) -> void:
	var sceneManager = get_tree().root.get_node_or_null("SceneManager")
	if sceneManager != null:
		sceneManager.change_scene(sceneKey, context)
		return
	if context.has("location"):
		Locations.currentLocation = context["location"]
	var scenePath: String = SceneManagerScript.SCENES[sceneKey]

	if sceneKey == "pregenerated_location":
		scenePath = scenePath.format({ "location": context.get("location", Locations.currentLocation) })
	elif sceneKey == "wfc_location":
		var locationName: String = context.get("location", Locations.currentLocation)
		scenePath = scenePath.format({ "location": locationName, "file": locationName.replace(" ", "") })
	get_tree().change_scene_to_file(scenePath)


func isOutSideTileMap(point):

	return point.x < 0 or point.y < 0 or point.x >= HelperVariables.locationChunkSize.x or point.y >= HelperVariables.locationChunkSize.y

func sortToTurnOrder(a, b) -> bool:
	return int(a.highTailin) > int(b.highTailin)
