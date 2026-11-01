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
	await testManifestValidation()
	await testBuildAndView()
	await testPanZoomFit()
	await testOverviewLod()
	await testNonMouseInput()
	await testRefreshAndLifecycle()
	await testDisposalAndRebuild()
	await testFocusTarget()
	await testMouseDragAndFocus()
	await testPlayerPositionProvider()

	print("TestOverworldMapTab: %d passed, %d failed" % [testsPassed, testsFailed])
	coordinates.dispose()
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
	data.format_version = OverworldMapData.FORMAT_VERSION
	var image := Image.create(projection.imageSize.x, projection.imageSize.y, false, Image.FORMAT_RGBA8)
	data.texture = ImageTexture.create_from_image(image)
	data.image_size = projection.imageSize
	var overviewImage := Image.create(projection.imageSize.x / 4, projection.imageSize.y / 4, false, Image.FORMAT_RGBA8)
	data.overview_texture = ImageTexture.create_from_image(overviewImage)
	data.overview_image_size = overviewImage.get_size()
	data.map_orientation = projection.orientation
	data.map_origin = projection.mapOrigin
	data.pixels_per_cell = projection.pixelsPerCell
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
	check(brokenTab.getFocusTarget() == null, "the regeneration state exposes no focus target")
	brokenTab.queue_free()
	await get_tree().process_frame


func testManifestValidation() -> void:
	print("--- Manifest validation ---")
	check(tab._isMapDataValid(mapData), "the valid synthetic manifest passes validation")
	var invalidOrigin: OverworldMapData = mapData.duplicate(true)
	invalidOrigin.map_origin += Vector2.ONE
	check(!tab._isMapDataValid(invalidOrigin), "a map origin that disagrees with cell bounds is rejected")
	var invalidScale: OverworldMapData = mapData.duplicate(true)
	invalidScale.pixels_per_cell = Vector2.ONE
	check(!tab._isMapDataValid(invalidScale), "an incompatible pixels-per-cell value is rejected")
	var invalidOrientation: OverworldMapData = mapData.duplicate(true)
	invalidOrientation.map_orientation = 99
	check(!tab._isMapDataValid(invalidOrientation), "an unknown map orientation is rejected")
	var invalidTexture: OverworldMapData = mapData.duplicate(true)
	invalidTexture.texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	check(!tab._isMapDataValid(invalidTexture), "a texture whose size differs from image_size is rejected")
	var invalidOverview: OverworldMapData = mapData.duplicate(true)
	invalidOverview.overview_image_size = Vector2i(3, 3)
	invalidOverview.overview_texture = ImageTexture.create_from_image(Image.create(3, 3, false, Image.FORMAT_RGBA8))
	check(!tab._isMapDataValid(invalidOverview), "an overview that does not divide image_size is rejected")
	var invalidPoi: OverworldMapData = mapData.duplicate(true)
	invalidPoi.locations[0]["image_position"] += Vector2.ONE
	check(!tab._isMapDataValid(invalidPoi), "a POI image position that disagrees with its cell is rejected")
	var duplicatePoi: OverworldMapData = mapData.duplicate(true)
	duplicatePoi.locations[1]["id"] = duplicatePoi.locations[0]["id"]
	check(!tab._isMapDataValid(duplicatePoi), "duplicate POI ids are rejected")

	# The checked-in artifact itself must satisfy the runtime contract.
	var committedTab = MapTabScene.instantiate()
	add_child(committedTab)
	var committed: OverworldMapData = committedTab._loadMapData()
	check(committed != null and committedTab._isMapDataValid(committed), "the committed generated manifest passes runtime validation")
	check(committed != null and committed.map_orientation == OverworldMapProjection.SHIPPED_ORIENTATION, "the committed manifest records the shipped orientation")
	committedTab.queue_free()
	await get_tree().process_frame


func testBuildAndView() -> void:
	print("--- Build and markers ---")
	tab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab.find_child("BaseMap", true, false) != null, "the tab builds the base map view from the manifest")
	check(tab.getFocusTarget() == tab._mapClip, "the map tab exposes the map clip as its shell focus target")
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


