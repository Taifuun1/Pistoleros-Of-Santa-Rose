extends Node

## Scene-run validation of the Journal map tab (Docs/System Design/Journal/
## Overworld Map.md, runtime section): markers, pan/zoom, providers, refresh
## and failure states with fake data — the tab never decodes chunks or
## bakes at runtime, so everything here is synthetic. Runs as a scene
## (TestOverworldMapTab.tscn) so Control/viewport behavior works.

const MapTabScene := preload("res://UI/Journal/Tabs/MapTab.tscn")

var testsPassed := 0
var testsFailed := 0

var tab
var mapData: OverworldMapData
var projection: OverworldMapProjection
var coordinates: OverworldCoordinates
var playerWorldPosition := Vector2.ZERO
var playerValid := true


func _ready() -> void:
	coordinates = OverworldCoordinates.makeHeadless()
	projection = OverworldMapProjection.cellForGrid(coordinates, Rect2i(0, 0, 2, 2), Vector2i(4, 4))
	mapData = _makeFakeMapData()
	tab = MapTabScene.instantiate()
	tab.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab.mapData = mapData
	tab.positionProvider = Callable(self, "_fakePositionProvider")
	tab.questMarkerProvider = Callable(self, "_fakeQuestMarkerProvider")
	add_child(tab)

	await testFailureState()
	await testBuildAndView()
	await testPanZoomFit()
	await testRefreshAndLifecycle()
	await testFocusTarget()
	await testMouseDragAndFocus()

	print("TestOverworldMapTab: %d passed, %d failed" % [testsPassed, testsFailed])
	get_tree().quit(testsFailed)


func check(condition: bool, testName: String) -> void:
	if condition:
		testsPassed += 1
		print("PASS: ", testName)
	else:
		testsFailed += 1
		print("FAIL: ", testName)


## Synthetic manifest: a tiny 2x2-chunk world with two Location anchors.
func _makeFakeMapData() -> OverworldMapData:
	var data := OverworldMapData.new()
	var image := Image.create(projection.imageSize.x, projection.imageSize.y, false, Image.FORMAT_RGBA8)
	data.texture = ImageTexture.create_from_image(image)
	data.image_size = projection.imageSize
	data.map_origin = projection.mapOrigin
	data.cell_min = projection.cellMin
	data.cell_max = projection.cellMax
	data.chunk_grid = Rect2i(0, 0, 2, 2)
	data.source_fingerprint = "fake"
	var anchorA := coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(1, 1))
	var anchorB := coordinates.chunkTileToCell(Vector2i(1, 1), Vector2i(2, 2))
	data.locations.append({
		"id": "Alpha", "display_name": "Alpha", "chunk": Vector2i(0, 0), "tile": Vector2i(1, 1),
		"cell": anchorA, "image_position": projection.cellToImage(anchorA), "icon": "location",
	})
	data.locations.append({
		"id": "Beta", "display_name": "Beta", "chunk": Vector2i(1, 1), "tile": Vector2i(2, 2),
		"cell": anchorB, "image_position": projection.cellToImage(anchorB), "icon": "location",
	})
	playerWorldPosition = coordinates.cellToWorld(anchorB)
	return data


func _fakePositionProvider() -> Dictionary:
	if !playerValid:
		return { "valid": false, "world_position": Vector2.ZERO, "is_live": false }
	return { "valid": true, "world_position": playerWorldPosition, "is_live": true }


func _fakeQuestMarkerProvider() -> Array:
	return [{ "quest_id": "q1", "objective_id": "o1", "target_id": "Alpha", "icon": "quest_current" }]


func _markerLayerChildCount() -> int:
	var markerLayer: Control = tab.find_child("MarkerLayer", true, false)
	return markerLayer.get_child_count() if markerLayer != null else -1


func testFailureState() -> void:
	print("--- Failure state ---")
	var brokenTab = MapTabScene.instantiate()
	brokenTab.set_anchors_preset(Control.PRESET_FULL_RECT)
	brokenTab.tabIcon = preload("res://Assets/Journal/MapIcon.png")
	brokenTab.mapDataPath = "res://Tests/nonexistent-map-data.tres"
	add_child(brokenTab)
	brokenTab.refreshTab()
	check(brokenTab.find_child("TabSprite", true, false) != null, "missing map data shows the regeneration state")
	check(brokenTab.find_child("BaseMap", true, false) == null, "missing map data never builds a map view")
	brokenTab.queue_free()
	await get_tree().process_frame


