extends Node


const SceneManagerScript = preload("res://Nodes/Scene Manager/SceneManager.gd")


## Switches scenes through the scene manager when it is in the tree (normal
## game runs). Falls back to a direct scene change when a scene is run
## directly (F6) without the scene manager.
func changeScene(sceneKey: String, context := {}) -> void:
	var sceneManager = sceneManagerNode()
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


## Vendor navigation needs the SceneManager's captured return context (see
## Docs/System Design/Location Vendors Implementation.md). Running a vendor
## scene directly (F6) has no way back, so report that instead of loading the
## room without a return path.
func enterVendorRoom(vendorId: String, returnPosition := Vector2.ZERO) -> bool:
	var sceneManager = sceneManagerNode()
	if sceneManager == null or !sceneManager.has_method("enterVendorRoom"):
		push_warning("HelperFunctions: vendor navigation is unsupported without the Scene Manager; enter the room from a Location.")
		return false
	return bool(sceneManager.enterVendorRoom(vendorId, returnPosition))


func openVendor(vendorId: String) -> bool:
	var sceneManager = sceneManagerNode()
	if sceneManager == null or !sceneManager.has_method("openVendor"):
		push_warning("HelperFunctions: vendor menus are unsupported without the Scene Manager.")
		return false
	return bool(sceneManager.openVendor(vendorId))


func exitVendorRoom() -> bool:
	var sceneManager = sceneManagerNode()
	if sceneManager == null or !sceneManager.has_method("exitVendorRoom"):
		push_warning("HelperFunctions: vendor room return is unsupported without the Scene Manager.")
		return false
	return bool(sceneManager.exitVendorRoom())


func sceneManagerNode() -> Node:
	return get_tree().root.get_node_or_null("SceneManager")


func isOutSideTileMap(point):

	return point.x < 0 or point.y < 0 or point.x >= HelperVariables.locationChunkSize.x or point.y >= HelperVariables.locationChunkSize.y

func sortToTurnOrder(a, b) -> bool:
	return int(a.highTailin) > int(b.highTailin)