func testOverviewLod() -> void:
	print("--- Overview LOD ---")
	check(mapData.overview_texture != null, "the fake manifest carries an overview")
	tab._fitMap()
	check(tab._baseMap.texture == mapData.overview_texture, "the generalized overview is used at fit scale")
	check(tab._baseMap.scale.is_equal_approx(Vector2(mapData.image_size) / Vector2(mapData.overview_image_size)), "the overview is drawn in the detailed map's coordinate space")
	tab._zoomAt(tab._mapClip.size * 0.5, 4.0)
	check(tab._baseMap.texture == mapData.texture, "zooming in switches to the detailed map")
	tab._fitMap()
	check(tab._baseMap.texture == mapData.overview_texture, "fitting again switches back to the overview")


## Step 5: keyboard and controller operation — zoom actions, POI cycling, real
## wheel delivery, and the map filling the tab with the controls overlaid.
func testNonMouseInput() -> void:
	print("--- Non-mouse input ---")
	tab.setTabActive(true)
	await get_tree().process_frame
	check(tab._mapClip.size.is_equal_approx(tab.size), "the map clip fills the whole tab content area")
	var controls: Control = tab.find_child("MapControls", true, false)
	check(controls != null and tab._mapClip.get_global_rect().encloses(controls.get_global_rect()), "the shortcut controls overlay the map instead of taking their own row")

	tab._fitMap()
	await get_tree().process_frame
	var clipRect: Rect2 = tab._mapClip.get_global_rect()
	var centre: Vector2 = clipRect.position + clipRect.size * 0.5

	var scaleBefore: float = tab._mapScale
	Input.parse_input_event(_wheelEvent(centre, MOUSE_BUTTON_WHEEL_UP))
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._mapScale > scaleBefore, "the mouse wheel zooms the map over the base texture")

	tab._fitMap()
	scaleBefore = tab._mapScale
	Input.parse_input_event(_keyEvent(KEY_EQUAL))
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._mapScale > scaleBefore, "the zoom-in key zooms the map")
	var zoomedIn: float = tab._mapScale
	Input.parse_input_event(_keyEvent(KEY_MINUS))
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._mapScale < zoomedIn, "the zoom-out key zooms the map")

	tab._fitMap()
	scaleBefore = tab._mapScale
	Input.parse_input_event(_joypadEvent(JOY_BUTTON_RIGHT_SHOULDER))
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._mapScale > scaleBefore, "the controller shoulder button zooms in")
	Input.parse_input_event(_joypadEvent(JOY_BUTTON_LEFT_SHOULDER))
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(tab._mapScale, tab._fitScale), "zooming out with the controller reaches fit scale")

	tab._poiFocusIndex = -1
	check(tab._poiFocusOrder.size() == mapData.locations.size(), "the POI cycle order lists every Location")
	tab._focusRelativePoi(1)
	check(tab._selectionPanel.visible and tab._selectionLabel.text.contains(tab._poiFocusOrder[0]), "cycling selects the first POI")
	tab._focusRelativePoi(1)
	check(tab._selectionLabel.text.contains(tab._poiFocusOrder[1]), "cycling advances to the next POI")
	tab._focusRelativePoi(1)
	check(tab._poiFocusIndex == 0, "POI cycling wraps past the last POI")
	tab._focusRelativePoi(-1)
	check(tab._poiFocusIndex == tab._poiFocusOrder.size() - 1, "POI cycling wraps backwards past the first POI")

	tab._poiFocusIndex = -1
	Input.parse_input_event(_keyEvent(KEY_BRACKETRIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._selectionPanel.visible and tab._selectionLabel.text.contains(tab._poiFocusOrder[0]), "the POI key cycles through the map input path")
	Input.parse_input_event(_joypadEvent(JOY_BUTTON_Y))
	await get_tree().process_frame
	await get_tree().process_frame
	check(tab._selectionLabel.text.contains(tab._poiFocusOrder[1]), "the controller button cycles POIs")

	tab._mapClip.grab_focus()
	await get_tree().process_frame
	var focusOwner := get_viewport().gui_get_focus_owner()
	check(focusOwner != null and focusOwner.name == "MapClip", "the map clip keeps focus while cycling POIs")
	if focusOwner != null:
		focusOwner.release_focus()
	await get_tree().process_frame


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


func testDisposalAndRebuild() -> void:
	print("--- Disposal and rebuild ---")
	var rebuildTab = MapTabScene.instantiate()
	rebuildTab.set_anchors_preset(Control.PRESET_FULL_RECT)
	rebuildTab.tabIcon = preload("res://Assets/Journal/MapIcon.png")
	rebuildTab.mapData = mapData
	rebuildTab.positionProvider = Callable(self, "_fakePositionProvider")
	add_child(rebuildTab)
	rebuildTab.refreshTab()
	rebuildTab.setTabActive(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var oldTimer: Timer = rebuildTab._refreshTimer
	var oldView: Control = rebuildTab._view
	rebuildTab._disposeView()
	await get_tree().process_frame
	await get_tree().process_frame
	check(!is_instance_valid(oldTimer), "disposal frees the direct-child refresh timer")
	check(!is_instance_valid(oldView), "disposal frees the old map view")
	check(rebuildTab._refreshTimer == null and rebuildTab._playerPulse == null, "disposal clears runtime timer and tween state")
	rebuildTab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame
	check(rebuildTab._built and rebuildTab._refreshTimer != null, "a disposed tab rebuilds with one fresh timer")
	var rebuiltTimer: Timer = rebuildTab._refreshTimer
	rebuildTab.mapData = null
	rebuildTab.mapDataPath = "res://Tests/nonexistent-map-data.tres"
	rebuildTab.refreshTab()
	await get_tree().process_frame
	await get_tree().process_frame
	check(!is_instance_valid(rebuiltTimer), "a later data failure also frees the rebuilt timer")
	check(rebuildTab.find_child("TabSprite", true, false) != null, "a later data failure leaves the regeneration state")
	rebuildTab.queue_free()
	await get_tree().process_frame


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
	var mapSize: Vector2 = Vector2(mapData.image_size) * tab._mapScale
	var clipSize: Vector2 = tab._mapClip.size
	var idealPosition: Vector2 = clipCenter - expectedImage * tab._mapScale
	var expectedPosition := Vector2(
		clampf(idealPosition.x, minf(0.0, clipSize.x - mapSize.x), maxf(0.0, clipSize.x - mapSize.x)),
		clampf(idealPosition.y, minf(0.0, clipSize.y - mapSize.y), maxf(0.0, clipSize.y - mapSize.y))
	)
	check(tab._mapContent.position.distance_to(expectedPosition) < 0.01, "'Show on map' centers the target as far as pan clamping allows")
	check(tab._mapScale > tab._fitScale, "'Show on map' zooms in on the target")
	check(Rect2(Vector2.ZERO, clipSize).has_point(markerScreen), "the focused marker is visible inside the map clip")
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
	# Fit scale leaves no pan slack on the shipped 2:1 map, so pan interactions
	# are exercised from a zoomed view like a player inspecting terrain.
	tab._zoomAt(clipRect.size * 0.5, 4.0)
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


func _wheelEvent(position: Vector2, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	return event


func _joypadEvent(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


## The step-6 player position provider against the real Overworld autoload:
## spawn fallback, exact last-known retention, spawn reseeding (re-entry
## unification), live registration, and the tab's default provider wiring.
## Autoload state is saved and restored afterwards.
func testPlayerPositionProvider() -> void:
	print("--- Player position provider ---")
	var overworldAutoload = get_tree().root.get_node_or_null("Overworld")
	check(overworldAutoload != null, "the Overworld autoload is available in scene-run tests")
	if overworldAutoload == null:
		return
	var savedChunk: Vector2i = overworldAutoload.spawnChunk
	var savedTile: Vector2i = overworldAutoload.spawnTile
	var savedLastKnown: Vector2 = overworldAutoload._lastKnownPosition
	var savedHasLastKnown: bool = overworldAutoload._hasLastKnownPosition
	var savedLiveActor = overworldAutoload._livePlayerActor

	var initial: Dictionary = overworldAutoload.getOverworldMapPosition()
	var initialExpected: Vector2 = coordinates.chunkTileToWorld(overworldAutoload.spawnChunk, overworldAutoload.spawnTile)
	check(initial["valid"] and !initial["is_live"], "with no exact state yet the provider falls back to the spawn anchor")
	check((initial["world_position"] as Vector2).distance_to(initialExpected) < 0.01, "the fallback is the spawn anchor, never (0,0)")

	var lazyspringsWorld: Vector2 = coordinates.cellToWorld(Vector2i(530, 1122))
	overworldAutoload.storeLastKnownPlayerPosition(lazyspringsWorld)
	var stored: Dictionary = overworldAutoload.getOverworldMapPosition()
	check(stored["valid"] and !stored["is_live"] and (stored["world_position"] as Vector2).distance_to(lazyspringsWorld) < 0.01, "a stored position is returned exactly as last-known")
	check(overworldAutoload.spawnChunk == Vector2i(8, 17) and overworldAutoload.spawnTile == Vector2i(20, 36), "storing reseeds the spawn anchor to the stored position's chunk/tile")

	var liveActor := Node2D.new()
	liveActor.name = "FakePlayerActor"
	add_child(liveActor)
	liveActor.global_position = coordinates.cellToWorld(Vector2i(550, 804))
	overworldAutoload.registerLivePlayer(liveActor)
	var live: Dictionary = overworldAutoload.getOverworldMapPosition()
	check(live["valid"] and live["is_live"] and (live["world_position"] as Vector2) == liveActor.global_position, "a registered actor provides the live position")
	liveActor.global_position = coordinates.cellToWorld(Vector2i(551, 805))
	var liveMoved: Dictionary = overworldAutoload.getOverworldMapPosition()
	check((liveMoved["world_position"] as Vector2) == liveActor.global_position, "the live position follows the actor")

	overworldAutoload.clearLivePlayer()
	var lastKnown: Dictionary = overworldAutoload.getOverworldMapPosition()
	check(lastKnown["valid"] and !lastKnown["is_live"] and (lastKnown["world_position"] as Vector2) == liveActor.global_position, "clearing the live player snapshots its exact final position")
	check(overworldAutoload.spawnChunk == Vector2i(8, 12) and overworldAutoload.spawnTile == Vector2i(41, 39), "the spawn anchor tracks the snapshotted cell")
	var reentryPlacement: Vector2 = coordinates.chunkTileToWorld(overworldAutoload.spawnChunk, overworldAutoload.spawnTile)
	check(reentryPlacement.distance_to(coordinates.cellToWorld(Vector2i(551, 805))) < 0.01, "re-entry from the reseeded anchor places the player back at the same tile, not a default spawn")

	# Off-center exit: the last-known marker keeps the exact position, while
	# re-entry must use the containing tile rather than flooring the fraction.
	var offCenterCell := Vector2i(550, 804)
	var offCenterWorld: Vector2 = coordinates.cellToWorld(offCenterCell) + Vector2(0, -1)
	var containingCell: Vector2i = coordinates._templateMap.local_to_map(coordinates._templateMap.to_local(offCenterWorld))
	var containingAnchor: Dictionary = coordinates.cellToChunkTile(containingCell)
	liveActor.global_position = offCenterWorld
	overworldAutoload.registerLivePlayer(liveActor)
	overworldAutoload.clearLivePlayer()
	var offCenterLastKnown: Dictionary = overworldAutoload.getOverworldMapPosition()
	check((offCenterLastKnown["world_position"] as Vector2) == offCenterWorld, "an off-center exit retains the exact last-known position")
	check(overworldAutoload.spawnChunk == containingAnchor["chunk"] and overworldAutoload.spawnTile == containingAnchor["tile"], "an off-center exit reseeds re-entry to its containing tile, not the neighboring cell")
	var offCenterReentry: Vector2 = coordinates.chunkTileToWorld(overworldAutoload.spawnChunk, overworldAutoload.spawnTile)
	check(offCenterReentry.distance_to(coordinates.cellToWorld(containingCell)) < 0.01, "off-center re-entry places the player at the containing tile's center")
	liveActor.queue_free()

	# The map tab's default provider wires straight into the autoload API.
	tab.positionProvider = Callable()
	tab._refreshPlayerMarker()
	check(tab._playerMarker != null and tab._playerMarker.visible, "the default provider shows the player marker")
	var expectedImage: Vector2 = projection.cellFractionToImage(coordinates.worldToCellFraction(overworldAutoload.getOverworldMapPosition()["world_position"]))
	check((tab._playerMarker.get_meta("image_position") as Vector2).distance_to(expectedImage) < 0.01, "the default provider's marker projects through the shared pipeline")

	overworldAutoload.spawnChunk = savedChunk
	overworldAutoload.spawnTile = savedTile
	overworldAutoload._lastKnownPosition = savedLastKnown
	overworldAutoload._hasLastKnownPosition = savedHasLastKnown
	overworldAutoload._livePlayerActor = savedLiveActor
	tab.positionProvider = Callable(self, "_fakePositionProvider")