func testBuildAndView() -> void:
	print("--- Build and markers ---")
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab.find_child("BaseMap", true, false) != null, "the tab builds the base map view from the manifest")
	var markerLayer: Control = tab.find_child("MarkerLayer", true, false)
	check(markerLayer != null and markerLayer.get_child_count() == 4, "two POIs, one quest target and the player marker are built")
	check(tab._locationMarkers.size() == 2 and tab._questMarkers.size() == 1, "markers resolve through the manifest")
	var alphaMarker: TextureButton = tab._locationMarkers["Alpha"]
	check(alphaMarker != null and alphaMarker.tooltip_text == "Alpha", "POI markers carry their display name")
	var expectedImage: Vector2 = projection.cellToImage(coordinates.chunkTileToCell(Vector2i(0, 0), Vector2i(1, 1)))
	check((alphaMarker.get_meta("image_position") as Vector2).distance_to(expectedImage) < 0.01, "the POI marker sits at its projected anchor")
	var playerMarker: TextureButton = tab._playerMarker
	check(playerMarker != null and playerMarker.visible, "a valid player position shows the player marker")
	var expectedPlayerImage: Vector2 = projection.cellFractionToImage(coordinates.worldToCellFraction(playerWorldPosition))
	check((playerMarker.get_meta("image_position") as Vector2).distance_to(expectedPlayerImage) < 0.01, "the player marker projects through the same pipeline")


func testPanZoomFit() -> void:
	print("--- Pan, zoom, fit, center ---")
	var alphaMarker: TextureButton = tab._locationMarkers["Alpha"]
	var clipSize: Vector2 = tab._mapClip.size
	var expectedFit := minf(clipSize.x / mapData.image_size.x, clipSize.y / mapData.image_size.y)
	check(absf(tab._fitScale - expectedFit) < 0.001, "fit scale is min(available/image) after layout")
	check(absf(tab._mapScale - expectedFit) < 0.001, "the first open fits the whole map")
	check(absf(alphaMarker.scale.x * tab._mapScale - 1.0) < 0.001, "markers counter-scale to a constant screen size at fit")
	tab._zoomAt(clipSize * 0.5, 4.0)
	check(absf(alphaMarker.scale.x * tab._mapScale - 1.0) < 0.001, "markers keep that size while zooming")
	var anchor: Vector2 = clipSize * 0.5
	var imageBefore: Vector2 = (anchor - tab._mapContent.position) / tab._mapScale
	tab._zoomAt(anchor, 2.0)
	var imageAfter: Vector2 = (anchor - tab._mapContent.position) / tab._mapScale
	check(imageBefore.distance_to(imageAfter) < 0.01, "zooming keeps the anchor point under the cursor")
	check(absf(tab._mapScale - expectedFit * 8.0) < 0.001, "zoom is clamped to the fit-relative range")
	var mapSize: Vector2 = Vector2(mapData.image_size) * tab._mapScale
	tab._panBy(Vector2(100000, 100000))
	check(absf(tab._mapContent.position.x - maxf(0.0, clipSize.x - mapSize.x)) < 0.01 and absf(tab._mapContent.position.y - maxf(0.0, clipSize.y - mapSize.y)) < 0.01, "panning far right/down clamps at the map edges")
	tab._panBy(Vector2(-100000, -100000))
	check(tab._mapContent.position.x <= minf(0.0, clipSize.x - mapSize.x) + 0.01 and tab._mapContent.position.y <= minf(0.0, clipSize.y - mapSize.y) + 0.01, "panning far left/up clamps at the opposite edges")
	check(tab._mapContent.position.x >= minf(0.0, clipSize.x - mapSize.x) - 0.01, "the left edge is reachable")
	var imagePosition: Vector2 = alphaMarker.get_meta("image_position")
	var textureSize: Vector2 = alphaMarker.texture_normal.get_size()
	var anchorLocal := Vector2(textureSize.x * alphaMarker.scale.x * 0.5, textureSize.y * alphaMarker.scale.x)
	check((alphaMarker.position + anchorLocal - imagePosition).length() < 0.01, "markers stay anchored bottom-center on their projected position")
	var contentBefore: Vector2 = tab._mapContent.position
	tab._onMapClipGuiInput(_keyEvent(KEY_LEFT))
	check(absf(tab._mapContent.position.x - contentBefore.x - 48.0) < 0.01, "the focused clip pans with the arrow keys")
	tab._onMapClipGuiInput(_keyEvent(KEY_F))
	check(absf(tab._mapScale - expectedFit) < 0.001, "F refits the whole map")


func _keyEvent(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func testRefreshAndLifecycle() -> void:
	print("--- Refresh and lifecycle ---")
	var markerLayer: Control = tab.find_child("MarkerLayer", true, false)
	var childCount := markerLayer.get_child_count()
	var timerCount := 0
	for child in tab.get_children():
		if child is Timer:
			timerCount += 1
	check(timerCount == 1, "exactly one refresh timer exists")
	tab.refreshTab()
	tab.setTabActive(true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(markerLayer.get_child_count() == childCount, "repeated refresh does not duplicate markers")
	check(tab._refreshTimer != null and !tab._refreshTimer.is_stopped(), "activation starts the player refresh timer")
	check(tab._playerPulse != null, "activation pulses the player marker")
	tab.setTabActive(false)
	check(tab._refreshTimer.is_stopped(), "deactivation stops the refresh timer")
	check(tab._playerPulse == null and absf(tab._playerMarker.modulate.a - 1.0) < 0.001, "deactivation kills the pulse and restores the marker")
	playerValid = false
	tab._refreshPlayerMarker()
	check(!tab._playerMarker.visible, "an invalid position hides the player marker")
	playerValid = true
	tab.questMarkerProvider = Callable(self, "_secondQuestMarkerProvider")
	tab._refreshQuestMarkers()
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._questMarkers.size() == 1 and tab._questMarkers.has("Beta"), "quest provider changes swap markers through the manifest")
	check(markerLayer.get_child_count() == childCount, "marker swaps do not duplicate nodes")
	tab.questMarkerProvider = Callable(self, "_ghostQuestMarkerProvider")
	tab._refreshQuestMarkers()
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._questMarkers.is_empty(), "unknown quest targets produce no marker")


func _secondQuestMarkerProvider() -> Array:
	return [{ "quest_id": "q2", "objective_id": "o2", "target_id": "Beta", "icon": "quest_current" }]


func _ghostQuestMarkerProvider() -> Array:
	return [{ "quest_id": "q3", "objective_id": "o3", "target_id": "Ghost", "icon": "quest_current" }]


func testFocusTarget() -> void:
	print("--- Show on map ---")
	tab.questMarkerProvider = Callable(self, "_fakeQuestMarkerProvider")
	tab._refreshQuestMarkers()
	await get_tree().process_frame
	await get_tree().process_frame
	var alphaMarker: TextureButton = tab._locationMarkers["Alpha"]
	var expectedImage: Vector2 = alphaMarker.get_meta("image_position")
	tab.focusTarget("Alpha")
	check(tab._selectionPanel != null and tab._selectionPanel.visible and tab._selectionLabel.text.contains("Alpha"), "'Show on map' selects the target marker")
	var clipCenter: Vector2 = tab._mapClip.size * 0.5
	var markerScreen: Vector2 = tab._mapContent.position + expectedImage * tab._mapScale
	check(markerScreen.distance_to(clipCenter) < 260.0, "'Show on map' centers the target (within pan clamp reach)")
	check(tab._questMarkers.size() == 1, "quest markers survive navigation")
	tab.focusTarget("Ghost")
	check(!tab._selectionLabel.text.contains("Ghost"), "unknown targets navigate nowhere without crashing")


## Driven through Input.parse_input_event so the polling drag, focus policy
## and unhandled-key fallback are validated like real input, not direct calls.
func testMouseDragAndFocus() -> void:
	print("--- Mouse drag and focus ---")
	tab.setTabActive(true)
	await get_tree().process_frame
	var clipRect: Rect2 = tab._mapClip.get_global_rect()
	check(clipRect.size.x > 10.0 and clipRect.size.y > 10.0, "the map clip is laid out")
	var dragStart: Vector2 = clipRect.position + clipRect.size * 0.5
	var contentBefore: Vector2 = tab._mapContent.position
	Input.parse_input_event(_mouseButtonEvent(dragStart, true))
	await get_tree().process_frame
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "parsed presses reach the Input singleton")
	for step in 3:
		Input.parse_input_event(_mouseMotionEvent(dragStart + Vector2((step + 1) * 15.0, 0.0), Vector2(15.0, 0.0)))
		await get_tree().process_frame
	Input.parse_input_event(_mouseButtonEvent(dragStart + Vector2(45.0, 0.0), false))
	await get_tree().process_frame
	await get_tree().process_frame
	check(absf(tab._mapContent.position.x - contentBefore.x - 45.0) < 0.01, "holding left over the map and moving pans by the cursor delta")
	check(absf(tab._mapContent.position.y - contentBefore.y) < 0.01, "a horizontal drag does not move vertically")
	check(!tab._dragging, "releasing the button ends the drag")

	var controlButtonsUnfocusable := true
	for child in tab.find_child("MapControls", true, false).get_children():
		controlButtonsUnfocusable = controlButtonsUnfocusable and child.focus_mode == Control.FOCUS_NONE
	check(controlButtonsUnfocusable, "shortcut buttons never join arrow focus traversal")
	check(tab._playerMarker != null and tab._playerMarker.focus_mode == Control.FOCUS_NONE, "markers never join arrow focus traversal")

	tab._mapClip.grab_focus()
	await get_tree().process_frame
	var panBefore: Vector2 = tab._mapContent.position
	Input.parse_input_event(_keyEvent(KEY_LEFT))
	await get_tree().process_frame
	await get_tree().process_frame
	check(absf(tab._mapContent.position.x - panBefore.x - 48.0) < 0.01, "arrow keys pan the focused clip through gui_input")
	var focusOwner := get_viewport().gui_get_focus_owner()
	check(focusOwner != null and focusOwner.name == "MapClip", "arrows never move focus off the map onto controls")

	if focusOwner != null:
		focusOwner.release_focus()
	await get_tree().process_frame
	var panBeforeFallback: Vector2 = tab._mapContent.position
	Input.parse_input_event(_keyEvent(KEY_LEFT))
	await get_tree().process_frame
	await get_tree().process_frame
	check(absf(tab._mapContent.position.x - panBeforeFallback.x - 48.0) < 0.01, "unhandled arrow keys still pan when nothing is focused")


func _mouseButtonEvent(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _mouseMotionEvent(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event